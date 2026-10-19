"""Offline tests for the BLUE extended-context memory gate.

The test imports only the pure ``validate`` function.  It never calls ``main``
or any DXGI, PowerShell, socket, LM Studio, SSH, or process-mutating path.
"""
from __future__ import annotations

import copy
import importlib.util
import math
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
QUALIFICATION = ROOT / "scripts" / "qualification"
HELPER_PATH = ROOT / "scripts" / "standalone-turbo" / "Read-BlueExtendedMemory.py"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


# The production helper deliberately imports the qualification module by its
# canonical name.  Load that module in-process without executing its main().
blue_q4_vision = load_module("blue_q4_vision", QUALIFICATION / "blue_q4_vision.py")
memory_gate = load_module("blue_extended_memory_test_target", HELPER_PATH)


class BlueExtendedMemoryTests(unittest.TestCase):
    @staticmethod
    def valid_row(shared_each: int = 512 * 1024 * 1024, free_mib: int = 2048):
        gpus = []
        for index, (name, (bus, uuid, watts, _total)) in enumerate(
            blue_q4_vision.EXPECTED_GPU.items(), start=1
        ):
            gpus.append(
                {
                    "name": name,
                    "bus": bus,
                    "uuid": uuid,
                    "power_w": watts,
                    "shared_bytes": shared_each,
                    "dedicated_bytes": 1024,
                    "headroom_mib": free_mib,
                    "luid": f"luid_0x0000000{index}_0x0000000{index}_phys_0",
                }
            )
        return {
            "gpus": gpus,
            "all_adapter_shared_bytes": shared_each * len(gpus),
        }

    def assert_rejected(self, row, label: str):
        with self.assertRaises(ValueError, msg=label):
            memory_gate.validate(row)

    def test_valid_two_gpu_row_is_accepted(self):
        row = self.valid_row()
        self.assertIs(memory_gate.validate(row), row)

    def test_combined_shared_gate_is_strictly_below_four_gib(self):
        almost = self.valid_row(shared_each=(2 * 1024**3) - 1)
        self.assertIs(memory_gate.validate(almost), almost)

        exact = self.valid_row(shared_each=2 * 1024**3)
        self.assert_rejected(exact, "exactly 4 GiB combined Shared must fail")

    def test_each_gpu_shared_is_at_most_two_gib(self):
        row = self.valid_row(shared_each=1)
        row["gpus"][0]["shared_bytes"] = (2 * 1024**3) + 1
        row["all_adapter_shared_bytes"] = sum(g["shared_bytes"] for g in row["gpus"])
        self.assert_rejected(row, "per-GPU Shared above 2 GiB must fail")

    def test_each_gpu_free_headroom_is_at_least_one_gib(self):
        boundary = self.valid_row(free_mib=1024)
        self.assertIs(memory_gate.validate(boundary), boundary)
        self.assert_rejected(self.valid_row(free_mib=1023), "free VRAM below 1 GiB must fail")

    def test_missing_or_wrong_uuid_is_rejected(self):
        missing = self.valid_row()
        missing["gpus"][0].pop("uuid")
        self.assert_rejected(missing, "missing UUID must fail")

        wrong = self.valid_row()
        wrong["gpus"][0]["uuid"] = "GPU-not-the-pinned-device"
        self.assert_rejected(wrong, "wrong UUID must fail")

    def test_missing_invalid_or_duplicate_luid_is_rejected(self):
        missing = self.valid_row()
        missing["gpus"][0].pop("luid")
        self.assert_rejected(missing, "missing LUID must fail")

        malformed = self.valid_row()
        malformed["gpus"][0]["luid"] = "luid-0"
        self.assert_rejected(malformed, "malformed LUID must fail")

        duplicate = self.valid_row()
        duplicate["gpus"][1]["luid"] = duplicate["gpus"][0]["luid"]
        self.assert_rejected(duplicate, "duplicate LUID must fail")

    def test_nan_or_infinite_memory_telemetry_is_rejected(self):
        nan_row = self.valid_row()
        nan_row["gpus"][0]["headroom_mib"] = math.nan
        self.assert_rejected(nan_row, "NaN memory telemetry must fail")

        inf_row = self.valid_row()
        inf_row["gpus"][1]["shared_bytes"] = math.inf
        inf_row["all_adapter_shared_bytes"] = 2 * 1024**3
        self.assert_rejected(inf_row, "infinite memory telemetry must fail")

    def test_missing_total_and_gpu_identity_are_rejected(self):
        missing_total = self.valid_row()
        missing_total.pop("all_adapter_shared_bytes")
        self.assert_rejected(missing_total, "missing total Shared telemetry must fail")

        wrong_count = self.valid_row()
        wrong_count["gpus"].pop()
        self.assert_rejected(wrong_count, "one-GPU telemetry must fail")

        wrong_name = self.valid_row()
        wrong_name["gpus"][0]["name"] = "NVIDIA GeForce RTX 4090"
        self.assert_rejected(wrong_name, "unrecognized GPU identity must fail")

    def test_validate_does_not_mutate_input(self):
        row = self.valid_row()
        original = copy.deepcopy(row)
        memory_gate.validate(row)
        self.assertEqual(row, original)

    def test_helper_main_is_not_used_by_offline_tests(self):
        source = HELPER_PATH.read_text(encoding="utf-8")
        self.assertIn("def validate(row):", source)
        self.assertIn("def main():", source)
        # This suite must not cross the runtime boundary.
        self.assertNotIn("subprocess.run", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
