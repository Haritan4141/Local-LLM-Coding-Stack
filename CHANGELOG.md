# Changelog

重要な管理構造、設定、ベンチマーク、モデル選定の変更を記録します。アプリの自動生成ログではなく、人が確認した判断履歴です。

## [Unreleased]

### Added

- MAIN RTX5090とBLUE RTX3090+RTX3060のGoose Turbo Output32Kを実機qualification。process-local `GOOSE_MAX_TOKENS=32768`がserver側`n_predict=32768`へ反映され、MAIN 17,100 / BLUE 17,183 output tokens、全連番、98,304 runtime context、完了後idle、永続Goose config SHA不変でPASSした。既存menu番号を維持して`[9] MAIN Turbo 96K / Output32K`と`[10] BLUE Turbo 96K / Output32K`を追加し、Output16Kを通常選択として保持する。
- RTX5090 MAIN、BLUE local、MAIN→BLUE remoteのDaily selectorへ`[4] Release`を追加。LM Studioのactive/queued prediction、Turbo `/slots`、managed PID/path/command/port、BLUE host/IPとMAIN tunnel ownershipをfail closedで検証し、idleなloaded modelまたは管理対象Turboだけを解放する。Windows PowerShell 5.1のtop-level slot arrayを明示展開し、実行ログをrepository外へ保存、失敗時は画面をpauseする。BLUE remoteでは管理対象tunnelも解放し、LM Studio server、Firewall、Power Limit、Goose設定、モデルファイルは変更しない。
- `00-Goose-Daily-Profiles.bat`をGooseの日常統合入口へ拡張。MAIN/BLUEのStable、Turbo、Quality Referenceについて、既存canonical runtime起動、provider/model/context/output/endpoint cross-check、Goose client設定、Goose Desktop起動までを一括実行する。Stable/QualityはLM Studioの永続profile、Turboは`openai` providerのprocess-local設定を使用し、Turbo 32Kは未qualificationのため追加しない。Goose起動中はruntime変更前にfail closedし、Cancelは無変更で終了する。
- MAIN/BLUEの統合Goose入口を実機regressionし、Stable、Turbo、Quality Referenceのmodel/provider/endpoint表示とshort smokeを確認。MAIN Turboでは17,936-token promptを`n_ctx_slot=98,304`、Goose client 90,112で処理し、`400 exceed_context_size`なし、`truncated=0`を確認した。終了後は両PCをQ5_K_M Vision 96K Stable、idle/queued0へ復旧し、Turbo process/tunnelと18080/18081 listenerを0にした。
- BLUE Goose custom providerを選ぶ際、既存provider名、OpenAI engine、`192.168.0.104:1234`のLAN endpoint、認証不要をfail closedで照合し、Q5 Stableと既存Q6 Referenceのmodel定義を両方保持する。異なるendpointや重複modelでは永続configを変更しない回帰testを追加。
- RED `pc7600x / DESKTOP-LMB720F / 192.168.0.103 / RX 9070 XT 16 GB`をAMD Remote LLM Node Candidateとして構築。LM Studio 0.4.21+2へROCm 2.29.1を追加・選択し、既存Vulkan 2.29.1はfallbackとして保持した。
- Jonathan公式IQ4_XS（15,309,039,008 bytes / SHA-256 `53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5`）をLM Studio外部領域へ導入。GGUFはGitへ保存していない。
- RED用96K/64K MAIN REMOTE loaderを追加。SSH Alias、hostname、IP、Private/LocalSubnet Firewall、ROCm/gfx1201、iGPU無効、artifact、active prediction、effective settings、Dedicated/Shared gateをfail closedで監査する。
- RED 96K/Q4_0/MTP2でMTP A/B、70,082-token入力、direct Tool Calling、Goose simple inference、Goose Developer toolを検証。Goose Custom Provider `custom_lm_studio_rx9070xt_remote`を追加し、RTX5090 localhost defaultは変更していない。
- managed model helperへ任意の`ws://` remote base URLを追加し、MAIN上の固定SDKからLAN LM Studioへ同じper-load設定とreadbackを適用可能にした。未指定時のlocalhost動作は維持する。
- RTX5090 Q5_K_M Vision 96KをMTP OFF/2/3/4/OFF sentinel、batch1024/2048、capacity、Text/Coding/Vision/69,139-token Long、exact Tool Calling、isolated Agentic Codingで最終qualification。MTP3/Q8/batch1024をRecommended Productionへ採用し、`benchmarks/results/2026-08-25-rtx5090-q5km-vision-96k-production.md`へcurated記録した。
- RTX5090 Q5 96K loaderとGoose preflightをMTP3/batch1024/mmap+mlockへ更新。Profile SelectorはQ5 Recommended、Q6 Balanced Reference、Q6 Safe、Q6 Coding-Fastの順に既存個別BATだけをCALLし、Q6 profileを削除・deprecated化していない。
- MAINへ公式Visual Studio Build Tools 2022 17.14.39、MSVC v143、Windows SDK 26100、CMake 4.4.2、Ninja 1.13.2を導入し、既存CUDA 12.9 nvccとRTX5090 `sm_120` compile/run smokeを検証。DFlash2 clone/build、Drafter download、server/18080、benchmarkは開始していない。
- BLUEへMAINのexact Jonathan Q5_K_M artifactを既存SMB経路で安全転送し、SHA-256一致後に独立LM Studio model key/API IDとして登録。既存projectorは同一SHAのNTFS hardlinkで再利用し、GGUF/projector/rawはGitへ保存していない。
- BLUE Q5_K_M Vision 96Kをunchanged Strict gate、MTP OFF/2/3/4、batch512/1024、Text/Coding/Vision/Long Prompt、Tool Calling、76,880-token入力、fresh Q6 Balanced comparisonでqualification。MTP3/Q8/batch1024をRecommended Productionへ採用し、curated結果を`benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`へ追加。
- Q5_K_M 96K local/REMOTE loaderを追加。identity、active prediction、GPU名+PCI Bus ID、Power Limit、effective config、Vision、IDLEに加え、combined `<4 GiB`とper-GPU `<=2 GiB`のShared gateをpost-loadでfail closed監査する。
- BLUE local/REMOTE selectorへQ5 Recommendedを先頭追加し、Q6 Balanced、Q6 Safe、Q6 Coding-Fast、Q6 370W Performanceの既存個別BATを削除・上書きせず保持。
- Q5 promotion後に公式Visual Studio Build Tools 2022 17.14.39のC++ workload、MSVC v143、Windows SDK 26100、CMake/Ninjaを`--norestart`でBLUEへ導入。cl 19.44、CMake 3.31.6、Ninja 1.12.1、既存nvcc 12.9.41、sm_86をDeveloper環境で確認し、DFlash2 clone/build等は開始していない。
- RTX5090とBLUEへQwen3.8 Vision 64KのSafe / Balanced / Coding-Fast個別loaderとselectorを追加。既存Safe loader、BLUE 370W Performance、Standard16K / Long32Kは変更せず独立維持した。BLUEにはlocal/REMOTE双方のBalanced/Coding-Fast launcherとREMOTE selectorを追加した。
- managed loader/helperを後方互換で拡張し、MTP draft 2/3/4、独立K/V Q8_0/Q4_0/F16、eval batchを明示指定・effective readbackできるようにした。未指定時は従来のdraft2/Q8/default batchを維持し、unsupported option/valueとF16/quantized mixed KVはfail closedする。ubatch設定機能は追加していない。
- Phase 1/1.5のRTX5090/BLUE結果、品質境界、Q4 caveat、実機profile switchingを`benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`へcurated記録した。
- RTX5090向けJonathanColetti Q5_K_M + official F16 Vision projectorを、独立model key/API ID `qwen3.8-27b-uncensored-vision-q5km`の96K Candidateとして外部LM Studio領域へ導入。固定revisionの本体/projectorサイズとSHA-256を検証し、GGUFはGitへ保存していない。
- Q5_K_M Visionの32K/64K/96K managed loader、Candidate profile、upstream調査、controlled benchmarkを追加。96KでMTP ON/OFF、同条件Q6_K control、VRAM/Shared、70,081-token入力、Vision 7/7、direct Tool Calling、Reasoning 8192、Goose multi-file Agentic Coding 10/10を記録。
- `Goose Q5KM Vision 96K Candidate`デスクトップショートカットを追加。98,304-token LM Studio runtimeをpreflightし、Goose子プロセスだけへ90,112 context limit、16,384 max output、compact threshold 0.3を渡す。永続Goose configと既存`Goose Vision 64K`は変更しない。
- 通常のGoose shortcutを使う手動運用向けに、永続client設定だけをQ5_K_M Vision 96Kへ切り替えるprofile selectorと、Q6_K Vision 64Kへ戻すselectorを追加。Goose起動中は拒否し、変更前configをrepository外へ日時付きbackupし、対象値を再検証する。LM Studio runtimeとGoose processは変更しない。
- BLUE Jonathan Q6_K Vision 64KへRTX3090 259W Primaryと370W Performance overrideの分離loaderをlocal/MAIN remoteの双方に追加。GPU indexを固定せず、GPU名・PCI Bus IDで一意照合したUUIDだけへPower Limitを設定・検証してからmanaged loadする。
- 370W→259W→370WのText/Vision/30.9K prompt/Sustained A/Bを`benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`へcurated記録。既存Standard16K / Long32K client profileはPower Limitから独立して維持。
- BLUE Q6_K Visionの既知Good Safe baselineとして64K / Q8_0 / RTX3090→RTX3060 priorityOrder / MTP 2 / parallel 1を採用し、identity、Power Limit、Vision、effective load config、両GPU利用を監査するlocal/REMOTE loaderを追加・実機検証。後続のPhase 1/1.5 integrationでOperational RecommendedだけをMTP3 / batch1024 Balancedへ更新した。
- Q8 capacityを64K/72K/80K/84K/88K/96K/128K、F16を64K/128Kで測定。80K～88KはPASSしたが安全余裕を優先し、96K/128KはShared gate FAILとして除外。Standard16KとLong32K（30,803 output tokens自然完了）、Vision 7/7を`benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`へ記録。
- Kilo Codeへ既存localhost defaultを変えずBLUE Standard16K / Long32K provider aliasesを追加。Kilo 7.4.22のmodel listingに加え、Long32K実経路で29,001 output tokensのgeneration stepを完了し、16K client limitがないことを確認。完了後の自動継続/要約ターンも注意事項として記録。
- 88K→96KのShared GPU Memory不連続増加を読み取り監査。per-GPU FB/BAR1/WDDM counters、P2P不可、auto-fit警告、bufferログの限界、Sysmem Fallbackの未確認点を`Observed / Inferred / Unknown`で`research/2026-08-24-blue-shared-gpu-memory-investigation.md`へ記録。
- Jonathan Vision Q6_KをRTX5090、RTX3090単独、RTX3090+RTX3060で同一native API・8K・F16 KV・mmap OFF条件により36正式run比較。raw成果物はリポジトリ外へ保持し、curated結果を`benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`へ追加。
- BLUEの現在ハードウェアをRTX3090 24GB + RTX3060 12GBへ同期し、3090 Gen3 x16 / 3060 Gen3 x4、合計36GB、GPU別VRAM・利用率・電力・温度をnode profileへ記録。
- 再生成可能な標準ライブラリのみのbenchmark harnessを外部作業ディレクトリへ配置し、Text/Vision、MTP OFF/ON、capacity strict判定、MTP acceptance、TTFT、prompt速度、1秒GPU/RAM telemetry、JSON/CSV/Markdown集計を保存。
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

