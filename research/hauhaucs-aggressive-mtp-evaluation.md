# HauhauCS Aggressive-MTP Evaluation Plan

Status: Candidate evaluated / not adopted
Created: 2026-08-20

## Subject

`HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF`

Current からの主な比較理由は Vision、embedded MTP、HauhauCS FastMTP、Aggressive uncensoring profile です。Hugging Face revision `993a5971fda8f30dd1b7eb2654792ba4415c7460` のモデルカードとFiles APIを2026-08-20に確認しました。詳細は `hauhaucs-aggressive-mtp-hf-snapshot-2026-08-20.md` に記録しています。

## Known and unknown

| Item | State | Evidence |
|---|---|---|
| Repository name/revision | verified | Hugging Face model/API |
| Candidate role | confirmed | local management decision |
| Vision capability/projector | locally verified | LM Studio API and Zoo Code PNG attachment |
| Embedded MTP | locally verified | LM Studio runtime draft acceptance logs |
| FastMTP | not tested; stock LM Studio lacks the required custom patch | model card + patch/provenance |
| Exact GGUF variant/file | Q6_K_P primary, Q5_K_P VRAM fallback | hashes matched upstream |
| LM Studio requirements | locally verified on 0.4.21 / llama.cpp CUDA 2.29.1 | load and API runs |
| Zoo Code compatibility | verified with separate Candidate profile | isolated five-file coding fixture |
| Context stability | Q6 practical only at 32K; Q5 stable at 32K/64K/96K | controlled runs |
| Speed / acceptance / VRAM | measured | `benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md` |

## Preflight research

Pre-download research completed:

1. Exact upstream repository, revision, file list, sizes, and checksums recorded.
2. Q6_K_P selected first; Q5_K_P retained as a VRAM fallback.
3. BF16 Vision projector identified as required for image/video input.
4. FastMTP sidecar and custom llama.cpp patch requirement recorded separately from embedded MTP.
5. Native context, sampling, MTP, Aggressive, agentic, and compatibility cautions recorded.
6. Apache-2.0 license recorded. Model files remain outside this repository.

## Controlled comparison

Use Current as the rollback baseline. Start at 32K and preserve Q8_0 K/V cache, Flash Attention ON, MTP max draft tokens 2, reasoning budget 8192, and concurrency 1 unless an upstream requirement forces a separately documented change.

Test sequence:

1. Load and basic text generation at 32K.
2. Zoo Code connection and a small coding task.
3. MTP OFF/ON repeated throughput and acceptance measurements.
4. 32K, 64K, then 96K VRAM/stability tests.
5. Fixed single-file and multi-file Agentic Coding fixtures.
6. Vision test with a fixed screenshot/image fixture.
7. Extended daily-use observation, including Windows responsiveness.

128K + Q8 KV is exploratory only because Current already demonstrated unacceptable desktop responsiveness under that condition.

## Decision record requirements

Promotion requires explicit user approval after results are stored under `benchmarks/results/`. The decision must report gains, regressions, failure modes, and rollback steps. If Vision or FastMTP needs a materially different runtime/configuration, compare both the controlled baseline and the best stable candidate configuration rather than presenting them as the same experiment.

## Local result

Evaluation completed on 2026-08-20. Q6_K_P delivered working Vision and faster prompt ingestion, but its model plus BF16 projector left too little RTX 5090 VRAM for practical 64K/96K use. Q5_K_P restored practical 96K headroom, but remained slower than Current and embedded MTP reduced speed on the fixed workload.

The strongest blocker was Reasoning Budget 8192: Candidate Q6_K_P consumed the full budget and stopped without a final answer, while Current converged and returned a correct final answer. Both completed the Zoo Code coding fixture, but Candidate took longer and repeated its internal design discussion. Current therefore remains unchanged. The detailed record is `../benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md`.
