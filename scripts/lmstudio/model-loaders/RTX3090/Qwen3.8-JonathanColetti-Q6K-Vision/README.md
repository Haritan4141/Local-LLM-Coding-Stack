# JonathanColetti Q6_K Vision 64K — BLUE Reference and Fallback Profiles

Daily Quality Reference starts from `../00-Daily-Profiles/3-Quality-Reference_REMOTE.bat` on MAIN or `../00-Daily-Profiles/3-Quality-Reference.bat` on BLUE. These wrappers safely release managed Turbo/tunnel state before CALLing the canonical Balanced BATs in this directory. Safe, Coding-Fast, 370W Performance, and compatibility aliases remain available here.

BLUE (`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`)専用の、RTX 3090 24 GB + RTX 3060 12 GB dual-GPU loaderです。repository-wide CurrentはRTX5090 JonathanColetti Q6_Kのままで、このnode roleは別管理です。

| Item | Value |
|---|---|
| Model | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Quantization | `Q6_K` |
| Model size | `22,430,999,968 bytes` |
| Vision projector | 外部LM Studio model dataに導入済み。Git管理外 |
| Model key | `qwen3.8-27b-uncensored@q6_k` |
| API identifier | `qwen3.8-27b-uncensored-vision-blue` |
| Base URL | `http://192.168.0.104:1234/v1` |
| Context | `65,536` |
| KV cache | profile-specific `Q8_0 / Q8_0` or `Q4_0 / Q4_0`; GPU offload ON |
| GPU split | `priorityOrder`: RTX3090 → RTX3060。runtime IDはGPU名から毎回解決 |
| Other load settings | full offload、Flash Attention ON、mmap OFF、keep in memory ON、parallel 1 |
| MTP / eval batch | profile-specific; see Operational profiles |
| Power Limit | Primary: RTX3090 `259W` / RTX3060 `170W`; Performance override: RTX3090 `370W` / RTX3060 `170W` |
| Client output profiles | Standard `16,384` / Long `32,768` |
| Use | BalancedはQuality/Performance Reference、Safeはknown-good fallback。既存の特殊profileも保持 |

## Operational profiles

| Profile | MTP draft | KV K/V | Eval / effective ubatch | Power | Role |
|---|---:|---|---:|---|---|
| Safe | 2 | Q8_0/Q8_0 | 512 / 512 | 259W / 170W | permanent known-good rollback; existing BAT preserved |
| **Balanced** | 3 | Q8_0/Q8_0 | 1024 / 512 | 259W / 170W | **Quality/Performance Reference** |
| Coding-Fast | 3 | Q4_0/Q4_0 | 512 / 512 | 259W / 170W | explicit coding-speed selection only |
| 370W Performance | 2 | Q8_0/Q8_0 | 512 / 512 | 370W / 170W | existing independent override |

All profiles use context 65,536, priorityOrder RTX3090→RTX3060, full offload, Flash Attention ON, mmap OFF, keep in memory ON, parallel 1, Vision true, and API ID `qwen3.8-27b-uncensored-vision-blue`. Balanced/Coding-Fast are validated only at 259W and cannot be combined with the 370W override. Standard16K / Long32K remain independent client output profiles.

## Launchers

| File | Execute on | Purpose |
|---|---|---|
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.bat` | BLUE | existing Safe。RTX3090を259Wへ設定・検証してロード |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W_REMOTE.bat` | MAIN | `pc5700x`を照合し、BLUEのSafe loaderを起動 |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat` | BLUE | Balanced / Quality-Performance Referenceをロード |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat` | MAIN | BLUE BalancedをREMOTE起動 |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat` | BLUE | Coding-Fastを明示ロード |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.bat` | MAIN | BLUE Coding-FastをREMOTE起動 |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat` | BLUE | 明示選択時だけRTX3090を370Wへ変更するPerformance override |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.bat` | MAIN | `pc5700x`を照合し、BLUEの370W Performance loaderを起動 |
| `Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat` | BLUE | Q5 Recommendedと既存Q6 Safe/Balanced/Coding-Fast/370Wの個別BATだけをCALL |
| `Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat` | MAIN | 対応REMOTE BATだけをCALL |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat` | BLUE | 旧ファイル名の互換エイリアス。259W Safeを起動 |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_REMOTE.bat` | MAIN | 旧ファイル名の互換エイリアス。259W Safeを起動 |

