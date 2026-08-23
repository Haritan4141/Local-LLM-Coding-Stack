# RTX3090 Remote LLM Node Evaluation

Date: 2026-08-20 (Asia/Tokyo)

Node: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`

Decision: **JonathanColetti Q4_K_M at 32K is the RTX3090 remote coding default; HauhauCS Aggressive Q4_K_P remains an optional Candidate**

The RTX5090 Current remains `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` Q6_K at 96K. This evaluation assigns a role to a separate LAN node and does not promote or replace the repository Current.

## Environment and network boundary

| Item | Value |
|---|---|
| Hardware | Ryzen 7 5700X / RTX 3090 24,576 MiB / RAM 31.93 GiB |
| NVIDIA driver | 591.86 |
| LM Studio | 0.4.21.0 / CLI commit `71bd99c` |
| Main-PC client | VS Code / Zoo Code 3.78.0 |
| LAN API | `http://192.168.0.104:1234` |
| Listen / reachability | `0.0.0.0:1234`; main-PC `GET /v1/models` passed |
| Firewall | TCP 1234 inbound / Private / LocalSubnet / Edge Block / LM Studio executable scoped |
| Firewall backup | `C:\Users\Atsuki\Codex-RTX3090-Setup\firewall-before-lmstudio-20260820-114203.wfw` |

No Public/Any TCP 1234 rule was created. The RTX5090 LM Studio runtime, Current model, settings, and loaders were not changed.

## Artifacts outside Git

