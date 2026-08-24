# Current State

State captured: 2026-08-24 (Asia/Tokyo)

## Operational status

- Current model: `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF`
- Variant: `Q6_K`
- Status: `Current / stable`
- Hardware: NVIDIA GeForce RTX 5090 32 GB
- Client path: VS Code -> Zoo Code -> LM Studio -> local model
- Max concurrent predictions: 1
- Repository lifecycle Current remains API ID `qwen3.8-27b-uncensored`; its model files and loader presets were not overwritten.
- BLUE currently has its independent Operational Default loaded and IDLE: API ID `qwen3.8-27b-uncensored-vision-blue`, 65,536 context, Q8_0/Q8_0, RTX3090→RTX3060 priority order, embedded MTP ON / draft 2, parallel 1, Vision true. This Remote Node role does not promote the Candidate or replace repository Current.
- goose Desktop persistent operational default on RTX5090: API ID `qwen3.8-27b-uncensored-vision` with client context limit 64,512. The desktop shortcut `Goose Vision 64K` performs a managed runtime preflight and starts goose without requiring normal model reselection.
- Recommended explicit 96K Goose Candidate: Jonathan Q5_K_M Vision, API ID `qwen3.8-27b-uncensored-vision-q5km`, Q8_0/Q8_0, MTP OFF, parallel 1. Its separate shortcut uses a process-only 90,112 client limit and does not replace the persistent Q6_K Vision 64K default.
- RTX5090 runtime at this capture: the Q5_K_M Vision Candidate is loaded IDLE at 98,304 and passed the managed preflight. The already-open Goose Desktop process was not interrupted; close it completely before using the Candidate shortcut so process-only overrides take effect.

## Effective profiles

| Profile | Context tokens | Intended use |
|---|---:|---|
| Normal | 98,304 | 通常のコーディング。現在の標準 |
| VRChat | 65,536 | VRChat/Unity 関連作業 |
| Light | 32,768 | 軽量・応答重視の作業 |

全プロファイルの共通設定:

| Setting | Current value |
|---|---:|
| K cache | Q8_0 |
| V cache | Q8_0 |
| Flash Attention | ON |
| GPU offload | all 65 layers |
| MTP | ON |
| Max draft tokens | 2 |
| Reasoning budget | 8,192 |

管理用の機械可読レコードは `configs/current/qwen38-27b-uncensored-q6k.json` にあります。この JSON は状態記録であり、LM Studio へ直接インポートできることを保証するものではありません。

## Managed loader presets

Currentの起動BATは `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/` で管理します。

| Preset | Context tokens | Purpose |
|---|---:|---|
| 96K Normal | 98,304 | Current標準 |
| 64K VRChat | 65,536 | VRChat / Unity作業 |
| 32K Light | 32,768 | VRAM余裕・軽快さ優先 |

各BATは現在ロード中の全LM Studioモデルを解除してから、API Model ID `qwen3.8-27b-uncensored` で再ロードします。BATの登録は管理上の変更であり、この構築時には実行していません。

## Optional Jonathan Q6_K Vision profile

Currentと同じQ6_K本体へJonathanColetti公式F16 Vision projectorを組み合わせた、明示切替用Candidate profileを追加しました。通常Currentのモデル枠とAPI IDは変更せず、Vision用のmodel key `qwen3.8-27b-uncensored-vision-q6k`、API ID `qwen3.8-27b-uncensored-vision`を使用します。Q6_Kとprojectorは外部モデル領域のNTFSハードリンクで共有し、GGUFをGitへ保存していません。

| Context | Vision fixture | Generation | Prompt processing | MTP acceptance | Peak VRAM |
|---:|---:|---:|---:|---:|---:|
| 32,768 | 7/7 | 63.03 tok/s | 1,274.73 tok/s | 81.15% | 27,057 MiB |
| 65,536 | 7/7 | 63.34 tok/s | 1,251.68 tok/s | 81.90% | 28,339 MiB |
| 98,304 | 7/7 | 61.30 tok/s | 1,238.88 tok/s | 81.90% | 29,736 MiB |

64Kを通常のVision presetとして推奨します。96Kも画像認識と生成に成功しましたが、測定後のGPU残量は約2.87 GBで、他のGPU負荷との併用余裕が小さくなります。Kilo CLIは画像転送に成功して6/7です。goose CLI 1.46.0は画像をtext pathとして扱い失敗しました。goose Desktop 1.47.0は添付・custom Vision ID・画像付き送信まで確認しましたが、初回はLM Studioがtext-only instanceをロードしてHTTP 400となりました。Vision 64K明示ロード後の同一ID direct recoveryは正答しています。日常起動はmanaged preflight付き`Goose Vision 64K`ショートカットへ統一し、text-only instanceの暗黙選択を避けます。Desktopでの画像付き成功再送は引き続きpending、Zoo Codeは未実施です。詳細は`benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`を参照してください。

## Recommended 96K Goose Candidate