ローカルloaderはhostname、IPv4、LM Studio runtime GPU名、モデル、Vision、active predictionの有無を確認します。次に`nvidia-smi`でGPU名とPCI Bus ID（RTX3090 `00000000:0B:00.0`、RTX3060 `00000000:01:00.0`）を一意に照合し、RTX3090のUUIDを指定して選択したPower Limitへ変更します。RTX3090の設定成功とRTX3060 `170W`維持を確認してから`lms unload --all`とmanaged loadを実行します。GPU indexは固定しません。active/queued predictionがあればPower Limitもruntimeも変更せず停止します。ロード後はeffective load config、Vision、両GPUのmemory use、Power Limitを再監査します。

MAIN用REMOTE launcherはMAINのLM Studioを変更しません。`pc5700x`のhostnameとIPv4を照合し、選択したBLUE loaderをSSH実行して、GPU名・PCI Bus ID・Power LimitとLAN API上の対象IDを再確認します。

Standard `16,384`とLong `32,768`はclient-side output profileであり、model load / Power Limit profileとは独立です。Safe/Balanced/Coding-Fast/370Wのどれをロードしても、既存2種類のclient output profileをそのまま使用できます。

## External runtime boundary

実行にはBLUE上の次のGit管理外ファイルが必要です。

```text
C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk\
  Load-ManagedModel.mjs
  Test-ManagedModel.mjs
  node_modules\@lmstudio\sdk\

C:\Users\Atsuki\Codex-RTX3090-Setup\model-loaders\
  Qwen3.8-JonathanColetti-Q6K-Vision\
```

GGUF、projector、LM Studio application data、SDK dependencyはrepositoryへ保存しません。既存JonathanColetti Q4_K_M 32K loaderはfallbackとして残します。

## Selection rationale

Phase 1でMTP2/Q8/batch512からMTP3/Q8/batch512へ変更すると、Text `+2.81%`、Coding `+7.70%`、Vision `+6.24%`、Long `+4.26%`で、品質は3/3、safetyは4/4でした。MTP3/Q8のbatch512→1024はLong prompt processing `+24.80%`、TTFT `-19.81%`で、generationはText `-0.60%`、Coding `-2.04%`、Vision `+0.61%`、Long `+0.25%`でした。Phase 1.5でも12/12 qualityとsafety 4/4のためMTP3/Q8/batch1024をBalancedへ採用しました。2026-08-25のQ5_K_M 96K昇格後も、この実測profileをQuality/Performance Referenceとして保持します。

Q4はPhase 1.5 fresh matrixでQ4固有failureを再現せず、Q8/batch1024比でCoding `+10.25%`、Long `-7.13%`でした。ただしPhase 1 Coding failure replayではQ4/batch1024のfailure履歴が再現し、fixture外同等性は証明されていません。そのためQ4/MTP3/batch512をCoding-Fastへ隔離し、General Defaultにしません。

80K/84K/88KもStrict PASSしましたが、Shared GPU Memory gateの余裕が順に0.469/0.407/0.343 GiBまで狭まりました。64Kは0.719 GiB、Dedicated headroom合計約9.49 GiBを確保し、Q8の速度はF16と同等でDedicated headroomが約1.46 GiB多いため、最大Contextより常用時の安全余裕を優先しました。96K/128KはShared gate FAILのためOperational loaderを作りません。

2026-08-24の同一モデル・同一64K設定A/Bでは、259Wは370Wに対してText `-4.43%`、Vision `-4.97%`、Long-prompt processing `-6.45%`、Sustained generation `-3.27%`でした。一方、Sustained dual-GPU平均電力は`380.9W`から`326.7W`へ`14.23%`低下し、RTX3090 peak temperatureは`83C`から`79C`、tok/s per GPU wattは`12.78%`改善しました。この結果を受け、259WをPrimary、370Wを明示的Performance overrideとして採用しました。

Profile選定の全比較と2026-08-24のSafe→Balanced→Coding-Fast→Safe実機回帰は`benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`にあります。Q5_K_M 96Kとのfresh comparisonと後続の切替回帰は`benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`に記録します。