| Model / projector | Bytes | SHA-256 | Result |
|---|---:|---|---|
| Jonathan Q4_K_M | 16,810,714,528 | `4c5e2db039e9325ac7724c8846c71356a24ad1cdfa28002d73ecb6be645f9675` | exact upstream match |
| Jonathan Vision F16 | 927,606,912 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` | installed; `mmproj-` hardlink alias used without duplicating bytes |
| HauhauCS Aggressive Q4_K_P | 17,923,393,664 | `ba36dc3c2b2ff5e0aa5d71092a8894546996a6a119ae391803dda07cdc08516d` | exact upstream match |
| HauhauCS Aggressive BF16 mmproj | 931,146,624 | `5681b690bcb8eb10cd28d62d078cb4e01521a3ea4880a3fc7d54de72de2dd142` | exact upstream match; active for Vision |

Both repositories advertise 262,144 native context and retained embedded MTP. HauhauCS FastMTP was not installed: its separate sidecar requires the author's custom patched llama.cpp and is not the stock LM Studio embedded-MTP path.

Sources: [JonathanColetti model card](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/README.md), [Jonathan files API](https://huggingface.co/api/models/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/tree/main?recursive=true&expand=true), [HauhauCS model card](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/blob/main/README.md), [HauhauCS files API](https://huggingface.co/api/models/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/tree/main?recursive=true&expand=true)

## Controlled settings

| Setting | Value |
|---|---|
| GPU offload | maximum / all 65 layers |
| Flash Attention | ON |
| K / V cache | Q8_0 / Q8_0 |
| KV cache GPU offload | ON |
| Max Concurrent Predictions | 1 |
| Embedded MTP | ON unless the row says OFF |
| Max draft tokens | 2 |
| Reasoning budget / max output | 8,192 for the dedicated reasoning test |

The official `@lmstudio/sdk` 1.5.0 loader was used with a narrow load-config injection for LM Studio's parallel-session and MTP boolean fields. Every accepted run audited context, Flash Attention, Q8/Q8, full GPU offload, MTP mode, draft max 2, and parallel 1 from the effective runtime configuration.

Zoo Code must select the same natural identifier used by the managed loader:

- Jonathan: `qwen3.8-27b-uncensored@q4_k_m`
- HauhauCS: `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp`

Selecting an indexed repository path instead can cause LM Studio to auto-load another instance with implicit 8K/parallel defaults.

## Performance, VRAM, MTP, and context

The generation fixture used one unmeasured warm-up followed by three measured 512-token runs. Peak VRAM is whole-GPU `nvidia-smi` usage. 32K MTP acceptance is aggregated from LM Studio's accepted/drafted counters for three runs.

| Model / context / MTP | Median generation | Peak VRAM | Draft acceptance | Stability |
|---|---:|---:|---:|---|
| Jonathan Q4_K_M / 32K / ON | 36.31 tok/s | 19,737 MiB | 578/782 = 73.91% | stable; recommended default |
| Jonathan Q4_K_M / 32K / OFF | 33.37 tok/s | 18,902 MiB | n/a | stable; MTP ON +8.8% |
| Jonathan Q4_K_M / 64K / ON | 35.88 tok/s | 21,106 MiB | not sampled | three runs stable; about 3.2 GiB idle headroom |
| HauhauCS Q4_K_P / 32K / ON | 35.47 tok/s | 20,867 MiB | 546/750 = 72.80% | stable Candidate |
| HauhauCS Q4_K_P / 32K / OFF | 31.86 tok/s | 19,932 MiB | n/a | stable; MTP ON +11.3% |
| HauhauCS Q4_K_P / 64K / ON | 36.28 tok/s | 22,156 MiB | not sampled | three runs stable; about 2.1 GiB idle headroom |

At 32K, Jonathan is about 2.4% faster, uses 1,130 MiB less peak VRAM, and has 1.11 percentage points higher draft acceptance. At 64K, HauhauCS is about 1.1% faster but uses 1,050 MiB more VRAM. Both 64K loads are valid, but neither should share the GPU with another model or graphics workload.

96K was deliberately not loaded. Extrapolated Q8 KV growth leaves too little safety margin on 24 GB, especially for HauhauCS. No 96K loader is provided.

## Prompt processing

Three unique 15,478-token list prompts were sent to each 32K model with a 16-token output cap. `prompt tokens / time_to_first_token` is reported as the practical prompt-processing rate.

| Model | TTFT runs | Prompt tok/s runs | Median |
|---|---|---|---:|
| Jonathan Q4_K_M | 17.0005 / 17.1542 / 17.0996 s | 910.44 / 902.29 / 905.17 | **905.17 tok/s** |
| HauhauCS Q4_K_P | 17.4524 / 17.1679 / 17.2438 s | 886.87 / 901.57 / 897.60 | **897.60 tok/s** |

Jonathan is about 0.8% faster; prompt ingestion is operationally equivalent.

## Reasoning Budget 8,192

| Model | Completion | Wall time | Generation | Stop | Usable final answer |
|---|---:|---:|---:|---|---|
| Jonathan Q4_K_M | 8,192 | 230.585 s | 35.55 tok/s | `maxPredictedTokensReached` | no |
| HauhauCS Q4_K_P | 8,192 | 238.659 s | 34.35 tok/s | `maxPredictedTokensReached` | no |

Both quantized 3090 models over-thought the fixed reasoning fixture and failed to expose a final answer. This makes neither a replacement for the 5090 Current's validated reasoning behavior.

## Tool Calling and Agentic Coding

Direct OpenAI-compatible Tool Calling returned the exact requested `read_file({"path":"README.md"})` call for both models.

The Zoo Code fixture began at 5/10 tests and required Japanese instruction understanding, multi-file reading, a failing test command, minimal edit, `CHANGE_NOTE.md` creation, final tests, and a scoped report.

| Item | Jonathan Q4_K_M | HauhauCS Q4_K_P |
|---|---|---|
| Initial / final tests | 5/10 -> 10/10 | 5/10 -> 10/10 |
| File read / command / edit / create | pass | pass |
| Japanese instruction and bug analysis | pass | pass |
| Workspace boundary | no outside edit observed | no outside edit observed |
| Long Agent loop | completed | completed after corrected 32K identifier load, about 320 s |
| Topic drift | none in coding task | none in coding task |
| Timing quality | not scored: an old HauhauCS conversation auto-loaded an 8K/parallel 4 instance and temporarily reduced free VRAM to 208 MiB | valid after correction |

The accidental dual-load was detected with `lms ps`; only the idle implicit HauhauCS instance was unloaded. This did not modify the model files or 5090 Current, but it establishes an operational rule: after a Zoo profile switch, start a new task and verify a single intended model before work.

## Vision

The deterministic PNG contains seven requested fields: product name, selected sidebar item, title, badge, context, KV cache, and error code.

| Path | Jonathan Q4_K_M | HauhauCS Q4_K_P |
|---|---|---|
| LM Studio model metadata | Vision projector recognized | Vision projector recognized |
| Direct LAN API PNG | 7/7 | 7/7 |
| UI text/layout understanding | pass | pass |
| Zoo Code image attachment | not repeated; attachment control available | image successfully attached and sent |
| Zoo Code answer | not measured | fail: repeated directory/README tool calls; stopped at 129 s without answering |

HauhauCS's direct Vision path is healthy, so the Zoo failure is not a missing projector, corrupt image, or LAN transport problem. The image reached Zoo Code, but Code mode combined it with agent tools and looped over workspace context. For dependable image-only work on this node, use LM Studio/direct API rather than Zoo Code Code mode until that integration behavior changes.

## Comparison with RTX5090 Current

The following 5090 values are existing controlled results for Jonathan Q6_K. GPU, quantization, and model/repository differences are inseparable variables, so this is an operational role comparison, not a pure GPU benchmark.

| System | 32K generation | 64K generation | 96K | Vision state | Agentic / reasoning role |
|---|---:|---:|---|---|---|
| RTX5090 Jonathan Q6_K Current | 49.50 tok/s | 53.38 tok/s | 49.94 tok/s, stable | installed Current lacks projector | primary; validated concise Agent loop and reasoning convergence |
| RTX3090 Jonathan Q4_K_M | 36.31 tok/s | 35.88 tok/s | excluded | direct API 7/7 with projector | remote coding default; Reasoning 8192 failed |
| RTX3090 HauhauCS Q4_K_P | 35.47 tok/s | 36.28 tok/s | excluded | direct API 7/7; Zoo Code looped | optional Candidate/Vision direct API; Reasoning 8192 failed |

The 3090 models are about 27–33% slower than the 5090 Current at comparable context sizes and use lower quantization. Their value is capacity isolation: VRChat/Unity or desktop work can stay on the 5090 while long local generation consumes the 3090.

## Decision and operational end state

1. Use Jonathan Q4_K_M 32K for routine RTX3090 remote coding. It has the best 32K speed, VRAM margin, and acceptance of the two.
2. Use 64K only for a single long-context job after confirming no other model/GPU workload. Prefer Jonathan because it retains about 1 GiB more headroom.
3. Use HauhauCS Q4_K_P when its Aggressive behavior or direct-API Vision is specifically useful. Do not treat Zoo Code Vision as reliable on this evidence.
4. Keep RTX5090 Jonathan Q6_K 96K as the main Current for quality, long-context stability, and reasoning. Use the 3090 to offload background/parallel coding work, especially while VRChat occupies the 5090.
5. When a verified Balanced-MTP release appears, repeat 32K/64K generation, prompt ingestion, MTP ON/OFF/acceptance, Reasoning 8192 convergence, the isolated Zoo Agent fixture, and Zoo image transport.

Evaluation end state:

- RTX3090 LM Studio: Jonathan Q4_K_M / 32K / Q8_0 K+V / full offload / embedded MTP 2 / parallel 1.
- Main-PC Zoo Code: active profile restored to `default`; `RTX3090 Jonathan Q4KM` and `RTX3090 Hauhau Q4KP` remain saved for manual selection.
- RTX5090 Current: unchanged.
