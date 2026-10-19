# BLUE Remote LLM Node

2026-10-19運用方針: **DeepSeek + BLUE IQ4_XS Vision256K = Daily Preferred Runtime / User Confirmed**。ユーザーの日常利用は正常との報告を受け、この選択を優先します。Q5_K_M Vision96KはHistorical Recommended Production / 手動fallback、Q6 Current / Reference / Safeは保持します。[追加監査・運用上の境界](../../research/2026-10-19-blue256k-daily-audit.md)を参照してください。以下の96K推奨説明は保持する既存profileの役割です。

2026-10-19実機確認: BLUEはstandalone IQ4_XS Vision256K Candidateで稼働、LM Studio loaded instancesは0。LM Studio実行ファイルは0.4.25.0。以下のLM Studio推奨構成・測定値は主に2026-08のbaselineであり、今日ロード中のprofileではありません。[現在状態](../../CURRENT_STATE.md)と[監査記録](../../research/2026-10-19-current-configuration-audit.md)を参照してください。

MAINのVS Code / Kilo Code / Zoo Code等から家庭内LAN経由で利用する独立LM Studio nodeです。RTX5090 localhost環境とは別のBase URLとAPI identifierを使用します。BLUEのRecommended Production roleはrepository-wide Currentを増やしません。

## Identity

| Item | Value |
|---|---|
| COMPUTERNAME | `DESKTOP-L9HAM1G` |
| IP | `192.168.0.104` |
| SSH Alias | `pc5700x` |
| GPU | RTX 3090 24,576 MiB + RTX 3060 12,288 MiB |
| GPU links | RTX3090 Gen3 x16; RTX3060 Gen3 x4 |
| Total physical VRAM | 36,864 MiB; independent devices, not pooled |
| Power Limit | Primary: RTX3090 259W / RTX3060 170W; Performance override: RTX3090 370W / RTX3060 170W |
| RAM | 31.93 GiB |
| NVIDIA driver | 591.86 |
| LM Studio baseline（2026-08） | 0.4.21.0 / CLI `71bd99c`。2026-10-19実機は0.4.25.0 |
| LAN URL | `http://192.168.0.104:1234` |
| Model storage | LM Studio external data only; never Git |

接続またはruntime変更前に`pc5700x`、`192.168.0.104`、`DESKTOP-L9HAM1G`を照合します。

## LAN server boundary

- LM Studioは`0.0.0.0:1234`で待受し、MAINからAPI到達確認済みです。
- Firewall rule: `Local-LLM-LMStudio-In-TCP-1234-Private-LocalSubnet`
- Scope: Inbound / Allow / TCP 1234 / Private / LocalSubnet / Edge Traversal Block / LM Studio executable。
- Backup: `C:\Users\Atsuki\Codex-RTX3090-Setup\firewall-before-lmstudio-20260820-114203.wfw`
- Q5_K_M 96K qualification/promotionではFirewall、SSH、SMB、server bind、driver、Power Limit、BIOS、LM Studio global GPU設定を変更していません。
- 2026-08-24のPower Limit A/B採用時はRTX3090のPrimaryだけを370Wから259Wへ変更しました。RTX3060、Firewall、server bind、driver、BIOS、LM Studio global GPU設定は変更していません。

## Historical Recommended Production / 手動fallback

| Item | Value |
|---|---|
| Model | JonathanColetti Qwen3.8 27B Uncensored Q5_K_M + F16 Vision projector |
| Model key | `qwen3.8-27b-uncensored-vision-q5km` |
| API identifier | `qwen3.8-27b-uncensored-vision-q5km-blue` |
| Context | 98,304 |
| KV | Q8_0/Q8_0; GPU offload ON |
| GPU split | `priorityOrder`: RTX3090 → RTX3060; runtime ID is resolved by name |
| Other | full offload, Flash Attention ON, mmap OFF, keep in memory ON |
| MTP / batch / concurrency | MTP ON / draft 3 / eval batch 1024 / effective ubatch 512 / parallel 1 |
| Primary Power | RTX3090 259W / RTX3060 170W |
| Performance override | RTX3090 370W / RTX3060 170W。明示loader選択時のみ |
| Role | Recommended Production for Coding, Agent, Vision, and >64K long context |

