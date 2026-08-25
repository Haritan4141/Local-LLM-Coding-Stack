# Qwen3.8 First-Wave Optimization Final Summary

Date: 2026-08-25 (Asia/Tokyo)

Final decision: **Qwen3.8高速化 第一期間 = COMPLETE**

## Scope and lifecycle boundary

The first wave optimized and qualified practical Qwen3.8 operating paths across RTX5090 MAIN and the independent BLUE RTX3090 + RTX3060 node. The final result is an operational navigation decision, not a repository lifecycle promotion.

The sole repository lifecycle `Current` remains `current-qwen38-27b-uncensored-q6k`. Stable, Turbo, and Quality Reference below are Operational Profiles and do not create multiple `Current` models.

## Phase 1 — LM Studio optimization

Phase 1 and 1.5 optimized MTP, KV cache precision, eval batch, context, power, and Q5/Q6 operational roles inside LM Studio.

- RTX5090 Q5_K_M Vision 96K settled at Q8_0/Q8_0, MTP3, batch1024, effective ubatch512, mmap+mlock, parallel1, and 402 W as Recommended Production.
- BLUE Q5_K_M Vision 96K settled at Q8_0/Q8_0, MTP3, batch1024, effective ubatch512, dual-GPU priority order, parallel1, and 259 W / 170 W as Recommended Production.
- Q6_K Vision 64K Balanced remained the Quality/Performance Reference on both systems.
- Q6 Safe remained the known-good fallback. Coding-Fast and BLUE 370W remained explicit Advanced choices.

Evidence: `benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md` and the Q5_K_M Production/qualification reports.

## Phase 2 — General Turbo qualification and integration

Phase 2 produced the largest general speed result. Official pinned llama.cpp with JonathanColetti Q5_K_M Vision 96K, Q8_0/Q8_0, MTP3, batch1024, ubatch512, and parallel1 qualified as explicit General Turbo.

| Target | Generation geomean versus Stable LM Studio |
|---|---:|
| RTX5090 | **+60.49%** |
| BLUE | **+16.32%** |

Vision, Tool Calling, Agentic Coding through Goose, 96K context behavior, long output, endurance, switching, and recovery passed. The runtime was integrated through pinned external bundles and fail-closed managed start/stop helpers. Stable LM Studio remained Recommended and rollback; Turbo remained explicit-only.

Evidence:

- `benchmarks/results/2026-08-25-rtx5090-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-25-blue-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-25-standalone-mtp3-turbo-integration.md`

## Phase 3 — Prompt cache

Phase 3 found that no extra Cache Optimized profile was required.

- The effective default—prompt cache ON, `cache-reuse=0`, slot similarity 0.10, parallel1—already gives very large exact-repeat and append-only reuse.
- RTX5090 Goose prompt processing improved 80.27%, first-chunk aggregate improved 50.32%, and total elapsed improved 29.26%, with 10/10 task quality.
- BLUE Goose reused 52,567 of 59,093 rendered prompt tokens, 88.956% aggregate reuse.
- The earlier BLUE Phase 2B cache miss was caused by the benchmark harness sending `cache_prompt: false`, not by multi-GPU behavior.
- Non-zero cache reuse is forced to 0 in the production-shaped multimodal/mmproj runtime.

Decision: keep the default cache behavior; add no cache-specific profile.

Evidence:

- `benchmarks/results/2026-08-25-rtx5090-prefix-cache-phase3.md`
- `benchmarks/results/2026-08-25-blue-prefix-cache-phase3.md`

## Phase 4 — n-gram coding specialization

The best `draft-mtp,ngram-mod` research setting was spectacular on synthetic warm rewrites and refactors, but it failed the mandatory Real Goose Agent gate on both systems.

| Target | Synthetic C1/C2/C3 elapsed reduction | Goose wall result | Goose inference result |
|---|---:|---:|---:|
| RTX5090 | 74.39% geomean | 18.74% slower | 16.70% slower |
| BLUE | 75.26% geomean | 5.53% slower | 5.04% slower |

Synthetic n-gram acceptance was near 99%, but real-agent acceptance fell to roughly 30%. Quality and final tests passed; speed and trajectory efficiency did not.

Decision: **Coding-Turbo = NO PROFILE**. Preserve the measurements as research only.

Evidence:

- `benchmarks/results/2026-08-25-rtx5090-coding-ngram-phase4.md`
- `benchmarks/results/2026-08-25-blue-coding-ngram-phase4.md`

## Final operational decision

Daily operation is finalized around three entry points:

| Profile | Status | Role |
|---|---|---|
| Stable | **ACTIVE / RECOMMENDED** | LM Studio Q5_K_M Vision; safest everyday default and rollback |
| Turbo | **ACTIVE / EXPLICIT** | official pinned llama.cpp; faster Coding, Agent, Vision, and long generation |
| Quality Reference | **ACTIVE / REFERENCE** | LM Studio Q6_K Vision Balanced 64K; compare questionable Q5 outputs |

Quality Reference means a higher-precision Q6_K comparison point, not a guarantee that every answer is better than Stable. Its context is 64K, so it is not a direct comparison path for tasks exceeding 64K.

Other retained roles:

- Q6 Safe: **FALLBACK**
- Coding-Fast: **ADVANCED**
- BLUE 370W: **ADVANCED PERFORMANCE**
- HauhauCS: **RESEARCH / CANDIDATE**
- DFlash2: **EXPERIMENTAL / SEPARATE RESEARCH TRACK**
- n-gram Coding: **REJECTED FOR PROFILE / RESEARCH RESULT ONLY**
- Cache Optimized: **NOT REQUIRED**

Stable remains Recommended because LM Studio offers the established management path, long-term operating history, and simplest rollback. Turbo's Phase 2 speed result does not automatically promote it to the default.

## Completion

Phase 1–4 answered the first-wave questions: the LM Studio baseline is optimized, a qualified General Turbo path exists, default prompt caching is already correct, and n-gram specialization does not pass real-agent promotion criteria.

**QWEN3.8 FIRST-WAVE OPTIMIZATION COMPLETE**
