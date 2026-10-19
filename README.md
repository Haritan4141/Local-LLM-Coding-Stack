# Local LLM Coding Stack

MAIN / BLUE / GREENのlocal LLM、LM Studio / standalone llama.cpp、起動profile、実測とモデル選定履歴を管理するプロジェクトです。Agent Client / MCP / Skills / DeepSeek設定の記録は隣接する`Local-AI-Agent-Stack`が担当します。

このリポジトリは「設定と判断の記録」を保持します。モデル本体、LM Studio の実データ、キャッシュ、生ログは保持しません。

## 現在の構成と確認範囲

2026-10-19の実機監査では、BLUE（RTX3090 + RTX3060）のstandalone llama.cppでIQ4_XS Vision 256K Candidateが稼働し、MAINの既存SSH forward `127.0.0.1:18081`経由で到達しました。runtime contextは262,144、parallelは1です。MAIN側のstandalone `:18080`は待受なし、MAIN / BLUEのLM Studio loaded instancesは0でした。これは観測時点の状態であり、CandidateのCurrent昇格や長時間品質保証ではありません。

MAINにはGoose Desktop 1.52.0とDeepSeek Harness（実行ファイルProductVersion `0.2.1.0`）があります。観測時はDeepSeekが起動中、Gooseは未起動でした。DeepSeekの保存既定値は`deepseek-account / deepseek-flash`で、local MAIN / BLUE routeは別途設定されています。保存設定と実際のsession選択は区別します。

唯一のrepository lifecycle `Current`は引き続きtext Q6_Kです。実測済みQ5_K_M Vision 96K Recommended Production、Q6 Vision Balanced / Safe、Quick 64K Candidate、IQ4_XS 256K Candidateを別の役割として保持します。今日の実機状態は[CURRENT_STATE.md](CURRENT_STATE.md)、GitHub差分・公開対象・検証と未確認事項は[2026-10-19監査](research/2026-10-19-current-configuration-audit.md)を参照してください。

監査中、`lms ps`がMAINのLM Studioを起動する副作用を生じました。モデルload/unloadや既存BLUE runtimeの操作は行っていません。以降はLMS CLIを使わず既存APIのGETだけで確認しました。詳細と影響範囲は監査記録に残しています。

## 保持するQ6 Current baseline（2026-08）

次の構成・測定値は登録済みbaselineです。今日ロード中のモデルや既定Clientを示しません。

```text
VS Code
  -> Zoo Code
  -> LM Studio
  -> JonathanColetti/Qwen3.8-27B-Uncensored-GGUF (Q6_K)
  -> NVIDIA GeForce RTX 5090 32 GB
```