- RED Recommended CandidateをJonathan IQ4_XS / 96K / Q4_0-Q4_0 / ROCm / MTP2 / batch512 / parallel1とし、64Kをlower-Shared fallbackとする。96K生成peak Shared 3.570 GiBと70K TTFT 246.93秒を制約として記録し、repository CurrentとRTX5090/BLUE operational roleは変更しない。
- BLUE Recommended ProductionをJonathan Q5_K_M Vision / 96K / Q8_0 / MTP3 / batch1024 / RTX3090 259W + RTX3060 170Wへ昇格する。Q6_K BalancedはQuality/Performance Reference、Q6_K Safeはknown-good fallback、Q6 Coding-Fast/370Wは明示選択profileとして永久保持する。Repository lifecycle Currentは変更しない。
- RTX5090 Recommended ProductionをJonathan Q5_K_M Vision / 96K / Q8_0 / MTP3 / batch1024 / effective ubatch512 / PL402Wとする。Repository lifecycle CurrentはQ6_Kのまま維持する。
- RTX5090 Q6 Vision 64K MTP4 / Q8_0 / batch2048 BalancedをQuality/Performance Reference、MTP2 / Q8_0 / batch2048をSafe、MTP4 / Q4_0 / batch2048をexplicit-only Coding-Fastとして永久保持する。Q6をdeprecated扱いしない。
- BLUE Q6 Vision 64K / 259WはMTP3 / Q8_0 / batch1024 Balancedの実測値をQuality/Performance Referenceとして保持する。MTP2 / Q8_0 / batch512はSafeとして永久保持し、MTP3 / Q4_0 / batch512はCoding-Fastとして明示選択時だけ使用する。Q4のfixture外品質同等性は保証しない。
- BLUE 370W PerformanceへMTP3/batch1024またはQ4を組み合わせるloaderは作成しない。Repository lifecycle Currentは`current-qwen38-27b-uncensored-q6k`の1件から変更しない。
- Q5_K_M最終sweepではdraft3が4-workload geomean 55.18 tok/s、weighted acceptance 84.06%、quality 12/12で総合最良。OFF比Text -8.88%を明記しつつCoding/Vision/Long +24.03/+16.05/+15.55%を採用根拠とし、draft4はgeomean/acceptance/VRAMで選ばない。
- BLUE RTX3090は259WをPrimary Operational Power Limitへ採用し、370Wは明示的Performance overrideへ変更。RTX3060は170Wのまま維持する。Repository lifecycle Currentとモデルartifactは変更しない。後続のPhase 1/1.5 integrationはPower方針を変えず、Q6_K Vision 64KのOperational tierだけを追加する。
- BLUEの旧Q6_K Vision / 64K Operational DefaultはQ5昇格後もReferenceとして保持し、Jonathan Q4_K_M / 32Kもlegacy fallbackとして残す。repository-wide CurrentはRTX5090 Jonathan Q6_K textの1件だけを維持する。
- Q6_Kの80K～88Kは最大値探索の証拠として保持するが、Shared gate marginが0.469～0.343 GiBしかないため常用しない。Q6_K 96K Q8のShared 5.021 GiB、128K Q8 8.065 GiB、128K F16 15.044 GiBを理由にQ6 operational 96K/128K loaderを作成しない。Q5_K_M 96Kは別量子化として独立Strict PASSした。
- 64K F16はQ8と同速でDedicated headroomが1,494 MiB少ないため、Q8_0を採用する。
- 2026-08-23時点では、RTX3090単独がcontext 8192/4096/2048の全条件でShared GPU Memoryへ約5.7–6.3 GiB退避するため、Jonathan Vision Q6_Kのstrict GPU-only構成として不採用。RTX3090+3060は8K strict GPU-onlyを満たし、品質優先のBLUE Vision用途に有効と判断し、当時のJonathan Q4_K_M / 32K defaultを維持した。2026-08-24の64K capacity評価で上記Operational Default判断へ更新。
- RTX5090はstrict dual GPUよりText/Visionで2.27–2.53倍高速。RTX3060追加は3090単独partialより3.89–5.34倍高速化し、Q6_K+projectorをdedicated-residentにする容量上の価値がある。これを理由にCurrentや標準LM Studio設定は変更しない。
- Jonathan Q6_K text-onlyを唯一のCurrentとして維持する。Visionは同一Q6_Kの明示切替Candidate/runtime profileとして扱い、通常は64Kを推奨、96Kは他のGPU負荷を止めた長context用途に限定する。
- RTX5090のgoose DesktopだけはJonathan Q6_K Vision 64Kをapp-global既定runtimeとして常用する。これはclient固有のOperational Defaultであり、Vision profileのCurrent昇格ではない。
- HauhauCS Aggressive Q6_K_P/Q5_K_PはCurrentへ昇格しない。
- Visionは実用上の利点だが、Q6_K_Pの64K/96K VRAM不足、Q5_K_Pの速度低下、Candidate embedded MTPの逆効果、Reasoning 8192の最終回答未到達を優先して判断。
- JonathanColetti Q6_KをCurrentとして維持し、将来のBalanced版を待つ。
- RTX3090の旧Jonathan Q4_K_M / 32K defaultは、2026-08-24以降BLUE fallbackとして保持する。
- RTX3090 HauhauCS Q4_K_Pはoptional Candidateとして保持する。direct API Visionは7/7だがZoo Code Code modeの画像経路はtool loopとなるため、画像認識はLM Studio/direct APIを優先する。

