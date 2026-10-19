# Jonathan Q6_K Vision: RTX 5090 / RTX 3090 / RTX 3090+3060 comparison

Date: 2026-08-23 (Asia/Tokyo)

Result class: controlled cross-hardware run. This result does not change the repository Current or the RTX3090 Remote coding default.

## Scope and identity

| Configuration | COMPUTERNAME | GPU configuration | Observed PCIe | Power limit |
|---|---|---|---|---:|
| `main-5090` | `DESKTOP-5NPLIIV` | RTX 5090 32 GB | Gen5 x16 | 402 W |
| `blue-3090` | `DESKTOP-L9HAM1G` | RTX 3090 24 GB; RTX 3060 excluded per load | Gen3 x16 | approximately 259 W |
| `blue-3090-3060` | `DESKTOP-L9HAM1G` | RTX 3090 24 GB + RTX 3060 12 GB | Gen3 x16 + Gen3 x4 | approximately 259 W + 170 W |

BLUE was verified through `pc5700x`, `192.168.0.104`, and hostname `DESKTOP-L9HAM1G` before runtime changes. GPU selection used LM Studio SDK per-load device configuration; Device Manager, driver, Power Limit, Firewall, SSH, and the LM Studio global defaults were not changed.

Both PCs ran LM Studio 0.4.21+2, CLI commit `71bd99c`, and llama.cpp CUDA12 runtime 2.29.1. NVIDIA drivers were 610.62 on MAIN and 591.86 on BLUE; the driver difference is recorded and was not normalized by an update.

## Model identity

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `Qwen3.8-27B-Uncensored-Q6_K.gguf` | 22,430,999,968 | `A50AA1478295B58EE3D93EABE02C17F6D5FCF6CB787FD8A0AB07AC629A46CAE6` |
| `mmproj-Qwen3.8-27B-Uncensored-vision-f16.gguf` | 927,606,912 | `5AC423F8A29059DC24E51BC6A43E9380DCD57A9347F28B62591E0B3F60B7081C` |

BLUE did not have the Q6_K body before this task. The body was copied from MAIN through the existing SSH path, and both artifacts were SHA-256 matched before benchmarking. GGUF data remains outside Git.

LM Studio keys differed by local layout: MAIN `qwen3.8-27b-uncensored-vision-q6k`, BLUE `qwen3.8-27b-uncensored@q6_k`. The temporary loaded API identifier was `benchmark-jonathan-q6k-vision` on all runs.

## Controlled settings

- Context 8,192; max output 512; temperature 0; reasoning OFF
- All 36 formal runs produced 512 output tokens and zero reasoning tokens
- GPU offload max, KV cache GPU offload ON, Flash Attention ON
- K/V cache F16/F16 with cache quantization disabled
- mmap OFF, Keep Model in Memory ON, eval batch 512, parallel 1
- MTP OFF or embedded MTP ON with max draft tokens 2
- LM Studio native `POST /api/v1/chat` on localhost only
- One 64-token warm-up per configuration/workload/MTP group, excluded from results
- Three 512-token formal runs per group; median generation tok/s and median TTFT are the primary values
- One-second UUID-based NVIDIA/RAM/shared-memory telemetry per formal run

This F16/F16 KV result is controlled within the three configurations but is not a direct replacement for the existing Q8_0/Q8_0 32K/64K/96K Vision result.

## Capacity preflight

Strict mode required a valid load audit, exact runtime fields, selected dedicated-VRAM delta sufficient for the model within 256 MiB, and shared-memory delta no greater than 2 GiB per selected GPU.

| Configuration | Context | Load | Dedicated delta | Shared delta | Strict result | Load time |
|---|---:|---:|---:|---:|---|---:|
| RTX 5090 | 8,192 | PASS | 22,486 MiB | 1,104 MiB | `STRICT_GPU_ONLY` | 5.274 s |
| RTX 3090 | 8,192 | PASS | 16,897 MiB | 6,480 MiB | `PARTIAL_OFFLOAD` | 14.885 s |
| RTX 3090 | 4,096 | PASS | 16,934 MiB | 6,175 MiB | `PARTIAL_OFFLOAD` | 26.356 s |
| RTX 3090 | 2,048 | PASS | 17,097 MiB | 5,867 MiB | `PARTIAL_OFFLOAD` | 24.343 s |
| RTX 3090+3060 | 8,192 | PASS | 22,665 MiB | 2,266 MiB | `STRICT_GPU_ONLY` | 8.575 s |