JonathanColetti Q5_K_Mと同じ公式F16 Vision projectorを組み合わせた独立Candidateを追加しました。Current/Q6_K model枠、API ID、loader、永続Goose configは上書きしていません。

| Item | Q5_K_M Candidate | Same-condition Q6_K control |
|---|---:|---:|
| Selected MTP | OFF | ON |
| 96K median generation | 53.7446 tok/s | 60.8219 tok/s |
| 96K Peak VRAM | 25,876 MiB | 29,720 MiB |
| Difference | 11.6% slower | 3,844 MiB more Peak VRAM |

Q5_K_M / MTP ONは45.5164 tok/s・27,265 MiB・acceptance 78.2548%で、OFFより遅くVRAMも多いため採用しません。MTP OFFの96Kでは予約420 MiB差引後6,311 MiB / 約6.16 GiBのeffective headroomを保持し、70,081-token入力、direct Vision 7/7、Tool Calling、Goose Agentic Coding 10/10に成功しました。Reasoning Budget 8,192はQ5と同条件Q6の双方が最終回答前に上限へ達したため未解決です。

デスクトップの`Goose Q5KM Vision 96K Candidate`は、Gooseを閉じた状態で実行します。LM Studioの98,304 contextを検査し、Goose子プロセスだけへ`GOOSE_CONTEXT_LIMIT=90112`、`GOOSE_MAX_TOKENS=16384`、compact threshold 0.3を渡します。既存`Goose Vision 64K`は従来どおりQ6_K Vision用です。

LM Studio loaderと通常のGoose shortcutを別々に使う運用向けに、永続client設定だけを切り替える`Set-Goose-Profile-Q5KM-Vision96K.bat`と、Q6_K 64Kへ戻す`Set-Goose-Profile-Q6K-Vision64K.bat`を追加しました。selectorはGoose完全終了時だけ動作し、変更前configをrepository外へbackupします。モデルloadやGoose起動は行わず、repository Currentも変更しません。

## Existing measurements

| Mode | Generation speed | MTP acceptance | Evidence |
|---|---:|---:|---|
| MTP ON | 63.92 tok/s | approximately 40–50% | user-provided measured result |
| MTP OFF | 48.30 tok/s | not applicable | user-provided measured result |

同条件と仮定した単純差分では、MTP ON は MTP OFF より 15.62 tok/s、約 32.3% 高速です。元測定のプロンプト、サンプリング、試行回数、VRAM 値は未記録のため、この差分は既存結果の整理値であり、再現性を保証する比較結果ではありません。

## Stability and capacity

- 96K context: 安定運用済み。
- 128K + Q8 KV: モデル実行で VRAM が圧迫され、Windows 操作がカクついたため常用しない。
- 128K は「不可能」ではなく「日常運用の安定条件を満たさない」と扱う。
- text-only Currentの定量的なVRAM baseline/peak/deltaは未記録。Vision profileは32K/64K/96Kのidle/peakを記録済み。

## Evaluated HauhauCS candidate

`HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` の比較を完了しました。Candidateとして記録を残しますが、Currentへの昇格は推奨しません。

- Verified locally: Vision with separate BF16 projector, embedded MTP, direct Tool Calling, Zoo Code image attachment and Agentic Coding
- Adoption status: not adopted
- Quantization/file selection: Q6_K_Pを第一候補として測定し、64K/96KのVRAM余裕不足によりQ5_K_Pもfallback測定
- Hugging Face revision: `993a5971fda8f30dd1b7eb2654792ba4415c7460`
- LM Studio compatibility: 0.4.21 / llama.cpp CUDA 2.29.1で確認。FastMTP custom patchは未導入・未検証
- Key result: Q5_K_Pは96Kを安定生成できたがCurrentより約23%遅く、Candidateのembedded MTPは固定fixtureで速度向上なし
- Blocking regression: Reasoning Budget 8192でQ6_K_Pが上限を使い切り、最終回答へ到達しなかった
- Full result: `benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md`

評価後、LM StudioをCurrentの96K/MTP ONへ戻し、Zoo Codeの選択を`default` Current profileへ戻しました。Candidateのモデルファイルとprofileは比較用に残しています。

## RTX3090 Remote LLM Node

`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`を、RTX5090 Currentから分離したLAN Remote Nodeとして管理します。これは別のCurrent昇格ではなく、メインPCのZoo Codeから必要時に選択する補助実行先です。

| Item | Value |
|---|---|
| GPU / RAM | RTX 3090 24,576 MiB + RTX 3060 12,288 MiB / 31.93 GiB |
| GPU links | RTX 3090 Gen3 x16 / RTX 3060 Gen3 x4 |
| LM Studio | 0.4.21.0 / CLI commit `71bd99c` |
| Base URL | `http://192.168.0.104:1234` |
| Server | `0.0.0.0:1234`; main-PC API reachability verified |
| Firewall | Inbound TCP 1234 / Private / LocalSubnet / Edge Block / LM Studio executable scoped |
| BLUE Operational Default | JonathanColetti Q6_K Vision / `qwen3.8-27b-uncensored-vision-blue` / 64K / Q8_0 / dual GPU |
| Primary Power Limit | RTX3090 259W / RTX3060 170W |
| Performance override | RTX3090 370W / RTX3060 170W; explicit loader selection only |
| Fallback | JonathanColetti Q4_K_M / `qwen3.8-27b-uncensored@q4_k_m` / 32K |
| Optional Vision candidate | HauhauCS Aggressive Q4_K_P / `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp` |
| Operational context | 65,536; 80K–88K are capacity evidence only |
| Excluded Q6_K context | 96K/128K; Shared-memory gate FAIL |

