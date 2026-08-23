# Qwen3.8 HauhauCS Aggressive Q6_K_P LM Studio Loaders

RTX 5090 32 GB上で評価するCandidate `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF`用のloaderです。CurrentのJonathanColetti Q6_Kとは別ディレクトリ・別API identifierで管理します。

## Model identity

| Item | Value |
|---|---|
| Role | Candidate / not adopted |
| Quantization | Q6_K_P |
| LM Studio model key | `hauhaucs/qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp-gguf/qwen3.8-27b-uncensored-hauhaucs-aggressive-q6_k_p.gguf` |
| API identifier | `qwen3.8-27b-hauhaucs-aggressive` |
| Native context | 262,144 tokens |
| Vision | Supported; BF16 mmproj installed outside this repository |
| Speculative decoding | Embedded MTP ON, max draft tokens 2 |
| FastMTP | Not enabled; separate sidecar and custom HauhauCS llama.cpp patch are required |

## Presets

| BAT | Context | Use |
|---|---:|---|
| `Qwen3.8-HauhauCS-Q6KP_96K.bat` | 98,304 | 通常のZoo Code・Agentic Coding比較 |
| `Qwen3.8-HauhauCS-Q6KP_64K.bat` | 65,536 | VRChat / Unityプロジェクト比較 |
| `Qwen3.8-HauhauCS-Q6KP_32K.bat` | 32,768 | 初期検証、Vision、VRAM余裕優先 |

128K loaderは作成しません。Currentでも128K + Q8 KVはWindows操作性を損なったため、Candidateの常用比較範囲を32K / 64K / 96Kに限定します。

## Load behavior

各BATは`lms unload --all`の後、Candidateを最大GPU offload、parallel 1、embedded MTP、max draft tokens 2で読み込みます。ロード失敗時はモデル未ロードになる可能性がありますが、Currentのモデルファイル、Per-model Defaults、JonathanColetti loaderは変更しません。

## Common LM Studio settings

CLIで明示できる値と、LM StudioのCandidate用Per-model Defaultsに保存する値を分離します。

| Setting | Candidate value | Managed by |
|---|---:|---|
| Context | 32,768 / 65,536 / 98,304 | BAT |
| GPU Offload | maximum / all layers | BAT `--gpu max` |
| Max Concurrent Predictions | 1 | BAT `--parallel 1` |
| MTP | ON / embedded | BAT `--speculative-draft-mtp` |
| Max draft tokens | 2 | BAT `--speculative-draft-max-tokens 2` |
| K Cache | Q8_0 | Candidate Per-model Defaults |
| V Cache | Q8_0 | Candidate Per-model Defaults |
| KV Cache GPU Offload | ON | Candidate Per-model Defaults |
| Flash Attention | ON | Candidate Per-model Defaults |
| Reasoning Budget | 8,192 | Zoo Code/request policy |

Q6_K_Pは実測で64K/96Kの実用的なVRAM余裕を確保できなかったため、Q5_K_Pを`../Qwen3.8-HauhauCS-Aggressive-Q5KP/`へ分離追加しました。このloaderはQ6_K_P用のまま維持します。

## Vision

LM Studio外部モデル保存領域では、Q6_K_P本体と次のprojectorを同じHugging Face repository配下へ導入しています。

`mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf`

`lms ls --json`で`vision: true`を確認し、Direct APIとZoo Code画像添付の両方で実画像理解を確認済みです。詳細は`../../../../../benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md`を参照してください。GGUFとmmprojはこのリポジトリに保存しません。

## Evaluation outcome

Q6_K_PはVisionとTool Callingを利用できましたが、32KでもCurrentより遅く、64K/96KではVRAM圧迫により速度が大幅に低下しました。Reasoning Budget 8192でも最終回答へ到達しなかったため、Currentへの昇格は推奨しません。

## Rollback

Currentへ戻す場合は、既存の`../Qwen3.8-JonathanColetti-Q6K/`にあるcontext別BATを実行します。Zoo Code側もCurrent用profileへ戻し、API ID `qwen3.8-27b-uncensored`を選択します。