Q5_K_M 96KはStrict gate、Text/Coding/Vision/Tool Calling、76,880-token入力、fresh Q6 comparisonをPASSしたためRecommended Productionへ昇格しました。Q6_K Balanced 64KはQuality/Performance Reference、Q6_K Safeはknown-good rollbackとして永久保持します。Q6_K Coding-Fastと370W Performanceも既存の明示選択profileのままです。未評価のQ5 370W loaderは作成しません。

Q5_K_M 96K Q8はロード時Shared 3.515 GiB、76,880-token run中の最大3.527 GiBでStrict PASSしました。ロード時DedicatedはRTX3090 17,870 MiB（headroom 6,706 MiB）、RTX3060 8,879 MiB（headroom 3,409 MiB）です。Q6_K 96K Q8のShared 5.021 GiB FAILはQ6_K固有のcapacity evidenceであり、量子化の異なるQ5_K_Mの結果へ転用しません。

Q6_Kの同じ64K F16 comparisonは速度が同等で、Q8よりDedicated headroomが1,494 MiB少ないため、Q6 referenceもQ8を維持します。

## Managed startup

- BLUE local Q5 Recommended: `scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat`
- MAIN remote Q5 Recommended: 同ディレクトリの`Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.bat`
- BLUE local Q5 Turbo explicit-only: 同ディレクトリの`Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat`
- MAIN remote Q5 Turbo explicit-only: 同ディレクトリの`Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.bat`。MAIN `127.0.0.1:18081`からBLUE localhost `127.0.0.1:18080`へmanaged SSH forwarding
- BLUE local / MAIN remote Stable recovery: 同ディレクトリの`_96K_259W_Stable.bat` / `_96K_259W_Stable_REMOTE.bat`
- BLUE local Q6 Safe/Balanced/Coding-Fast: `scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/`の既存個別BAT
- MAIN remote Q6 Safe/Balanced/Coding-Fast: 対応する既存`_REMOTE.bat`
- Local/REMOTE selector: `Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat` / `Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat`
- BLUE local Performance: 同ディレクトリの`Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat`
- MAIN remote Performance: 同ディレクトリの`Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.bat`

local loaderはidentity、IP、GPU名・PCI Bus ID、model、Vision、active predictionを確認し、RTX3090 UUIDだけへ選択したPower Limitを設定します。Q5 loaderはロード後のcombined/per-GPU Shared gateも自動監査し、FAIL時はQ5 instanceをunloadします。REMOTE launcherはMAINのLM Studioを変更しません。Q6の旧`_64K` local/REMOTE名は259W Safeへ委譲する互換エイリアスです。

2026-08-25のQ6 Safe→Q5 Recommended→Q6 Balanced→Q5 Recommended切替とQ5 REMOTE経路はPASSしました。終了状態はQ5対象1件がIDLE、96K、Q8_0/Q8_0、MTP3、batch1024、ubatch512、parallel1、Vision true、259W/170Wです。

2026-08-25にofficial llama.cpp `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`のStandalone MTP3 Turboを明示選択profileとして統合しました。Stable Remote→Turbo Remote→Stable Remote→Turbo Remote→Stable Remote、MAINとの同時endpoint、Vision 7/7、Tool Calling、Goose built-in `openai` tool-useを実機確認しています。Turbo終了後はBLUE port 18080とMAIN tunnel port 18081がfree、standalone/tunnel 0件、上記Stable Q5対象がIDLE / queued 0へ復帰しました。Stableは引き続きRecommended Production、Turboはexplicit-onlyです。

## Client profiles

Kilo Code 7.4.22へ次の選択肢を追加し、既存localhost modelを既定のまま維持しました。

| Profile | Context | Output | Vision / tools |
|---|---:|---:|---|
| `openai-compatible/blue-jonathan-vision-64k-standard16k` | 65,536 | 16,384 | enabled |
| `openai-compatible/blue-jonathan-vision-64k-long32k` | 65,536 | 32,768 | enabled |

Long32Kのnative API実測は30,803 output tokensで自然完了しました。さらにKilo Code実経路でも最初のgeneration stepが29,001 output tokensまで到達し、16K client limitで停止しないことを確認しました。Kiloは終了後に自動継続/要約ターンへ入るため、長大な定型出力では追加ターンに注意します。Gooseは単一active profile方式なので今回変更していません。Zoo Codeは正式な保存profile schemaがrepositoryにないため、UIからBase URLとnatural IDを指定する作業をpendingとします。

