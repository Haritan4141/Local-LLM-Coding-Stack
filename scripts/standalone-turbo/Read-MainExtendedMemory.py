"""Read-only MAIN memory gate for the RTX 5090 extended-context candidate.

This probe deliberately has no LM Studio, loader, model, power-setting, or
process-control path.  It combines the exact DXGI adapter LUID with the live
Win32 GPU performance-counter row, then verifies the pinned MAIN identity via
``nvidia-smi``.  The JSON row matches the BLUE extended-memory probe schema so
the managed runtime gate can consume either host's result.
"""

from __future__ import annotations

import base64
import ctypes as c
import json
from datetime import datetime, timezone
import math
import re
import socket
import subprocess
import sys
import uuid


EXPECTED_HOST = "DESKTOP-5NPLIIV"
EXPECTED_GPU = {
    "name": "NVIDIA GeForce RTX 5090",
    "bus": "00000000:01:00.0",
    "uuid": "GPU-8dc7cc4e-ecb6-2e20-59d3-3d5acca86a8b",
    "power_w": 402,
    "total_mib": 32607,
}
STRICT_PER_GPU_SHARED_BYTES = 2 * 1024**3
STRICT_ALL_ADAPTER_SHARED_BYTES = 4 * 1024**3
MIN_HEADROOM_MIB = 1024
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ps_json() -> dict:
    """Read NVIDIA, DXGI-counter, and system-memory telemetry only."""
    script = r"""
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
if ($env:COMPUTERNAME -ne 'DESKTOP-5NPLIIV') { throw 'MAIN-only telemetry.' }
$rows = @(& nvidia-smi '--query-gpu=uuid,name,pci.bus_id,memory.total,memory.used,memory.free,temperature.gpu,power.limit' '--format=csv,noheader,nounits')
if ($LASTEXITCODE -ne 0) { throw 'NVIDIA telemetry failed.' }
$gpus = @($rows | ConvertFrom-Csv -Header uuid,name,bus,total_mib,used_mib,free_mib,temperature_c,power_w)
$memory = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory |
    Select-Object Name,DedicatedUsage,SharedUsage,TotalCommitted)
$os = Get-CimInstance Win32_OperatingSystem
[ordered]@{
    recorded_at_utc = [DateTime]::UtcNow.ToString('o')
    gpus = $gpus
    adapters = $memory
    ram_free_bytes = [int64]$os.FreePhysicalMemory * 1024
    ram_total_bytes = [int64]$os.TotalVisibleMemorySize * 1024
} | ConvertTo-Json -Depth 6 -Compress
"""
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    result = subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-EncodedCommand",
            encoded,
        ],
        capture_output=True,
        creationflags=NO_WINDOW,
        timeout=40,
        check=False,
    )
    if result.returncode:
        detail = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError("Read-only PowerShell telemetry failed: " + detail[:600])
    try:
        return json.loads(result.stdout.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError("Read-only telemetry returned invalid JSON.") from error


def _luid_text(luid) -> str:
    return f"luid_0x{luid.high & 0xffffffff:08x}_0x{luid.low:08x}_phys_0"


def dxgi_adapters() -> list[dict]:
    """Return DXGI adapter descriptions with live-compatible LUID text.

    This is the same IDXGIFactory1 / adapter LUID technique used by the BLUE
    qualification.  Adapter index is never used as GPU identity.
    """

    class GUID(c.Structure):
        _fields_ = [("bytes", c.c_ubyte * 16)]

    class LUID(c.Structure):
        _fields_ = [("low", c.c_uint32), ("high", c.c_int32)]

    class DESC(c.Structure):
        _fields_ = [
            ("description", c.c_wchar * 128),
            ("vendor", c.c_uint32),
            ("device", c.c_uint32),
            ("subsys", c.c_uint32),
            ("revision", c.c_uint32),
            ("dedicated_video", c.c_size_t),
            ("dedicated_system", c.c_size_t),
            ("shared_system", c.c_size_t),
            ("luid", LUID),
            ("flags", c.c_uint32),
        ]

    def method(obj, index, *args):
        address = c.cast(obj, c.POINTER(c.POINTER(c.c_void_p)))[0][index]
        return c.WINFUNCTYPE(c.c_long, c.c_void_p, *args)(address)

    guid = GUID(
        (c.c_ubyte * 16).from_buffer_copy(
            uuid.UUID("770aae78-f26f-4dba-a829-253c83d1b387").bytes_le
        )
    )
    factory = c.c_void_p()
    dll = c.WinDLL("dxgi.dll")
    dll.CreateDXGIFactory1.argtypes = [c.POINTER(GUID), c.POINTER(c.c_void_p)]
    dll.CreateDXGIFactory1.restype = c.c_long
    if dll.CreateDXGIFactory1(c.byref(guid), c.byref(factory)) != 0:
        raise RuntimeError("DXGI factory failed.")
    rows = []
    try:
        enum = method(factory, 12, c.c_uint, c.POINTER(c.c_void_p))
        for index in range(16):
            adapter = c.c_void_p()
            status = enum(factory, index, c.byref(adapter))
            if status != 0:
                break
            try:
                desc = DESC()
                if method(adapter, 10, c.POINTER(DESC))(adapter, c.byref(desc)) != 0:
                    raise RuntimeError("DXGI descriptor failed.")
                rows.append(
                    {
                        "name": desc.description,
                        "vendor": desc.vendor,
                        "dedicated_bytes": desc.dedicated_video,
                        "instance": _luid_text(desc.luid),
                    }
                )
            finally:
                method(adapter, 2)(adapter)
    finally:
        method(factory, 2)(factory)
    return rows


def _finite_nonnegative(value, field: str):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"Missing/invalid {field} telemetry.")
    if not math.isfinite(float(value)) or value < 0:
        raise ValueError(f"Missing/invalid {field} telemetry.")


