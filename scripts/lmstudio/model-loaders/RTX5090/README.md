# RTX5090 LM Studio Model Loaders

RTX 5090 32 GB 向けのモデル起動BATを、モデル単位で分離して管理します。

```text
RTX5090/
  README.md
  Qwen3.8-JonathanColetti-Q6K/
    README.md
    Qwen3.8-JonathanColetti-Q6K_96K.bat
    Qwen3.8-JonathanColetti-Q6K_64K.bat
    Qwen3.8-JonathanColetti-Q6K_32K.bat
  Qwen3.8-JonathanColetti-Q6K-Vision/
    README.md
    Qwen3.8-JonathanColetti-Q6K-Vision_96K.bat
    Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat
    Qwen3.8-JonathanColetti-Q6K-Vision_32K.bat
  Qwen3.8-HauhauCS-Aggressive-Q6KP/
    README.md
    Qwen3.8-HauhauCS-Q6KP_96K.bat
    Qwen3.8-HauhauCS-Q6KP_64K.bat
    Qwen3.8-HauhauCS-Q6KP_32K.bat
  Qwen3.8-HauhauCS-Aggressive-Q5KP/
    README.md
    Qwen3.8-HauhauCS-Q5KP_96K.bat
    Qwen3.8-HauhauCS-Q5KP_64K.bat
    Qwen3.8-HauhauCS-Q5KP_32K.bat
  <Future-Model-Name>/
    README.md
    <model-specific loaders>.bat
```

## Directory policy

- 別モデル、別publisher、互換性の異なるvariantは、それぞれ新しいモデルディレクトリを追加します。
- ディレクトリ名には量子化を含め、`<Model-Variant-Quantization>/`形式で識別します。
- BAT名は`<Model-Identifier>_<Context>K.bat`形式とし、`Normal`、`VRChat`、`Light`などの用途名は含めません。用途は各READMEへ記録します。
- Candidate用BATをCurrentのディレクトリへ混在させません。
- 各モデルディレクトリのREADMEにrepository、variant、API Model ID、各BATの用途、変更する設定、変更しない共通設定、既知の制約を記録します。
- BATはLM Studioへインストール済みのモデル名を参照するだけにし、GGUFのコピー、ダウンロード、絶対パスの埋め込みを行いません。
- loader追加だけではモデルのCurrent昇格を意味しません。状態は `MODEL_REGISTRY.md` を正とします。
