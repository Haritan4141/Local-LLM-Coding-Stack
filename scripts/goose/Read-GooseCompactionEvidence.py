"""Read synthetic qualification metadata; never query conversation message tables."""
import argparse
from contextlib import closing
import json
from pathlib import Path
import sqlite3

parser = argparse.ArgumentParser()
parser.add_argument("run_root", type=Path)
args = parser.parse_args()
root = args.run_root.resolve(strict=True)
results_path = root / "results.json"
records = json.loads(results_path.read_text(encoding="utf-8-sig"))
if isinstance(records, dict):
    records = [records]
summaries = []
for record in records:
    if record.get("pilot"):
        continue
    round_root = (root / f"round-{record['round']}").resolve(strict=True)
    database = round_root / "data" / "sessions" / "sessions.db"
    with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as connection:
        connection.execute("PRAGMA query_only=ON")
        connection.row_factory = sqlite3.Row
        ledger = [dict(row) for row in connection.execute(
            "SELECT id,is_compaction,input_tokens,output_tokens,total_tokens "
            "FROM usage_ledger WHERE session_id=? ORDER BY id", (record["session_id"],)
        )]
        columns = {row[1] for row in connection.execute("PRAGMA table_info(sessions)")}
        if "model_config_json" in columns:
            raw_config = connection.execute(
                "SELECT model_config_json FROM sessions WHERE id=?", (record["session_id"],)
            ).fetchone()[0]
            config = json.loads(raw_config) if raw_config else {}
        else:
            config = {}
    compactions = [entry for entry in ledger if entry["is_compaction"] == 1]
    summary = {key: record.get(key) for key in (
        "name", "round", "goose_version", "provider", "api_model", "runtime_context", "client_context", "max_output_tokens",
        "system_config_absent", "additional_config_files_removed",
        "threshold", "actual_usage_before_probe", "actual_usage_after_probe", "facts_retained",
        "actual_usage_after_first",
        "facts_expected", "auto_compaction_notification", "first_seconds", "second_seconds", "probe_seconds",
        "observed_slot_output_caps",
    )}
    summary["ledger"] = ledger
    summary["compactions"] = len(compactions)
    summary["session_max_tokens"] = config.get("max_tokens")
    summary["session_model_name"] = config.get("model_name")
    summary["session_vision_capability_flag"] = config.get("supports_vision")
    # Metadata only: this capability flag is not an image-input test. Older
    # harness revisions omitted api_model; preserve both recorded identities.
    # There are exactly three user invocations. No compaction before the third
    # invocation is accepted. The normal calls must remain below real capacity;
    # this excludes a context-overflow recovery being mistaken for our trigger.
    target = record["client_context"] * record["threshold"]
    margin = (
        record["runtime_context"] - record["actual_usage_before_probe"] - record["max_output_tokens"] - 8192
    ) if type(record.get("actual_usage_before_probe")) is int else None
    summary["margin_before_probe_after_next_output_and_8k"] = margin
    summary["output_reserve_budget_pass"] = margin > 0 if margin is not None else None
    summary["margin_before_probe_after_next_output_and_16k"] = margin - 8192 if margin is not None else None
    summary["observed_usage_16k_growth_budget_fits"] = margin > 8192 if margin is not None else None
    sequence_ok = (
        len(ledger) == 4
        and [entry["is_compaction"] for entry in ledger] == [0, 0, 1, 0]
        and all(type(entry.get(key)) is int for entry in ledger
                for key in ("input_tokens", "output_tokens", "total_tokens"))
        and all(entry["input_tokens"] >= 0 and entry["output_tokens"] >= 0
                and entry["total_tokens"] == entry["input_tokens"] + entry["output_tokens"]
                for entry in ledger)
        and ledger[0]["total_tokens"] <= target
        and ledger[1]["total_tokens"] == record["actual_usage_before_probe"]
        and ledger[2]["input_tokens"] < record["runtime_context"]
        and ledger[2]["input_tokens"] + record["max_output_tokens"] < record["runtime_context"]
        and ledger[3]["total_tokens"] == record["actual_usage_after_probe"]
    )
    summary["probe_compaction_sequence_pass"] = sequence_ok
    summary["boundary_compaction_pass"] = (
        len(compactions) == 1
        and sequence_ok
        and record["facts_retained"] == record["facts_expected"] == 10
        and record["actual_usage_before_probe"] > target
        and record["actual_usage_after_probe"] < target
        and config.get("max_tokens") == record["max_output_tokens"]
        and summary["output_reserve_budget_pass"] is True
        and (not record.get("observed_slot_output_caps")
             or record["observed_slot_output_caps"] == [record["max_output_tokens"]])
    )
    caps = record.get("observed_slot_output_caps")
    summary["server_output_cap_matches"] = (caps == [record["max_output_tokens"]]) if caps else None
    summary["padding_method"] = record.get("padding_method", "initial fixed 0.80 / 0.30+1024; first usage verified in ledger")
    summary["qualification_scope"] = "CLI, no tools, text-only synthetic history; not Desktop/long-loop/Vision qualification"
    summaries.append(summary)
print(json.dumps(summaries, ensure_ascii=False, indent=2))
