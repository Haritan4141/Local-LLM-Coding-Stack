# RTX5090 Standalone MTP3 Turbo Phase 2B Qualification

Date: 2026-08-25 (Asia/Tokyo)  
Host: `DESKTOP-5NPLIIV` / AMD Ryzen 9 9950X3D / NVIDIA GeForce RTX 5090 32 GB  
Decision: **PASS — General Turbo Candidate**

## Decision and scope

The standalone llama.cpp MTP3 configuration qualified as a General Turbo Candidate for the existing JonathanColetti Qwen3.8-27B-Uncensored Vision Q5_K_M 96K target. It substantially improved measured generation throughput while passing the normal quality matrix, Vision, tool calling, agentic coding through Goose, long-context, long-output, endurance, switching, and failure-recovery gates.

This is a separate opt-in runtime Candidate. Stable LM Studio Production was not changed, no repository runtime/profile integration was performed, and no default was promoted. DFlash2 remains a different Candidate and was not enabled or combined with this result.

## Fixed configuration

| Dimension | Qualified setting |
|---|---|
| Model | JonathanColetti Qwen3.8-27B-Uncensored Vision Q5_K_M |
| Model SHA-256 | `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547` |
| Vision projector | F16, SHA-256 `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |
| Context | 98,304 |
| Target KV | Q8_0 / Q8_0, GPU resident |
| Speculative decoding | target-contained MTP, draft max 3, draft KV Q8_0 / Q8_0 |
| Eval batch / effective ubatch | 1024 / 512 |
| Runtime | standalone llama.cpp, native Windows x64 CUDA build |
| GPU execution | Flash Attention ON, full GPU offload, parallel 1 |
| Load mode | mmap + mlock |
| Sampling | temperature 0, reasoning OFF |
| GPU power limit | 402 W |

The qualification build was `f7aadef0932e47d66a4349245957e81126a7c734` (`llama-server.exe` SHA-256 `08f989b85438291600fdeee8857686dad7703c5b25b5cdb96ed21160daf26445`). An independent parity build from official mainline commit `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` completed successfully for CUDA `sm_120a`; its `llama-server.exe` SHA-256 was `103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5`.

## Stable LM Studio versus Standalone Turbo

Values are controlled formal-run medians. The Stable Text value uses the closing sentinel because the initial Stable Text run showed a non-reproduced transient slowdown; the sentinel was within 3.05% of the Phase 2A reference.

| Workload | Stable LM Studio tok/s | Standalone Turbo tok/s | Turbo change |
|---|---:|---:|---:|
| Text | 49.06 | 83.75 | **+70.72%** |
| Coding | 65.43 | 106.50 | **+62.78%** |
| Long | 62.56 | 93.06 | **+48.75%** |
| Generation geomean | — | — | **+60.49%** |

All three normal workloads retained 3/3 quality PASS. MTP was active in Turbo runs. Acceptance varied by workload—approximately 52.01% Text, 76.51% Coding, and 70.78% Long—so the throughput result is not presented as a universal acceptance-rate increase.

## Vision and functional quality

| Gate | Result |
|---|---|
| Vision canary | PASS, 7/7 checks |
| Vision formal | **3/3 runs PASS; 7/7 checks in every run** |
| Vision MTP | ACTIVE; formal aggregate 621 accepted / 972 drafted, 63.89% |
| Tool Calling | **3/3 PASS**; exact function and schema-valid arguments, no extra prose |
| Agentic Coding | **10/10 PASS** after the isolated fixture repair; independent rerun 10/10 |
| Goose integration | **PASS** through Goose's built-in OpenAI-compatible provider against localhost |

The agentic run used an isolated copy of the repository fixture. It changed only the requested fixture files, completed the Goose edit/test loop, and passed the independent final tests. Persistent Goose configuration was not changed.

Quality equivalence is based on task completion, fixture tests, structured-output validity, constraint adherence, semantic checks, and exact markers where the task required them. Bit-exact natural-language output is not treated as the sole condition for quality equivalence.

## Context, endurance, and cache behavior

| Gate | Observed result |
|---|---|
| Long-context recall | **PASS** at 76,852 input tokens; 6/6 facts recovered; no overflow or truncation |
| Multi-turn | **15/15 PASS**; exact turn and recall markers, no cross-turn contamination |
| Sequential endurance | **20/20 PASS**; no HTTP errors, queue buildup, or monotonic memory growth |
| Long output | **18,432 output tokens PASS**; 30,888 prompt / 49,320 total tokens; no crash or overflow |
| Default prefix reuse | cold TTFT **7.068 s** → warm TTFT **0.151 s** with the same long prefix |

The long-output run sustained 109.90 generation tok/s and finished normally. The prefix result records observed default server reuse; no special prefix-cache optimization was enabled for this claim.

## Resources, thermals, and stability

| Metric | Stable LM Studio | Standalone Turbo | Interpretation |
|---|---:|---:|---|
| Conservative peak dedicated VRAM | 29,489 MiB | **27,663 MiB** | Turbo used 1,826 MiB less at the observed maxima |
| Dedicated headroom at Turbo peak | — | **4,944 MiB / about 4.83 GiB** | Based on 32,607 MiB reported total |
| Formal Shared peak | 675.0 MiB | **674.9 MiB** | No Shared-memory spill or growth |
| Formal host RAM peak | 74.69 GiB | **74.08 GiB** | No host-memory pressure failure |
| Average power: Text / Coding / Long | — | **380.6 / 354.1 / 387.8 W** | PL remained 402 W |
| Peak temperature | — | **67 C** | No thermal failure |

A short telemetry sample reached about 412.97 W while the configured NVIDIA power limit remained 402 W; no power-limit mutation, OOM, TDR, crash, or responsiveness failure occurred. No manual desktop UX score is inferred from the automated health checks.

## Runtime switching and recovery

- Stable → Turbo → Stable completed **3/3 cycles**, with exact smoke markers and expected model/runtime audits at every stage.
- Forced standalone-server termination and restoration to Stable completed **PASS**.
- The final qualification state was the unchanged Stable LM Studio Q5_K_M Vision 96K Production model, idle with parallel 1; no standalone server remained and port 18080 was free.
- Stable LM Studio Production settings and repository profiles were not changed by Phase 2B.

## Official mainline parity

The exact official mainline commit `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` was built independently and compared against the primary qualification binary under the same MTP3/Q8/96K/batch configuration.

| Workload | Qualification build tok/s | Official mainline tok/s | Mainline delta |
|---|---:|---:|---:|
| Text | 83.752 | 84.199 | +0.53% |
| Coding | 106.502 | 106.691 | +0.18% |

Both parity workloads passed 3/3 quality checks. The official build is therefore within the required ±3% performance envelope and is the preferred pinned source reference for future runtime integration. This parity statement is limited to the measured Text and Coding workloads; it does not claim that every upstream revision or every model/runtime combination is qualified.

## Classification

**General Turbo Candidate: PASS.** The standalone MTP3 runtime is qualified for explicit Candidate use with this exact Q5_K_M Vision 96K configuration. It is not yet the General Default or Production runtime. Stable LM Studio remains Production and rollback. DFlash2 remains a separate Specialized Experimental Candidate and is not part of this result.

## Raw evidence boundary

Raw JSON, SSE responses, prompts, telemetry CSVs, server logs, Goose transcripts, isolated workspaces, source trees, and binaries remain outside Git under:

`D:\AI-Throughput-Lab\RTX5090-Phase2\phase2b-mtp3`

Key evidence groups include `raw/fresh-t-turbo/`, `raw/formal-t-vision/`, `raw/formal-t-tool/`, `raw/goose-agentic-primary3/`, `raw/extended/`, `raw/switching/`, and `raw/mainline-f280-parity/`. No raw benchmark, model weight, projector, credential, private prompt, source clone, or compiled binary is committed.