保持するCurrentのprofile値:

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
| Candidate / RTX5090 Recommended Production | JonathanColetti `Q5_K_M` + official `vision-f16` projector / 96K / MTP3 / batch1024 |
| Candidate | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` / evaluated, not adopted |
| Watch | 将来の HauhauCS Balanced-MTP-GGUF。公開確認後に登録内容を確定 |

Candidate は Current と分離して扱います。Aggressive Q6_K_P/Q5_K_Pの評価ではVisionとZoo Code連携を確認しましたが、速度・VRAM・Reasoningの回帰によりCurrentへ昇格しません。結果は `benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md` にあります。FastMTPはcustom patchが必要なため未検証です。

JonathanColetti版には公式F16 Vision projectorが追加されました。既存Q6_Kを再ダウンロードせず、別のLM Studio model key/API IDとして分離したVision profileで32K・64K・96Kの画像認識7/7を確認しています。64Kを通常のVision presetとして推奨し、96Kは長context専用とします。2026-08-23時点ではRTX5090のgoose Desktopに、このVision 64K profileをapp-global既定runtimeとして設定しました。今日の保存値は冒頭とCURRENT_STATEを参照してください。デスクトップの`Goose Vision 64K`ショートカットがモデル、Vision capability、context、Q8/Q8、MTP、parallelをpreflightし、必要な場合だけmanaged reloadしてgooseを起動します。これはgoose固有の運用判断であり、repository lifecycle Currentは通常text Q6_K / 96Kのままです。導入方式とclient別結果は`research/jonathan-q6k-vision-2026-08-23.md`、実測は`benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`にあります。

Phase 1/1.5後のRTX5090 Q6_K Vision 64K Balanced（MTP4 / Q8_0 / eval batch 2048）はQuality/Performance Referenceです。既存64K loaderはSafe（MTP2 / Q8_0 / batch 2048）として変更せず保持し、Coding-Fast（MTP4 / Q4_0 / batch 2048）は明示選択時だけ使用します。既存Goose one-click startupはSafe preflightを維持します。Q6はdeprecatedではありません。Profile Selectorと実測根拠は各loader READMEおよび`benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`を参照してください。

RTX5090 Recommended ProductionはJonathanColetti Q5_K_M Vision / 96K / Q8_0 / MTP3 / eval batch1024です。最終設定でText 47.02、Coding 63.08、Vision 59.98 tok/s（7/7）、69,139-token入力、exact Tool Calling、isolated Agentic Coding 10/10を確認しました。load時raw headroomは6,175 MiB、420 MiB reserve差引後5,755 MiBです。今回の実用fixtureではPromotionを妨げる品質差を観測していない、という限定した結論であり、Q5/Q6の完全同品質は主張しません。互換名`Goose Q5KM Vision 96K Candidate`ショートカットは90,112-token client limit、16,384 max output、0.3 compact thresholdを維持します。Repository lifecycle CurrentはQ6_Kのままです。

Gooseの日常統合入口は`00-Goose-Daily-Profiles.bat`です。MAIN/BLUEのStable、Turbo、Quick Response Candidate、Quality Referenceを選ぶと、既存canonical runtimeの起動、provider・model・context・output・endpointのcross-check、Goose設定、Goose Desktop起動までを一括実行します。Stable/QualityはLM Studio providerと永続profile、Turbo/Quickは`openai` providerとprocess-local設定を使用し、永続configは変更しません。Q5 StableとTurboは`96K / 16K`または`96K / 32K`、QuickはVision対応`64K / 8K`・Reasoning Low/2048・MTP1、Q6 Quality Referenceは`64K / 32K`です。Goose v1.49向けQuickは画面上でローカルQwenだと分かるaliasを表示し、末尾の`gpt-4o` tokenだけをVision能力判定に使用します。接続先と実モデルはローカルJonathan Q5_K_M Visionです。Quickは未実測Candidateで、CurrentやStableを変更しません。Turbo 32Kのqualification結果は`benchmarks/results/2026-08-26-goose-turbo-output32k-qualification.md`、Quickの判断根拠は`research/2026-09-07-qwen38-quick-response-64k-8k.md`を参照してください。

## Remote nodes

RTX5090 localhost Currentを変更せず、`pc5700x / RTX 3090 24 GB + RTX 3060 12 GB`をLAN経由の補助LM Studio nodeとして分離管理します。

```text
Main PC: VS Code -> Zoo Code
  -> http://192.168.0.104:1234
  -> LM Studio on DESKTOP-L9HAM1G
  -> RTX 3090 24 GB + RTX 3060 12 GB
