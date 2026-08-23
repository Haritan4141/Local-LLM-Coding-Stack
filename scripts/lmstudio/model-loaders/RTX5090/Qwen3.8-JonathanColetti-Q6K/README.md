# Qwen3.8 JonathanColetti LM Studio Loaders

RTX 5090 32 GB 上の Current モデル `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` Q6_K を、用途別contextで読み込むBATセットです。

管理元として取り込んだローカルプリセットセット: `Qwen3.8_LMStudio_Context_Presets`

モデル本体やGGUFの実パスは含みません。LM Studio側にインストール済みの `qwen3.8-27b-uncensored` を `lms` CLIから参照します。

## Presets

| BAT | Context | Use |
|---|---:|---|
| `Qwen3.8-JonathanColetti-Q6K_96K.bat` | 98,304 | 通常のZoo Code・コーディング用。Current標準 |
| `Qwen3.8-JonathanColetti-Q6K_64K.bat` | 65,536 | VRChat / Unity + Zoo Code用 |
| `Qwen3.8-JonathanColetti-Q6K_32K.bat` | 32,768 | VRAM余裕と軽快さを優先する作業用 |

128Kプリセットは作成しません。Currentでは128K + Q8 KVによりVRAMが圧迫され、Windows操作性が低下したためです。

## What every BAT changes

各BATは次の順序でLM Studioの実行状態を変更します。

1. `lms unload --all` で現在ロードされている全モデルを解除する。
2. `lms load "qwen3.8-27b-uncensored"` で対象モデルを読み込む。
3. `--context-length` に各用途のcontextを指定する。
4. `--gpu max` で最大GPU offloadを要求する。
5. `--identifier "qwen3.8-27b-uncensored"` でZoo Codeから使うAPI Model IDを固定する。

実行にはLM Studioが起動し、`lms` CLIがPATHから利用でき、対象モデルがLM Studioへインストール済みである必要があります。ロードに失敗した場合、先行するunloadは元に戻らないため、LM Studioがモデル未ロードの状態になる可能性があります。

## Common LM Studio settings

BATが直接指定するのはcontext、最大GPU offload、API Model IDです。次のCurrent共通値はBATから上書きせず、LM Studioの保存済みPer-model Defaultsで維持します。

| Setting | Required Current value | BAT behavior |
|---|---:|---|
| K Cache | Q8_0 | 変更しない |
| V Cache | Q8_0 | 変更しない |
| Flash Attention | ON | 変更しない |
| GPU Offload | 全65層 | `--gpu max`で要求 |
| MTP | ON | 変更しない |
| Max draft tokens | 2 | 変更しない |
| Max Concurrent Predictions | 1 | 変更しない |

Reasoning Budget 8,192はZoo Code/リクエスト側の共通運用値として維持します。BATはこの値を設定しません。

## Usage and safety

- BATをダブルクリックするか、通常のCommand Promptから実行します。
- 実行すると現在ロード中のLM Studioモデルがすべて解除されるため、別タスクの推論中には実行しません。
- `lms load`が解決するローカルモデル名とAPI Model IDはどちらも `qwen3.8-27b-uncensored` です。
- モデルを別variantへ変更する場合、このディレクトリを上書きせず、`RTX5090/` 配下に新しいモデルディレクトリを追加します。
- GGUF、Vision projector、tokenizer payload、LM Studio実データはこのリポジトリへコピーしません。
