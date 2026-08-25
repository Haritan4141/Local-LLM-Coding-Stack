# BLUE Standalone MTP3 Turbo Phase 2B Qualification

Date: 2026-08-25 (Asia/Tokyo)

Host: `DESKTOP-L9HAM1G` / AMD Ryzen 7 5700X / NVIDIA GeForce RTX 3090 24 GB + RTX 3060 12 GB

Decision: **PASS — General Turbo Candidate**

## Decision and scope

Standalone llama.cpp with target-contained MTP3 qualified as a General Turbo Candidate for the BLUE JonathanColetti Qwen3.8-27B-Uncensored Vision Q5_K_M 96K target. It improved measured generation and prompt-processing performance over Stable LM Studio Production while passing Vision, coding, tool-calling, long-context, multi-turn, endurance, long-output, Shared-memory, thermal, client-integration, runtime-switching, and recovery gates.

This result does not promote or modify BLUE Production. Stable LM Studio remains the operational Production runtime and rollback. DFlash2 was not loaded, enabled, patched, or retested in Phase 2B. The Phase 2A DFlash2 multi-GPU speculative-scheduler BLOCKED result is a separate experiment and does not apply to this target-contained MTP3 qualification.

## Fixed configuration

| Dimension | Qualified setting |
|---|---|
| Model | JonathanColetti Qwen3.8-27B-Uncensored Vision Q5_K_M |
| Model SHA-256 | `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547` |
| Vision projector | F16, SHA-256 `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |
| Context | 98,304 |
| KV cache | Q8_0 / Q8_0, GPU resident |
| Speculative decoding | Native target-contained MTP, draft max 3; no second draft model |
| Eval batch / ubatch | 1024 / 512 |
| Runtime | Standalone llama.cpp, native Windows x64 CUDA build |
| GPU execution | Flash Attention ON, full GPU offload, layer split, parallel 1 |
| Tensor split | RTX 3090 / RTX 3060 = `0.7108 / 0.2892` (about 71.08% / 28.92%) |
| Load mode | mmap OFF |
| Sampling | temperature 0, reasoning OFF |
| GPU power limit | RTX 3090 259 W / RTX 3060 170 W |
| Experimental API | BLUE localhost `127.0.0.1:18080` only |

Dynamic device discovery mapped llama.cpp `CUDA0` to the RTX 3090 at PCI Bus `00000000:0B:00.0` and `CUDA1` to the RTX 3060 at PCI Bus `00000000:01:00.0`. GPU indices were not assumed from `nvidia-smi`. Startup dedicated allocation was approximately 17.36 GiB on the RTX 3090 and 8.66 GiB on the RTX 3060.

The primary qualification source/result SHA was `37f5689f71d08d60d68f52da1d62d413aa55519e`; `llama-server.exe` SHA-256 was `dc331c14aaab614660a4a1a5f89f41ac77295e93346dbe2d47220276fc12629b`. The build used Release/Ninja, CUDA 12.9, CUDA architecture `sm_86`, `GGML_CUDA=ON`, `GGML_NATIVE=OFF`, server/examples ON, and tests/CURL OFF.

## Stable LM Studio versus Standalone Turbo

Values are arithmetic means from three controlled formal runs after a separate warm-up. Quality passed in every measured run.

| Workload | Stable generation tok/s | Turbo generation tok/s | Turbo change | Stable prompt tok/s | Turbo prompt tok/s | Stable TTFT | Turbo TTFT |
|---|---:|---:|---:|---:|---:|---:|---:|
| Text | 28.538 | 32.409 | **+13.56%** | 184.35 | 334.45 | 0.735 s | 0.292 s |
| Coding | 39.495 | 45.213 | **+14.48%** | 411.61 | 673.94 | 1.335 s | 0.778 s |
| Long | 28.148 | 34.072 | **+21.05%** | 774.47 | 920.44 | 19.966 s | 16.758 s |
| Generation geomean | — | — | **+16.3159%** | — | — | — | — |

Prompt processing and TTFT improved in all three workloads. The results reproduced the Phase 2A references within approximately 2.4%.

MTP counters increased in every run. Aggregate accepted/drafted counts were Stable/Turbo Text `755/980` and `906/1875`, Coding `1302/1393` and `1785/2097`, and Long `776/927` and `988/1632`. Counter behavior is recorded as observed and is not interpreted as a cross-runtime quality metric.

## Vision, coding, tools, and client integration

| Gate | Result |
|---|---|
| Vision canary | **PASS, 7/7**; no HTTP or position error; server remained healthy |
| Vision formal | **3/3 PASS, 7/7 checks in every run** |
| Coding quality | **78/78** across three outputs: public 10/10 plus hidden/edge 16/16 per output |
| Tool Calling | **3/3 PASS**; exact function, schema-valid arguments, no extra prose or malformed call |
| MAIN-to-BLUE access | **PASS** through an SSH tunnel from MAIN localhost:18080 to BLUE localhost:18080; no firewall change |
| Goose Agentic Coding | **10/10 PASS** after the requested isolated fixture edit; independent final rerun also 10/10 |

The Goose run used its built-in OpenAI-compatible provider with process-local settings through the SSH tunnel. It exercised tool use, multi-turn interaction, code editing, test execution, and final response generation. Persistent Goose configuration was not changed.

## Context, endurance, and output length

| Gate | Observed result |
|---|---|
| Long-context recall | **PASS** with 76,831 input tokens; TTFT 136.404 s; prompt processing 566.99 tok/s; no truncation or overflow |
| Multi-turn | **15/15 PASS** in one session; prompt tokens increased from 45 to 507; no contamination or KV failure |
| Sequential endurance | **20/20 PASS**; final health OK; no request-by-request VRAM growth |
| Long output | **24,000 output tokens PASS**; 30,867 prompt / 54,867 total tokens; no 16K client cap, overflow, or crash |
| Prefix/cache observation | No special cache optimization; repeated 15,375-token prompt showed no material warm-prefix gain |

The long-output response ran at 41.840 generation tok/s and ended at the expected 24,000-token limit. A wrapper post-check initially inspected the wrong JSON field; the recorded response was independently validated at `usage.completion_tokens=24000`, so this was a harness post-check defect rather than a runtime failure.

## Resources, thermals, and stability

| Metric | Observed Turbo result |
|---|---:|
| Combined Shared maximum | **3.531 GiB**; strict limit <4 GiB |
| RTX 3090 Shared maximum | **1.787 GiB**; per-GPU limit <=2 GiB |
| RTX 3060 Shared maximum | **1.744 GiB**; per-GPU limit <=2 GiB |
| RTX 3090 maximum temperature | **81 C** |
| RTX 3060 maximum temperature | **82 C** |
| Continuous telemetry duration | More than 13 minutes |
| OOM / hardware thermal slowdown / hardware power brake | **None** |

Dedicated VRAM remained stable through the 20-request endurance sequence: RTX 3090 `17853 -> 17853 MiB` and RTX 3060 `8879 -> 8879 MiB`. Both GPUs reached 100% utilization during measured work. The continuous run observed average/peak power of 204.44/234.92 W on the RTX 3090 and 116.73/128.25 W on the RTX 3060 while the configured limits remained 259/170 W. Software power-cap flags reflected normal PL enforcement; hardware thermal-slowdown and power-brake flags remained inactive.

## Runtime switching and recovery

- Stable -> Turbo -> Stable completed **3/3 cycles** with runtime/configuration audits, exact smoke markers, port checks, VRAM release, and Production reload at every cycle.
- Forced termination of the validated standalone Turbo process and restoration to Stable completed **PASS** without a driver or operating-system reset.
- The SSH tunnel and standalone listener were stopped after testing; port 18080 was free on both MAIN and BLUE.
- Final state was the unchanged Stable LM Studio Q5_K_M Vision 96K Production model, API reachable, idle, queued 0, and parallel 1.

## Official mainline parity

Official llama.cpp master commit `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` was built independently for CUDA `sm_86` with the same relevant configuration. Its `llama-server.exe` SHA-256 was `970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4`.

| Workload | Primary qualification tok/s | Official mainline tok/s | Mainline delta |
|---|---:|---:|---:|
| Text | 32.409 | 32.402 | **-0.02%** |
| Coding | 45.213 | 46.427 | **+2.68%** |
| Vision canary | 7/7 | **7/7** | Quality parity PASS |

The official build also passed the unchanged Strict Shared gate. This pinned official commit is the preferred source reference for a future Turbo integration, but Phase 2B does not perform that integration or promote the Candidate.

## Classification

**General Turbo Candidate: PASS.** Standalone MTP3 is qualified for explicit Candidate use with this exact BLUE Q5_K_M Vision 96K configuration. It is not the General Operational Default or the Production runtime. Stable LM Studio remains Production and rollback. No Turbo loader or profile is integrated by this report.

## Raw evidence boundary

BLUE primary raw evidence remains outside Git under:

`C:\Users\Atsuki\Documents\DFlash2-Phase2\RTX3090-Dual\phase2b-mtp3`

MAIN-side orchestration, snapshots, and the isolated Goose fixture remain in the Git-ignored session-local path:

`benchmarks/raw/blue-mtp3-turbo-phase2b/session-20260825`

No raw logs, telemetry CSVs, model weights, projector, source clone, compiled binary, persistent client profile, credential, or private prompt is committed.
