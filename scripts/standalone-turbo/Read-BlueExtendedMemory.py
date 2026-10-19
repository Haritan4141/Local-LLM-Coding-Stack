"""Read-only BLUE memory gate; reuses the qualification's exact UUID/LUID probe.

Never loads, unloads, downloads, stops a process, or changes power/configuration.
Imports the sibling qualification source with bytecode writes disabled (-B).
"""
import json
from pathlib import Path
import re
import socket
import sys


def validate(row):
    # Same strict Shared gate as qualification, plus the daily 1 GiB margin.
    if not isinstance(row, dict) or len(row.get('gpus', [])) != 2:
        raise ValueError('Expected two exactly identified BLUE GPUs.')
    from blue_q4_vision import EXPECTED_GPU, gate
    expected = set(EXPECTED_GPU)
    if {gpu.get('name') for gpu in row['gpus']} != expected:
        raise ValueError('BLUE GPU identity mismatch.')
    luids = [gpu.get('luid') for gpu in row['gpus']]
    if any(not isinstance(luid, str) or not re.fullmatch(r'luid_0x[0-9a-f]{8}_0x[0-9a-f]{8}_phys_0', luid) for luid in luids) or len(set(luids)) != 2:
        raise ValueError('Missing/ambiguous exact live LUID telemetry.')
    for gpu in row['gpus']:
        bus, gpu_uuid, watts, _ = EXPECTED_GPU[gpu['name']]
        if (gpu.get('bus'), gpu.get('uuid'), gpu.get('power_w')) != (bus, gpu_uuid, watts):
            raise ValueError('BLUE GPU bus/UUID/power mismatch.')
        for field in ('shared_bytes', 'dedicated_bytes', 'headroom_mib'):
            value = gpu.get(field)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not (0 <= value < float('inf')):
                raise ValueError('Missing/invalid GPU memory telemetry.')
    total = row.get('all_adapter_shared_bytes')
    if isinstance(total, bool) or not isinstance(total, int) or total < sum(g['shared_bytes'] for g in row['gpus']):
        raise ValueError('Missing/inconsistent total Shared telemetry.')
    reasons = gate(row)
    reasons += [gpu['name'] + ' free VRAM < 1024 MiB'
                for gpu in row['gpus'] if gpu['headroom_mib'] < 1024]
    if reasons:
        raise ValueError('; '.join(reasons))
    return row


def main():
    if socket.gethostname().upper() != 'DESKTOP-L9HAM1G':
        raise RuntimeError('BLUE-only memory preflight; no runtime state changed.')
    from blue_q4_vision import dxgi_adapters, memory
    row = validate(memory(dxgi_adapters()))
    print(json.dumps(row, ensure_ascii=True))


sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'qualification'))
if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('[BLUE_EXTENDED_MEMORY] ' + str(error), file=sys.stderr)
        sys.exit(1)
