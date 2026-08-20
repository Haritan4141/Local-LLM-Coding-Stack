# HauhauCS Aggressive-MTP Evaluation Plan

Status: Candidate / not adopted
Created: 2026-08-20

## Subject

`HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF`

Current からの主な比較理由は Vision と FastMTP です。この機能情報はユーザー提供の候補情報であり、このリポジトリ作成時点では upstream metadata やローカル実行で再確認していません。

## Known and unknown

| Item | State | Evidence |
|---|---|---|
| Repository name | provided | user-provided |
| Candidate role | confirmed | local management decision |
| Vision | to verify | user-provided candidate feature |
| FastMTP | to verify | user-provided candidate feature |
| Exact GGUF variant/file | unknown | selection pending |
| LM Studio requirements | unknown | verification pending |
| Zoo Code compatibility | unknown | verification pending |
| Context stability | unknown | benchmark pending |
| Speed / acceptance / VRAM | unknown | benchmark pending |

## Preflight research

Before downloading or loading the model, record:

1. Exact upstream repository and revision/date.
2. Available GGUF files, quantization, size, and checksum.
3. Vision projector or companion artifact requirements, if any.
4. LM Studio/llama.cpp version required for Vision and FastMTP.
5. Chat template, tokenizer, MTP configuration, and known limitations.
6. License and redistribution constraints. Model files remain outside this repository.

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