def validate(row: dict) -> dict:
    """Validate a captured MAIN row without touching live state."""
    if not isinstance(row, dict) or len(row.get("gpus", [])) != 1:
        raise ValueError("Expected one exactly identified MAIN GPU.")
    gpu = row["gpus"][0]
    if gpu.get("name") != EXPECTED_GPU["name"]:
        raise ValueError("MAIN GPU identity mismatch.")
    if (
        gpu.get("bus"),
        gpu.get("uuid"),
        gpu.get("power_w"),
    ) != (
        EXPECTED_GPU["bus"],
        EXPECTED_GPU["uuid"],
        EXPECTED_GPU["power_w"],
    ):
        raise ValueError("MAIN GPU bus/UUID/power mismatch.")
    luid = gpu.get("luid")
    if not isinstance(luid, str) or not re.fullmatch(
        r"luid_0x[0-9a-f]{8}_0x[0-9a-f]{8}_phys_0", luid
    ):
        raise ValueError("Missing/ambiguous exact live LUID telemetry.")
    for field in (
        "shared_bytes",
        "dedicated_bytes",
        "headroom_mib",
        "used_mib",
        "temperature_c",
    ):
        _finite_nonnegative(gpu.get(field), field)
    total = row.get("all_adapter_shared_bytes")
    if isinstance(total, bool) or not isinstance(total, int) or total < gpu["shared_bytes"]:
        raise ValueError("Missing/inconsistent total Shared telemetry.")
    if total >= STRICT_ALL_ADAPTER_SHARED_BYTES:
        raise ValueError("all-adapter Shared must be strictly below 4 GiB.")
    if gpu["shared_bytes"] >= STRICT_PER_GPU_SHARED_BYTES:
        raise ValueError("MAIN GPU Shared must be strictly below 2 GiB.")
    if gpu["headroom_mib"] < MIN_HEADROOM_MIB:
        raise ValueError("MAIN GPU free VRAM below 1 GiB.")
    if gpu["used_mib"] + gpu["headroom_mib"] > EXPECTED_GPU["total_mib"]:
        raise ValueError("Inconsistent MAIN GPU used/free capacity telemetry.")
    return row


