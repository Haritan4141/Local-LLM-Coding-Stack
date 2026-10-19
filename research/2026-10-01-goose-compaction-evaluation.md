# Goose profile-specific compaction evaluation

Started: 2026-10-01 (Asia/Tokyo). Status: **EXPLORATORY EVALUATION COMPLETE — 36/36 bounded CLI repeats passed; no production adoption.**

## Scope and checkpoint

- [x] Verify installed Goose v1.52.0, MAIN identity, BLUE SSH alias/hostname/IP and idle runtime state.
- [x] Inspect all 12 Daily profile definitions; calculate output-aware candidate thresholds.
- [x] Prove isolated `GOOSE_PATH_ROOT` config/data/session storage with a short CLI pilot.
- [x] MAIN Quick 60%: three real-usage compactions and 10/10 retained facts per run.
- [x] MAIN Turbo 96K/16K 65%: three real-usage compactions and 10/10 retained facts per run.
- [x] MAIN Turbo 96K/32K 50%: three repeats; server observed `max_tokens/n_predict=32768`.
- [x] MAIN Stable 96K/16K 65% and 96K/32K 50%: three repeats each, with ledger and retention checks.
- [x] BLUE Turbo 96K/16K 65%: three repeats and exact facts retained.
- [x] BLUE Turbo 96K/32K 50% and Quick 64K/8K 60%: three ledger-qualified repeats each; sampled server caps 32,768 and 8,192.
- [x] MAIN Quality Reference 64K/32K 30%: three repeats; restored MAIN empty runtime.
- [x] Complete all six MAIN combinations, three repeats each; all selected ledger/retention/output-reserve checks passed.
- [x] BLUE Stable 96K/16K 65%: three ledger-qualified repeats with positive output-plus-growth reserve.
- [x] BLUE Stable 96K/32K 50%: three ledger-qualified repeats; session output cap 32,768, native server cap not sampled.
- [x] Complete BLUE Quality Reference 64K/32K at unchanged 30%, three repeats.
- [x] Verify selected current-usage/ledger matches, session output cap, summary size/time and short continuation for every run. Missing server cap samples remain unknown.
- [x] Restore initial empty model state, verify Power Limits and production Goose config unchanged.
- [x] Final repository validation/readback after all curated artifacts are saved: `Test-Repository.ps1` passed; all nine evidence regression fixtures passed; JSON readback confirmed 12 cases / 36 repeats, 9 sampled and 27 unknown server caps, 18 separate 16K-growth sensitivity rejections, all referenced configs and raw result roots present, and no production adoption.

The user authorized temporary runtime switching on both PCs and closed Goose Desktop. At preflight, both LM Studio instances were running with **no loaded models**, and no managed Turbo endpoint was listening. Restore this observed starting state, not a guessed previous profile.

Final restoration verified at **2026-10-01T13:12:15+09:00**: both verified hosts have LM Studio running with empty CLI model arrays and no API loaded instances; MAIN 18080/18081 and BLUE 18080 listeners are absent. Goose Desktop is closed. MAIN RTX5090 PL402W, BLUE RTX3090 PL259W / RTX3060 PL170W match GPU names and PCI Bus IDs. Production Goose config hash was unchanged in every harness and against the live checkpoint. Source/deployed BLUE module and its old backup hashes were independently rechecked.

This evaluation does not promote a model or change Daily launcher compaction defaults. Production thresholds remain 0.3 until a separate adoption decision. Synthetic CLI sessions do not establish Desktop UI or unbounded agent-loop qualification.

