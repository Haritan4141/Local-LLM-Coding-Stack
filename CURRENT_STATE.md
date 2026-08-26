# Current State

State captured: 2026-08-25 (Asia/Tokyo)

## Operational status

- Current model: `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF`
- Variant: `Q6_K`
- Status: `Current / stable`
- Hardware: NVIDIA GeForce RTX 5090 32 GB
- Client path: VS Code -> Zoo Code -> LM Studio -> local model
- Max concurrent predictions: 1
- Repository lifecycle Current remains API ID `qwen3.8-27b-uncensored`; its model files and loader presets were not overwritten.
- BLUE currently has its independent Recommended Production profile loaded and IDLE: Jonathan Q5_K_M Vision, API ID `qwen3.8-27b-uncensored-vision-q5km-blue`, 98,304 context, Q8_0/Q8_0, RTX3090→RTX3060 priority order, embedded MTP ON / draft 3, eval batch 1024, effective ubatch 512, parallel 1, Vision true, RTX3090 259W / RTX3060 170W. This Remote Node role does not promote the Candidate to repository Current or replace the RTX5090 Current.
- RTX5090 Recommended Production / Operational Profile: Jonathan Q5_K_M Vision, API ID `qwen3.8-27b-uncensored-vision-q5km`, 98,304 context, Q8_0/Q8_0, MTP draft 3, eval batch 1024, effective ubatch 512, parallel 1, mmap+mlock, PL 402W. Its Goose profile keeps the 90,112 client context limit, 16,384 max output, and 0.3 compact threshold.
- `00-Goose-Daily-Profiles.bat` is the integrated daily Goose entry for MAIN/BLUE Stable, Turbo and Quality Reference. It calls the existing canonical runtime wrapper, cross-checks runtime/provider/model/context/output/endpoint, applies the supported Goose client profile, and launches Goose Desktop. Stable/Quality use LM Studio plus persistent profiles; Turbo uses the built-in `openai` provider with process-local settings and leaves persistent Goose configuration unchanged. Stable keeps 16K/32K output choices, Turbo is qualified only at 16K, and Quality uses Q6 Vision 64K / 32K.
- Q6_K Vision profiles remain fully supported: Balanced is the Quality/Performance Reference, Safe is the permanent known-good fallback, and Coding-Fast is explicit-only. The existing `Goose Vision 64K` Safe-preflight shortcut remains available.
- RTX5090 runtime at this capture: Jonathan Q5_K_M Vision 96K Recommended Production loaded as the sole model and IDLE; repository lifecycle Current remains unchanged.
- RED `pc7600x` is now an independent AMD Remote Node Candidate: Jonathan IQ4_XS, API ID `qwen3.8-27b-uncensored-iq4xs-red`, 98,304 context, Q4_0/Q4_0, ROCm 2.29.1, MTP2, batch512, parallel1, Vision false. MAINから`192.168.0.103:1234`へ到達し、Goose simple inference / Developer tool pathを確認済みです。

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

Q6 Vision 64KはQuality/Performance Referenceとして推奨します。既存64K loaderは永久Safeとして保持します。96Kも画像認識と生成に成功しましたが、測定後のGPU残量は約2.87 GBで、他のGPU負荷との併用余裕が小さくなります。Kilo CLIは画像転送に成功して6/7です。goose CLI 1.46.0は画像をtext pathとして扱い失敗しました。goose Desktop 1.47.0は添付・custom Vision ID・画像付き送信まで確認しましたが、初回はLM Studioがtext-only instanceをロードしてHTTP 400となりました。Vision 64K明示ロード後の同一ID direct recoveryは正答しています。既存`Goose Vision 64K` one-click startupは既知GoodのSafe preflightを維持し、Q5 Recommended/Q6 Balanced/Coding-FastはProfile Selectorから明示選択します。Desktopでの画像付き成功再送は引き続きpending、Zoo Codeは未実施です。詳細は`benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`を参照してください。

### Qwen3.8 Vision 64K Operational Profiles

