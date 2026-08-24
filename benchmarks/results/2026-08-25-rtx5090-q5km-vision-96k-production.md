# RTX5090 Jonathan Q5_K_M Vision 96K Production Finalization

Date: 2026-08-25 (Asia/Tokyo)

## Decision

JonathanColetti Qwen3.8-27B-Uncensored Vision Q5_K_M at 98,304 context is the RTX5090 **Recommended Production / Operational Profile** with MTP draft 3, Q8_0/Q8_0 KV, eval batch 1024, effective ubatch 512, Flash Attention, full GPU/KV offload, mmap+mlock, parallel 1, and PL 402W.

Repository lifecycle `Current` remains `current-qwen38-27b-uncensored-q6k`. Q6 Vision Balanced remains the Quality/Performance Reference, Q6 Safe remains the permanent known-good fallback, and Q6 Coding-Fast remains explicit-only. No Q6 loader was deleted, overwritten, or deprecated.

今回の実用fixtureではPromotionを妨げる品質差を観測していない。This is not a claim that Q5 and Q6 have completely equal quality.

## Artifact verification

| Artifact | Bytes | SHA-256 | Result |
|---|---:|---|---|
| `Qwen3.8-27B-Uncensored-Q5_K_M.gguf` | 19,535,701,408 | `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547` | re-hash PASS |
| `Qwen3.8-27B-Uncensored-vision-f16.gguf` | 927,606,912 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` | re-hash PASS |

Both files remain outside Git. The managed LM Studio model key and API identifier are `qwen3.8-27b-uncensored-vision-q5km`.

## Fixed protocol

MTP was the only intended variable in the final sweep: 98,304 context, Q8_0/Q8_0, eval batch 2048, effective ubatch 512, parallel 1, Flash Attention ON, full GPU and KV offload, mmap+mlock, PL 402W, temperature 0, and reasoning OFF. Each Text, Coding, Vision, and Long workload used one warm-up plus three formal runs. The sequence was OFF-A → draft 2 → draft 3 → draft 4 → OFF sentinel.

### MTP sweep — generation and quality

| MTP | Text tok/s | Coding tok/s | Vision tok/s | Long tok/s | 4-workload geomean | Weighted acceptance | Quality | Peak VRAM MiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| OFF-A | 51.07 | 50.87 | 50.92 | 46.23 | 49.73 | n/a | 12/12 PASS | 25,241 |
| draft 2 | 46.78 | 59.98 | 57.83 | 51.94 | 53.88 | 86.97% | 12/12 PASS | 26,412 |
| **draft 3** | **46.54** | **63.09** | **59.10** | **53.42** | **55.18** | **84.06%** | **12/12 PASS** | **26,548** |
| draft 4 | 47.56 | 63.27 | 56.97 | 53.63 | 55.06 | 79.93% | 12/12 PASS | 26,692 |
| OFF sentinel | 50.85 | 50.91 | 50.91 | 46.34 | 49.71 | n/a | 12/12 PASS | 25,217 |

The OFF-A Vision response scored 7/7 but the first harness validity rule rejected its short natural completion. The same condition was re-run after correcting only that session-local validity rule; all three formal Vision runs were 7/7 and valid. The corrected 50.92 tok/s value is used above.

Draft 3 versus OFF-A changed Text/Coding/Vision/Long generation by -8.88%/+24.03%/+16.05%/+15.55%, respectively, and improved the geomean by about 10.97%. Draft 4 did not beat draft 3 on geomean, Vision, acceptance, or VRAM. OFF sentinel drift versus OFF-A was -0.43%/+0.09%/-0.03%/+0.23%, all below 0.5%. Draft 3 is therefore selected, with the Text regression explicitly accepted as an operational tradeoff.

### MTP sweep — prompt, TTFT, and telemetry

Each workload cell is median prompt tok/s / median TTFT seconds.

| MTP | Text | Coding | Vision | Long | Shared peak GiB | RAM peak GiB | Median average power W | Peak power W | Peak temp C |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| OFF-A | 1,454.92 / 0.0982 | 6,380.18 / 0.0927 | 8,365.74 / 0.0974 | 273,619.77 / 0.1061 | 0.426 | 70.90 | 365.32 | 404.97 | 60 |
| draft 2 | 1,471.40 / 0.0961 | 5,964.31 / 0.0989 | 7,553.43 / 0.1034 | 193,861.27 / 0.1579 | 0.585 | 72.44 | 302.88 | 390.24 | 58 |
| draft 3 | 1,434.13 / 0.0985 | 6,010.45 / 0.0962 | 7,928.60 / 0.0993 | 194,721.01 / 0.1549 | 0.589 | 72.36 | 302.92 | 402.24 | 58 |
| draft 4 | 1,417.62 / 0.0974 | 5,907.12 / 0.0991 | 8,111.96 / 0.0974 | 206,882.96 / 0.1483 | 0.585 | 71.84 | 300.45 | 398.40 | 58 |
| OFF sentinel | 1,445.62 / 0.0971 | 5,897.13 / 0.1002 | 8,388.00 / 0.0977 | 277,783.21 / 0.1025 | 0.426 | 69.54 | 356.45 | 407.31 | 60 |

The repeated MTP-sweep Long fixture triggered LM Studio prefix/checkpoint caching, so its prompt/TTFT values are retained as observed telemetry but are not used for the eval-batch decision. The batch comparison below used run-unique prompts with a nonce at the beginning and exact paired content across conditions.

## Eval batch comparison

MTP draft 3 and effective ubatch 512 were fixed. Text used the normal fixture; Long used approximately 24,136 input tokens with unique warm-up/run nonces.

| Eval batch | Text gen tok/s | Text prompt tok/s | Text TTFT s | Long gen tok/s | Long prompt tok/s | Long TTFT s | Long peak VRAM MiB | Long Shared GiB | Long RAM GiB |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **1024** | **47.02** | **1,431.06** | **0.0988** | **59.95** | **2,132.05** | **11.3648** | **26,480** | **0.563** | **73.66** |
| 2048 | 46.61 | 1,413.55 | 0.0989 | 60.15 | 2,129.33 | 11.3727 | 26,478 | 0.583 | 73.99 |

Long prompt throughput and TTFT were effectively equal. Batch 1024 was selected because it was slightly better for Text and retained slightly lower Shared memory and RAM, without sacrificing the effective ubatch 512 invariant.

## Capacity gate

The final MTP3/batch1024 load audit passed at 98,304 context.

| Metric | Result |
|---|---:|
| Dedicated VRAM after load | 26,432 MiB |
| Raw dedicated headroom | 6,175 MiB |
| Reserve | 420 MiB |
| Effective headroom after reserve | 5,755 MiB / about 5.62 GiB |
| Shared after load | 0.540 GiB |
| Shared increase | 0.309 GiB |
| Maximum selected-setting generation peak | 26,498 MiB |
| Maximum selected-setting Shared peak | 0.569 GiB |
| Maximum selected-setting RAM peak | 73.66 GiB in paired Long; 72.80 GiB in >64K gate |

The configuration preserves roughly 6 GiB-class raw VRAM headroom and does not optimize up to the memory limit. It leaves room for the future DFlash2 drafter qualification, while making no claim that an unmeasured drafter already fits.

## Final quality gate

| Gate | Result | Evidence |
|---|---|---|
| Text | PASS | 47.02 tok/s, prompt 1,431.06 tok/s, TTFT 0.0988 s |
| Coding | PASS | 63.08 tok/s, prompt 5,987.91 tok/s, TTFT 0.0971 s; 3/3 formal |
| Vision | PASS | 59.98 tok/s, prompt 7,805.42 tok/s, TTFT 0.1002 s; 7/7 in all 3 formal runs |
| Long Context >64K | PASS | 69,139 input tokens, 53.98 generation tok/s, 1,641.79 prompt tok/s, TTFT 42.1738 s, 95.56% MTP acceptance |
| Tool Calling | PASS | exactly one `lookup_inventory` call with exact `sku` and `warehouse` arguments, no prose, reasoning tokens 0 |
| Agentic Coding | PASS | isolated copy, initial 5/10 to final 10/10, independent re-test exit 0, required files only, no dependency addition |

During Agentic Coding, Goose made recoverable Windows shell-selection mistakes and one unnecessary image-read attempt, then completed the task and passed independent tests. These are recorded as minor tool-selection drift, not a functional gate failure.

## Q6 relationship

- The Q5 model artifact is 2,895,298,560 bytes (2.6965 GiB) smaller than Q6_K.
- The earlier 96K Q6 control peaked at 29,720 MiB. The final Q5 Production >64K run peaked at 26,498 MiB, an indicative 3,222 MiB reduction; this is cross-session evidence, not a fresh same-profile speed A/B.
- Q5 provides the selected 96K operational capacity and headroom. Q6 Balanced remains the measured 64K Quality/Performance Reference; Q6 Safe and Coding-Fast remain separately selectable.
- No complete Q5/Q6 quality-equivalence claim is made.

## DFlash2 build toolchain readiness

Only the Windows build toolchain was prepared. No llama.cpp/DFlash2 repository was cloned or fetched, no DFlash2 binary was built, no drafter was downloaded, no server was started, port 18080 was not used, and no DFlash2 benchmark was run.

| Component | Verified version/result |
|---|---|
| Visual Studio Build Tools 2022 | 17.14.39 |
| MSVC v143 | compiler 19.44.35228; tools 14.44.35207 |
| Windows SDK | 10.0.26100.0 |
| MSBuild | 17.14.51.32402 |
| CMake | 4.4.2 |
| Ninja | 1.13.2 |
| CUDA nvcc | 12.9 / V12.9.41 |
| CUDA architecture smoke | `sm_120` configure/build/run PASS on RTX5090; `cc=12.0 value=5090` |
| Installer reboot state | Visual Studio installer `isRebootRequired=false`; CBS and Windows Update reboot-pending markers absent |

A pre-existing `PendingFileRenameOperations` value was observed, but it was not corroborated by the Visual Studio installer, CBS, or Windows Update as a new toolchain reboot requirement. No automatic reboot occurred.

## Raw evidence boundary

All raw telemetry, prompts, SSE responses, tool transcripts, isolated working copies, and the CUDA smoke project remain ignored under `benchmarks/raw/q5km-production-finalization-20260824/`. Key condition directories are:

- `harness/phase1-results/q5-96k-mtp-off-a-final/`
- `harness/phase1-results/q5-96k-mtp-off-a-vision-final/`
- `harness/phase1-results/q5-96k-mtp2-final/`
- `harness/phase1-results/q5-96k-mtp3-final/`
- `harness/phase1-results/q5-96k-mtp4-final/`
- `harness/phase1-results/q5-96k-mtp-off-sentinel-final/`
- `harness/phase1-results/q5-mtp3-batch1024-long-final/`
- `harness/phase1-results/q5-mtp3-batch2048-long-final/`
- `harness/phase1-results/q5-final-mtp3-batch1024-capacity/`
- `harness/phase1-results/q5-final-mtp3-batch1024-long64/`
- `quality-tool-final/`
- `agentic-final-result/`
- `toolchain-smoke/`

No model weight, projector, credential, API key, private prompt, or raw sensitive artifact is committed.
