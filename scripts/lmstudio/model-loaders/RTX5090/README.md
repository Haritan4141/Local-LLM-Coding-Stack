# RTX5090 LM Studio Model Loaders

RTX 5090 32 GB 向けのモデル起動BATを、モデル単位で分離して管理します。

```text
RTX5090/
  README.md
  Qwen3.8-JonathanColetti/
    README.md
    Qwen3.8_96K_Normal.bat
    Qwen3.8_64K_VRChat.bat
    Qwen3.8_32K_Light.bat
  <Future-Model-Name>/
    README.md
    <model-specific loaders>.bat
```

## Directory policy

- 別モデル、別publisher、互換性の異なるvariantは、それぞれ新しいモデルディレクトリを追加します。
- Candidate用BATをCurrentのディレクトリへ混在させません。
- 各モデルディレクトリのREADMEにrepository、variant、API Model ID、各BATの用途、変更する設定、変更しない共通設定、既知の制約を記録します。
- BATはLM Studioへインストール済みのモデル名を参照するだけにし、GGUFのコピー、ダウンロード、絶対パスの埋め込みを行いません。
- loader追加だけではモデルのCurrent昇格を意味しません。状態は `MODEL_REGISTRY.md` を正とします。