There is no three-configuration Common Benchmark Context in strict GPU-only mode. The primary strict comparison is RTX 5090 versus RTX 3090+3060 at 8,192. RTX 3090-only numbers below use the same 8,192 workload but are supplemental PARTIAL_OFFLOAD results.

## Formal results

### Text / MTP OFF

| Metric | RTX 5090 | RTX 3090 partial | RTX 3090+3060 |
|---|---:|---:|---:|
| Median generation | 56.057 tok/s | 4.218 tok/s | 22.522 tok/s |
| Median TTFT | 0.0734 s | 0.4654 s | 0.2878 s |
| Median prompt processing | 2,064.9 tok/s | 297.9 tok/s | 593.4 tok/s |
| Average total GPU power | 348.6 W | 105.0 W | 321.2 W |
| Peak temperature | 64 C | 62 C | 73 C |
| Peak VRAM sum | 24,679 MiB | 17,547 MiB | 23,390 MiB |
| Peak used RAM | 51.27 GiB | 13.90 GiB | 8.78 GiB |

### Text / MTP ON

| Metric | RTX 5090 | RTX 3090 partial | RTX 3090+3060 |
|---|---:|---:|---:|
| Median generation | 61.697 tok/s | 6.994 tok/s | 27.198 tok/s |
| Median TTFT | 0.0730 s | 0.4968 s | 0.3172 s |
| Median prompt processing | 1,765.7 tok/s | 211.1 tok/s | 350.7 tok/s |
| Weighted MTP acceptance | 84.61% | 79.73% | 85.19% |
| Average total GPU power | 318.9 W | 109.2 W | 297.8 W |
| Peak temperature | 57 C | 64 C | 72 C |
| Peak VRAM sum | 25,495 MiB | 18,328 MiB | 24,358 MiB |
| Peak used RAM | 51.88 GiB | 14.76 GiB | 9.40 GiB |

### Vision / MTP OFF

| Metric | RTX 5090 | RTX 3090 partial | RTX 3090+3060 |
|---|---:|---:|---:|
| Median generation | 56.532 tok/s | 4.218 tok/s | 22.382 tok/s |
| Median TTFT | 0.0684 s | 0.4740 s | 0.3137 s |
| Median prompt processing | 8,677.7 tok/s | 1,014.8 tok/s | 1,956.2 tok/s |
| Vision correctness | 3/3 | 3/3 | 3/3 |
| Average total GPU power | 338.0 W | 105.9 W | 319.2 W |
| Peak temperature | 58 C | 64 C | 74 C |
| Peak VRAM sum | 24,728 MiB | 17,580 MiB | 23,426 MiB |
| Peak used RAM | 51.49 GiB | 14.12 GiB | 8.76 GiB |

### Vision / MTP ON

| Metric | RTX 5090 | RTX 3090 partial | RTX 3090+3060 |
|---|---:|---:|---:|
| Median generation | 82.689 tok/s | 8.608 tok/s | 34.034 tok/s |
| Median TTFT | 0.0704 s | 0.5228 s | 0.3427 s |
| Median prompt processing | 6,813.4 tok/s | 736.2 tok/s | 1,185.2 tok/s |
| Weighted MTP acceptance | 88.75% | 88.27% | 88.36% |
| Vision correctness | 3/3 | 3/3 | 3/3 |
| Average total GPU power | 294.5 W | 109.6 W | 296.4 W |
| Peak temperature | 58 C | 64 C | 71 C |
| Peak VRAM sum | 25,544 MiB | 18,345 MiB | 24,333 MiB |
| Peak used RAM | 51.50 GiB | 14.76 GiB | 9.42 GiB |

All 18 formal Vision runs correctly read serial `A7K-42Q-9183`, 12 shapes, 17/29/43, displayed total 89, and the blue-circle-to-red-square arrow. The PNG SHA-256 was `08B97AD7211BE012B2417A5FEA79EFA4ADC0B0ED55FE9CBA8A6238B9DF9DAFAB` on both PCs.

## Ratios and MTP effect

| Workload | MTP | RTX5090 / RTX3090 | RTX5090 / dual | Dual / RTX3090 |
|---|---|---:|---:|---:|
| Text | OFF | 13.29x | 2.49x | 5.34x |
| Text | ON | 8.82x | 2.27x | 3.89x |
| Vision | OFF | 13.40x | 2.53x | 5.31x |
| Vision | ON | 9.61x | 2.43x | 3.95x |

