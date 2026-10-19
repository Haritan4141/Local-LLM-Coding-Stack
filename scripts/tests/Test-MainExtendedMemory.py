"""Offline tests for the MAIN RTX 5090 extended-memory gate.

The suite imports only ``validate`` and never calls the live DXGI/PowerShell
probe.  It therefore cannot load a model, touch LM Studio, or change hardware
state.
"""

from __future__ import annotations

import copy
import importlib.util
import math
import sys
import unittest
from unittest.mock import patch
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HELPER_PATH = ROOT / "scripts" / "standalone-turbo" / "Read-MainExtendedMemory.py"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


memory_gate = load_module("main_extended_memory_test_target", HELPER_PATH)


class MainExtendedMemoryTests(unittest.TestCase):
    @staticmethod
    def valid_row(shared_bytes: int = 512 * 1024 * 1024, free_mib: int = 2048):
        expected = memory_gate.EXPECTED_GPU
        return {
            "gpus": [
                {
                    "name": expected["name"],
                    "bus": expected["bus"],
                    "uuid": expected["uuid"],
                    "power_w": expected["power_w"],
                    "used_mib": expected["total_mib"] - free_mib,
                    "temperature_c": 60.0,
                    "shared_bytes": shared_bytes,
                    "dedicated_bytes": 1024,
                    "headroom_mib": free_mib,
                    "luid": "luid_0x00000001_0x00000001_phys_0",
                }
            ],
            "all_adapter_shared_bytes": shared_bytes,
        }

    def assert_rejected(self, row, label: str):
        with self.assertRaises(ValueError, msg=label):
            memory_gate.validate(row)

    def test_valid_one_gpu_row_is_accepted(self):
        row = self.valid_row()
        self.assertIs(memory_gate.validate(row), row)

    def test_per_gpu_shared_gate_is_strictly_below_two_gib(self):
        almost = self.valid_row(shared_bytes=(2 * 1024**3) - 1)
        self.assertIs(memory_gate.validate(almost), almost)

        exact = self.valid_row(shared_bytes=2 * 1024**3)
        self.assert_rejected(exact, "exactly 2 GiB per-GPU Shared must fail")

    def test_all_adapter_shared_gate_is_strictly_below_four_gib(self):
        row = self.valid_row(shared_bytes=1)
        row["all_adapter_shared_bytes"] = (4 * 1024**3) - 1
        self.assertIs(memory_gate.validate(row), row)

        row["all_adapter_shared_bytes"] = 4 * 1024**3
        self.assert_rejected(row, "exactly 4 GiB all-adapter Shared must fail")

    def test_free_headroom_is_at_least_one_gib(self):
        boundary = self.valid_row(free_mib=1024)
        self.assertIs(memory_gate.validate(boundary), boundary)
        self.assert_rejected(self.valid_row(free_mib=1023), "free VRAM below 1 GiB must fail")

    def test_wrong_host_gpu_bus_uuid_or_power_is_rejected(self):
        for field, value in (
            ("name", "NVIDIA GeForce RTX 4090"),
            ("bus", "00000000:02:00.0"),
            ("uuid", "GPU-not-the-pinned-device"),
            ("power_w", 450),
        ):
            row = self.valid_row()
            row["gpus"][0][field] = value
            self.assert_rejected(row, f"wrong {field} must fail")

    def test_one_gpu_and_exact_luid_are_required(self):
        two = self.valid_row()
        two["gpus"].append(copy.deepcopy(two["gpus"][0]))
        self.assert_rejected(two, "ambiguous two-GPU row must fail")

        missing = self.valid_row()
        missing["gpus"][0].pop("luid")
        self.assert_rejected(missing, "missing LUID must fail")

        malformed = self.valid_row()
        malformed["gpus"][0]["luid"] = "luid-0"
        self.assert_rejected(malformed, "malformed LUID must fail")

    def test_nan_infinite_missing_or_inconsistent_telemetry_is_rejected(self):
        for field, value in (
            ("headroom_mib", math.nan),
            ("shared_bytes", math.inf),
            ("dedicated_bytes", None),
            ("temperature_c", -1),
        ):
            row = self.valid_row()
            row["gpus"][0][field] = value
            self.assert_rejected(row, f"invalid {field} must fail")

        missing_total = self.valid_row()
        missing_total.pop("all_adapter_shared_bytes")
        self.assert_rejected(missing_total, "missing total Shared must fail")

        lower_total = self.valid_row(shared_bytes=512)
        lower_total["all_adapter_shared_bytes"] = 1
        self.assert_rejected(lower_total, "inconsistent total Shared must fail")

    def test_validate_does_not_mutate_input(self):
        row = self.valid_row()
        original = copy.deepcopy(row)
        memory_gate.validate(row)
        self.assertEqual(row, original)

    def test_probe_uses_actual_free_not_total_minus_used(self):
        expected = memory_gate.EXPECTED_GPU
        luid = "luid_0x00000001_0x00000001_phys_0"
        live = {
            "gpus": [{
                "name": expected["name"], "bus": expected["bus"],
                "uuid": expected["uuid"], "power_w": "402",
                "total_mib": "32607", "used_mib": "30000",
                "free_mib": "1100", "temperature_c": "60",
            }],
            "adapters": [{"Name": luid, "DedicatedUsage": 1024, "SharedUsage": 512}],
        }
        adapters = [{"name": expected["name"], "vendor": 0x10DE, "instance": luid}]
        with patch.object(memory_gate, "_ps_json", return_value=live):
            row = memory_gate.memory(adapters)
            self.assertEqual(row["gpus"][0]["headroom_mib"], 1100)
            self.assertEqual(row["gpus"][0]["capacity_minus_used_mib"], 2607)
            live["gpus"][0]["free_mib"] = "900"
            with self.assertRaises(ValueError):
                memory_gate.memory(adapters)
            live["gpus"][0].pop("free_mib")
            with self.assertRaises(RuntimeError):
                memory_gate.memory(adapters)

    def test_impossible_free_capacity_is_rejected(self):
        row = self.valid_row()
        row["gpus"][0]["headroom_mib"] = 3000
        self.assert_rejected(row, "free plus used exceeds physical capacity")

    def test_probe_is_read_only_and_host_pinned(self):
        source = HELPER_PATH.read_text(encoding="utf-8")
        self.assertIn("DESKTOP-5NPLIIV", source)
        self.assertIn("GPU-8dc7cc4e-ecb6-2e20-59d3-3d5acca86a8b", source)
        self.assertIn("00000000:01:00.0", source)
        self.assertIn("402", source)
        self.assertIn("Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory", source)
        for forbidden in (
            "lms unload",
            "lms load",
            "TerminateProcess",
            "SetPowerLimit",
            "power-limit",
        ):
            self.assertNotIn(forbidden.lower(), source.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
