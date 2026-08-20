# Model Registry

Last updated: 2026-08-20

## Registry

| ID | Status | Repository / model | Variant | Key capabilities | Evidence state |
|---|---|---|---|---|---|
| `current-qwen38-27b-uncensored-q6k` | Current | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K | Text coding, MTP | Stable at 96K; measured MTP ON/OFF speed supplied |
| `candidate-hauhaucs-aggressive-mtp` | Candidate | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` | TBD | Vision + FastMTP comparison target | Unverified; benchmark pending |
| `watch-hauhaucs-balanced-mtp` | Watch | HauhauCS Balanced-MTP-GGUF (provisional reference) | TBD | Expected balanced MTP profile | Publication and exact repository not yet confirmed |

## Current: current-qwen38-27b-uncensored-q6k

- Role: stable daily driver
- Repository: `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF`
- Selected variant: `Q6_K`
- Runtime: LM Studio
- Integration: Zoo Code in VS Code
- Hardware: RTX 5090 32 GB
- Stable context: 98,304 tokens in the Normal profile
- Known performance: 63.92 tok/s with MTP ON; 48.30 tok/s with MTP OFF
- Known limitation: 128K with Q8 KV harms desktop responsiveness because of VRAM pressure
- Management profile: `configs/current/qwen38-27b-uncensored-q6k.json`
- Managed loaders: `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/`
- Curated baseline: `benchmarks/results/current-baseline-mtp.json`

Current remains the rollback point for every Candidate experiment.

## Candidate: candidate-hauhaucs-aggressive-mtp

- Repository: `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF`
- Motivation: compare Vision and FastMTP while preserving Qwen3.8 27B-class behavior
- Candidate type: model/repository change
- Variant: not selected yet
- Current compatibility evidence: none recorded
- Required comparison: throughput, MTP acceptance, VRAM, 32K/64K/96K stability, Vision, Zoo Code tool use, multi-file coding, regression behavior
- Management profile: `configs/candidates/hauhaucs-qwen38-27b-aggressive-mtp.json`
- Research plan: `research/hauhaucs-aggressive-mtp-evaluation.md`

Promotion is blocked until the exact model artifact and runtime prerequisites are verified and the benchmark matrix is complete.

## Watch: watch-hauhaucs-balanced-mtp

- Reference: future HauhauCS Balanced-MTP-GGUF
- Availability: not confirmed in this repository
- Rule: do not infer the final repository name, quantization, Vision support, FastMTP behavior, or release date
- Next action: verify publication and metadata before creating a Candidate profile
- Research note: `research/hauhaucs-balanced-mtp-watch.md`

## Lifecycle rules

- Register every newly investigated model as Candidate or Watch, never directly as Current.
- Preserve the model ID even if display names or upstream filenames change.
- Record exact repository, filename/variant, quantization, checksum if available, runtime version, and evaluation date before adoption.
- A Candidate becomes Current only after explicit user approval and a synchronized update to Current State, configs, benchmark results, and changelog.
- A replaced Current becomes Retired; keep its settings and benchmark evidence for rollback and longitudinal comparison.