同一条件の32K MTP ON中央値はJonathanが36.31 tok/s・19,737 MiB、HauhauCSが35.47 tok/s・20,867 MiBでした。64Kは両方とも3回連続生成に成功しましたが、idle free VRAMはJonathan約3,238 MiB、HauhauCS約2,188 MiBのため、他モデルとの同時ロードを避けて使用します。MTP acceptanceはそれぞれ73.91%と72.80%です。

両モデルともdirect APIのVision fixtureは7/7でした。HauhauCSはZoo Codeから画像添付できたものの、Code modeが画像回答へ進まずtool loopになったため、画像認識は現時点ではLM Studioまたはdirect APIを使用します。Agentic Coding fixtureは両モデルとも完遂しましたが、JonathanのZoo Code所要時間は意図しないHauhauCS 8K自動ロードとの競合で汚染されたため比較値にはしません。

Kilo Code 7.4.22にはBLUE専用OpenAI-compatible providerを追加し、Standard16KとLong32Kを選択可能にしました。既定modelはRTX5090 localhostのままです。Long32K aliasのKilo実生成は最初のstepで29,001 output tokensに達し、16K client limitがないことを確認しました。終了後にKiloが自動継続/要約ターンへ入る挙動は注意事項です。Zoo Codeは正式な保存profile schemaを推測せず、GUIでのBLUE profile追加をpendingとします。切替後は新しいtaskを開始し、`lms ps`で対象モデル1個・意図したcontext・parallel 1を確認します。

Q6_K Visionは64K/Q8_0/dual GPUをOperational Defaultへ採用しました。64KはShared 3.281 GiB、Shared gate margin 0.719 GiB、Dedicated headroom合計9,720 MiBです。80K/84K/88KもPASSしましたがmarginが0.469/0.407/0.343 GiBまで縮むため採用しません。96K Q8はShared 5.021 GiB、128K Q8は8.065 GiB、128K F16は15.044 GiBでFAILです。64K F16はQ8と同速でDedicated headroomが1,494 MiB少ないため、Q8を選びました。

64K short runは26.13 tok/s、MTP acceptance 79.41%。Vision fixtureは7/7、33.60 tok/sです。Long32K output profileはnative APIで30,803 tokensを自然完了し、Kilo実経路でも29,001 tokensを生成しました。Standard16K / Long32KはPower Limitから独立したclient profileです。

同一64K設定の370W→259W→370W A/Bを行い、259WはText -4.43%、Vision -4.97%、Long-prompt processing -6.45%、Sustained -3.27%でした。一方、Sustained dual-GPU平均電力は-14.23%、RTX3090 peak temperatureは-4C、tok/s per GPU wattは+12.78%でした。この結果からRTX3090 259WをPrimary Operational、370Wを明示的Performance overrideへ変更し、RTX3060は170Wを維持します。local/MAIN remote loaderはGPU名・PCI Bus IDを照合し、UUID指定でPower Limitを設定・検証してからロードします。Q4_K_M 32K fallback回帰後、終了状態をQ6_K Vision 64K / 259Wへ復帰しました。詳細は`benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`、Power A/Bは`benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`、Shared原因調査は`research/2026-08-24-blue-shared-gpu-memory-investigation.md`を参照してください。

Identity、Firewall backup、モデルartifact、context別実測は`profiles/RTX3090-Remote/`、詳細比較は`benchmarks/results/2026-08-20-rtx3090-remote-node.md`を正とします。Remote NodeのidentifierはRTX5090 localhost CurrentのAPI IDを流用しません。

## Next decision

1. JonathanColetti Q6_Kを唯一のCurrentとして維持する。
2. Gooseで64K以内なら既存Q6_K Vision 64K、64Kを超える可能性がある作業はQ5_K_M Vision 96K Candidateを明示選択する。
3. Q5_K_M 96KはMTP OFFで運用し、実使用の品質、マウス応答性、長い同一turn tool loop、Desktop画像添付を追加観察する。自動昇格しない。
4. HauhauCS Aggressiveは比較履歴として保持する。
5. BLUEはJonathan Q6_K Vision / 64K / Q8_0 / dual GPU / RTX3090 259WをPrimary Operational Defaultとし、370WをPerformance override、Q4_K_M / 32Kをfallbackとして保持する。
6. HauhauCS Balanced-MTP-GGUFが実際に公開された場合、同じfixtureで再評価してから昇格可否を判断する。
