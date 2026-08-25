# Model Registry

Last updated: 2026-08-25

## Registry

| ID | Status | Repository / model | Variant | Key capabilities | Evidence state |
|---|---|---|---|---|---|
| `current-qwen38-27b-uncensored-q6k` | Current | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K | Text coding, MTP | Stable at 96K; measured MTP ON/OFF speed supplied |
| `candidate-jonathan-q6k-vision` | Candidate / RTX5090 Quality-Performance Reference | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K + official F16 projector | Vision, text coding, MTP | Phase 1/1.5 selected 64K MTP4/Q8/batch2048 Balanced Reference; permanent MTP2/Q8 Safe and explicit Q4 Coding-Fast retained; not deprecated |
| `candidate-jonathan-q5km-vision` | Candidate / RTX5090 Recommended Production | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q5_K_M + official F16 projector | Vision, tool use, lower-VRAM 96K | Final MTP/batch/capacity/quality gates passed at 96K MTP3/Q8/batch1024; lifecycle Current remains Q6_K |
| `candidate-hauhaucs-aggressive-mtp` | Candidate | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` | Q6_K_P primary; Q5_K_P fallback | Vision + embedded MTP; custom-patch FastMTP | Local evaluation complete; promotion not recommended |
| `candidate-rtx3090-jonathan-q4km` | Candidate / Remote Node Fallback | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q4_K_M | Text coding, embedded MTP, separate Vision projector | Evaluation complete; retained as BLUE 32K fallback |
| `candidate-rtx3090-hauhaucs-aggressive-q4kp` | Candidate / Remote Node Optional | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` | Q4_K_P | Vision + embedded MTP; stock LM Studio path | Evaluation complete; retain for optional/direct Vision use |
| `candidate-rtx3090-dual-jonathan-q5km-vision-96k` | Candidate / BLUE Recommended Production | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q5_K_M + F16 projector | Dual-GPU Vision, embedded MTP, 96K | Strict gate, Text/Coding/Vision/Tool/76,880-token quality, and fresh Q6 comparison PASS; MTP3/Q8/batch1024 at 259W selected |
| `candidate-rtx3090-dual-jonathan-q6k-vision` | Candidate / BLUE Quality-Performance Reference | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | Q6_K + F16 projector | Dual-GPU Vision, embedded MTP, 64K | Phase 1/1.5 selected MTP3/Q8/batch1024 Balanced at 259W; MTP2/Q8/batch512 Safe and explicit Q4 Coding-Fast retained; 370W stays separate |
| `candidate-rx9070xt-jonathan-iq4xs-96k` | Candidate / RED Remote Node Recommended | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` | IQ4_XS text/tool | ROCm, embedded MTP, 96K Q4 KV | 64K/96K load, MTP A/B, 70,082-token input, exact Tool Calling and Goose path PASS; Shared-dependent |
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
- Operational profiles: Balanced is the Quality/Performance Reference at 64K / MTP4 / Q8_0/Q8_0 / batch2048; existing Safe remains MTP2/Q8/batch2048; Coding-Fast is explicit MTP4/Q4/batch2048 only
- Direct result: fixed PNG fixture 7/7 at 32K, 64K, and 96K
- Client result: Kilo transported the image and scored 6/7; goose CLI 1.46.0 did not transport the image; goose Desktop 1.47.0 attached and sent the image under the Vision ID but the first inference hit a text-only LM Studio instance. Direct recovery passed after an explicit Vision reload; Desktop remains conditional and Zoo Code remains pending
- Recommended Reference preset: 64K. The Q6 96K run passed but peaked at 29,736 MiB and leaves reduced GPU headroom
- Operational role: RTX5090 Quality/Performance Reference with Safe and Coding-Fast retained; Q6 is not deprecated and remains the sole repository Current artifact
- One-click startup: desktop shortcut `Goose Vision 64K`, backed by `Start-Goose-Jonathan-Vision64K.ps1`, verifies the single Vision instance and all managed load fields before opening goose
- Lifecycle decision: retain as an explicit Vision Candidate/runtime profile; do not create a second repository-wide Current
- Management profile: `configs/candidates/jonathan-q6k-vision.json`
- Research note: `research/jonathan-q6k-vision-2026-08-23.md`
- Controlled result: `benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`
- Cross-hardware result: `benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`; RTX5090 and RTX3090+3060 were strict at 8K, while RTX3090 alone remained PARTIAL_OFFLOAD even at 2K
- Phase 1/1.5 profiles: `benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`
- Managed loaders: `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/`

## Candidate: candidate-jonathan-q5km-vision

- Role: RTX5090 Recommended Production / Operational Profile at 96K while retaining repository lifecycle `Candidate`
- Repository: `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF`
- Revision: `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3`
- Variant: `Q5_K_M` plus official F16 Vision projector
- Model size: 19,535,701,408 bytes; 2,895,298,560 bytes / 2.696 GiB smaller than Q6_K
- Model key / API identifier: `qwen3.8-27b-uncensored-vision-q5km`
- Selected runtime: 98,304 context, Q8_0/Q8_0, full GPU offload, Flash Attention ON, mmap+mlock, MTP draft 3, eval batch 1024, effective ubatch 512, parallel 1, PL 402W
- Speed/capacity: final Text/Coding/Vision/69K Long generation 47.02/63.08/59.98/53.98 tok/s; load 26,432 MiB with 6,175 MiB raw and 5,755 MiB reserve-adjusted headroom; production peak 26,498 MiB / Shared 0.569 GiB
- MTP decision: draft 3 produced the highest four-workload geomean (55.18 tok/s), 84.06% weighted acceptance, and 12/12 formal PASS. Relative to OFF it traded Text -8.88% for Coding/Vision/Long +24.03/+16.05/+15.55%; draft 4 did not improve the overall result
- Batch decision: 1024 and 2048 were effectively equal on the unique ~24K Long Prompt (2,132.05 versus 2,129.33 prompt tok/s; TTFT 11.3648 versus 11.3727 seconds); 1024 retained slightly lower Shared/RAM
- Functional result: 69,139-token input PASS, direct Vision 7/7 across three formal runs, exact direct Tool Calling, isolated Goose multi-file fixture 10/10
- Known limitation: Reasoning Budget 8,192 did not reach a final answer; same-condition Q6_K also failed, so the cause remains shared/unresolved
- Goose integration: compatibility-named `Goose Q5KM Vision 96K Candidate` shortcut with process-only 90,112 context limit, 16,384 max output, and 0.3 compact threshold; Q6 shortcut remains available
- Quality statement: 今回の実用fixtureではPromotionを妨げる品質差を観測していない。This does not assert complete Q5/Q6 quality equivalence
- Lifecycle decision: promote to RTX5090 Recommended Production operational role without changing the single repository Current
- Management profile: `configs/candidates/jonathan-q5km-vision.json`
- Research note: `research/jonathan-q5km-vision-2026-08-24.md`
- Controlled result: `benchmarks/results/2026-08-24-rtx5090-jonathan-q5km-vision.md`
- Production finalization: `benchmarks/results/2026-08-25-rtx5090-q5km-vision-96k-production.md`
- Managed loaders: `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q5KM-Vision/`

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
- Recommended Production artifact: Q5_K_M, 19,535,701,408 bytes, SHA-256 `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547`; projector SHA-256 `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c`.
- Jonathan artifact: Q4_K_M, 16,810,714,528 bytes, SHA-256 `4c5e2db039e9325ac7724c8846c71356a24ad1cdfa28002d73ecb6be645f9675`
- HauhauCS artifact: Q4_K_P, 17,923,393,664 bytes, SHA-256 `ba36dc3c2b2ff5e0aa5d71092a8894546996a6a119ae391803dda07cdc08516d`
- Operational API identifier: Q5_K_M Vision `qwen3.8-27b-uncensored-vision-q5km-blue`; Q6_K Vision reference/fallback `qwen3.8-27b-uncensored-vision-blue`; legacy Jonathan Q4_K_M `qwen3.8-27b-uncensored@q4_k_m`; optional HauhauCS `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp`.
- Vision projectors are separate external GGUF artifacts; model weights and projectors remain outside this repository.
- 32K result: Jonathan 36.31 tok/s / 19,737 MiB / MTP acceptance 73.91%; HauhauCS 35.47 tok/s / 20,867 MiB / 72.80%.
- 64K result: both completed three controlled generations; Jonathan retained about 3,238 MiB idle free VRAM and HauhauCS about 2,188 MiB. Use only as a single-model long-context profile.
- Q5_K_M 96K result: load Shared 3.515 GiB, maximum observed 3.527 GiB, RTX3090 headroom 6,706 MiB, RTX3060 headroom 3,409 MiB, no OOM, unchanged Strict gate PASS. Q6_K 96K remains excluded because its own Q8 Shared result was 5.021 GiB.
- Reasoning result: both consumed the 8,192-token budget without reaching a final answer. This role does not replace the reasoning-stable RTX5090 Current.
- Tool/Vision result: both passed exact direct Tool Calling and direct Vision 7/7. Both completed the isolated Zoo Code Agentic fixture; HauhauCS Zoo Code Code mode did not consume the attached image and entered a tool loop.
- Role decision: Jonathan Q5_K_M Vision / 96K / Q8_0 / MTP3 / batch1024 / RTX3090→RTX3060 is BLUE Recommended Production. Q6_K Balanced is the Quality/Performance Reference, Q6_K Safe the known-good fallback, and Q6 Coding-Fast/370W remain explicit-only. RTX3090 259W is Primary; RTX3060 remains 170W. The repository-wide Current remains RTX5090 Jonathan Q6_K.
- Fresh comparison: Q5 versus Q6 Balanced improved Text/Coding/Vision generation by about 12.5/3.3/7.5 percent, Long prompt processing by 5.7 percent, Long TTFT by 5.4 percent, and reduced Dedicated peak by about 754 MiB without a quality failure.
- Q6_K Vision result: 64K Shared 3.281 GiB and total Dedicated headroom 9,720 MiB. 80K/84K/88K passed with narrowing Shared-gate margin; 96K/128K failed. The 64K F16 comparison had equivalent speed and 1,494 MiB less Dedicated headroom, so Q8_0 was selected.
- Output/Vision: Standard16K stops at 16,384 by design; native Long32K naturally completed at 30,803 output tokens with exact fixture hash; the actual Kilo Long32K client path completed a 29,001-token first step before its automatic continuation; Vision PNG scored 7/7. Kilo exposes both aliases without changing its localhost default.
- Management profiles: `configs/candidates/rtx3090-dual-jonathan-q5km-vision-96k.json`, `configs/candidates/rtx3090-dual-jonathan-q6k-vision.json`, `configs/candidates/rtx3090-jonathan-q4km.json`, `configs/candidates/rtx3090-hauhaucs-aggressive-q4kp.json`
- Node profile: `profiles/RTX3090-Remote/`
- Controlled result: `benchmarks/results/2026-08-20-rtx3090-remote-node.md`
- Cross-hardware result: `benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`
- Operational selection: `benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`
- Phase 1/1.5 profiles: `benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`
- Q5_K_M 96K qualification: `benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`
- Shared memory investigation: `research/2026-08-24-blue-shared-gpu-memory-investigation.md`
- Lifecycle rule: these entries assign a Remote Node role only. They do not replace `current-qwen38-27b-uncensored-q6k`.

## Remote Node candidate: RX9070XT

- Node: `pc7600x / DESKTOP-LMB720F / 192.168.0.103 / AMD Radeon RX 9070 XT 16 GB`
- Runtime: LM Studio 0.4.21+2 / AMD ROCm 2.29.1; Vulkan 2.29.1 retained as fallback
- Artifact: Jonathan `IQ4_XS`, 15,309,039,008 bytes, SHA-256 `53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5`
- API identifier: `qwen3.8-27b-uncensored-iq4xs-red`
- Recommended Candidate: 96K / Q4_0-Q4_0 / MTP draft 2 / batch512 / parallel1 / RX9070XT only / Vision false
- Capacity: 96K load Dedicated 14.816 GiB / Shared 3.542 GiB; generation peak 14.845 / 3.570 GiB. 64K fallback Shared is 2.604 GiB
- Speed: MTP2 median 36.762 tok/s versus OFF 29.664 tok/s, about +23.9%
- Long context: 70,082-token input completed with 3/3 retrieval; TTFT 246.93 seconds
- Client: exact direct Tool Calling, Goose simple inference, and Goose Developer tool call PASS. Goose global default remains RTX5090 localhost
- Management profile: `configs/candidates/rx9070xt-jonathan-iq4xs-96k.json`
- Node profile: `profiles/RX9070XT-Remote/`
- Result: `benchmarks/results/2026-08-25-rx9070xt-iq4xs-96k.md`
- Lifecycle: Remote Node Candidate only; it does not replace Current or the RTX5090/BLUE operational profiles

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