### Runtime impact

- REDは終了時に`qwen3.8-27b-uncensored-iq4xs-red` 1件がIDLE / queued0 / 98,304 / Q4_0-Q4_0 / ROCm / RX9070XT only / MTP2 / batch512 / parallel1で常駐。LM Studioは`0.0.0.0:1234`で待受し、MAINからTCP/API/Goose到達PASS。Firewall backupは`C:\Users\Atsuki\Codex-RX9070XT-Setup\firewall-before-lmstudio-20260825-110328.wfw`。driver、BIOS、UAC、Defender、既存RTX5090/BLUE runtimeは変更していない。
- 2026-08-25 Q5 promotion終了時、BLUEはQ6 Safe→Q5 Recommended→Q6 Balanced→Q5 Recommendedの実機切替にPASS。Q5 REMOTE launcherもMAINからexit0となり、対象1件がIDLE / queued0 / 98,304 / Q8_0-Q8_0 / MTP3 / batch1024 / physical batch512 readback / parallel1 / Vision true / RTX3090 259W / RTX3060 170Wで常駐する。Firewall、SSH、SMB、driver、BIOS、LM Studio global settingsは変更していない。
- 2026-08-24 profile integration終了時、MAINはSafe→Balanced→Coding-Fast→Safeを実機切替後に0 loaded modelsへ復帰。BLUEは同じ切替回帰後、Balanced / MTP3 / Q8_0 / batch1024 / effective ubatch512 / 64K / priorityOrder / mmap OFF / parallel1 / Vision true / RTX3090 259W / RTX3060 170Wを1件だけIDLEで常駐。MAINからnative API到達とreasoning OFF Coding fixtureを確認した。この項目が同日中の旧runtime終了記録を更新する。
- MAIN BalancedでText/Coding/Vision smoke、両PCのCoding-FastでPhase 1 Coding fixture必須5マーカー・両関数・code blockを確認。Safe復帰後はQ4、draft3/4、batch1024の残留なし。Firewall、SSH、driver、BIOS、global LM Studio設定、モデル重量、client output profileは変更していない。
- MAIN RTX5090の終了時runtimeはJonathan Q5_K_M Vision Recommended Production / 98,304 / Q8_0-Q8_0 / MTP3 / batch1024 / effective ubatch512 / mmap+mlock / parallel1 / Vision true / IDLE / PL402W。Repository Current、Q6 loaders、Zoo Code、Kilo、driver、CUDA、LM Studio global settingsは変更していない。
- BLUEでQ4_K_M 32K fallbackを回帰後、259W Primary remote loaderを実行。終了状態はRTX3090 259W / RTX3060 170W、Jonathan Q6_K Vision、65,536、Q8_0/Q8_0、MTP draft 2、parallel 1、Vision true、MAINからTCP/API到達PASS。370W Performance loaderは通常loaderから分離した。
- BLUE external SDKへ後方互換managed loaderを配備し、BLUE local/MAIN remote launcherの両方でQ6_K Vision 64Kをロード。既存Q4_K_M 32K引数でもQ8_0/Q8_0、full offload、MTP draft 2、parallel 1の後方互換監査にPASSし、その後Q6_K Vision 64Kへ復帰。作業終了状態は対象1件がIDLE、context 65,536、parallel 1。Power LimitはRTX3090 370W / RTX3060 170Wのまま、driver、Firewall、BIOS、LM Studio global GPU設定は変更していない。
- MAINのKilo configへBLUE provider 2件を追加したが、既定modelは`lmstudio/qwen3.8-27b-uncensored`のまま。Goose、Zoo Code、MAIN LM Studio runtimeは変更していない。
- BLUEへ欠けていたJonathan Q6_K本体だけを既存SSH経路でコピーし、MAIN/BLUEで本体とVision projectorのSHA-256一致を確認。GGUFはGitへ保存していない。benchmarkはper-load GPU splitだけを使用し、global GPU priority、Power Limit、driver、Firewall、SSH/SMBを変更していない。
- cross-hardware benchmark開始時と終了時はMAIN/BLUEともロード済みLM Studioモデル0件。CurrentのAPI ID、Goose Vision 64K operational default、Zoo Code profileは変更していない。
- RTX5090 Vision profile検証直後はJonathan Q6_K Vision / 64K / Q8_0 K+V / full GPU offload / embedded MTP 2 / parallel 1をロードしていた。後続のcross-hardware benchmark終了時は上記のとおりアンロード済みで、通常Currentのモデル枠、API ID、loaderは保持している。
- Kilo Globalはsibling Vision entryを追加したまま既定text modelを維持。goose app-global modelはユーザー選択済みVision IDを維持し、現行config SHAは`F25BA3CF...269B1F86`。既知text baselineとの差はVision model選択と`0.30`→`0.3`の同値表記だけで、Secret file、MCP、OAuthは変更していない。Zoo Code設定も変更していない。
- `Goose Vision 64K` launcherのpreflightは、単一Vision instance、65,536 context、full offload、Flash Attention、Q8_0/Q8_0、KV GPU offload、MTP draft 2、parallel 1でPASS。正しいruntimeは再ロードせず、active / queued predictionを中断しない。
- RTX3090 nodeのLM Studio server bindをlocalhostからLAN待受へ変更し、TCP 1234だけをLAN限定で許可。RTX5090 runtime、Current model、localhost Zoo Code profileは変更していない。
- 2026-08-20のRTX3090評価終了時はJonathan Q4_K_M / 32K / Q8_0 K+V / full GPU offload / embedded MTP 2 / parallel 1へ設定していた。後続の2026-08-23 benchmark終了時はアンロード済みで、メインPC Zoo Codeのactive profileは`default`のまま変更していない。
- Zoo Code切替時に旧conversationがHauhauCS 8K / parallel 4を暗黙ロードしてVRAM競合したため、Remote profile切替後は新規taskを開始し、`lms ps`で対象モデル1個・意図したcontext・parallel 1を確認する運用規則を追加。
- Candidate用Per-model DefaultsとZoo Codeの分離profileを追加。Currentのモデルファイル、設定、loaderは上書きしていない。
- 評価中のみAPI IDを分けてモデルを切り替えた。完了後、Zoo Codeは`default` Current profile、LM StudioはJonathanColetti Q6_K / 98,304 context / embedded MTP ONへ復帰確認済み。
- Q6_K_P、Q5_K_P、mmprojはリポジトリ外のLM Studioモデル領域にのみ存在する。FastMTP sidecar/custom patchは未導入。

