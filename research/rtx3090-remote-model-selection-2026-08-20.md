# RTX3090 Remote Node model selection snapshot

Captured: 2026-08-20 (Asia/Tokyo)

## Node constraint

`DESKTOP-L9HAM1G / RTX 3090 24,576 MiB / RAM 31.93 GiB`で、Q8_0 K/Vと32K・64K contextを優先する。最大量子化ではなく、モデルとKV cacheをVRAM内へ収める実用性を選定基準とする。

## JonathanColetti

- Repository revision: `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3`
- Selected fused artifact: `Qwen3.8-27B-Uncensored-Q4_K_M.gguf`
- Size: 16,810,714,528 bytes
- SHA-256: `4c5e2db039e9325ac7724c8846c71356a24ad1cdfa28002d73ecb6be645f9675`
- Embedded MTP: retained and verified by publisher; 65/65 blocks
- Native context: 262,144
- Vision: separate `Qwen3.8-27B-Uncensored-vision-f16.gguf`, 927,606,912 bytes, required for image input
- Selection: Q5_K_M is 19,535,701,408 bytes and would reduce 64K KV headroom by about 2.7 GB. Q4_K_M is the practical first choice for a 24GB remote node.

Source: [JonathanColetti model card](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/README.md), [Files API](https://huggingface.co/api/models/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/tree/main?recursive=true&expand=true)

## HauhauCS Aggressive

- Repository revision: `993a5971fda8f30dd1b7eb2654792ba4415c7460`
- Selected artifact: `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf`
- Size: 17,923,393,664 bytes
- SHA-256: `ba36dc3c2b2ff5e0aa5d71092a8894546996a6a119ae391803dda07cdc08516d`
- Embedded MTP: retained
- Native context: 262,144
- Vision: BF16 projector required, 931,146,624 bytes
- FastMTP: separate 903,453,952-byte sidecar plus custom patched llama.cpp is required. It is not selected for stock LM Studio evaluation.
- Selection: Q4_K_P is the highest requested quality tier with a plausible 32K fit on 24GB. 64K remains measurement-dependent.

Source: [HauhauCS model card](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/blob/main/README.md), [Files API](https://huggingface.co/api/models/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/tree/main?recursive=true&expand=true)

## Controlled evaluation policy

- Full GPU offload, Flash Attention ON, Q8_0 K/V, KV GPU offload ON, parallel 1.
- Embedded MTP ON with max draft tokens 2, plus controlled OFF comparison.
- Start at 32K. Evaluate 64K only after a successful load and generation run. Do not force 96K without measured headroom.
- Keep RTX5090 Current, loader, LM Studio, and Zoo Code localhost profile unchanged.

LM Studio 0.4.21の`lms load`はcontext、GPU、parallel、MTPを指定できる一方、K/V cache quantization flagを公開していない。評価ロードは公式`@lmstudio/sdk` 1.5.0の`LLMLoadModelConfig`を使い、Q8_0 K/Vを含む全設定を単一リクエストで指定する。programmatic loadでparallelが既定値へ戻った既知報告があるため、毎回`lms ps`で`PARALLEL 1`を確認し、合わないrunは採用しない。

Sources: [LM Studio LLMLoadModelConfig](https://lmstudio.ai/docs/typescript/api-reference/llm-load-model-config), [LM Studio CLI load](https://lmstudio.ai/docs/cli/local-models/load), [programmatic K/V + parallel issue](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/2024)

## Evaluation result

Evaluation completed: 2026-08-20 (Asia/Tokyo)

| Model | 32K MTP ON | 32K peak VRAM | 64K MTP ON | 64K idle free VRAM | Decision |
|---|---:|---:|---:|---:|---|
| JonathanColetti Q4_K_M | 36.31 tok/s | 19,737 MiB | 35.88 tok/s | about 3,238 MiB | RTX3090 remote coding default at 32K |
| HauhauCS Aggressive Q4_K_P | 35.47 tok/s | 20,867 MiB | 36.28 tok/s | about 2,188 MiB | optional Candidate / direct Vision |

- MTP ON improved the 32K median by 8.8% for Jonathan and 11.3% for HauhauCS. Draft acceptance was 73.91% and 72.80%, respectively.
- The controlled 15,478-token prompt-processing medians were 905.17 tok/s for Jonathan and 897.60 tok/s for HauhauCS; the 0.8% difference is operationally equivalent.
- Both models completed three controlled 64K generations. Neither received a 96K loader because the measured 64K margin did not justify a 96K load attempt on a 24GB Windows display GPU.
- Both passed exact direct `read_file` Tool Calling and direct Vision 7/7 with their external projectors.
- Both consumed the full Reasoning Budget 8192 without a final answer. Use the RTX5090 Current for reasoning-sensitive and long Agentic work.
- The isolated Zoo Code Agentic fixture completed for both models. HauhauCS accepted an image attachment through Zoo Code, but Code mode ignored the visual task and entered a directory/README tool loop; this isolates the current failure to the Zoo Code mode/integration path rather than the projector, LM Studio server, or OpenAI-compatible Vision API.

The final API identifiers are the LM Studio-resolvable IDs `qwen3.8-27b-uncensored@q4_k_m` and `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp`. More descriptive aliases caused Zoo Code/LM Studio implicit auto-load behavior and were not retained. After switching a remote profile, start a new Zoo Code task and verify one intended model, context, and `PARALLEL 1` with `lms ps`.

Full observations and comparison with the RTX5090 Current are in `benchmarks/results/2026-08-20-rtx3090-remote-node.md`.