| Configuration | Text MTP speed-up | Vision MTP speed-up |
|---|---:|---:|
| RTX 5090 | +10.1% | +46.3% |
| RTX 3090 partial | +65.8% | +104.1% |
| RTX 3090+3060 | +20.8% | +52.1% |

## Dual-GPU work split

| Workload | MTP | GPU | Avg utilization | Avg power | Peak VRAM | Peak temp | PCIe |
|---|---|---|---:|---:|---:|---:|---|
| Text | OFF | RTX 3090 | 53.7% | 225.7 W | 17,751 MiB | 73 C | Gen3 x16 |
| Text | OFF | RTX 3060 | 38.4% | 95.5 W | 5,639 MiB | 65 C | Gen3 x4 |
| Text | ON | RTX 3090 | 40.2% | 201.6 W | 18,051 MiB | 72 C | Gen3 x16 |
| Text | ON | RTX 3060 | 43.0% | 96.2 W | 6,307 MiB | 67 C | Gen3 x4 |
| Vision | OFF | RTX 3090 | 55.0% | 224.0 W | 17,785 MiB | 74 C | Gen3 x16 |
| Vision | OFF | RTX 3060 | 39.1% | 95.2 W | 5,641 MiB | 68 C | Gen3 x4 |
| Vision | ON | RTX 3090 | 42.0% | 197.5 W | 18,024 MiB | 71 C | Gen3 x16 |
| Vision | ON | RTX 3060 | 46.5% | 98.9 W | 6,309 MiB | 67 C | Gen3 x4 |

The RTX 3060 is not idle capacity: it holds roughly 5.6-6.3 GiB, averages 38-47% utilization, and draws 95-99 W during the formal runs.

Observed: dual GPU makes the full Q6_K + projector dedicated-resident and improves the same-context generation throughput by 3.89-5.34x over the spilling RTX 3090-only configuration.

Inferred: the remaining gap to RTX 5090 is consistent with the slower RTX 3060, its lower memory bandwidth, inter-GPU synchronization, and the asymmetric Gen3 x4 link. This telemetry cannot isolate one cause, so none is claimed as the proven sole bottleneck.

## Decision

- RTX 5090 is 2.27-2.53x faster than the strict dual-GPU BLUE configuration, with lower TTFT and better GPU-only throughput per watt in every group.
- Adding RTX 3060 is valuable for Vision Q6_K capacity: 8,192 changes from PARTIAL_OFFLOAD to STRICT_GPU_ONLY and becomes practically usable at 22-34 tok/s.
- RTX 3090 alone can technically complete all runs and recognize the image, but 4-9 tok/s is not a practical Q6_K default. Keep the existing Jonathan Q4_K_M / 32K Remote coding default when the 3060 must remain unused.
- RTX 3090+3060 is the practical BLUE option for quality-prioritized Q6_K Vision when MAIN is unavailable. The 36 GB configuration has clear capacity value despite its multi-GPU speed penalty.
- The repository-wide Current remains RTX5090 Jonathan text-only Q6_K. The existing Jonathan Vision Candidate/runtime profile and BLUE Remote coding default are not promoted or replaced by this hardware benchmark.

## Measurement notes

- Native API did not expose separate image preprocessing time, so that field remains `null`.
- Native API request path did not expose seed; temperature 0 and response SHA-256 were retained. No invented seed value is recorded.
- GPU-only efficiency excludes CPU and PSU conversion losses.
- One RTX 5090 Vision/MTP ON sample reported a transient 410.8 W against the nominal 402 W limit. Group average was about 295 W, peak temperature was 58 C, and no thermal-throttling evidence was observed. Power Limit was not changed.
- Failed initial capacity-audit calibration and the first invalid Vision input-schema attempt are preserved in external raw artifacts and excluded from formal results.

## External artifacts

Full raw JSON, LM Studio stats logs, one-second GPU/RAM telemetry CSVs, deterministic fixture, harness, per-configuration `results.json`, and generated JSON/CSV/Markdown summaries remain outside Git at:

- MAIN: `C:\Users\Haritan\Documents\LMStudio-Vision-Q6K-Benchmark`
- BLUE: `C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08\LMStudio-Vision-Q6K-Benchmark`

Both PCs started with no loaded LM Studio model and ended with `lms ps --json` equal to `[]`. Global LM Studio settings and GPU priority were not changed.