| System / profile | MTP draft | KV K/V | Eval batch | Effective ubatch | Power | Role |
|---|---:|---|---:|---:|---|---|
| RTX5090 Q5_K_M Recommended 96K | 3 | Q8_0/Q8_0 | 1024 | 512 | 402W | **Recommended Production** |
| RTX5090 Q6_K Safe 64K | 2 | Q8_0/Q8_0 | 2048 | 512 | 402W | permanent known-good fallback |
| RTX5090 Q6_K Balanced 64K | 4 | Q8_0/Q8_0 | 2048 | 512 | 402W | Quality/Performance Reference |
| RTX5090 Q6_K Coding-Fast 64K | 4 | Q4_0/Q4_0 | 2048 | 512 | 402W | explicit coding-speed selection only |
| BLUE Q5_K_M Recommended 96K | 3 | Q8_0/Q8_0 | 1024 | 512 | 259W/170W | **Recommended Production** |
| BLUE Q6_K Safe 64K | 2 | Q8_0/Q8_0 | 512 | 512 | 259W/170W | permanent known-good rollback |
| BLUE Q6_K Balanced 64K | 3 | Q8_0/Q8_0 | 1024 | 512 | 259W/170W | Quality/Performance Reference |
| BLUE Q6_K Coding-Fast 64K | 3 | Q4_0/Q4_0 | 512 | 512 | 259W/170W | explicit coding-speed selection only |

Except for the explicitly marked Q5 96K rows, these profiles use context 65,536. All use Flash Attention ON, full GPU offload, Vision true, and parallel 1. MAIN retains its existing mmap/mlock behavior; BLUE uses mmap OFF and priority-order RTX3090→RTX3060. The existing BLUE Q6 370W Performance override remains separate; no Q5 370W loader exists. Q4 fixture-external quality equivalence is not established. MAIN Q5 finalization is in `benchmarks/results/2026-08-25-rtx5090-q5km-vision-96k-production.md`; BLUE Q5 qualification is in `benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`; Q6 Phase 1/1.5 evidence remains in `benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`.

## RTX5090 Q5_K_M Vision 96K Recommended Production

JonathanColetti Q5_K_Mと公式F16 Vision projectorを組み合わせた独立profileを、RTX5090のRecommended Production / Operational Profileへ昇格しました。Repository lifecycleはCandidateのままです。Current/Q6_K model枠、Q6 loader、API IDを上書き・削除していません。

| Item | Final value |
|---|---:|
| Context / KV | 98,304 / Q8_0-Q8_0 |
| Selected MTP / batch / ubatch | draft 3 / 1024 / 512 |
| Text / Coding / Vision / Long generation | 47.02 / 63.08 / 59.98 / 53.98 tok/s |
| MTP-sweep 4-workload geomean / acceptance | 55.18 tok/s / 84.06% |
| Load Dedicated / raw headroom | 26,432 / 6,175 MiB |
| Effective headroom after 420 MiB reserve | 5,755 MiB / about 5.62 GiB |
| Production generation Peak / Shared peak | 26,498 MiB / 0.569 GiB |

最終MTP sweepではdraft 3がOFF比でText -8.88%のtradeoffを示す一方、Coding +24.03%、Vision +16.05%、Long +15.55%、geomean約+10.97%となりました。draft 4はgeomean、acceptance、VRAMでdraft 3を上回らず、OFF sentinel driftは全workload 0.5%未満でした。batch 1024/2048の固有nonce付きLong Promptは2,132.05/2,129.33 tok/s、TTFT 11.3648/11.3727秒で、余裕を優先し1024を採用しました。

最終設定でVision 7/7を3正式run、69,139-token input、exact Tool Calling、Goose Agentic Coding 10/10に成功しました。今回の実用fixtureではPromotionを妨げる品質差を観測していない、という限定した結論であり、Q5とQ6の完全同品質は主張しません。Reasoning Budget 8,192の過去課題はQ5と同条件Q6の双方で最終回答前に上限へ達したため、量子化固有と断定せず未解決履歴として保持します。

互換性のため既存名を保持するデスクトップの`Goose Q5KM Vision 96K Candidate`は、Gooseを閉じた状態で実行します。LM Studioの98,304/Q8/MTP3/batch1024を検査し、Goose子プロセスだけへ`GOOSE_CONTEXT_LIMIT=90112`、`GOOSE_MAX_TOKENS=16384`、compact threshold 0.3を渡します。既存`Goose Vision 64K`は従来どおりQ6_K Vision用です。

