# RTX5090 Prefix / Prompt Cache Phase 3

Date: 2026-08-25 (Asia/Tokyo)

Host: `DESKTOP-5NPLIIV` / NVIDIA GeForce RTX 5090 32 GB / PL 402 W

Decision: **PASS — keep the current runtime cache defaults; no additional profile**

## Scope and fixed profile

Phase 3 tested prefix/prompt-cache behavior on the pinned official llama.cpp Turbo runtime for JonathanColetti Q5_K_M Vision at 98,304 context. The fixed production-shaped settings were Q8_0/Q8_0 target and draft KV, MTP3, eval batch 1024, effective ubatch 512, parallel 1, Flash Attention, full CUDA offload, mmap+mlock, Vision, temperature 0, and reasoning OFF.

The launcher does not override the pinned cache defaults. The effective values were:

- prompt cache ON;
- `cache-reuse=0`;
- slot prompt similarity `0.10`;
- one slot because parallel is 1.

This operational cache decision does not change the repository lifecycle `Current` model.

## Exact-repeat scale results

Warm requests reused the same server process and slot as their cold request. TTFT is client-observed wall time.

| Prompt scale | Cold TTFT | Warm TTFT | Warm cached tokens | Result |
|---|---:|---:|---:|---|
| 15K | 7.043 s | 0.166 s | 14,980 / 14,984 | PASS |
| 32K | 17.411 s | 0.172 s | 32,000 / 32,004 | PASS |
| 64K | 42.796 s | 0.369 s | 64,005 / 64,009 | PASS |

Cache OFF did not show a material warm-prefix benefit. Cache ON with reuse 0 reduced warm TTFT by 97.64% at 15K, 99.01% at 32K, and 99.14% at 64K. Exact-repeat outputs passed the required quality checks.

## Conversation-shape behavior

Append-only conversation growth is the useful production case. The second request reused 15,002 tokens and evaluated only 31 tokens; reuse included almost the whole previous rendered conversation, including assistant tokens carried into the next turn. TTFT fell from 7.018 s to 0.290 s.

A middle edit did not preserve the unchanged suffix in practice. Although the deterministic prompts shared a 5,020-token longest common prefix and the slot was selected above the 0.10 similarity threshold, only 21 tokens remained reusable and 14,991 were reprocessed. Raw token similarity is therefore not a guarantee that a valid MTP/hybrid-memory checkpoint exists for suffix reuse.

## `cache-reuse` sweep

| Requested | Effective | Result |
|---:|---:|---|
| 0 | 0 | Valid default |
| 128 | 0 | Forced off for multimodal/mmproj |
| 256 | 0 | Forced off for multimodal/mmproj |
| 512 | 0 | Forced off for multimodal/mmproj |
| 1024 | 0 | Forced off for multimodal/mmproj |

The pinned server logged that cache reuse is unsupported with multimodal input and disabled every non-zero startup value. These values were not distinct effective conditions, so treating them as an optimization sweep would be misleading.

## Goose Real Agent result

An isolated 10-turn coding-agent fixture was run with process-local client settings. Cache ON and explicit Cache OFF both completed the task at 10/10 quality.

| Aggregate | Cache OFF | Cache ON / reuse 0 | Change |
|---|---:|---:|---:|
| Prompt processing | 15.522 s | 3.063 s | **-80.27%** |
| First-chunk / TTFT sum | 24.694 s | 12.268 s | **-50.32%** |
| Total proxy elapsed | 40.614 s | 28.732 s | **-29.26%** |
| Prompt-evaluated tokens | 34,467 | 4,351 | -87.38% |
| Cached/reused tokens | 0 | 30,218 | +30,218 |
| Final task result | 10/10 PASS | 10/10 PASS | equivalent outcome |

The trajectories were not byte-identical after model-selected tool calls, so time totals are observed agent comparisons rather than an exact paired-prompt counterfactual. Token counters directly confirm the avoided prompt work.

## Vision, resources, and decision

The final default-cache Vision canary passed 7/7 with MTP active. No OOM, Shared-memory failure, HTTP error, or unhealthy server state occurred. Phase 3 ended with standalone Turbo stopped, MAIN port 18080 free, and LM Studio Stable Q5_K_M Vision 96K restored IDLE with queued 0 and PL 402 W.

**Decision:** retain prompt cache ON, `cache-reuse=0`, slot similarity 0.10, and parallel 1. Do not create a Cache Optimized profile.

Raw evidence remains outside Git under `D:\AI-Throughput-Lab\RTX5090-Phase3-Cache`.
