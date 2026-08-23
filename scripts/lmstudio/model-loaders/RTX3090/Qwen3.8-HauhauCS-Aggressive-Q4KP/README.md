# HauhauCS Aggressive Q4_K_P RTX3090 Loaders

RTX3090 Remote Node用のVision対応Candidateです。JonathanColetti Q4_K_Mを上書きせず、別モデル・別identifierとして切り替えます。

| Item | Value |
|---|---|
| Model | `HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` |
| Quantization | `Q4_K_P` |
| Model size | 17,923,393,664 bytes |
| API identifier | `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp` |
| Vision | separate BF16 `mmproj` installed outside Git; direct API 7/7 |
| FastMTP | inactive; requires a separate sidecar and custom llama.cpp patch |
| Measured VRAM | 20,867 MiB peak at 32K; 22,156 MiB peak at 64K |
| Default use | 32K Vision / Candidate comparison |
| 64K use | single-user long-context test only; VRAM margin is about 2.1 GiB |

## Presets

| BAT | Context | Use |
|---|---:|---|
| `Qwen3.8-HauhauCS-Q4KP_32K.bat` | 32,768 | 通常のCandidate/Vision評価 |
| `Qwen3.8-HauhauCS-Q4KP_64K.bat` | 65,536 | 他GPU workloadを止めた条件付き長context |

共通設定は全GPU offload、Flash Attention ON、K/V cache `Q8_0/Q8_0`、KV GPU offload ON、Max Concurrent Predictions 1、embedded MTP ON、Max draft tokens 2です。32Kは35.47 tok/s、MTP acceptance 72.80%。Reasoning評価は8,192 tokensで行いました。

BATはRTX3090 PCの外部SDK環境 `C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk` を呼び出します。そこへ配置済みの`Load-ManagedModel.mjs`と`@lmstudio/sdk@1.5.0`が必要です。実行時にRTX3090 node上のロード済みモデルをすべて解除します。モデル、projector、SDK dependencyはGit管理対象外です。

Zoo Codeでは同じnatural identifierを選択しないと、未ロードのindexed modelが既定8Kで暗黙ロードされます。API identifierを変更しないでください。96KはVRAM安全余裕不足のためloaderを作りません。