### Follow-up

- Zoo Codeの画像mentionと、managed startup後のgoose Desktop画像付き成功再送を次回sessionで完了する。goose CLI 1.46.0のWindows path指定は画像を送信せずtext扱いとなるため、現時点ではDesktop paperclip添付と`Goose Vision 64K` launcherを使用する。
- Balanced-MTP-GGUFの公開を確認できた場合のみ、同じfixtureで新しいCandidate評価を開始する。

### Fixed

- Goose configにlocalhostとBLUE remoteの複数provider `model:`行がある場合、Q6_K Vision 64K launcherが全provider横断で1件を期待して停止する問題を修正。`lmstudio` provider block内だけを一意照合し、remote providerを変更しない。
- BLUE PowerShell 5.1 loaderで`lms ps --json`の配列を平坦化し、status/queued fieldがない未知objectもactiveとして保守的に拒否するよう修正。`processingPrompt`中の検証runに対し、モデルを解除せず`An LM Studio prediction is active or queued`で停止することを実機確認。
- Windows PowerShell 5.1で`lms ps --json`がモデル未ロード時に返す`[]`をnested object 1件と誤認し、one-click launcherが存在しない`.type`で停止する問題を修正。空配列を0モデルとして扱い、未知のmodel fieldもreload判定前に安全に拒否する。

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
