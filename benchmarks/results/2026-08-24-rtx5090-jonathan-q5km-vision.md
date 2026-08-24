# RTX5090 JonathanColetti Q5_K_M Vision 96K Candidate evaluation

Date: 2026-08-24 (Asia/Tokyo)

## Decision summary

JonathanColetti Q5_K_M + official F16 Vision projector qualifies as the recommended explicit 96K Goose Candidate on RTX5090. Use Q8_0/Q8_0, full GPU offload, Flash Attention ON, MTP OFF, and parallel 1. It preserves substantially more VRAM than Q6_K Vision 96K and completed the long-context, Vision, Tool Calling, and isolated Agentic Coding gates.

It does not replace repository Current. Q6_K / MTP ON remains faster, the local quality sample is too small for a general equivalence claim, and the Reasoning Budget 8,192 fixture did not converge for either Q5_K_M or the same-condition Q6_K control.

## Identity and artifacts

| Item | Value |
|---|---|
| Host | `DESKTOP-5NPLIIV` |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB total / 420 MiB reserved |
| Driver observed | 610.62 |
| LM Studio CLI | commit `71bd99c` |
| Repository | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Revision | `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3` |
| Q5 artifact | `Qwen3.8-27B-Uncensored-Q5_K_M.gguf`, 19,535,701,408 bytes |
| Q5 SHA-256 | `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547` |
| Vision projector | `Qwen3.8-27B-Uncensored-vision-f16.gguf`, 927,606,912 bytes |
| Projector SHA-256 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |
| Model key / API identifier | `qwen3.8-27b-uncensored-vision-q5km` |

Both artifacts remain outside Git. The LM Studio model view uses NTFS hardlinks to the verified external files.

## Controlled runtime

- Context: 98,304
- K / V cache: Q8_0 / Q8_0
- KV cache GPU offload: ON
- Flash Attention: ON
- GPU offload: maximum / all layers
- Parallel: 1
- MTP comparison: ON and OFF; max draft tokens 2
- Text generation fixture: 512 output-token limit, temperature 0, top_p 1, one warm-up plus three measured runs
- Same-condition control: Q6_K Vision at 98,304 with the same cache, offload, parallel, and text fixture

The final managed preflight reported `valid=true`, Vision true, 98,304 context, Q8_0/Q8_0, MTP OFF, draft 2, and parallel 1.

## Speed and memory

| Model / MTP | Measured generation runs | Median | Median TTFT | Peak VRAM | WDDM Shared peak | MTP acceptance |
|---|---|---:|---:|---:|---:|---:|
| Q5_K_M / OFF | 53.9505, 53.4059, 53.7446 tok/s | 53.7446 tok/s | 0.0837 s | 25,876 MiB | 0.708 GiB | N/A |
| Q5_K_M / ON | 45.5164, 45.6169, 45.2101 tok/s | 45.5164 tok/s | 0.1132 s | 27,265 MiB | 0.885 GiB | 565 / 722 = 78.2548% |
| Q6_K / ON control | 60.5203, 60.8219, 60.8895 tok/s | 60.8219 tok/s | 0.0892 s | 29,720 MiB | not retained | not retained |
| Q6_K / OFF control | 48.4589, 48.3194, 48.0582 tok/s | 48.3194 tok/s | 0.0865 s | 28,413 MiB | not retained | N/A |

Observed comparisons:

- Q5_K_M MTP OFF was 18.1% faster than Q5_K_M MTP ON and used 1,389 MiB less peak VRAM.
- Q5_K_M MTP OFF was 11.6% slower than Q6_K MTP ON but used 3,844 MiB less peak VRAM.
- Q5_K_M MTP OFF retained 6,311 MiB / approximately 6.16 GiB effective headroom at peak after subtracting the 420 MiB NVIDIA reservation. This is a materially safer capacity margin than Q6_K Vision 96K, whose measured peak was 29,720 MiB in the same fixture.
- A distinct prompt-processing tok/s metric was not retained for this fixture. Do not infer one from TTFT.