def memory(adapters: list[dict]) -> dict:
    """Join pinned NVIDIA telemetry to exactly one live DXGI/PDH LUID."""
    if len(adapters) == 0:
        raise RuntimeError("No DXGI adapters detected.")
    nvidia = [
        adapter
        for adapter in adapters
        if adapter.get("vendor") == 0x10DE
    ]
    exact_dxgi = [
        adapter
        for adapter in nvidia
        if adapter.get("name") == EXPECTED_GPU["name"]
    ]
    live = _ps_json()
    gpus = live.get("gpus")
    if not isinstance(gpus, list) or len(gpus) != 1:
        raise RuntimeError("Expected exactly one unambiguous MAIN NVIDIA telemetry row.")
    observed = gpus[0]
    if (
        observed.get("name", "").strip(),
        observed.get("bus", "").strip(),
        observed.get("uuid", "").strip(),
    ) != (
        EXPECTED_GPU["name"],
        EXPECTED_GPU["bus"],
        EXPECTED_GPU["uuid"],
    ):
        raise RuntimeError("MAIN nvidia-smi GPU identity mismatch.")
    try:
        total_mib = int(float(observed["total_mib"]))
        used_mib = float(observed["used_mib"])
        free_mib = float(observed["free_mib"])
        temperature_c = float(observed["temperature_c"])
        power_w = float(observed["power_w"])
    except (KeyError, TypeError, ValueError) as error:
        raise RuntimeError("Missing/invalid MAIN nvidia-smi telemetry.") from error
    if total_mib != EXPECTED_GPU["total_mib"] or power_w != EXPECTED_GPU["power_w"]:
        raise RuntimeError("MAIN GPU capacity/power telemetry mismatch.")
    counters = live.get("adapters")
    if not isinstance(counters, list):
        raise RuntimeError("Missing GPU performance-counter telemetry.")
    live_dxgi = [
        adapter
        for adapter in exact_dxgi
        if sum(
            1
            for counter in counters
            if isinstance(counter, dict)
            and str(counter.get("Name", "")).lower() == adapter["instance"].lower()
        )
        == 1
    ]
    if len(live_dxgi) != 1:
        raise RuntimeError("Exact live NVIDIA DXGI LUID mapping missing or ambiguous.")
    exact_adapter = live_dxgi[0]
    matching = [
        counter
        for counter in counters
        if isinstance(counter, dict)
        and str(counter.get("Name", "")).lower() == exact_adapter["instance"].lower()
    ]
    if len(matching) != 1:
        raise RuntimeError("Exact live DXGI LUID counter mapping missing or ambiguous.")
    counter = matching[0]
    try:
        dedicated_bytes = int(counter["DedicatedUsage"])
        shared_bytes = int(counter["SharedUsage"])
    except (KeyError, TypeError, ValueError) as error:
        raise RuntimeError("Missing/invalid live GPU memory counters.") from error
    row = {
        "at_utc": utc(),
        "gpus": [
            {
                "name": EXPECTED_GPU["name"],
                "uuid": EXPECTED_GPU["uuid"],
                "bus": EXPECTED_GPU["bus"],
                "power_w": EXPECTED_GPU["power_w"],
                "used_mib": used_mib,
                # Actual available VRAM excludes driver reservations; total-used
                # is not a safe substitute for NVIDIA's memory.free reading.
                "headroom_mib": free_mib,
                "capacity_minus_used_mib": total_mib - used_mib,
                "temperature_c": temperature_c,
                "luid": exact_adapter["instance"],
                "dedicated_bytes": dedicated_bytes,
                "shared_bytes": shared_bytes,
            }
        ],
        "combined_shared_bytes": shared_bytes,
        "all_adapter_shared_bytes": sum(
            int(counter.get("SharedUsage", 0)) for counter in counters
        ),
        "ram_free_bytes": live.get("ram_free_bytes"),
        "ram_total_bytes": live.get("ram_total_bytes"),
    }
    return validate(row)


def main() -> None:
    if socket.gethostname().upper() != EXPECTED_HOST:
        raise RuntimeError("MAIN-only telemetry; no runtime state changed.")
    row = memory(dxgi_adapters())
    print(json.dumps(row, ensure_ascii=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("[MAIN_EXTENDED_MEMORY] " + str(error), file=sys.stderr)
        sys.exit(1)
