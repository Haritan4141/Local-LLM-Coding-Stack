# MAIN IQ4_XS Vision256K short acceptance — 2026-10-11

Status: **PASS_WITH_PENDING_LONG_CONTEXT_AND_DESKTOP_ACCEPTANCE** / Candidate.
Not a formal Benchmark, a Q4-vs-Q5 quality ranking, or Current/Production promotion.

## Identity and configuration

MAIN DESKTOP-5NPLIIV /192.168.0.100 /RTX5090 UUID GPU-8dc7cc4e-ecb6-2e20-59d3-3d5acca86a8b.
NVIDIA reports32607MiB total and the existing402W power limit; no power/driver/Firewall changes.
Exact BLUE model snapshot copied read-only from pc5700x to MAIN outside Git:15309039008bytes,
SHA53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5.
Existing MAIN F16 projector reused after SHA5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c match.
Pinned sm120 llama.cpp commitf280b2698 /executableSHA103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5.

Manifest `scripts/standalone-turbo/runtime-manifests/RTX5090-IQ4XS256K.json`:
runtime262144 /VisionON /Q8 target KV /F16 draft KV /MTP3 /batch1024 /ubatch256 /parallel1 /mmap+mlock /reasoningOFF.
Goose input237568 +output16384 +reserve8192 =262144; compaction0.6.
DeepSeek `main-local`: context262144, output16384, text+image, reasoningOFF.
API `http://127.0.0.1:18080/v1`; alias `qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o`.
This is standalone llama.cpp, not LM Studio's native1234 server.

## Observations

- LM Studio loaded0 before and after; /props and /v1/models confirm262144, Visiontrue, one slot and exact MAIN alias.
- Server spawned2026-10-11 12:47:36.685 JST, ready12:47:51.803 JST; spawn-to-ready15.118s excludes model hashing/preflight.
- Before load:5528MiB GPU used,27079MiB free,167514112bytes Shared.
- Loaded:30719MiB used,1888MiB free,1016500224bytes Shared (~0.947GiB).
- Initial short smoke samples: maximum observed 30816 MiB used, minimum total-minus-used headroom 1791 MiB. This early probe did not subtract driver reservations; retain these as estimated headroom, not actual free VRAM.
- Final audit: NVIDIA `memory.free` 1359 MiB, `memory.reserved` 420 MiB, used 30829 MiB. MAIN gate now reads actual `memory.free` (not total-minus-used), without changing the minimum 1024 MiB or Shared thresholds. These are samples, not continuous transient peak measurement.
- Subsequent reserved-aware snapshot: actual free 1336 MiB, total-minus-used 1755 MiB, GPU Shared ~0.846 GiB; gate PASS. Raw record: AgentStack ignored `.local-backups/main-iq4xs256k-20261011/reserved-aware-memory.snapshot.json`. Final full regression/preflight/hash/secret results: `verification-final.json` in the same backup directory.
- Strict gate PASS: GPU Shared<2GiB, all-adapter Shared<4GiB, free>=1024MiB, exact live DXGI LUID/UUID/bus/power identity.
- Direct API text marker /schema-valid tool arguments /two-color image recognition PASS.
- Goose CLI1.52.0 isolated home: controlled `type probe.txt` exactly one successful shell request+response, recovered nonce and final exact answer PASS. Canonical Daily MAIN profile `-NoLaunch` preflight PASS; same managed PID reused, Global config SHA unchanged.
- DeepSeek Harness0.2.0-rc.2 isolated CLI: chat with0 tools, read with1 call, read_image with1 call PASS. All3 saved request headers confirm `main-local` and maxTokens16384. Original generic YAML/plugin schema validation passed, but did not exercise Desktop merge handling; see repair below. Previous BLUE/default/account/UI rows preserved.

## Raw evidence and limitations

