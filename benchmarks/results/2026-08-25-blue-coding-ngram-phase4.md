# BLUE Coding n-gram Phase 4

Date: 2026-08-25 (Asia/Tokyo)

Host: `DESKTOP-L9HAM1G` / RTX 3090 24 GB + RTX 3060 12 GB / PL 259 W + 170 W

Decision: **NO PROFILE**

## Scope

Phase 4 tested coding-specialized n-gram/lookup speculative decoding on BLUE using the pinned official llama.cpp runtime. General Turbo remained fixed at JonathanColetti Q5_K_M Vision 96K, Q8_0/Q8_0, MTP3, batch 1024, ubatch 512, parallel 1, Flash Attention, dual-GPU layer split `0.7108,0.2892`, mmap OFF, prompt cache ON, and cache reuse 0.

The best research configuration was:

```text
--spec-type draft-mtp,ngram-mod
--spec-draft-n-max 3
--spec-ngram-mod-n-match 32
--spec-ngram-mod-n-min 48
--spec-ngram-mod-n-max 64
```

It is evidence for future research only, not an approved operational launcher.

## Synthetic result

The configuration was extremely fast on warm rewrite/refactor/edit workloads and passed all corrected synthetic quality checks.

| Workload | General Turbo A | Best research config | Elapsed reduction |
|---|---:|---:|---:|
| C1 rewrite | 190.863 s | 35.542 s | **81.38%** |
| C2 refactor | 317.173 s | 82.230 s | **74.07%** |
| C3 patch/edit | 3.280 s | 1.029 s | **68.63%** |
| C1/C2/C3 elapsed geomean | — | — | **75.26%** |

The held-out 185-line full-file rewrite fell from 132.261 s to 24.592 s formally and from 136.815 s to 35.533 s cold. By contrast, held-out refactor cold time was essentially neutral/slightly slower, and fresh-code cold time improved only 0.81%.

Synthetic ngram-mod acceptance was 63,315 of 63,687 generated tokens, approximately **99.42%**.

## Goose Real Agent hard gate

Two fresh runs per condition used isolated fixtures. Every run completed the coding task and passed final tests.

| Two-run mean | General Turbo A | ngram-mod candidate | Candidate change |
|---|---:|---:|---:|
| Wall time | 53.538 s | 56.499 s | **5.53% slower** |
| Model inference | 51.216 s | 53.795 s | **5.04% slower** |

Candidate n-gram acceptance collapsed to 382 of 1,280 generated tokens, approximately **29.84%**, and both candidate trajectories required four correction turns instead of three. Functional quality passed, but the required Real Agent speed improvement did not.

## Resources and decision

All measured conditions passed the unchanged Strict Shared gate. The Stage 2 best condition peaked at 3.616 GiB combined Shared, with each GPU below 2 GiB. No OOM occurred. Final-candidate Vision, long-context, and separate endurance gates were not run after Goose rejected the candidate, so no full operational qualification claim is made.

**Decision: NO PROFILE.** Do not create Coding-Turbo, do not add n-gram to Daily selectors or runtime manifests, and do not change Stable or General Turbo. Retain the result as research evidence only.

Phase 4 ended with candidate standalone and tunnel stopped, BLUE port 18080 and MAIN port 18081 free, and BLUE Stable Q5_K_M Vision 96K restored IDLE with queued 0 at 259 W / 170 W.

Raw evidence remains outside Git under:

- `C:\Users\Atsuki\Documents\Local-LLM-Research-Archive\2026-08\DFlash2-Phase4\RTX3090-Dual\ngram-coding`
- `benchmarks/raw/blue-phase4-ngram/session-20260825`