```

BLUE Recommended ProductionのAPI identifierは`qwen3.8-27b-uncensored-vision-q5km-blue`です。Q6 Referenceは`qwen3.8-27b-uncensored-vision-blue`を保持し、localhost CurrentのIDを流用しません。Kilo CodeにはBLUE Standard16K / Long32Kを追加し、既定localhost modelは変更していません。Zoo CodeのBLUE profileは正式なUIから追加する作業をpendingとします。

BLUEの普段使いはJonathan Q5_K_M Vision / 96K / Q8_0 / MTP3 / eval batch1024 / RTX3090→RTX3060 dual GPUのRecommended Productionです。Q6 Balanced 64KはQuality/Performance Reference、既存MTP2 / batch512 loaderはSafeとして永久保持し、Q4_0 / MTP3 / batch512はCoding-Fastとして明示選択時だけ使用します。Q5 96KはStrict Shared gateにPASSしました。Q6は80K～88Kをcapacity evidenceとして保持し、96K/128KはShared gate FAILのためOperational loaderを作りません。RTX3090 Power Limitは259WをPrimary Operational、370Wを明示選択の独立Performance overrideとします。RTX3060は常に170Wです。loaderはGPU名・PCI Bus IDで照合したUUIDへ設定し、成功確認後にモデルをロードします。

Q5 96K qualificationはText/Coding/Vision/Tool Calling/76,880-token入力とfresh Q6 comparisonにPASSしました。Q6 64K Referenceのshort generationは26.13 tok/s、MTP acceptance 79.41%、Vision fixture 7/7です。Long32Kはnative APIで30,803 output tokensを自然完了し、Kilo実経路でも29,001 tokensを生成しました。Standard16K / Long32KはPower Limitから独立したclient profileとして維持します。MAINのREMOTE launcherは`pc5700x / 192.168.0.104 / DESKTOP-L9HAM1G`を照合してBLUEだけを起動します。Q4_K_M / 32Kはfallback、HauhauCS Q4_K_Pはoptional Candidateとして保持します。詳細は`profiles/RTX3090-Remote/`、Q5選定結果は`benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`、Q6 Referenceは`benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`、Power A/Bは`benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`、Shared原因は`research/2026-08-24-blue-shared-gpu-memory-investigation.md`に記録します。

`pc7600x / RX 9070 XT 16 GB`はRED AMD Remote Node Candidateです。Jonathan公式IQ4_XSをROCm 2.29.1でロードし、API ID `qwen3.8-27b-uncensored-iq4xs-red`、96K、Q4_0/Q4_0、MTP2、batch512、parallel1を採用しました。70,082-token入力、exact Tool Calling、Goose simple/Developer tool pathを確認済みです。96K生成peakはDedicated 14.845 GiB / Shared 3.570 GiBなので、重いGPU workloadと併用しない補助nodeとして扱います。64K fallbackも保持します。詳細は`profiles/RX9070XT-Remote/`と`benchmarks/results/2026-08-25-rx9070xt-iq4xs-96k.md`を参照してください。

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

Currentモデルの96K / 64K / 32K BATは `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/` で管理します。同じQ6_Kへprojectorを追加するVision用BATは`Qwen3.8-JonathanColetti-Q6K-Vision/`、Recommended ProductionのQ5_K_M Vision 96Kは`Qwen3.8-JonathanColetti-Q5KM-Vision/`へ分離します。Candidate Q6_K_PとQ5_K_P fallbackも、量子化を明記した別ディレクトリです。RTX5090/BLUEのVision selectorは個別loaderをCALLするだけです。RTX3090はOperational Recommendedを`RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/`、Q6 referenceを`Qwen3.8-JonathanColetti-Q6K-Vision/`、fallbackを`Qwen3.8-JonathanColetti-Q4KM/`、optional Candidateを`Qwen3.8-HauhauCS-Aggressive-Q4KP/`へ分離します。RX9070XTは`RX9070XT/Qwen3.8-JonathanColetti-IQ4XS/`にMAIN用64K/96K REMOTE loaderを置きます。別モデルを試す場合は、既存BATを上書きせず対象GPU配下へモデル・量子化別ディレクトリを追加します。

BATはGGUFを内包・ダウンロードせず、LM Studioへインストール済みのモデルを `lms` CLIで参照します。実行時に `lms unload --all` を行うため、現在ロード中のモデルを解除する点に注意してください。

Gooseを完全終了した状態で`scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`を実行すれば、対応するRTX5090/BLUE Daily runtimeの起動、Goose profileの整合確認、Goose Desktop起動まで完結します。既存の個別runtime selectorとprofile helperは互換・保守用に保持します。詳細は`scripts/goose/README.md`を参照してください。

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
