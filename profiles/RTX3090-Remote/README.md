# BLUE Remote LLM Node

MAINのVS Code / Kilo Code / Zoo Code等から家庭内LAN経由で利用する独立LM Studio nodeです。RTX5090 localhost環境とは別のBase URLとAPI identifierを使用します。BLUEのOperational Recommended roleはrepository-wide Currentを増やしません。

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
| LM Studio | 0.4.21.0 / CLI `71bd99c` |
| LAN URL | `http://192.168.0.104:1234` |
| Model storage | LM Studio external data only; never Git |

接続またはruntime変更前に`pc5700x`、`192.168.0.104`、`DESKTOP-L9HAM1G`を照合します。

## LAN server boundary

- LM Studioは`0.0.0.0:1234`で待受し、MAINからAPI到達確認済みです。
- Firewall rule: `Local-LLM-LMStudio-In-TCP-1234-Private-LocalSubnet`
- Scope: Inbound / Allow / TCP 1234 / Private / LocalSubnet / Edge Traversal Block / LM Studio executable。
- Backup: `C:\Users\Atsuki\Codex-RTX3090-Setup\firewall-before-lmstudio-20260820-114203.wfw`
- 今回の64K採用ではFirewall、server bind、driver、Power Limit、BIOS、LM Studio global GPU設定を変更していません。
- 2026-08-24のPower Limit A/B採用時はRTX3090のPrimaryだけを370Wから259Wへ変更しました。RTX3060、Firewall、server bind、driver、BIOS、LM Studio global GPU設定は変更していません。

## Operational Recommended

| Item | Value |
|---|---|
| Model | JonathanColetti Qwen3.8 27B Uncensored Q6_K + F16 Vision projector |
| Model key | `qwen3.8-27b-uncensored@q6_k` |
| API identifier | `qwen3.8-27b-uncensored-vision-blue` |
| Context | 65,536 |
| KV | Q8_0/Q8_0; GPU offload ON |
| GPU split | `priorityOrder`: RTX3090 → RTX3060; runtime ID is resolved by name |
| Other | full offload, Flash Attention ON, mmap OFF, keep in memory ON |
| MTP / batch / concurrency | MTP ON / draft 3 / eval batch 1024 / effective ubatch 512 / parallel 1 |
| Primary Power | RTX3090 259W / RTX3060 170W |
| Performance override | RTX3090 370W / RTX3060 170W。明示loader選択時のみ |
| Role | Coding, Agent, Vision, single-user long context |

The Recommended row is the Balanced profile. The permanent Safe rollback is MTP2 / Q8_0 / eval batch512 / ubatch512 at the same 64K and 259W/170W. Coding-Fast is MTP3 / Q4_0 / batch512 and is explicit selection only; fixture-external quality equivalence is not established. The existing 370W Performance override stays independent and is not combined with Balanced or Coding-Fast.

64K Q8はShared 3.281 GiBでStrict PASSし、Shared gate margin 0.719 GiB、Dedicated headroomはRTX3090 6,709 MiB + RTX3060 3,011 MiBです。80K/84K/88KもPASSしましたが、Shared gate marginが0.469/0.407/0.343 GiBまで縮むため、最大Contextより常用余裕を優先しました。96K Q8はShared 5.021 GiB、128K Q8は8.065 GiB、128K F16は15.044 GiBでFAILです。

同じ64KのF16は速度が同等で、Q8よりDedicated headroomが1,494 MiB少ないため採用しません。

## Managed startup

- BLUE local Safe: `scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.bat`
- BLUE local Balanced: 同ディレクトリの`Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat`
- BLUE local Coding-Fast: 同ディレクトリの`Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat`
- MAIN remote Safe/Balanced/Coding-Fast: 対応する`_REMOTE.bat`
- Local/REMOTE selector: `Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat` / `Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat`
- BLUE local Performance: 同ディレクトリの`Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat`
- MAIN remote Performance: 同ディレクトリの`Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.bat`

local loaderはidentity、IP、GPU名・PCI Bus ID、model、Vision、active predictionを確認し、RTX3090 UUIDだけへ選択した259W/370Wを設定します。RTX3090とRTX3060 170Wを検証してからidle modelを解除し、ロード後にeffective settings、Vision、両GPUの利用、Power Limitを再監査します。REMOTE launcherはMAINのLM Studioを変更しません。旧`_64K` local/REMOTE名は259W Safeへ委譲する互換エイリアスです。

2026-08-24のSafe→Balanced→Coding-Fast→Safe切替、259W local/REMOTE経路、370W Performance分岐、Q4_K_M fallback回帰はPASSしました。Profile integration終了時はBalancedで対象1件がIDLE、64K、Q8_0/Q8_0、MTP3、batch1024、ubatch512、parallel 1、Vision true、259W/170Wです。

## Client profiles

Kilo Code 7.4.22へ次の選択肢を追加し、既存localhost modelを既定のまま維持しました。

| Profile | Context | Output | Vision / tools |
|---|---:|---:|---|
| `openai-compatible/blue-jonathan-vision-64k-standard16k` | 65,536 | 16,384 | enabled |
| `openai-compatible/blue-jonathan-vision-64k-long32k` | 65,536 | 32,768 | enabled |

Long32Kのnative API実測は30,803 output tokensで自然完了しました。さらにKilo Code実経路でも最初のgeneration stepが29,001 output tokensまで到達し、16K client limitで停止しないことを確認しました。Kiloは終了後に自動継続/要約ターンへ入るため、長大な定型出力では追加ターンに注意します。Gooseは単一active profile方式なので今回変更していません。Zoo Codeは正式な保存profile schemaがrepositoryにないため、UIからBase URLとnatural IDを指定する作業をpendingとします。

Standard16K / Long32Kはmodel load / Power Limitから独立したclient profileです。Safe/Balanced/Coding-Fast/370W Performanceで同じ2 profileを使い、client出力上限や既存検証結果は変更しません。

## Fallback and optional models

| Role | Model | Quant | API identifier | Context |
|---|---|---|---|---:|
| Fallback | JonathanColetti Qwen3.8 27B | Q4_K_M | `qwen3.8-27b-uncensored@q4_k_m` | 32K default / 64K solo |
| Optional Candidate | HauhauCS Aggressive | Q4_K_P | `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp` | 32K default / 64K solo |

既存Q4_K_M loaderは削除・上書きしていません。Q4_K_M 32Kは、3060を空けたい場合やQ6_K Visionで問題が出た場合のfallbackです。

Q4_K_M loaderはPower Limitを変更せず、現在選択されている259Wまたは370Wを継承します。通常の復帰先はQ6_K Vision 64K / 259W Primaryです。

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

- Operational selection: `benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md`
- Power Limit A/B and adoption: `benchmarks/results/2026-08-24-blue-rtx3090-power-limit-ab.md`
- Shared GPU Memory investigation: `research/2026-08-24-blue-shared-gpu-memory-investigation.md`
- Cross-hardware comparison: `benchmarks/results/2026-08-23-jonathan-q6k-vision-gpu-comparison.md`
- Legacy Q4 comparison: `benchmarks/results/2026-08-20-rtx3090-remote-node.md`
- Phase 1/1.5 operational profiles: `benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`
