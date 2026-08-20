# Local LLM Coding Stack

VS Code + Zoo Code + LM Studio + local LLM の安定運用、候補評価、モデル乗り換え履歴を継続管理するための専用プロジェクトです。

このリポジトリは「設定と判断の記録」を保持します。モデル本体、LM Studio の実データ、キャッシュ、生ログは保持しません。

## Current stack

```text
VS Code
  -> Zoo Code
  -> LM Studio
  -> JonathanColetti/Qwen3.8-27B-Uncensored-GGUF (Q6_K)
  -> NVIDIA GeForce RTX 5090 32 GB
```

Current の主な運用値:

| 項目 | 値 |
|---|---:|
| Normal Context | 98,304 |
| VRChat Context | 65,536 |
| Light Context | 32,768 |
| K / V Cache | Q8_0 / Q8_0 |
| Flash Attention | ON |
| GPU Offload | 65 / 65 layers |
| MTP | ON |
| Max draft tokens | 2 |
| Reasoning Budget | 8,192 |
| Max Concurrent Predictions | 1 |

既存実測では MTP ON が 63.92 tok/s、MTP OFF が 48.30 tok/s、MTP acceptance は概ね 40–50% です。96K は安定しています。128K + Q8 KV は VRAM 圧迫で Windows の操作性が低下したため、常用対象外です。

## Model lifecycle

| Status | Model |
|---|---|
| Current | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` / `Q6_K` |
| Candidate | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` |
| Watch | 将来の HauhauCS Balanced-MTP-GGUF。公開確認後に登録内容を確定 |

Candidate は Current と分離して扱います。Vision と FastMTP は比較対象の機能ですが、性能・安定性・互換性は未検証です。

## Repository map

| Path | Role |
|---|---|
| `CURRENT_STATE.md` | 現在の実運用状態と既知の制約 |
| `MODEL_REGISTRY.md` | Current / Candidate / Watch / Retired の台帳 |
| `CHANGELOG.md` | 設定変更とモデル判断の時系列履歴 |
| `configs/` | LM Studio/Zoo Code の有効設定を表す管理用 JSON |
| `benchmarks/` | 共通プロトコル、テンプレート、整形済み実測 |
| `research/` | 候補調査、出典、仮説、未確認事項 |
| `logs/` | Git 管理しないローカル生ログ |
| `scripts/` | ベンチマーク記録、整合性検証、管理対象のLM Studio loader |

## Daily workflow

1. Current の事実は `CURRENT_STATE.md` を確認します。
2. 新モデルは `MODEL_REGISTRY.md` へ Candidate として追加します。
3. `configs/candidates/` に Current と分離した比較設定を作ります。
4. `benchmarks/README.md` の固定条件で測定し、`benchmarks/results/` に結果を保存します。
5. 採用判断は速度だけでなく、VRAM、長文安定性、MTP acceptance、Vision、Agentic Coding の完遂率を含めます。
6. 変更と判断を `CHANGELOG.md` に残します。

## Managed LM Studio loaders

Currentモデルの96K Normal / 64K VRChat / 32K Light BATは `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/` で管理します。別モデルを試す場合は、CurrentのBATを上書きせず `RTX5090/` 配下へモデル別ディレクトリを追加します。

BATはGGUFを内包・ダウンロードせず、LM Studioへインストール済みのモデルを `lms` CLIで参照します。実行時に `lms unload --all` を行うため、現在ロード中のモデルを解除する点に注意してください。

新規ベンチマーク記録の雛形:

```powershell
.\scripts\New-BenchmarkRecord.ps1 `
  -ModelId 'candidate-hauhaucs-aggressive-mtp' `
  -ConfigPath 'configs/candidates/hauhaucs-qwen38-27b-aggressive-mtp.json' `
  -WorkloadId 'coding-fixed-v1'
```

リポジトリ検査:

```powershell
.\scripts\Test-Repository.ps1
```

## Data boundary

`.gitignore` は GGUF、SafeTensors、各種重み、LM Studio キャッシュ、`models/`、生ログを除外します。モデルファイルは LM Studio が管理する外部の保存場所に置き、このリポジトリでは `repository`、`variant`、任意の外部参照だけを記録してください。
