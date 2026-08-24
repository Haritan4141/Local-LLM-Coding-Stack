# JonathanColetti Q4_K_M RTX3090 Loaders

RTX3090 Remote Node用の通常コーディングモデルです。

| Item | Value |
|---|---|
| Model | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Quantization | `Q4_K_M` |
| Model size | 16,810,714,528 bytes |
| API identifier | `qwen3.8-27b-uncensored@q4_k_m` |
| Power Limit | 変更しない。現在選択中のBLUE Primary 259WまたはPerformance 370Wを継承し、RTX3060 170Wも変更しない |
| Vision | separate F16 projector installed outside Git; direct API verified |
| Measured VRAM | 19,737 MiB peak at 32K; 21,106 MiB peak at 64K |
| Default use | 32K remote coding / Zoo Code |
| 64K use | single-user long-context work; narrow VRAM margin |

## Presets

| BAT | Context | Use |
|---|---:|---|
| `Qwen3.8-JonathanColetti-Q4KM_32K.bat` | 32,768 | 普段使い。VRAM余裕を優先 |
| `Qwen3.8-JonathanColetti-Q4KM_64K.bat` | 65,536 | 長いrepository/contextを単独処理するとき |

共通設定は全GPU offload、Flash Attention ON、K/V cache `Q8_0/Q8_0`、KV GPU offload ON、Max Concurrent Predictions 1、embedded MTP ON、Max draft tokens 2です。32Kは36.31 tok/s、MTP acceptance 73.91%。Reasoning評価は8,192 tokensで行いました。

BATはRTX3090 PCの外部SDK環境 `C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk` を呼び出します。そこへ配置済みの`Load-ManagedModel.mjs`と`@lmstudio/sdk@1.5.0`が必要です。実行時にRTX3090 node上のロード済みモデルをすべて解除します。モデル、projector、SDK dependencyはGit管理対象外です。

96KはQ8 KVで安全余裕が不足するためloaderを作りません。32Kを通常値、64Kを条件付き上限として扱います。
