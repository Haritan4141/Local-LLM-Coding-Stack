# Changelog

重要な管理構造、設定、ベンチマーク、モデル選定の変更を記録します。アプリの自動生成ログではなく、人が確認した判断履歴です。

## [Unreleased]

### Added

- JonathanColetti公式`vision-f16` projector（927,606,912 bytes）をHugging Faceの固定revisionから外部cacheへ取得し、SHA-256を検証。既存Q6_KとprojectorをNTFSハードリンクで共有する独立LM Studio Vision枠を追加し、22.43 GBのモデル本体を複製していない。
- API ID `qwen3.8-27b-uncensored-vision`、Q8_0/Q8_0、full offload、Flash Attention ON、embedded MTP draft 2、parallel 1で32K/64K/96Kを測定。固定PNGを全contextで7/7認識し、速度・MTP acceptance・VRAMを`benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md`へ記録。
- Jonathan Q6_K VisionのCandidate profile、upstream/hash調査、32K/64K/96K managed loader、Kilo用の独立Vision model entryを追加。loader helperを再現可能にするため`@lmstudio/sdk` 1.5.0をrepository dependencyとして固定。
- goose Desktop 1.47.0でpaperclip添付、thumbnail、custom Vision ID、画像付きrequest送信を確認。初回はLM Studioがtext-only instanceを暗黙選択してHTTP 400となったため、Vision 64K managed loader後に`lms ps`の`vision = true`を確認するpreflightを必須化。同一IDのdirect recoveryは固定PNGのerror codeを正答したが、Desktop成功再送は未完了として条件付きに留めた。
- Vision 64Kの全managed load fieldをSDKで検査する`Test-ManagedModel.mjs`と、必要時だけ安全にreloadしてgooseを起動するPowerShell/BAT launcherを追加。デスクトップへ`Goose Vision 64K.lnk`を作成した。
- `pc5700x / DESKTOP-L9HAM1G / RTX 3090 24 GB`を、RTX5090 Currentから分離したRemote LLM Nodeとしてprofile登録。
- LM Studioを`192.168.0.104:1234`でLAN利用できるようにし、Private + LocalSubnet + TCP 1234 + Edge Block + LM Studio実行ファイル限定のInbound ruleを追加。変更前Firewallをnode側へバックアップ。
- RTX3090用Jonathan Q4_K_MとHauhauCS Aggressive Q4_K_PのCandidate profile、upstream revision/size/checksum/量子化選定調査を追加。
- RTX3090用の32K/64K managed loader、モデル別README、Zoo Code profile `RTX3090 Jonathan Q4KM` / `RTX3090 Hauhau Q4KP`を追加。
- RTX3090上で32K/64K、MTP ON/OFF、VRAM、prompt processing、Reasoning 8192、direct Tool Calling、Zoo Code Agentic Coding、Visionを比較し、`benchmarks/results/2026-08-20-rtx3090-remote-node.md`へ記録。
- RTX5090 loaderのディレクトリ名へ量子化を明記し、BAT名を`<Model-Identifier>_<Context>K.bat`形式へ統一。用途語`Normal`、`VRChat`、`Light`はファイル名から除外。
- HauhauCS Aggressive-MTPのHugging Face revision、全quant/size、checksum、Vision projector、FastMTP patch要件をダウンロード前スナップショットとして記録。
- Candidate Q6_K_P、BF16 mmproj、VRAM fallback Q5_K_PをLM Studio外部モデル領域へ導入し、サイズとSHA-256を検証。
- Q6_K_P用とQ5_K_P fallback用に、それぞれ分離した96K Normal / 64K VRChat / 32K Light loader BATとREADMEを追加。
- 固定API speed、multi-file Agentic Coding、Vision UI fixtureと測定helperを追加。
- Repository検証をGit管理外のraw/log JSONから分離し、管理対象JSONとモデル重量混入を正しく監査するよう修正。
- Current / Candidateの32K・64K・96K、MTP ON/OFF、VRAM、prompt processing、Reasoning、Tool Calling、Zoo Code、Vision結果を追加。
- 評価結果を `benchmarks/results/2026-08-20-hauhaucs-aggressive-ab.md` に記録。
- Current Qwen3.8 JonathanColetti用の96K Normal / 64K VRChat / 32K Light LM Studio loader BATを追加。
- RTX 5090配下で今後のモデルごとにloaderディレクトリを分離する管理規約を追加。
- 各BATの用途、`lms unload --all` の副作用、共通LM Studio/Zoo Code設定、GGUF非保存方針をREADMEへ記録。

### Decision

