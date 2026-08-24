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
    Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat
    Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat
    Qwen3.8-JonathanColetti-Q6K-Vision_32K.bat
    Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat  # Q5 Recommended + retained Q6 profiles
    Start-Goose-Jonathan-Vision64K.ps1
    Start-Goose-Jonathan-Vision64K.bat
  Qwen3.8-JonathanColetti-Q5KM-Vision/
    README.md
    Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat
    Qwen3.8-JonathanColetti-Q5KM-Vision_64K.bat
    Qwen3.8-JonathanColetti-Q5KM-Vision_32K.bat
    Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1
    Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.bat
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
- 通常のBAT名は`<Model-Identifier>_<Context>K.bat`形式です。同一モデル・Contextの明示的Operational tierだけは`_Balanced` / `_Coding-Fast`を付加し、既存Safe名は変更しません。`Normal`、`VRChat`、`Light`などの曖昧な用途名は含めません。
- モデル/量子化ごとのBATは別ディレクトリに保持し、共通Selectorから相対pathでCALLします。
- 各モデルディレクトリのREADMEにrepository、variant、API Model ID、各BATの用途、変更する設定、変更しない共通設定、既知の制約を記録します。
- BATはLM Studioへインストール済みのモデル名を参照するだけにし、GGUFのコピー、ダウンロード、絶対パスの埋め込みを行いません。
- loader追加だけではモデルのCurrent昇格を意味しません。状態は `MODEL_REGISTRY.md` を正とします。
- RTX5090のOperational roleはQ5_K_M Vision 96KをRecommended Production、Q6_K Vision 64K BalancedをQuality/Performance Reference、Q6 Safeをknown-good fallback、Q6 Coding-Fastをexplicit-onlyとします。Repository lifecycle CurrentはQ6_Kの1件を維持します。
- Selectorは個別loaderをCALLするだけとし、LM Studio設定ロジックやPower Limit操作を持たせません。Safeは上書きせず、Coding-FastはGeneral Defaultにしません。