`00-Goose-Daily-Profiles.bat`は、runtime selectorとGoose profile selectorを統合したone-click入口です。MAIN/BLUE Q5 Stableは`96K / 16K`または`96K / 32K`、Turboは`96K / 16K`、MAIN/BLUE Q6 Quality Referenceは`64K / 32K`を選択できます。Goose完全終了をruntime変更前に確認し、canonical wrapperの実行後にprovider/model/endpointをcross-checkしてからGoose Desktopを起動します。Stable/Qualityの変更前configと必要時のBLUE custom-provider JSONはrepository外へbackupし、Turboは永続configを変更しません。既存個別selectorは互換入口として保持し、repository Currentも変更しません。2026-08-26の実機回帰ではMAIN/BLUE全profileのshort smokeと17,936-token MAIN Turbo入力を確認し、終了後は両PCをQ5 Stable 96K、idle/queued0へ復旧しました。詳細は`benchmarks/results/2026-08-26-goose-daily-profiles-integration.md`です。

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
| BLUE Recommended Production | JonathanColetti Q5_K_M Vision / `qwen3.8-27b-uncensored-vision-q5km-blue` / 96K / Q8_0 / MTP3 / batch1024 / dual GPU |
| Quality/Performance Reference | JonathanColetti Q6_K Vision / `qwen3.8-27b-uncensored-vision-blue` / 64K / Q8_0 / MTP3 / batch1024 / dual GPU |
| Primary Power Limit | RTX3090 259W / RTX3060 170W |
| Performance override | RTX3090 370W / RTX3060 170W; explicit loader selection only |
| Fallback | JonathanColetti Q4_K_M / `qwen3.8-27b-uncensored@q4_k_m` / 32K |
| Optional Vision candidate | HauhauCS Aggressive Q4_K_P / `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp` |
| Operational context | Q5_K_M 98,304 |
| Excluded Q6_K context | 96K/128K; Shared-memory gate FAIL; this does not apply to Q5_K_M |
| DFlash2 toolchain readiness | Build Tools 2022 17.14.39 / MSVC v143 / Windows SDK 26100 / CMake 3.31.6 / Ninja 1.12.1 / CUDA 12.9 nvcc 12.9.41 / sm_86; no build started |

同一条件の32K MTP ON中央値はJonathanが36.31 tok/s・19,737 MiB、HauhauCSが35.47 tok/s・20,867 MiBでした。64Kは両方とも3回連続生成に成功しましたが、idle free VRAMはJonathan約3,238 MiB、HauhauCS約2,188 MiBのため、他モデルとの同時ロードを避けて使用します。MTP acceptanceはそれぞれ73.91%と72.80%です。

両モデルともdirect APIのVision fixtureは7/7でした。HauhauCSはZoo Codeから画像添付できたものの、Code modeが画像回答へ進まずtool loopになったため、画像認識は現時点ではLM Studioまたはdirect APIを使用します。Agentic Coding fixtureは両モデルとも完遂しましたが、JonathanのZoo Code所要時間は意図しないHauhauCS 8K自動ロードとの競合で汚染されたため比較値にはしません。

Kilo Code 7.4.22にはBLUE専用OpenAI-compatible providerを追加し、Standard16KとLong32Kを選択可能にしました。既定modelはRTX5090 localhostのままです。Long32K aliasのKilo実生成は最初のstepで29,001 output tokensに達し、16K client limitがないことを確認しました。終了後にKiloが自動継続/要約ターンへ入る挙動は注意事項です。Zoo Codeは正式な保存profile schemaを推測せず、GUIでのBLUE profile追加をpendingとします。切替後は新しいtaskを開始し、`lms ps`で対象モデル1個・意図したcontext・parallel 1を確認します。

Q5_K_M Vision 96K/Q8_0/dual GPUはMTP3 / batch1024でStrict gate、Text/Coding/Vision/Tool Calling、76,880-token入力をPASSし、BLUE Recommended Productionへ昇格しました。ロード時Shared 3.515 GiB、長文脈run中最大3.527 GiB、Dedicated headroomはRTX3090 6,706 MiB + RTX3060 3,409 MiBです。fresh Q6 Balanced比でText generation +12.5%、Coding +3.3%、Vision +7.5%、Long prompt processing +5.7%、Long TTFT -5.4%、Dedicated peak約754 MiB削減でした。

Q6_K Vision 64K/Q8_0/dual GPUのMTP3 / batch1024はQuality/Performance Referenceとして保持し、既存MTP2 / batch512はSafeです。Q6 64KはShared 3.281 GiB、Dedicated headroom合計9,720 MiBでした。Q6の80K/84K/88Kはcapacity evidenceのみ、96K/128KはShared gate FAILです。