The older [2026-08-24 integration decision](jonathan-q5km-vision-2026-08-24.md#goose-integration-decision) already documents 30%, an intentional 8K server/client gap and missed same-turn tool-loop boundaries. It does not establish that 30% was necessary solely because of the UI denominator bug. A corrected display does not remove the backend output reserve or turn-boundary limitation; the new evaluation must judge those independently.

## Primary sources (checked 2026-10-01)

- [Goose v1.52.0 official context guide](https://github.com/aaif-goose/goose/blob/v1.52.0/documentation/docs/guides/sessions/smart-context-management.md): default auto-compaction threshold 80%; an explicit 60% configuration example. These are application settings, not a universal optimal percentage for local models.
- [Goose v1.52.0 compaction implementation](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/agents/state_machine/ops_compaction.rs): compares reported context usage / provider-resolved context limit **strictly greater** than threshold. This file describes the experimental state-machine loop, whose proactive compaction requires the latest effective role to be User. Do not generalize that particular guard to every Goose loop.
- [Goose v1.52.0 legacy reply implementation](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/agents/agent.rs): checks automatic compaction before the reply stream/tool loop. These synthetic CLI runs exercise the default legacy loop, with the inherited state-machine variable absent in earlier runs and explicitly disabled in later runs.
- [Loop selector](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/agents/state_machine/mod.rs#L72-L76): only `1`, `true`, `TRUE` and `yes` enable the experimental loop; `false` reliably selects legacy. Legacy proactive compaction is checked once before the inner tool loop, not at every tool boundary; its context-error recovery path is separate. PR #12444 changes the experimental/unrolled loop only, not legacy, so it is not a promised fix for the installed default path.
- [Tool-boundary compaction PR #12444](https://github.com/aaif-goose/goose/pull/12444): merged upstream, but not contained in the installed v1.52.0 release. Do not assume all loop implementations or later releases have identical behavior.
- [Goose v1.52.0 path isolation](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/config/paths.rs): absolute `GOOSE_PATH_ROOT` isolates config, data, state and plugin roots.
- [Goose v1.52.0 configuration merge](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/config/base.rs#L155-L205): that root does **not** suppress `%PROGRAMDATA%\goose\config.yaml` or `GOOSE_ADDITIONAL_CONFIG_FILES`. Read-only verification on MAIN found the system file absent and no inherited additional-config variable. Later helper invocations reject an existing system config, explicitly remove the additional-config variable, and execute `--version` to verify 1.52.0 before inference. Earlier cases used the same exact executable, whose version was independently verified; these retrospective checks are not represented as guards executed by the earlier revision.
- [Anthropic threshold-compaction documentation](https://platform.claude.com/docs/en/build-with-claude/compaction-threshold): uses an absolute input-token trigger (default 150,000), illustrating that policies are model/application specific. This is not a recommended threshold for Qwen or Goose.

## Output-aware static budget

Use the runtime capacity, not a misleading fixed percentage alone:

`usage at trigger + full NEXT response allowance + growth reserve < runtime context`

`first eligible usage = floor(Goose client context * threshold) + 1`

This deliberately conservative arithmetic uses provider-reported current total usage as the starting quantity. It reserves a complete next response even if the previous usage already includes output. It does not reserve each turn of an unlimited agent loop, and it does not assume compaction fires immediately at the crossing. It is a planning gate, **not an operational PASS**.

Initial growth reserve: 8,192 tokens for new input, tool output, images/tokenization differences and compaction overhead. This is an explicit engineering assumption, not a measured upper bound. Also test 16,384 growth to expose sensitivity. Do not add Reasoning Budget again if it is already counted within the request's output allowance; verify provider accounting during live qualification.

| Daily profiles (MAIN and BLUE) | Runtime | Goose limit | Max output | Existing rate | Candidate | First eligible usage | Remaining after next max output | Remaining after extra 8K growth |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Quick 64K/8K | 65,536 | 57,344 | 8,192 | 30% | 60% | 34,407 | 22,937 | 14,745 |
| Stable / Turbo 96K/16K | 98,304 | 90,112 | 16,384 | 30% | 65% | 58,573 | 23,347 | 15,155 |
| Stable / Turbo 96K/32K | 98,304 | 90,112 | 32,768 | 30% | 50% | 45,057 | 20,479 | 12,287 |
| Quality Reference 64K/32K | 65,536 | 64,512 | 32,768 | 30% | **retain 30%** | 19,354 | 13,414 | 5,222 |

All 12 profiles pass the static 8K-growth budget at these candidates. With 16K growth, Quality Reference fails by 2,970 tokens despite retaining 30%. It must not be described as safe for arbitrary large tool responses.

The static statement above uses the ideal first eligible point. At **actual observed pre-probe usage**, the 16K-growth sensitivity rejects 18/36 runs across MAIN Stable16K, MAIN Turbo16K, MAIN Turbo32K, BLUE Turbo16K and both Quality cases. Larger real turns overshot the nominal trigger. These are arithmetic rejections, not observed crashes; all 36 passed the declared 8K-growth planning gate. Do not generalize that gate to unlimited tool output or images.

Changing the compaction rate can also change the derived tool-call summarization cutoff. In [v1.52.0 `compute_tool_call_cutoff`](https://github.com/aaif-goose/goose/blob/v1.52.0/crates/goose/src/context_mgmt/mod.rs), this is `clamp(3 * floor(client_context * threshold) / 20000, 10, 500)` with integer division. All twelve current and proposed profiles resolve to **10**, so this particular derived cutoff remains unchanged here. This does not override an explicit `GOOSE_TOOL_CALL_CUTOFF` or qualify tool-output summarization.

Tool-pair summarization is separately opt-in (`GOOSE_TOOL_PAIR_SUMMARIZATION`, default false) in v1.52.0; a derived cutoff alone does not mean the feature is active. The no-tools harness disables it explicitly in later runs. Enabling it or changing the agent-loop implementation is outside this evaluation.

At a blanket 80% rate, the same 8K-growth arithmetic leaves only 3,276 tokens for Quick and 1,638 for 96K/16K; 96K/32K exceeds capacity by 14,746 and 64K/32K by 27,034. These negative values are budget rejections, not measured crashes.

## Reproduction and live acceptance

Read-only budget calculation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\goose\Measure-GooseCompactionBudget.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\tests\Test-GooseCompactionBudget.ps1
```

`Invoke-GooseCompactionQualification.ps1` uses only an already-loaded, verified idle endpoint. It never starts/stops a runtime or edits a production Goose profile. Each round creates an isolated config and session under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\compaction-qualification\` and uses the installed v1.52.0 CLI with `--no-profile` (no personal extensions). The same profile context, output limit and temperature are sent as process-local overrides.

Each round submits actual synthetic messages: a first padding turn below the threshold, a second turn crossing it, then a short user probe. No fabricated usage values or imported conversations are inserted. Provider-reported usage and `usage_ledger.is_compaction` must show actual automatic compaction. Require completion and exact retention of ten immutable facts, including negative instructions, then confirm continued normal response. Run each combination three times.

Initial runs used padding of 80% of the planned trigger, then 30% + 1,024 tokens. After observing provider/template overhead, later runs size the second real message from the **measured** first-call usage to cross by approximately 1,024 tokens; Quality starts at 70% instead of 80% to leave system/response room below its low trigger. The ledger remains the acceptance authority. Record the padding method per run; these are functional threshold tests, not latency A/B comparisons of identical prompt lengths.

The helper's `-PaddingMethod fixed-v1` reproduces the initial sizing; its default `measured-v2` reproduces the later adaptive sizing. Earlier records without an explicit method field are identified from the ledger and raw prompts, not silently treated as identical workloads.

The read-only SQLite evidence helper requires the ledger sequence `[normal, normal, compaction, normal]`, first-call usage below the trigger, exact pre-/post-probe usage agreement, compaction input **plus the requested full output** below runtime capacity, all ten facts, and the requested session `max_tokens`. It also requires the actual pre-probe usage to preserve a next full response plus the assumed 8K growth. A successful short reply with a negative reserve is not an output-aware PASS. These conservative checks distinguish the intended probe compaction from an earlier compaction or a capacity-recovery accident in this clean workload; they do not classify arbitrary provider retries. Later harness calls explicitly clear `GOOSE_SYSTEM_PROMPT_FILE_PATH`, disable the experimental loop, reject missing usage, and export the first-call usage as an additional guard. No personal prompt/state-machine environment variable was set at initial preflight. Server slot output caps are captured for standalone endpoints; missing samples are recorded as unmeasured, not zero or a fabricated PASS.

Long max output is a cap, not a target; these tests do not force 32K generation. The earlier [32K Turbo qualification](../benchmarks/results/2026-08-26-goose-turbo-output32k-qualification.md) demonstrated >16K generation but does not qualify post-compaction 32K generation. Live ledger, short answer retention and client output-cap forwarding are separate checks. A long-output-after-compaction stress test, multimodal token growth and tool-boundary runs remain additional gates.

## Observations

Complete per-run data and the twelve-case matrix are in [the curated result](../benchmarks/results/2026-10-01-goose-profile-compaction.md) and its adjacent JSON. All 36 runs had exactly one ledger compaction, retained 10/10 facts, continued normally and preserved the requested session cap. Server cap was sampled in nine runs (MAIN/BLUE Turbo32K and BLUE Quick8K); the other 27 are explicitly unmeasured for that check. Nothing was sent to a cloud model.

MAIN Quick 60% (three repeats): provider usage before probe 39,633; compaction request ledger entry input 39,830 / output 1,158; final response current usage 1,278; ten exact facts retained. Compaction is a separate request, not ordinary output truncation. Raw evidence: `%LOCALAPPDATA%\Local-LLM-Coding-Stack\compaction-qualification\main-quick60-20261001-113706-060\`.

MAIN Turbo 96K/16K 65% (three repeats): provider usage before probe 66,162; final current usage 1,273; one ledger compaction per run and ten exact facts retained. Isolated session `max_tokens=16384` was preserved. Raw evidence: `%LOCALAPPDATA%\Local-LLM-Coding-Stack\compaction-qualification\main-turbo16k65-20261001-114120-999\`.

MAIN Turbo 96K/32K 50% (three repeats): before 51,281 / after 1,310; ledger compaction input 51,502 / output 1,105; all ten facts retained. The server slot cap and isolated session both remained 32,768. Raw evidence: `%LOCALAPPDATA%\Local-LLM-Coding-Stack\compaction-qualification\main-turbo32k50-20261001-114437-782\`.

MAIN Stable 96K/16K: all three repeats passed the ledger/retention checks; actual pre-probe usage 70,738–70,950 and post-probe usage 1,593–1,791. In this synthetic case the full next 16K output plus 8K reserve still fit at the observed crossing, with 2,778–2,990 tokens remaining. The compaction request's reported output was 5,052–5,083 tokens; the total probe call (compaction plus short continuation, CLI overhead included) took 130.618–138.693 seconds. These measurements do not isolate reasoning versus visible summary output and are not a speed A/B benchmark.

BLUE Turbo 96K/16K: three ledger-qualified compactions, 10/10 facts retained; before 66,282–66,397 / after 1,544–1,546. The probe call took 299.384–305.545 seconds in this test and the compaction ledger output was 5,980 tokens. Do not equate this duration with normal chat latency.

BLUE Quick 64K/8K: three ledger-qualified compactions, before 35,585 / after 1,277, all ten facts retained; sampled server cap 8,192 matched the session setting. Compaction ledger input/output 35,782 / 1,189; probe wall time 45.475–90.509 seconds. This is not an end-to-end image or general-response-speed qualification.

BLUE Stable 96K/16K: three repeats passed; before 60,387–60,391 / after 1,790–1,808. The actual output-plus-assumed-8K reserve was 13,337–13,341 tokens. Compaction ledger input/output 60,514 / 6,155; probe wall time 325.343–327.527 seconds. Native server caps were not sampled; the requested session output cap was 16,384. Different padding revisions and warm/cold behavior mean the MAIN/BLUE times are not a controlled performance ranking.

BLUE Stable 96K/32K: three repeats passed; before 46,753–46,888 / after 1,453–1,662. Output-plus-assumed-8K reserve 10,456–10,591; probe wall time 249.179–343.586 seconds. The session's requested output cap remained 32,768; native server cap was not sampled. Quick's isolated model config records the friendly Qwen alias and `supports_vision=true`, but this metadata is not an image-input test; absent capability metadata in other cases remains unknown.

BLUE Quality Reference 64K/32K at 30%: three repeats passed; before 20,926–20,927 / after 1,785, all ten facts retained. Compaction ledger input/output 21,074 / 5,333; probe time 180.903–212.967 seconds. Actual output-plus-assumed-8K reserve 3,649–3,650, but with 16K growth it is negative by 4,542–4,543. Keep 30% as the conservative candidate; this does not establish safety for giant input/tool additions.

An early MAIN Stable32K attempt failed before inference because clearing a string environment variable through the .NET overload produced an empty `GOOSE_SYSTEM_PROMPT_FILE_PATH`, which Goose tried to open as a file. Changed the isolated helper to explicitly remove absent process environment keys and preserve empty result arrays as `[]`; the retry completed three successful rounds. The failed raw folder `main-stable32k50-20261001-115644-265` is retained as diagnostic evidence and excluded from successful run counts. Production config was unchanged, and the failed queue safely unloaded MAIN.

Nine read-only evidence regression fixtures (`Test-GooseCompactionEvidence.py`) cover correct probe sequence, wrong server output cap, earlier compaction, missing usage, capacity recovery, compaction-input-plus-output overflow, actual-crossing growth-reserve exhaustion, separate 16K sensitivity and incomplete fact retention. They are explicitly synthetic **unit fixtures**, not measured benchmark rows.

## BLUE deployment drift repaired with explicit approval

BLUE Quick initially failed before model load. `BLUE-Quick.json` already had the friendly Qwen alias ending in `-gpt-4o`, but deployed `Turbo.Common.psm1` still required the bare alias `gpt-4o` and one legacy ID. The repository module accepts the friendly alias and two legacy IDs. This was a script-version mismatch, not a context/VRAM/compaction failure.

With explicit user approval, synchronized **only** `Turbo.Common.psm1` to `C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Turbo.Common.psm1`. Backup: `backups\before-compaction-20261001-1138\Turbo.Common.psm1` under that directory. Target SHA-256 matched MAIN source `1A5360DCB391D8CE3AC116D74D02A2595CB3E1BB60967DD26461A76EDAC1D057`; a read-only module check accepted the current Quick manifest. No GPU limit, model load setting, Firewall, driver, persistent execution policy or Goose config was changed by this synchronization.

The subsequent canonical BLUE Quick startup passed alias/context/parallel/Vision and pinned-process checks; all three Quick compactions and final restoration passed. The old module hash retained in the backup is `3D84AE8BB243F15397314408B1E7628306938E52414A15E7CBD305A76B1F39BE`.

## Decision

Do not change production thresholds automatically. Quick 60%, Stable/Turbo96K/16K 65%, Stable/Turbo96K/32K 50% and Quality64K/32K 30% are **bounded-test candidates**, not unconditional Operational acceptance. The installed legacy loop's tool-boundary limitation remains; a per-response output-token-limit warning is separate from input-context overflow and is not repaired by a compaction-rate change alone. Desktop sessions, real tools, multimodal growth and a full long response after compaction remain additional gates. No software update, agent-loop feature switch or model promotion was performed.
