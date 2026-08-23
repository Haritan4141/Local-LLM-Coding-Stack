# HauhauCS Aggressive-MTP Candidate A/B Result

Date: 2026-08-20 (Asia/Tokyo)

Decision: **do not promote; keep JonathanColetti Q6_K as Current**

## Environment and controlled settings

| Item | Value |
|---|---|
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB, driver 610.62 |
| LM Studio | 0.4.21 / CLI commit 71bd99c / llama.cpp CUDA runtime 2.29.1 |
| VS Code / Zoo Code | 1.121.0 / 3.78.0 |
| Current | JonathanColetti Q6_K, API ID `qwen3.8-27b-uncensored` |
| Candidate Q6 | HauhauCS Aggressive Q6_K_P, API ID `qwen3.8-27b-hauhaucs-aggressive` |
| Candidate fallback | HauhauCS Aggressive Q5_K_P, temporary API ID `qwen3.8-27b-hauhaucs-aggressive-q5kp` |
| Common load policy | all GPU layers, Flash Attention ON, Q8_0 K/V target, KV GPU offload ON, parallel 1 |
| Controlled MTP | embedded MTP, max draft tokens 2; OFF runs explicitly use `--no-speculative-draft-mtp` |
| Reasoning | budget/max output 8,192 for the dedicated reasoning test |

The fixed speed fixture generated 512 tokens after one unmeasured warm-up. Medians are three runs except Q6_K_P 96K, which is a single exploratory run because VRAM was already saturated. Peak VRAM is whole-GPU `nvidia-smi` usage, so unrelated desktop applications are included.

Q6_K_PのQ8_0 K/VはLM StudioのGUIで直接確認した。Q5_K_Pは同じHauhauCS repositoryの保存済みCandidate defaultsを継承してロードしたが、CLIはcache quantizationをechoしないため、Q5_K_P variant単独のGUI再確認は行っていない。Q5_K_Pの表中数値はその実ロード状態での観測値である。

## Artifacts outside the repository

| Artifact | Bytes | SHA-256 | Result |
|---|---:|---|---|
| Q6_K_P GGUF | 25,924,151,424 | `70c8139f4dcd05d3818bc9843cde7301faa44f66321e5966965929baa9c24a6a` | hash matched upstream |
| Q5_K_P GGUF | 20,218,177,664 | `a21e22af885bd2f7c430a72b550a78f5445966e6a72d3143b0950baa0bd6d411` | fallback downloaded after Q6 VRAM failure; hash matched upstream |
| BF16 mmproj | 931,146,624 | `5681b690bcb8eb10cd28d62d078cb4e01521a3ea4880a3fc7d54de72de2dd142` | required and active for Vision |

The FastMTP sidecar was not downloaded or activated. It requires the author's custom llama.cpp patch and is not the embedded-MTP path bundled with stock LM Studio.

## Speed, VRAM, and context stability

| Model / context / MTP | Median generation tok/s | Peak VRAM MiB | Draft acceptance | Stability judgement |
|---|---:|---:|---:|---|
| Current Q6_K / 32K / ON | 49.50 | 25,843 | 590/781 = 75.54% | stable |
| Current Q6_K / 64K / ON | 53.38 | 27,174 | 628/786 = 79.90% | stable |
| Current Q6_K / 64K / OFF | 47.87 | 26,194 | n/a | stable |
| Current Q6_K / 96K / ON | 49.94 | 28,749 | 598/785 = 76.18% | stable Current baseline |
| Candidate Q6_K_P / 32K / ON | 38.38 | 30,423 | 561/794 = 70.65% | stable but little VRAM headroom |
| Candidate Q6_K_P / 32K / OFF | 39.00 | 29,512 | n/a | stable; ON was 1.6% slower |
| Candidate Q6_K_P / 64K / ON | 15.59 | 31,305 | 573/788 = 72.72% | loads, but VRAM/shared-memory pressure makes it impractical |
| Candidate Q6_K_P / 96K / ON | 17.05 | 31,742 | 92/138 = 66.67% | loads, only about 865 MiB nominal headroom; not a daily-use result |
| Candidate Q5_K_P / 32K / ON | 41.10 | 25,098 | 563/769 = 73.21% | stable |
| Candidate Q5_K_P / 32K / OFF | 45.90 | 24,333 | n/a | stable; ON was 10.5% slower |
| Candidate Q5_K_P / 64K / ON | 38.72 | 27,452 | 556/782 = 71.10% | stable, practical VRAM headroom |
| Candidate Q5_K_P / 96K / ON | 38.24 | 29,614 | 514/726 = 70.80% | three runs stable, about 2,993 MiB nominal headroom |