64K short runは26.13 tok/s、MTP acceptance 79.41%。Vision fixtureは7/7、33.60 tok/sです。Long32K output profileはnative APIで30,803 tokensを自然完了し、Kilo実経路でも29,001 tokensを生成しました。Standard16K / Long32KはPower Limitから独立したclient profileです。

同一64K設定の370W→259W→370W A/Bを行い、259WはText -4.43%、Vision -4.97%、Long-prompt processing -6.45%、Sustained -3.27%でした。一方、Sustained dual-GPU平均電力は-14.23%、RTX3090 peak temperatureは-4C、tok/s per GPU wattは+12.78%でした。この結果からRTX3090 259WをPrimary Operational、370Wを明示的Performance overrideへ変更し、RTX3060は170Wを維持します。local/MAIN remote loaderはGPU名・PCI Bus IDを照合し、UUID指定でPower Limitを設定・検証してからロードします。Q4_K_M 32K fallback回帰後、終了状態をQ6_K Vision 64K / 259Wへ復帰しました。詳細は`benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`、Power A/Bは`benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`、Shared原因調査は`research/2026-08-24-blue-shared-gpu-memory-investigation.md`を参照してください。

Identity、Firewall backup、モデルartifact、context別実測は`profiles/RTX3090-Remote/`、詳細比較は`benchmarks/results/2026-08-20-rtx3090-remote-node.md`を正とします。Remote NodeのidentifierはRTX5090 localhost CurrentのAPI IDを流用しません。

## RX9070XT Remote LLM Node

`pc7600x / DESKTOP-LMB720F / 192.168.0.103`をRED AMD Remote Nodeとして分離管理します。LM Studio 0.4.21+2へAMD ROCm 2.29.1を追加・選択し、Vulkan 2.29.1はfallbackとして保持しました。

| Item | Value |
|---|---|
| GPU / RAM | RX 9070 XT 16 GB (`gfx1201`) / 63.09 GiB |
| Base URL | `http://192.168.0.103:1234` |
| Firewall | TCP 1234 / Private / LocalSubnet / Edge Block / LM Studio executable |
| Model | Jonathan IQ4_XS / `qwen3.8-27b-uncensored-iq4xs-red` / Vision false |
| Recommended Candidate | 96K / Q4_0-Q4_0 / MTP2 / batch512 / parallel1 |
| Fallback | 同一model 64K / Q4_0-Q4_0 |

96KはDedicated 14.816 GiB / Shared 3.542 GiB、生成peakは14.845 / 3.570 GiBです。70,082-token入力を3/3回収で完走しましたがTTFTは246.93秒で、長文収容と即応性を区別します。MTP2は36.762 tok/s median、OFFは29.664 tok/sで約23.9%向上しました。Shared依存のため、重いGPU workloadとの併用は避けます。

Goose Custom Provider `custom_lm_studio_rx9070xt_remote`を追加し、既定`active_provider: lmstudio`は変更していません。Desktop model switcherへ反映するにはGooseの完全終了・再起動が必要です。Managed loaderは`scripts/lmstudio/model-loaders/RX9070XT/Qwen3.8-JonathanColetti-IQ4XS/`です。

## Next decision

1. JonathanColetti Q6_Kを唯一のCurrentとして維持する。
2. RTX5090ではQ5_K_M Vision 96K / MTP3 / batch1024をRecommended Productionとして使用し、長い同一turn tool loopとdesktop responsivenessを継続観察する。
3. RTX5090 Q6_K Vision 64K Balanced/Safe/Coding-FastをReference/fallback/explicit-onlyとして保持し、deprecated扱いしない。
4. HauhauCS Aggressiveは比較履歴として保持する。
5. BLUEはJonathan Q5_K_M Vision / 96K / Q8_0 / MTP3 / batch1024 / dual GPU / RTX3090 259WをRecommended Productionとする。Q6 BalancedをQuality/Performance Reference、Q6 Safeをknown-good fallback、Q6 Coding-Fastと370Wを独立明示profileとして保持する。
6. REDはJonathan IQ4_XS / 96K / Q4_0 / ROCm / MTP2をRemote Node Candidateとして使用し、Shared 4 GiB gateと重いGPU workload非併用を維持する。必要時は64Kへ切り替える。
7. HauhauCS Balanced-MTP-GGUFが実際に公開された場合、同じfixtureで再評価してから昇格可否を判断する。
