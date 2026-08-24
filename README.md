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
| Candidate / Vision profile | JonathanColetti `Q6_K` + official `vision-f16` projector / direct Vision 7/7 |
| Candidate | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` / evaluated, not adopted |
| Watch | 将来の HauhauCS Balanced-MTP-GGUF。公開確認後に登録内容を確定 |

Candidate は Current と分離して扱います。Aggressive Q6_K_P/Q5_K_Pの評価ではVisionとZoo Code連携を確認しましたが、速度・VRAM・Reasoningの回帰によりCurrentへ昇格しません。結果は `benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md` にあります。FastMTPはcustom patchが必要なため未検証です。

JonathanColetti版には公式F16 Vision projectorが追加されました。既存Q6_Kを再ダウンロードせず、別のLM Studio model key/API IDとして分離したVision profileで32K・64K・96Kの画像認識7/7を確認しています。64Kを通常のVision presetとして推奨し、96Kは長context専用とします。2026-08-23からRTX5090のgoose Desktopは、このVision 64K profileをapp-global既定runtimeとして運用します。デスクトップの`Goose Vision 64K`ショートカットがモデル、Vision capability、context、Q8/Q8、MTP、parallelをpreflightし、必要な場合だけmanaged reloadしてgooseを起動します。これはgoose固有の運用判断であり、repository lifecycle Currentは通常text Q6_K / 96Kのままです。導入方式とclient別結果は`research/jonathan-q6k-vision-2026-08-23.md`、実測は`benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`にあります。

## Remote nodes

RTX5090 localhost Currentを変更せず、`pc5700x / RTX 3090 24 GB + RTX 3060 12 GB`をLAN経由の補助LM Studio nodeとして分離管理します。

```text
Main PC: VS Code -> Zoo Code
  -> http://192.168.0.104:1234
  -> LM Studio on DESKTOP-L9HAM1G
  -> RTX 3090 24 GB + RTX 3060 12 GB
```

BLUE Operational DefaultのAPI identifierは`qwen3.8-27b-uncensored-vision-blue`です。localhost CurrentのIDを流用しません。Kilo CodeにはBLUE Standard16K / Long32Kを追加し、既定localhost modelは変更していません。Zoo CodeのBLUE profileは正式なUIから追加する作業をpendingとします。

BLUEの普段使いはJonathan Q6_K Vision / 64K / Q8_0 / RTX3090→RTX3060 dual GPUです。Shared 3.281 GiB、Dedicated headroom合計9,720 MiBで選定し、80K～88Kはcapacity evidence、96K/128KはShared gate FAILとしてOperational loaderを作りません。RTX3090 Power Limitは259WをPrimary Operational、370Wを明示選択のPerformance overrideとします。RTX3060は常に170Wです。loaderはGPU名・PCI Bus IDで照合したUUIDへ設定し、成功確認後にモデルをロードします。

64K short generationは26.13 tok/s、MTP acceptance 79.41%、Vision fixture 7/7です。Long32Kはnative APIで30,803 output tokensを自然完了し、Kilo実経路でも29,001 tokensを生成しました。Standard16K / Long32KはPower Limitから独立したclient profileとして維持します。MAINのREMOTE launcherは`pc5700x / 192.168.0.104 / DESKTOP-L9HAM1G`を照合してBLUEだけを起動します。Q4_K_M / 32Kはfallback、HauhauCS Q4_K_Pはoptional Candidateとして保持します。詳細は`profiles/RTX3090-Remote/`、選定結果は`benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`、Power A/Bは`benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`、Shared原因は`research/2026-08-24-blue-shared-gpu-memory-investigation.md`に記録します。

## Repository map

| Path | Role |
|---|---|
| `CURRENT_STATE.md` | 現在の実運用状態と既知の制約 |
| `MODEL_REGISTRY.md` | Current / Candidate / Watch / Retired の台帳 |
| `CHANGELOG.md` | 設定変更とモデル判断の時系列履歴 |
| `configs/` | LM Studio/Zoo Code の有効設定を表す管理用 JSON |
| `benchmarks/` | 共通プロトコル、テンプレート、整形済み実測 |
| `research/` | 候補調査、出典、仮説、未確認事項 |
| `profiles/` | GPU/PC別のRemote Node identity、接続、容量、実測 |
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

Currentモデルの96K / 64K / 32K BATは `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/` で管理します。同じQ6_Kへprojectorを追加するVision用BATは`Qwen3.8-JonathanColetti-Q6K-Vision/`へ分離します。Candidate Q6_K_PとQ5_K_P fallbackも、量子化を明記した別ディレクトリです。RTX3090はOperational Defaultを`RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/`、fallbackを`Qwen3.8-JonathanColetti-Q4KM/`、optional Candidateを`Qwen3.8-HauhauCS-Aggressive-Q4KP/`へ分離します。別モデルを試す場合は、既存BATを上書きせず対象GPU配下へモデル・量子化別ディレクトリを追加します。

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