Q5_K_P fixes Q6_K_P's capacity problem, but at 96K it is about 23% slower than Current. Embedded MTP did not provide a speed gain for either Candidate quant on the fixed workload.

## Prompt processing and reasoning

The identical 22,864-token list-recall prompt measured 1,919.00 prompt tok/s for Candidate Q6_K_P and 1,750.74 prompt tok/s for Current. Candidate was about 9.6% faster at prompt ingestion.

| Reasoning-budget test | Current Q6_K | Candidate Q6_K_P |
|---|---:|---:|
| Completion tokens | 3,776 | 8,192 |
| Reasoning tokens / behavior | 2,882; converged | consumed the full budget and ended mid-reasoning |
| Wall time | 80.18 s | 179.36 s |
| Generation speed | 47.88 tok/s | 45.84 tok/s |
| Stop reason | `eosFound` | `maxPredictedTokensReached` |
| Usable final answer | yes, correct bug analysis and minimal fix | no |

This is the decisive regression: the Aggressive Q6_K_P did not stop reasoning or reach a final answer under the requested 8,192 budget.

## Tool Calling, Agentic Coding, and Japanese instructions

Direct OpenAI-compatible Tool Calling returned a valid single call to `read_file({"path":"README.md"})` for Current, Candidate Q6_K_P, and Candidate Q5_K_P.

The Zoo Code test used isolated copies of the same five-file Node fixture. It required reading files, running failing tests, minimally editing `src/duration.js`, creating `CHANGE_NOTE.md`, rerunning tests, and reporting in Japanese.

| Zoo Code item | Current Q6_K | Candidate Q6_K_P |
|---|---|---|
| Initial / final tests | 5/10 -> 10/10 | 5/10 -> 10/10 |
| File read / command / edit / create | all succeeded | all succeeded |
| Workspace boundary | no outside edit | no outside edit |
| Approximate elapsed agent loop | 111 s | 163 s |
| Agent-loop MTP acceptance | 2,472/2,599 = 95.11% | 3,753/3,983 = 94.23% |
| Behavior note | concise test-oriented fix | more general fix, but repeated its design analysis and grew the conversation to about 31K prompt tokens |

Both models initially saw only `README.md` through Zoo Code's file listing, failed a PowerShell command in the cmd shell, recovered with `dir`, and completed. Because this symptom was identical for both models, it is attributed to the Zoo Code tool/shell context rather than to Aggressive alone. No topic drift or out-of-scope edit occurred, but Candidate was slower and more verbose across the long loop.

## Vision

The Q6_K_P and BF16 mmproj were recognized by LM Studio as `vision: true`. A deterministic 960x540 PNG contained a title, selected navigation item, context value, K/V cache, warning code, button label, and a two-column layout.

| Path | Result |
|---|---|
| Direct LM Studio API | 6/7 fields correct; it confused the requested button element once, while correctly reading the other UI text and layout |
| Zoo Code image attachment -> LM Studio | 7/7 correct; also rejected the prompt's false claim that the button was green and identified the actual blue `RUN VISION TEST` button |
| Current | `vision: false`; no mmproj path exists for the installed JonathanColetti model |

Vision is a real Candidate advantage, and the complete Zoo Code image transport path works.

## Decision

Do not promote Aggressive Q6_K_P or Q5_K_P to Current.

- Wins: working Vision, about 9.6% faster prompt ingestion, correct direct Tool Calling, successful isolated Zoo Code editing task, Q5_K_P can run 96K with practical VRAM headroom.
- Losses: Q6_K_P is not practical above 32K on 32 GB; Q5_K_P is materially slower than Current; embedded MTP gives no speedup; the 8,192-reasoning test failed to reach a final answer; the Candidate agent loop is slower and more verbose.
- Operational result: Zoo Code returned to the `default` Current profile, and LM Studio returned to JonathanColetti Q6_K at 98,304 context with embedded MTP enabled.
- Follow-up: wait for a verified HauhauCS Balanced Qwen3.8 release and repeat the same fixtures. Vision can justify keeping Aggressive as an optional, manually selected secondary model, but not replacing the stable coding Current.
