# RTX5090 Coding n-gram Phase 4

Date: 2026-08-25 (Asia/Tokyo)

Host: `DESKTOP-5NPLIIV` / NVIDIA GeForce RTX 5090 32 GB / PL 402 W

Decision: **NO PROFILE**

## Scope

Phase 4 tested coding-specialized n-gram/lookup speculative decoding on the pinned official llama.cpp runtime. General Turbo remained the fixed baseline: JonathanColetti Q5_K_M Vision 96K, Q8_0/Q8_0, MTP3, batch 1024, ubatch 512, parallel 1, Flash Attention, full offload, mmap+mlock, prompt cache ON, cache reuse 0, temperature 0, and reasoning OFF.

The best research configuration was:

```text
--spec-type draft-mtp,ngram-mod
--spec-draft-n-max 3
--spec-ngram-mod-n-match 32
--spec-ngram-mod-n-min 48
--spec-ngram-mod-n-max 64
```

It is recorded for research reproducibility only. It is not an approved operational launcher.

## Synthetic result

The best configuration produced very large repeat-generation gains while passing all valid synthetic quality checks.

| Workload | General Turbo A | Best research config | Elapsed reduction |
|---|---:|---:|---:|
| C1 rewrite | 75.03 s | 14.27 s | 80.98% |
| C2 refactor | 119.38 s | 32.98 s | 72.37% |
| C3 patch/edit | 1.315 s | 0.420 s | 68.05% |
| C1/C2/C3 elapsed geomean | — | — | **74.39%** |

The held-out full-file rewrite reduced its formal median from 49.96 s to 9.04 s, an 81.91% reduction. The synthetic ngram-mod path accepted 71,600 of 72,103 generated tokens, about 99.30%.

These are mainly warm repeat-generation results. Held-out refactor cold performance improved only 2.04%, and held-out fresh-code cold performance was 1.60% slower.

## Goose Real Agent hard gate

Two independent General Turbo and candidate runs used fresh servers and isolated coding fixtures. All final repositories passed tests.

| Two-run mean | General Turbo A | ngram-mod candidate | Candidate change |
|---|---:|---:|---:|
| Wall time | 20.45 s | 24.28 s | **18.74% slower** |
| Model inference | 18.41 s | 21.48 s | **16.70% slower** |

Candidate n-gram acceptance fell to 29.42% and 32.87% in the real agent runs. It also required more tool and correction work. Functional quality passed, but the mandatory Real Agent speed gate failed reproducibly.

## Qualification boundary and decision

Because no Final Candidate remained after the Goose hard gate, standardized Tool Calling 3/3, Vision 7/7, 50–70K long-context, and separate endurance gates were not run. No claim of full operational qualification is made.

**Decision: NO PROFILE.** Do not create Coding-Turbo, do not add this setting to Daily selectors, and do not change Stable or General Turbo. Preserve the parameters as a research result only.

Phase 4 ended with standalone stopped, MAIN port 18080 free, and LM Studio Stable Q5_K_M Vision 96K restored IDLE with queued 0 and PL 402 W.

Raw evidence remains outside Git under `D:\AI-Throughput-Lab\RTX5090-Phase4-Ngram`.
