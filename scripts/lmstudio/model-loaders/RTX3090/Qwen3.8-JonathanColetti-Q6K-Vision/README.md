# JonathanColetti Q6_K Vision 64K — BLUE Operational Default

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
| KV cache | `Q8_0 / Q8_0`、GPU offload ON |
| GPU split | `priorityOrder`: RTX3090 → RTX3060。runtime IDはGPU名から毎回解決 |
| Other load settings | full offload、Flash Attention ON、mmap OFF、keep in memory ON、parallel 1 |
| MTP | ON、Max draft tokens 2 |
| Power Limit | RTX3090 `370W`、RTX3060 `170W`を読み取り検査。変更しない |
| Client output profiles | Standard `16,384` / Long `32,768` |
| Use | BLUEの通常coding、agent、Vision、長文脈 |

## Launchers

| File | Execute on | Purpose |
|---|---|---|
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat` | BLUE | ローカルで64K Operational Defaultをロード |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K_REMOTE.bat` | MAIN | `pc5700x`を照合してBLUE上のloaderを起動 |

ローカルloaderはhostname、IPv4、LM Studio runtime GPU名、モデル、Vision、Power Limit、active predictionの有無を確認してから`lms unload --all`を実行します。active/queued predictionがあれば中断せず停止します。ロード後はeffective load config、Vision、両GPUのmemory use、Power Limitを再監査します。

MAIN用REMOTE launcherはMAINのLM Studioを変更しません。`pc5700x`のhostnameとIPv4を照合し、BLUE loaderをSSH実行してLAN APIから対象IDを再確認します。

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

80K/84K/88KもStrict PASSしましたが、Shared GPU Memory gateの余裕が順に0.469/0.407/0.343 GiBまで狭まりました。64Kは0.719 GiB、Dedicated headroom合計約9.49 GiBを確保し、Q8の速度はF16と同等でDedicated headroomが約1.46 GiB多いため、最大Contextより常用時の安全余裕を優先しました。96K/128KはShared gate FAILのためOperational loaderを作りません。
