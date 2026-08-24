# Model Registry

Last updated: 2026-08-24

## Registry

| ID | Status | Repository / model | Variant | Key capabilities | Evidence state |
|---|---|---|---|---|---|
| `current-qwen38-27b-uncensored-q6k` | Current | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K | Text coding, MTP | Stable at 96K; measured MTP ON/OFF speed supplied |
| `candidate-jonathan-q6k-vision` | Candidate / Vision profile; goose operational default | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K + official F16 projector | Vision, text coding, MTP | Direct Vision validated at 32K/64K/96K on RTX5090; 8K cross-hardware comparison completed on RTX5090, RTX3090 partial, and RTX3090+3060 strict; Desktop image response still pending |
| `candidate-hauhaucs-aggressive-mtp` | Candidate | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` | Q6_K_P primary; Q5_K_P fallback | Vision + embedded MTP; custom-patch FastMTP | Local evaluation complete; promotion not recommended |
| `candidate-rtx3090-jonathan-q4km` | Candidate / Remote Node Fallback | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q4_K_M | Text coding, embedded MTP, separate Vision projector | Evaluation complete; retained as BLUE 32K fallback |
| `candidate-rtx3090-hauhaucs-aggressive-q4kp` | Candidate / Remote Node Optional | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` | Q4_K_P | Vision + embedded MTP; stock LM Studio path | Evaluation complete; retain for optional/direct Vision use |
| `candidate-rtx3090-dual-jonathan-q6k-vision` | Candidate / BLUE Operational Default | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K + F16 projector | Dual-GPU Vision, embedded MTP, 64K | 64K/Q8 selected; 80K–88K capacity-only; 96K/128K Shared gate FAIL |
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
- Managed loaders: `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/`
- Curated baseline: `benchmarks/results/current-baseline-mtp.json`

Current remains the rollback point for every Candidate experiment.

## Candidate profile: candidate-jonathan-q6k-vision

- Repository/model: the same JonathanColetti Q6_K artifact used by Current
- Added capability: official `Qwen3.8-27B-Uncensored-vision-f16.gguf` projector, 927,606,912 bytes
- Local storage: separate LM Studio Vision model view using NTFS hardlinks; no second 22.43 GB Q6_K copy and no GGUF in Git
- Vision model key: `qwen3.8-27b-uncensored-vision-q6k`
- API identifier: `qwen3.8-27b-uncensored-vision`
- Controlled settings: Q8_0/Q8_0, Flash Attention ON, all 65 layers offloaded, embedded MTP ON / draft 2, parallel 1
- Direct result: fixed PNG fixture 7/7 at 32K, 64K, and 96K
- Client result: Kilo transported the image and scored 6/7; goose CLI 1.46.0 did not transport the image; goose Desktop 1.47.0 attached and sent the image under the Vision ID but the first inference hit a text-only LM Studio instance. Direct recovery passed after an explicit Vision reload; Desktop remains conditional and Zoo Code remains pending
- Recommended runtime preset: 64K. The 96K run passed but peaked at 29,736 MiB and leaves reduced GPU headroom
- Operational role: RTX5090 goose Desktop app-global default at 64K; this client-specific role does not promote the profile to repository Current
- One-click startup: desktop shortcut `Goose Vision 64K`, backed by `Start-Goose-Jonathan-Vision64K.ps1`, verifies the single Vision instance and all managed load fields before opening goose
- Lifecycle decision: retain as an explicit Vision Candidate/runtime profile; do not create a second repository-wide Current
- Management profile: `configs/candidates/jonathan-q6k-vision.json`
- Research note: `research/jonathan-q6k-vision-2026-08-23.md`
- Controlled result: `benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`
- Cross-hardware result: `benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`; RTX5090 and RTX3090+3060 were strict at 8K, while RTX3090 alone remained PARTIAL_OFFLOAD even at 2K
- Managed loaders: `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/`

## Candidate: candidate-hauhaucs-aggressive-mtp

