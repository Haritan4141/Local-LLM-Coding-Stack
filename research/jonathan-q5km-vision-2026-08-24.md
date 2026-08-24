# JonathanColetti Q5_K_M Vision 96K Candidate research

Date: 2026-08-24

## Objective

Evaluate whether JonathanColetti Q5_K_M with the official F16 Vision projector can provide a 96K Goose coding profile with materially more RTX5090 desktop headroom than Q6_K Vision 96K, without an operationally meaningful Agentic Coding regression. Repository Current remains JonathanColetti Q6_K.

## Verified upstream artifacts

Revision: `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3`

| Artifact | Size | SHA-256 | MTP |
|---|---:|---|---|
| `Qwen3.8-27B-Uncensored-Q5_K_M.gguf` | 19,535,701,408 bytes | `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547` | embedded |
| `Qwen3.8-27B-Uncensored-Q6_K.gguf` | 22,430,999,968 bytes | `a50aa1478295b58ee3d93eabe02c17f6d5fcf6cb787fd8a0ab07ac629a46cae6` | embedded |
| `Qwen3.8-27B-Uncensored-vision-f16.gguf` | 927,606,912 bytes | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` | not applicable |

Q5_K_M is 2,895,298,560 bytes (2.696 GiB, 12.91%) smaller than Q6_K. Both fused artifacts retain the verified MTP block and can use the same official Vision projector. Upstream native context is 262,144.

Sources:

- [Model card and quantization table](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/README.md)
- [Q5_K_M artifact](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/Qwen3.8-27B-Uncensored-Q5_K_M.gguf)
- [Vision projector](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/Qwen3.8-27B-Uncensored-vision-f16.gguf)

## Quality evidence and limits

The upstream same-session Wikitext-2 measurements report Q5_K_M PPL 7.1573 +/- 0.25055 and Q6_K PPL 7.1689 +/- 0.25149. The author explicitly states that the non-IQ2 quantizations are not separable within these error bars and that perplexity does not measure reasoning, code, multilingual ability, or refusal behavior. Therefore this evidence does not show a measurable Q5 quality loss, but it also cannot replace a local coding/tool-loop A/B.

## Local storage and catalog verification

The Q5_K_M artifact was downloaded to the Hugging Face cache at the fixed revision and verified by size and SHA-256. A separate LM Studio Vision directory uses NTFS hardlinks to the verified Q5 artifact and the already verified projector. No GGUF is stored in Git and the Q6 model views were not changed.

LM Studio catalog result:

- model key: `qwen3.8-27b-uncensored-vision-q5km`
- quantization: `Q5_K_M`
- Vision: true
- trained for Tool Use: true
- native maximum context: 262,144
- combined model + projector size: 20,463,308,320 bytes

## Pre-test capacity estimate

Existing Q6_K Vision 96K measured peak is 29,736 MiB. Subtracting only the exact target-weight size difference predicts approximately 26,975 MiB for Q5_K_M Vision 96K. With the current RTX5090 32,607 MiB total and approximately 420 MiB reserved, estimated effective headroom is about 5,212 MiB. This is a capacity hypothesis, not a measured result.

## Local controlled results

The capacity hypothesis was confirmed with a larger margin than predicted when MTP was disabled.

| 96K configuration | Median generation | Median TTFT | Peak VRAM | WDDM Shared peak | MTP acceptance |
|---|---:|---:|---:|---:|---:|
| Q5_K_M / MTP OFF | 53.7446 tok/s | 0.0837 s | 25,876 MiB | 0.708 GiB | N/A |
| Q5_K_M / MTP ON | 45.5164 tok/s | 0.1132 s | 27,265 MiB | 0.885 GiB | 78.2548% |
| Q6_K / MTP ON control | 60.8219 tok/s | 0.0892 s | 29,720 MiB | not retained in this run | not retained in this run |

Q5_K_M / MTP OFF was 18.1% faster than the same Q5_K_M fixture with MTP ON and used 1,389 MiB less peak VRAM. Against the same-condition Q6_K / MTP ON control, it was 11.6% slower but used 3,844 MiB less peak VRAM. This is why the Candidate's managed loaders deliberately use MTP OFF even though the artifact contains an MTP block.

The 96K MTP OFF run retained about 6.16 GiB of effective headroom at peak after subtracting the 420 MiB NVIDIA reservation (`32607 - 25876 - 420 = 6311 MiB`) and did not show a WDDM Shared-memory spill. It is materially safer for Windows desktop responsiveness than Q6_K Vision 96K, although interactive mouse smoothness still requires real-user observation during longer everyday sessions.

## Functional gate results

- Long context: a 70,081-token input, above the former 64K ceiling, returned the exact `NEEDLE-96K-PASS` marker without a truncation error.
- Vision: the fixed PNG was recognized with all seven requested UI fields present. An auxiliary PowerShell scorer had a regex-array construction error, so the recorded 7/7 is a direct verification of the response rather than that scorer's numeric output.
- Direct Tool Calling: exact function name and arguments passed.
- Agentic Coding: Goose CLI 1.47.0 inspected and edited an isolated multi-file fixture, created the requested change note, and finished with 10/10 tests. It made one unnecessary `read_image` call on a non-image file, received an error, and recovered without task failure.
- Reasoning Budget 8,192: both Q5_K_M / MTP OFF and same-condition Q6_K / MTP ON consumed all 8,192 completion tokens in reasoning and did not emit a final answer. Treat this as a shared runtime/prompt issue, not evidence of a Q5-only regression, and keep it open for a differently designed reasoning fixture.

## Goose integration decision

The Candidate launcher uses a 98,304-token LM Studio runtime and gives its Goose child process `GOOSE_CONTEXT_LIMIT=90112`, `GOOSE_MAX_TOKENS=16384`, and `GOOSE_AUTO_COMPACT_THRESHOLD=0.3`. The 8,192-token gap between Goose's context limit and the server capacity protects against boundary overshoot. Goose auto-compaction is evaluated only at turn boundaries, so a single long tool turn can still cross a limit; the backend headroom is therefore intentional.

The launcher passes provider/model/context values only to the new Goose Desktop process. It does not rewrite the persistent Goose config, and it does not replace the existing Q6_K Vision 64K shortcut.

Goose references:

- [Official configuration-file guide](https://github.com/block/goose/blob/main/documentation/docs/guides/config-files.md)
- [Open issue: auto-compaction can miss an over-limit same-turn tool loop](https://github.com/aaif-goose/goose/issues/11072)

## Evaluation gate

The 96K Candidate is acceptable for normal Goose use only if controlled testing confirms:

1. Q8_0/Q8_0, full GPU offload, Flash Attention, model-specific MTP OFF, parallel 1 and Vision true.
2. At least 4 GiB effective VRAM headroom with no material Shared GPU Memory growth.
3. A prompt above the prior 64K ceiling completes without `truncated = 1`.
4. Vision fixture remains 7/7.
5. MTP ON/OFF speed and ON acceptance are recorded.
6. Coding, Tool Calling and long agent-loop behavior do not show a meaningful regression from Q6_K.
7. Goose is configured against the real 96K runtime rather than its 128K fallback display, with compaction margin retained.

The operational gate passed for an explicit 96K Candidate profile. Promotion remains blocked pending broader everyday quality observation and explicit user approval; repository Current stays Q6_K.