## Long-context gate

| Metric | Result |
|---|---|
| Actual input tokens | 70,081 |
| Prior 64K ceiling exceeded | PASS |
| Expected marker | `NEEDLE-96K-PASS` |
| Returned marker | exact match |
| Request/runtime truncation error | not observed |
| TTFT | 39.5236 s |
| Generation | 40.6837 tok/s |
| Peak VRAM | 25,959 MiB |

The response stopped at the deliberately small 64-token output budget after returning the expected marker. This proves the 96K runtime accepted and processed an input above 65,536 tokens; it is not a full 90K agent-loop endurance test.

## Vision and Tool Calling

| Gate | Result | Notes |
|---|---|---|
| Direct Vision | PASS, 7/7 | Title, status, menu, context, KV cache, error text, button, and layout were correctly described |
| Vision generation | 52.2462 tok/s | Q5_K_M / MTP OFF |
| Vision peak VRAM | at most 25,959 MiB in the combined functional runs | No Shared-memory spill observed |
| Direct Tool Calling | PASS | Exact `record_candidate_metric` function and `context_tokens=98304`, `peak_vram_mib=25959` arguments |

An auxiliary PowerShell auto-scorer constructed its regex array incorrectly and printed 0/7 despite the response containing every requested field. The PASS is therefore based on direct verification of the model response, not the broken numeric scorer. The scorer failure is not counted as a model failure.

## Goose Agentic Coding

Goose CLI 1.47.0 was run against the Q5_K_M Candidate with process-only overrides:

- Provider: `lmstudio`
- Model: `qwen3.8-27b-uncensored-vision-q5km`
- `GOOSE_CONTEXT_LIMIT=90112`
- `GOOSE_MAX_TOKENS=16384`
- context strategy: summarize
- built-in developer tools only
- no session, max turns 20, max identical tool repetitions 3

The isolated fixture began at 5/10 tests. Goose inspected the multi-file tree, diagnosed the duration bug, modified only `src/duration.js`, added the requested `CHANGE_NOTE.md`, reran tests, and reached 10/10. An independent final test rerun returned exit code 0 with 10/10.

Goose made one unnecessary `read_image` call on a non-image source file, received an unsupported-image error, and recovered. Record this as minor tool-selection drift, not task failure. Final Goose statistics reported 49.87 tok/s, 0.39 s TTFT, and 711 output tokens.

Raw work products remain under ignored `benchmarks/raw/q5km-agentic-coding-v1/`; only this curated result is committed.

## Reasoning Budget 8,192

| Model / selected MTP | Completion tokens | Final answer | Stop reason |
|---|---:|---|---|
| Q5_K_M / OFF | 8,192 | none | `maxPredictedTokensReached` |
| Q6_K / ON control | 8,192 | none | `maxPredictedTokensReached` |

Both runs spent the full budget in the reasoning channel and emitted no final answer. Because the same-condition Q6_K control showed the same behavior, this run does not establish a Q5-specific reasoning regression. It also means Reasoning is not a PASS for promotion; a revised fixture is required before any lifecycle change.

## Operational recommendation

Use the Candidate when 64K is insufficient and desktop responsiveness matters:

- LM Studio: Q5_K_M Vision, 98,304, Q8_0/Q8_0, Flash ON, full offload, MTP OFF, parallel 1.
- Goose child process: context limit 90,112, max output 16,384, compact threshold 0.3.
- Start with `Goose Q5KM Vision 96K Candidate`; it leaves the persistent Goose config and existing `Goose Vision 64K` shortcut unchanged.

Keep Q6_K as repository Current. Prefer Q6_K when peak coding speed is more important and the working context fits safely. Continue real-world observation for quality, mouse responsiveness, very long same-turn tool loops, and Desktop image attachment before considering promotion.