- Repository: `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF`
- Motivation: compare Vision and FastMTP while preserving Qwen3.8 27B-class behavior
- Candidate type: model/repository change
- Upstream revision: `993a5971fda8f30dd1b7eb2654792ba4415c7460`
- Evaluated variants: `Q6_K_P`, 25,924,151,424 bytes; `Q5_K_P`, 20,218,177,664 bytes as the 96K VRAM fallback
- Vision: separate BF16 projector required
- FastMTP: separate sidecar plus custom llama.cpp patch; not assumed available in stock LM Studio
- Local compatibility: LM Studio load, embedded MTP, direct Tool Calling, Vision, and separate Zoo Code Candidate profile verified
- Context result: Q6_K_P is practical only at 32K; Q5_K_P completed 32K/64K/96K but was slower than Current
- Agentic result: isolated Zoo Code fixture completed, but the loop was slower/more verbose than Current
- Reasoning result: Q6_K_P consumed all 8,192 completion tokens and failed to reach a final answer; Current converged normally
- Promotion recommendation: do not promote; retain as optional Vision Candidate and wait for a verified Balanced release
- Management profile: `configs/candidates/hauhaucs-qwen38-27b-aggressive-mtp.json`
- Research plan: `research/hauhaucs-aggressive-mtp-evaluation.md`
- Hugging Face snapshot: `research/hauhaucs-aggressive-mtp-hf-snapshot-2026-08-20.md`
- Controlled result: `benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md`

Promotion is blocked by measured speed, VRAM, MTP, and Reasoning regressions. Current remains unchanged.

## Remote Node candidates: RTX3090

- Node: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104 / RTX 3090 24 GB + RTX 3060 12 GB`
- Connection: main-PC Zoo Code -> `http://192.168.0.104:1234`
- Jonathan artifact: Q4_K_M, 16,810,714,528 bytes, SHA-256 `4c5e2db039e9325ac7724c8846c71356a24ad1cdfa28002d73ecb6be645f9675`
- HauhauCS artifact: Q4_K_P, 17,923,393,664 bytes, SHA-256 `ba36dc3c2b2ff5e0aa5d71092a8894546996a6a119ae391803dda07cdc08516d`
- Operational API identifier: Q6_K Vision `qwen3.8-27b-uncensored-vision-blue`; fallback Jonathan Q4_K_M `qwen3.8-27b-uncensored@q4_k_m`; optional HauhauCS `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp`.
- Vision projectors are separate external GGUF artifacts; model weights and projectors remain outside this repository.
- 32K result: Jonathan 36.31 tok/s / 19,737 MiB / MTP acceptance 73.91%; HauhauCS 35.47 tok/s / 20,867 MiB / 72.80%.
- 64K result: both completed three controlled generations; Jonathan retained about 3,238 MiB idle free VRAM and HauhauCS about 2,188 MiB. Use only as a single-model long-context profile.
- 96K result: excluded without a load attempt because Q8_0 KV and the measured 64K headroom do not leave a safe Windows/VRAM margin.
- Reasoning result: both consumed the 8,192-token budget without reaching a final answer. This role does not replace the reasoning-stable RTX5090 Current.
- Tool/Vision result: both passed exact direct Tool Calling and direct Vision 7/7. Both completed the isolated Zoo Code Agentic fixture; HauhauCS Zoo Code Code mode did not consume the attached image and entered a tool loop.
- Role decision: Jonathan Q6_K Vision / 64K / Q8_0 / RTX3090→RTX3060 is the BLUE Operational Default. Jonathan Q4_K_M / 32K is the fallback; HauhauCS remains optional. The repository-wide Current remains RTX5090 Jonathan Q6_K.
- Q6_K Vision result: 64K Shared 3.281 GiB and total Dedicated headroom 9,720 MiB. 80K/84K/88K passed with narrowing Shared-gate margin; 96K/128K failed. The 64K F16 comparison had equivalent speed and 1,494 MiB less Dedicated headroom, so Q8_0 was selected.
- Output/Vision: Standard16K stops at 16,384 by design; native Long32K naturally completed at 30,803 output tokens with exact fixture hash; the actual Kilo Long32K client path completed a 29,001-token first step before its automatic continuation; Vision PNG scored 7/7. Kilo exposes both aliases without changing its localhost default.
- Management profiles: `configs/candidates/rtx3090-jonathan-q4km.json`, `configs/candidates/rtx3090-hauhaucs-aggressive-q4kp.json`, `configs/candidates/rtx3090-dual-jonathan-q6k-vision.json`
- Node profile: `profiles/RTX3090-Remote/`
- Controlled result: `benchmarks/results/2026-08-20-rtx3090-remote-node.md`
- Cross-hardware result: `benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`
- Operational selection: `benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`
- Shared memory investigation: `research/2026-08-24-blue-shared-gpu-memory-investigation.md`
- Lifecycle rule: these entries assign a Remote Node role only. They do not replace `current-qwen38-27b-uncensored-q6k`.

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
