# HauhauCS Aggressive-MTP Hugging Face Snapshot

Captured: 2026-08-20 (Asia/Tokyo)

Candidate ID: `candidate-hauhaucs-aggressive-mtp`

## Source identity

- Repository: `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF`
- Revision: `993a5971fda8f30dd1b7eb2654792ba4415c7460`
- Hugging Face last modified: `2026-08-17T22:02:10Z`
- Base model: `Qwen/Qwen3.8-27B`
- License: Apache-2.0
- Pipeline: `image-text-to-text`
- Native context stated by the author: 262,144 tokens
- Framework-specific extended context claim: up to 1,000,000 tokens

Primary sources:

- Model card: <https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/blob/main/README.md>
- Files/API: <https://huggingface.co/api/models/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/tree/main?recursive=true&expand=true>
- Model API: <https://huggingface.co/api/models/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF>
- Base model card: <https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/README.md>

This file records upstream facts and claims before downloading a model artifact. Performance claims are not local RTX 5090 measurements.

## Available artifacts

Sizes below are the Files API byte counts, shown in decimal GB and binary GiB.

| Artifact | BPW/card role | Bytes | GB | GiB |
|---|---:|---:|---:|---:|
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q8_K_P.gguf` | 9.21 | 31,457,990,784 | 31.46 | 29.30 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf` | 7.59 | 25,924,151,424 | 25.92 | 24.14 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q5_K_P.gguf` | 5.92 | 20,218,177,664 | 20.22 | 18.83 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf` | 5.25 | 17,923,393,664 | 17.92 | 16.69 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-IQ4_XS.gguf` | 4.60 | 15,705,860,224 | 15.71 | 14.63 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q3_K_P.gguf` | 3.93 | 13,441,058,944 | 13.44 | 12.52 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-IQ3_M.gguf` | 3.74 | 12,789,303,424 | 12.79 | 11.91 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-IQ3_XS.gguf` | 3.56 | 12,175,558,784 | 12.18 | 11.34 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q2_K_P.gguf` | 3.12 | 10,676,422,784 | 10.68 | 9.94 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-IQ2_M.gguf` | 3.02 | 10,319,906,944 | 10.32 | 9.61 |
| `mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf` | Vision projector | 931,146,624 | 0.93 | 0.87 |
| `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf` | FastMTP sidecar | 903,453,952 | 0.90 | 0.84 |

The repository does not provide a plain `Q6_K` or `Q5_K_M` artifact. Those labels appear only as reference rows in the card.

## Quantization comparison and selection

The author describes K_P ("Perfect") as a model-specific GGUF quantization that selectively preserves important tensors. The claimed tradeoff is approximately 5–15% more size than the base quant for quality comparable to one or two higher quant levels. This is an author claim and must be evaluated locally.

| Choice | Comparison meaning | RTX 5090 decision |
|---|---|---|
| Q6_K_P | 25.92 GB, 7.59 BPW. Higher-quality candidate than plain Q6_K, but 3.49 GB larger than the installed JonathanColetti Q6_K file | Selected first, per quality-first policy |
| Q6_K | 6.60 BPW reference only; no file in this Candidate repository | Cannot be selected for exact quant parity |
| Q5_K_P | 20.22 GB, 5.92 BPW. 5.71 GB smaller than Q6_K_P | Fallback if Q6_K_P cannot maintain practical 96K + Q8 KV headroom |

Selected artifact:

- File: `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf`
- Size: 25,924,151,424 bytes (25.92 GB / 24.14 GiB)
- SHA-256: `70c8139f4dcd05d3818bc9843cde7301faa44f66321e5966965929baa9c24a6a`

Fallback artifact verified after the Q6_K_P 96K test exhausted practical VRAM headroom:

- File: `Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q5_K_P.gguf`
- Size: 20,218,177,664 bytes (20.22 GB / 18.83 GiB)
- SHA-256: `a21e22af885bd2f7c430a72b550a78f5445966e6a72d3143b0950baa0bd6d411`

The RTX 5090 has 32 GB VRAM. Q6_K_P leaves only nominal space for runtime state, Q8 KV cache, embedded MTP, and the optional projector. Therefore 32K, 64K, and 96K must be tested separately. If 96K harms Windows responsiveness or fails to retain safe VRAM headroom, Q5_K_P becomes the next Candidate artifact; Current is not changed.

## MTP and FastMTP

- Every text GGUF preserves Qwen3.8 native NextN/embedded MTP.
- Embedded MTP is the fair LM Studio comparison path and requires a current MTP-capable bundled llama.cpp runtime.
- The Candidate starts with embedded MTP depth/max draft tokens 2 to match Current.
- HauhauCS FastMTP uses the separate 32K sidecar, depth 3, pinned `llama.cpp@4df29be4f4c3673f428170fda944a5b19f743bb8`, and `HauhauCS-FastMTP-llama.cpp.patch`.
- Stock LM Studio compatibility with that custom patch is not claimed. FastMTP must not be reported as active unless runtime evidence proves the patched path is in use.

The card's speed and acceptance results were measured on RTX PRO 6000 Blackwell 96 GB, not RTX 5090 32 GB. They are upstream references only.

## Vision

Vision and video understanding require the separate BF16 projector:

- File: `mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf`
- Size: 931,146,624 bytes (0.93 GB / 0.87 GiB)
- SHA-256: `5681b690bcb8eb10cd28d62d078cb4e01521a3ea4880a3fc7d54de72de2dd142`

The projector works with every text quant according to the card. LM Studio recognition and Zoo Code image transport remain local test items.

## Author-recommended serving settings

The FastMTP example uses full GPU offload, Flash Attention, parallel 1, batch 2048, ubatch 512, split mode none, no mmap, Jinja chat template, reasoning enabled/preserved, and depth 3. The provided LM Studio Candidate profile keeps Current's Q8_0 K/V caches, embedded MTP depth 2, reasoning budget 8192, and concurrency 1 for fair A/B comparison unless measured evidence requires a separate experiment.

Official thinking sampler values quoted by the Candidate card:

- temperature 1.0
- top_p 0.95
- top_k 20
- min_p 0.0
- presence penalty 0.0
- repetition penalty 1.0
- reasoning effort xhigh for deepest reasoning

## Aggressive and agentic cautions

The author describes Aggressive as direct, refusal-free, and minimal-preamble. The same card explicitly says a Balanced release is normally safer for reliability-critical long-context agentic work when available. The card claims text, reasoning, agentic, image, and video capabilities are preserved, but it does not publish Zoo Code tool-calling results.

Local promotion therefore depends on tool syntax, correct tool selection, multi-file edits, verification behavior, long agent loops, topic drift, and instruction adherence—not refusal rate or throughput alone.