Standard16K / Long32Kは既存Q6 API ID向けclient profileで、今回変更していません。Q5 Recommendedは新しいnatural ID `qwen3.8-27b-uncensored-vision-q5km-blue`をdirect OpenAI-compatible APIまたは明示的なclient設定から使用します。

## DFlash2 build toolchain readiness

Q5 promotion後、公式winget package `Microsoft.VisualStudio.2022.BuildTools` 17.14.39を`--norestart`で導入しました。Desktop development with C++ workload、MSVC v143、Windows 11 SDK 26100、Visual Studio CMake componentだけを明示し、IDEや無関係workloadは追加していません。

Developer Command Prompt x64で次を確認済みです。

| Tool | Verified version/state |
|---|---|
| `cl` | 19.44.35228 x64 / MSVC v143 |
| `cmake` | 3.31.6-msvc6 |
| `ninja` | 1.12.1 |
| `nvcc` | CUDA 12.9 / V12.9.41 |
| GPU code | `sm_86` available; RTX3090/RTX3060ともCompute Capability 8.6 |

installer exitは0で、CBS/Windows Updateのreboot-required keyはありません。PendingFileRenameOperationsにはinstaller bootstrapper JSONと一時ファイルの削除予約が残りましたが、明示的な再起動要求ではなくtoolchainは現sessionで実行確認済みです。再起動は実施していません。llama.cpp clone、PR checkout、patch、DFlash2 build、Drafter download、port 18080、tunnel、benchmarkは開始していません。

## Reference, fallback, and optional models

| Role | Model | Quant | API identifier | Context |
|---|---|---|---|---:|
| Quality/Performance Reference | JonathanColetti Qwen3.8 27B Vision | Q6_K | `qwen3.8-27b-uncensored-vision-blue` | 64K |
| Known-good fallback | JonathanColetti Qwen3.8 27B Vision Safe | Q6_K | `qwen3.8-27b-uncensored-vision-blue` | 64K |
| Fallback | JonathanColetti Qwen3.8 27B | Q4_K_M | `qwen3.8-27b-uncensored@q4_k_m` | 32K default / 64K solo |
| Optional Candidate | HauhauCS Aggressive | Q4_K_P | `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp` | 32K default / 64K solo |

既存Q4_K_M loaderは削除・上書きしていません。Q4_K_M 32Kは、3060を空けたい場合やQ6_K Visionで問題が出た場合のfallbackです。

Q4_K_M loaderはPower Limitを変更せず、現在選択されている259Wまたは370Wを継承します。旧Q4 profileからの手動復帰先としてQ5_K_M Vision96K / 259Wを保持します。現在の日常優先BLUE256Kを自動的に置き換える指示ではありません。

2026-08-24に拡張managed loaderとの後方互換性を実機確認し、Q4_K_M 32KのQ8_0/Q8_0、full offload、MTP draft 2、parallel 1がPASSしました。確認後はQ6_K Vision 64KをREMOTE launcherで復帰・再監査しています。

## Legacy Q4 results

| Model / context / MTP | Generation median | Peak VRAM | MTP acceptance | Result |
|---|---:|---:|---:|---|
| Jonathan Q4_K_M / 32K / ON | 36.31 tok/s | 19,737 MiB | 73.91% | stable fallback |
| Jonathan Q4_K_M / 64K / ON | 35.88 tok/s | 21,106 MiB | not sampled | solo use |
| HauhauCS Q4_K_P / 32K / ON | 35.47 tok/s | 20,867 MiB | 72.80% | optional Candidate |
| HauhauCS Q4_K_P / 64K / ON | 36.28 tok/s | 22,156 MiB | not sampled | narrow margin |

Both passed direct Tool Calling and direct Vision 7/7. HauhauCS entered a Zoo Code image/tool loop, so it was not selected.

## Evidence

- Q5_K_M 96K qualification and promotion: `benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`
- Operational selection: `benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`
- Power Limit A/B and adoption: `benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`
- Shared GPU Memory investigation: `research/2026-08-24-blue-shared-gpu-memory-investigation.md`
- Cross-hardware comparison: `benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`
- Legacy Q4 comparison: `benchmarks/results/2026-08-20-rtx3090-remote-node.md`
- Phase 1/1.5 operational profiles: `benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`
