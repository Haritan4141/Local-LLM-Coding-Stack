# RTX 5090 Jonathan Q6_K Vision result

Date: 2026-08-23

## Controlled configuration

| Item | Value |
|---|---|
| GPU | RTX 5090 32 GB |
| Runtime | LM Studio 0.4.21+2, llama.cpp CUDA backend 2.22.0 |
| Model | JonathanColetti Qwen3.8-27B Uncensored Q6_K |
| Projector | official `vision-f16`, 927,606,912 bytes |
| API identifier | `qwen3.8-27b-uncensored-vision` |
| K/V cache | Q8_0 / Q8_0, GPU offload ON |
| Flash Attention | ON |
| GPU offload | all 65 layers |
| Embedded MTP | ON, max draft tokens 2 |
| Parallel | 1 |
| Sampling | temperature 0, measured max tokens 1,024 |

The first image request after each reload was a warm-up and was excluded. The measured request used `benchmarks/raw/vision-ui-v1.png` generated from the tracked `vision-ui-v1` fixture. Peak VRAM is whole-GPU `nvidia-smi` usage. Prompt and MTP counters come from the matching LM Studio server log entry.

## Direct LM Studio Vision

| Context | Correct fields | Prompt processing | Generation | TTFT | MTP acceptance | Idle VRAM | Peak VRAM |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 32,768 | 7/7 | 1,274.73 tok/s | 63.03 tok/s | 0.496 s | 353/435 = 81.15% | 27,002 MiB | 27,057 MiB |
| 65,536 | 7/7 | 1,251.68 tok/s | 63.34 tok/s | 0.505 s | 457/558 = 81.90% | 28,177 MiB | 28,339 MiB |
| 98,304 | 7/7 | 1,238.88 tok/s | 61.30 tok/s | 0.510 s | 457/558 = 81.90% | 29,582 MiB | 29,736 MiB |

All three runs correctly read the title, `CANDIDATE`, selected `Benchmarks` menu, `98,304 tokens`, `Q8_0 / Q8_0`, exact `ERROR CODE: VRAM-96K-042`, button label, and the relative layout.

The 96K result remained responsive enough to complete the request, but only about 2.87 GB of GPU memory remained after the measured request. Use 64K as the normal Vision preset and reserve 96K for long-context work without other GPU-heavy applications.

## Client transport

| Client/path | Result | Detail |
|---|---|---|
| LM Studio direct API | PASS | Image recognized; 7/7 at every context |
| Kilo CLI 7.4.22 | PARTIAL PASS | Image reached model; 6/7 due to `042` being misread as `Q42`; client-reported 52.69 tok/s |
| goose CLI 1.46.0 | FAIL | Both Windows and forward-slash paths remained plain text; no image content was sent. The bundled 1.47.0 CLI was version-checked but not rerun for image transport |
| goose Desktop 1.47.0 | PARTIAL / CONDITIONAL | Paperclip attachment, thumbnail, custom Vision ID selection, and an outgoing image request were verified. The first inference returned HTTP 400 because LM Studio had the text-only instance loaded; after explicitly reloading Vision 64K the same ID passed a direct image request, but a successful Desktop resend was not completed |
| Zoo Code | PENDING | VS Code was not open; no image mention run was performed |

The failed Desktop request is useful transport evidence: Goose logged `model_name = qwen3.8-27b-uncensored-vision` and an image-bearing message. At that instant `lms ps` reported `qwen3.8-27b-uncensored`, `vision = false`, context 64,512. After the managed Vision 64K reload, `GET /v1/models` exposed both the Vision API identifier and model key, and a recovery request using the same PNG returned the exact code `VRAM-96K-042` in 2.079 seconds. Do not rely on LM Studio just-in-time loading for this split text/Vision layout: run the Vision loader and confirm `vision = true` before sending an image from Goose.

## Decision

- Keep `current-qwen38-27b-uncensored-q6k` as the only repository Current.
- Keep Vision as explicit Candidate/runtime profile `candidate-jonathan-q6k-vision`. Goose Desktop image transport is verified but end-to-end inference remains conditional on the preloaded Vision instance; Zoo transport remains pending.
- The model capability itself is validated. Remaining issues are client transport and model-selection UX, not Jonathan Q6_K image understanding.
