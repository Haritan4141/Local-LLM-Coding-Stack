"""Regression fixtures only. These numbers are NOT benchmark measurements."""
import json
from contextlib import closing
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

READER = Path(__file__).resolve().parents[1] / "goose" / "Read-GooseCompactionEvidence.py"


class EvidenceTests(unittest.TestCase):
    def run_fixture(self, *, flags=(0, 0, 1, 0), cap=32768, facts=10,
                    missing_usage=False, overflow=False, output_overflow=False, growth_overflow=False, larger_growth_risk=False):
        with tempfile.TemporaryDirectory(prefix="goose-evidence-unit-fixture-") as temp:
            root = Path(temp)
            assert root.resolve().parent == Path(tempfile.gettempdir()).resolve()
            assert root.name.startswith("goose-evidence-unit-fixture-")
            database = root / "round-1" / "data" / "sessions" / "sessions.db"
            database.parent.mkdir(parents=True)
            rows = [(30000, 3), (45097, 3), (45300, 900), (924, 100)]
            if overflow:
                rows[2] = (100000, 900)
            if output_overflow:
                rows[2] = (70000, 900)
            if growth_overflow:
                rows[1] = (59000, 3)
                rows[2] = (59200, 900)
            if larger_growth_risk:
                rows[1] = (55000, 3)
                rows[2] = (55200, 900)
            with closing(sqlite3.connect(database)) as connection:
                connection.execute("CREATE TABLE usage_ledger (id INTEGER, session_id TEXT, is_compaction INTEGER, input_tokens INTEGER, output_tokens INTEGER, total_tokens INTEGER)")
                connection.execute("CREATE TABLE sessions (id TEXT, model_config_json TEXT)")
                connection.execute("INSERT INTO sessions VALUES (?, ?)", ("fixture", json.dumps({"max_tokens": 32768})))
                for index, (flag, (input_tokens, output_tokens)) in enumerate(zip(flags, rows), 1):
                    connection.execute("INSERT INTO usage_ledger VALUES (?, ?, ?, ?, ?, ?)",
                                       (index, "fixture", flag, input_tokens, output_tokens, input_tokens + output_tokens))
                connection.commit()
            record = {
                "name": "UNIT-FIXTURE-NOT-A-MEASUREMENT", "round": 1, "session_id": "fixture",
                "runtime_context": 98304, "client_context": 90112, "max_output_tokens": 32768,
                "threshold": 0.5, "actual_usage_before_probe": None if missing_usage else sum(rows[1]),
                "actual_usage_after_probe": 1024, "facts_retained": facts, "facts_expected": 10,
                "observed_slot_output_caps": [cap],
            }
            (root / "results.json").write_text(json.dumps([record]), encoding="utf-8")
            result = subprocess.run([sys.executable, str(READER), str(root)], capture_output=True, text=True, check=True)
            return json.loads(result.stdout)[0]

    def test_valid_probe_sequence(self):
        self.assertTrue(self.run_fixture()["boundary_compaction_pass"])

    def test_wrong_server_output_cap(self):
        self.assertFalse(self.run_fixture(cap=16384)["boundary_compaction_pass"])

    def test_earlier_compaction_is_not_probe_compaction(self):
        self.assertFalse(self.run_fixture(flags=(0, 1, 0, 0))["boundary_compaction_pass"])

    def test_missing_usage_stays_unmeasured(self):
        result = self.run_fixture(missing_usage=True)
        self.assertFalse(result["boundary_compaction_pass"])
        self.assertIsNone(result["margin_before_probe_after_next_output_and_8k"])

    def test_capacity_recovery_is_not_threshold_qualification(self):
        self.assertFalse(self.run_fixture(overflow=True)["boundary_compaction_pass"])

    def test_compaction_input_plus_full_output_must_fit(self):
        self.assertFalse(self.run_fixture(output_overflow=True)["boundary_compaction_pass"])

    def test_actual_crossing_must_preserve_growth_reserve(self):
        result = self.run_fixture(growth_overflow=True)
        self.assertTrue(result["probe_compaction_sequence_pass"])
        self.assertFalse(result["output_reserve_budget_pass"])
        self.assertFalse(result["boundary_compaction_pass"])

    def test_16k_sensitivity_does_not_change_the_primary_8k_gate(self):
        result = self.run_fixture(larger_growth_risk=True)
        self.assertTrue(result["boundary_compaction_pass"])
        self.assertFalse(result["observed_usage_16k_growth_budget_fits"])

    def test_facts_without_complete_retention_fail(self):
        self.assertFalse(self.run_fixture(facts=9)["boundary_compaction_pass"])


if __name__ == "__main__":
    unittest.main()