- `benchmarks/raw/main-iq4xs256k-2026-10-11T03-48-22-686Z/`: initial API/chat/tool/Vision and Goose output, retained unchanged.
- Initial controller treated Goose output as JSONL, but installed CLI emits a banner plus a multiline JSON document. Its nonce-only Goose PASS field is insufficient as a tool-policy gate: actual transcript used one safe shell `type probe.txt` despite a text_editor/no-shell instruction. Original artifact remains as raw evidence; initial tool-selection requirement FAILED.
- `benchmarks/raw/main-iq4xs256k-2026-10-11T03-49-48-227Z/`: separate clarified controlled-shell smoke, exactly1 call+1 response and final nonce PASS. New transcript auditor rejects missing/wrong/duplicate/error tool results; eight offline cases PASS. This does not retroactively turn the initial tool-selection failure into a pass.
- AgentStack ignored `.local-backups/main-iq4xs256k-20261011/`: DSH chat/tool/vision JSONL, request audit, schema validator, config backup, regression and secret/hash reports.
- Managed server state/logs remain in `%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo`; no model/log payload is Git managed.
- Full256K input quality, long coding/research, real compaction at60%, sustained latency, and loop-prevention effectiveness NOT_TESTED.
- User confirmed repaired DSH MAIN catalog display; actual MAIN Desktop inference/attached-image UI and Goose Desktop acceptance remain Pending. CLI/API acceptance is not a Desktop inference claim.
- Observed MAIN headroom is small. Other GPU applications may invalidate the gate; failures must not lower the thresholds or terminate unrelated apps.
- BLUE's running256K server/tunnel and its manifest unchanged. Q5/Q6 profiles, sole Q6 Current, Kilo/Zoo and credentials preserved.
- LM Studio settings changed before this task's first state write: LastWrite2026-10-11T03:33:56.275322Z versus first backup03:38:06.554939Z. Previous-turn SHA drift is retained as pre-existing, not attributed to this task. Current pre-loadSHA2C99CD0410755E3A58A593696309603E7238866D2C62E08D9EFB79EB014CC7BE stayed unchanged.

## Final regression and safety audit

- AgentStack `npm test`: 77/77 PASS, no skipped tests.
- CodingStack `scripts/Test-Repository.ps1`: PASS; 29 managed JSON files, exactly one Current profile, no model binaries. Included MAIN profile (15 cases), MAIN memory (11 cases, including actual-free/reservation cases), existing BLUE profile (16 cases), and strict Goose transcript (8 cases) regressions.
- Both repositories: `git diff --check` PASS; high-signal and known-secret comparison scans found no secrets in managed/non-ignored files. Backups/raw captures remain Git-ignored.
- All 10 protected configuration/artifact hashes matched the current pre-load baseline. Existing Q5/Q6 loader files and prior runtime manifests were also unchanged. The DeepSeek patch's intended change is the additional MAIN provider with supported shared transport aliases; the existing BLUE/default configuration is preserved.
- Added Python bytecode/cache exclusions to prevent accidental Git inclusion. The new task-generated bytecode cache remains local-only; cleanup was blocked by the execution policy and was not retried through another route.
- The final read-only managed preflight verifies the existing MAIN server without restarting it. No commit/push was performed.

## Use / rollback

Goose: close Goose normally, launch `scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`, choose14.
DeepSeek: run the MAIN IQ4XS256K model loader if no server is active, then refresh the model picker and select `Qwen3.8 27B IQ4_XS Vision - MAIN 256K` under `MAIN RTX5090 - IQ4XS Vision 256K`. Repair initially preserved BLUE as default; the later Desktop save selected MAIN as current default. BLUE remains available with unchanged provider settings.
Never run inference clients simultaneously during controlled comparison.
Stop only the verified idle Candidate through `Stop-ManagedTurbo.ps1 -Profile RTX5090-IQ4XS256K`; normal MAIN Q5/Q6 selections remain available. No automatic app/OS restart or commit/push.

## Desktop parser correction provenance

Initial MAIN config used a YAML merge (`<<`) from BLUE. Installed DSH0.2.0-rc.2 `loadOptionalPatches` uses `JSON_SCHEMA.extend(JsExpr)` and does not expand that key, so MAIN lacked its required API route and was absent from Desktop. The earlier DEFAULT-schema test expanded the merge before isolated CLI execution, hiding the Desktop-only failure. Original config, validator and CLI evidence are retained; initial schema success is not reclassified as Desktop parser success.

AgentStack's minimal repair gives MAIN explicit API/reasoning and supported simple aliases to unchanged BLUE headers/compat. Actual installed boot parser reproduces the original failure and accepts the repair; non-MAIN plugin rows/default selection and BLUE semantics are unchanged. New isolated chat/read/read_image and all three request maxTokens16384 checks PASS. User confirmed MAIN catalog display. No app/model reload or configuration change outside the intended DSH patch; Desktop inference/image UX and long-context acceptance remain Pending.

Repair backup and raw verification are Git-ignored in `Local-AI-Agent-Stack/.local-backups/dsh-main-yaml-repair-20261011-132901/`; original artifacts were not overwritten. No commit/push.

A subsequent Desktop save changed only `agent-default-model` provider/model to MAIN. The original default-preservation verifier detected that difference; its initial PASS remains as historical evidence, not a claim that the current default is BLUE. Separate read-only `live-selection-audit.json` uses the installed parser to confirm exactly these two changed selection fields and unchanged BLUE/MAIN routes, account/UI rows and credentials. No repair-driven app/server/model restart; the running MAIN server/tunnel process starts remain unchanged. Full npm77/77, repository validation, read-only MAIN preflight, diff/Secret checks and10 protected hashes PASS.
