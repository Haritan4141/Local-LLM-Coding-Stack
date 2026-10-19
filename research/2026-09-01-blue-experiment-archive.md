# BLUE experiment workspace archive

Date: 2026-09-01 (Asia/Tokyo)

## Decision

The eight historical experiment workspaces previously stored directly below `C:\Users\Atsuki\Documents` on BLUE were not active runtime dependencies. They were moved, not deleted, to:

`C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08`

The archive retains qualification inputs, raw JSON/CSV/NDJSON/log evidence, harnesses, reports and the experimental DFlash2 Q4_K_M GGUF. Model/runtime payloads remain outside Git.

## Identity and safety boundary

- SSH Alias: `pc5700x`
- COMPUTERNAME: `DESKTOP-L9HAM1G`
- IPv4: `192.168.0.104`
- Pre-move process / Service / Scheduled Task references to all eight source paths: 0
- Post-move references to both old and new paths: 0
- Managed runtime boundary left in place: `C:\Users\Atsuki\Codex-RTX3090-Setup`
- No model load/unload, inference, Power Limit, Firewall, LM Studio, Goose, driver or network change was part of this move.

## Verified mapping

| Folder | Files | Directories | Bytes | Lifecycle |
|---|---:|---:|---:|---|
| `BLUE-Q5KM-96K-Qualification` | 655 | 53 | 22,717,153 | Q5_K_M 96K qualification evidence |
| `DFlash2-Phase2` | 394 | 81 | 1,152,685,462 | standalone MTP3 qualification / DFlash2 research |
| `DFlash2-Phase3` | 82 | 10 | 4,533,017 | prefix-cache research |
| `DFlash2-Phase4` | 304 | 34 | 13,073,817 | rejected n-gram specialization research |
| `LMStudio-Optimization-Phase1` | 898 | 81 | 30,272,264 | BLUE profile optimization evidence |
| `LMStudio-Optimization-Phase1.5` | 344 | 40 | 12,032,850 | BLUE isolation follow-up evidence |
| `LMStudio-Vision-Q6K-128K-Evaluation` | 222 | 46 | 16,227,948 | Q6 capacity / output / power evidence |
| `LMStudio-Vision-Q6K-Benchmark` | 156 | 12 | 4,293,309 | Q6 cross-GPU benchmark evidence |
| **Total** | **3,055** | **357** | **1,255,835,820** | external historical evidence |

All eight source paths were absent and all eight archive targets were present at `2026-09-01T16:25:18+09:00`. Each target matched its before snapshot for file count, directory count, total bytes and metadata tree fingerprint.

## External manifests

- Completed: `C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08\MOVE-MANIFEST-20260901-162331.json`
- Pre-move record: `C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08\MOVE-MANIFEST-20260901-162331.planned.json`
- Human-readable boundary: `C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08\README.md`

The completed manifest records each old/new path, before/after counts and fingerprints, plus SHA-256 for selected Markdown, ZIP and GGUF artifacts. The retained GGUF is:

`DFlash2-Phase2\RTX3090-Dual\artifacts\Qwen3.8-27B-DFlash2-Q4_K_M.gguf` — 1,143,006,752 bytes.

This GGUF is not used by the current Stable or Turbo profiles. It can be considered separately for deletion only with explicit approval; this archive operation preserved it.

## Repository path updates

Only BLUE external raw-evidence paths were updated. MAIN references under `C:\Users\Haritan\Documents`, including Phase 1/1.5 sources, were not rewritten because those are different workspaces on a different PC.