- Jonathan Q6_K text-onlyを唯一のCurrentとして維持する。Visionは同一Q6_Kの明示切替Candidate/runtime profileとして扱い、通常は64Kを推奨、96Kは他のGPU負荷を止めた長context用途に限定する。
- RTX5090のgoose DesktopだけはJonathan Q6_K Vision 64Kをapp-global既定runtimeとして常用する。これはclient固有のOperational Defaultであり、Vision profileのCurrent昇格ではない。
- HauhauCS Aggressive Q6_K_P/Q5_K_PはCurrentへ昇格しない。
- Visionは実用上の利点だが、Q6_K_Pの64K/96K VRAM不足、Q5_K_Pの速度低下、Candidate embedded MTPの逆効果、Reasoning 8192の最終回答未到達を優先して判断。
- JonathanColetti Q6_KをCurrentとして維持し、将来のBalanced版を待つ。
- RTX3090ではJonathan Q4_K_M / 32KをRemote coding defaultとする。64Kは単独長context作業だけに使い、96Kは安全余裕不足のためloaderを作成しない。
- RTX3090 HauhauCS Q4_K_Pはoptional Candidateとして保持する。direct API Visionは7/7だがZoo Code Code modeの画像経路はtool loopとなるため、画像認識はLM Studio/direct APIを優先する。

### Runtime impact

- RTX5090評価終了時はJonathan Q6_K Vision / 64K / Q8_0 K+V / full GPU offload / embedded MTP 2 / parallel 1をロード。通常Currentのモデル枠、API ID、loaderは保持しており、BATで明示的に戻せる。
- Kilo Globalはsibling Vision entryを追加したまま既定text modelを維持。goose app-global modelはユーザー選択済みVision IDを維持し、現行config SHAは`F25BA3CF...269B1F86`。既知text baselineとの差はVision model選択と`0.30`→`0.3`の同値表記だけで、Secret file、MCP、OAuthは変更していない。Zoo Code設定も変更していない。
- `Goose Vision 64K` launcherのpreflightは、単一Vision instance、65,536 context、full offload、Flash Attention、Q8_0/Q8_0、KV GPU offload、MTP draft 2、parallel 1でPASS。正しいruntimeは再ロードせず、active / queued predictionを中断しない。
- RTX3090 nodeのLM Studio server bindをlocalhostからLAN待受へ変更し、TCP 1234だけをLAN限定で許可。RTX5090 runtime、Current model、localhost Zoo Code profileは変更していない。
- RTX3090評価終了時はJonathan Q4_K_M / 32K / Q8_0 K+V / full GPU offload / embedded MTP 2 / parallel 1へ設定。メインPCZoo Codeのactive profileは`default`へ復帰。
- Zoo Code切替時に旧conversationがHauhauCS 8K / parallel 4を暗黙ロードしてVRAM競合したため、Remote profile切替後は新規taskを開始し、`lms ps`で対象モデル1個・意図したcontext・parallel 1を確認する運用規則を追加。
- Candidate用Per-model DefaultsとZoo Codeの分離profileを追加。Currentのモデルファイル、設定、loaderは上書きしていない。
- 評価中のみAPI IDを分けてモデルを切り替えた。完了後、Zoo Codeは`default` Current profile、LM StudioはJonathanColetti Q6_K / 98,304 context / embedded MTP ONへ復帰確認済み。
- Q6_K_P、Q5_K_P、mmprojはリポジトリ外のLM Studioモデル領域にのみ存在する。FastMTP sidecar/custom patchは未導入。

### Follow-up

- Zoo Codeの画像mentionと、managed startup後のgoose Desktop画像付き成功再送を次回sessionで完了する。goose CLI 1.46.0のWindows path指定は画像を送信せずtext扱いとなるため、現時点ではDesktop paperclip添付と`Goose Vision 64K` launcherを使用する。
- Balanced-MTP-GGUFの公開を確認できた場合のみ、同じfixtureで新しいCandidate評価を開始する。

## [2026-08-20] - Initial management baseline

### Added

- VS Code + Zoo Code + LM Studio + local LLM 専用の管理構造を作成。
- `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` Q6_K を Current として登録。
- 32K / 64K / 96K の context profile と Q8_0 KV、Flash Attention、65-layer offload、MTP 設定を記録。
- MTP ON 63.92 tok/s、MTP OFF 48.30 tok/s、acceptance 約 40–50% の既存実測を baseline として記録。
- 128K + Q8 KV は Windows 操作性を損なうため常用しないという運用制約を記録。
- HauhauCS Aggressive-MTP を Candidate、将来の Balanced-MTP を Watch として登録。
- モデル本体、LM Studio データ、raw logs をリポジトリ外に保つ除外規則を追加。
- ベンチマーク記録生成とリポジトリ検査の PowerShell スクリプトを追加。

### Runtime impact

- なし。この変更は管理ファイルの新規作成のみで、LM Studio、Zoo Code、VS Code、モデル配置、ドライバー設定は変更していない。
