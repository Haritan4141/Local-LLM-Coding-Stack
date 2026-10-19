# BLUE Prefix / Prompt Cache Phase 3

Date: 2026-08-25 (Asia/Tokyo)

Host: `DESKTOP-L9HAM1G` / RTX 3090 24 GB + RTX 3060 12 GB / PL 259 W + 170 W

Decision: **PASS — no BLUE-specific cache fault; keep the current runtime defaults; no additional profile**

## Scope and root-cause finding

Phase 3 tested the pinned official llama.cpp Turbo runtime for BLUE JonathanColetti Q5_K_M Vision at 98,304 context, Q8_0/Q8_0 KV, MTP3, batch 1024, ubatch 512, parallel 1, Flash Attention, dual-GPU layer split, mmap OFF, and Vision.

The Phase 2B observation that BLUE showed no material warm-prefix gain was not a multi-GPU cache defect. Its benchmark request explicitly sent `cache_prompt: false`. Replaying the production-shaped request with the field omitted enabled the server default and restored prefix reuse.

The effective default is:

- prompt cache ON;
- `cache-reuse=0`;
- slot prompt similarity `0.10`;
- parallel 1.

## Exact-repeat scale results

| Prompt scale | Cold TTFT | Warm TTFT | Result |
|---|---:|---:|---|
| 15K | 16.866 s | 0.239 s | PASS |
| 32K | 35.270 s | 0.334 s | PASS |
| 64K | 81.832 s | 0.483 s | PASS |

The 15K repeat reused 15,426 prompt tokens. Quality checks passed, and the behavior reproduced across restart-separated cycles.

## Conversation and reuse behavior

Append-only requests reused the previous conversation prefix, which is the production-relevant agent pattern. A middle edit required most of the suffix to be evaluated again; cache reuse does not turn an edited middle section into arbitrary suffix reuse.

As on RTX5090, non-zero `cache-reuse` values 128/256/512/1024 were not usable as distinct Vision conditions because the multimodal/mmproj runtime forced them to effective 0. The valid setting remains reuse 0.

## Goose Real Agent result

The isolated Goose coding-agent route from MAIN through the managed tunnel passed its final tests. Across the agent trajectory:

| Metric | Observed value |
|---|---:|
| Rendered prompt tokens | 59,093 |
| Cached/reused tokens | 52,567 |
| Aggregate reuse | **88.956%** |
| Final coding result | PASS |

This demonstrates large practical reuse on the actual multi-turn route without a new cache profile or persistent Goose configuration change.

## Resources, Vision, and decision

The default-cache Vision canary passed all seven fixture checks in its recorded run. The raw artifact is one canary run, not a seven-run aggregate. The 20-request memory check passed the unchanged Strict Shared gate: combined Shared peaked at 3.502 GiB, with RTX3090 at 1.760 GiB and RTX3060 at 1.742 GiB. Dedicated allocation remained stable and no OOM occurred.

The Phase 3 raw set records the tested Turbo state and resource results but does not contain a separate final Stable-recovery audit equivalent to RTX5090's. Final Stable state is therefore verified separately by the first-wave Daily-profile switching regression, not inferred from this raw set.

**Decision:** BLUE has no platform-specific prompt-cache fault. Keep prompt cache ON, `cache-reuse=0`, slot similarity 0.10, and parallel 1. Do not add a BLUE cache profile.

Raw evidence remains outside Git under:

- `C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08\DFlash2-Phase3\RTX3090-Dual\prefix-cache\session-20260825`
- `benchmarks/raw/blue-phase3-prefix-cache/session-20260825`
