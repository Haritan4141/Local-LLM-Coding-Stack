# RTX3090 Remote Node Loaders

`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104 / RTX 3090 24 GB`上で実行するLM Studio loaderを、モデル・量子化別に管理します。

## Directory convention

```text
RTX3090/
  Qwen3.8-JonathanColetti-Q4KM/
  Qwen3.8-HauhauCS-Aggressive-Q4KP/
```

新しいモデルや量子化を評価する場合は既存ディレクトリを上書きせず、`<Model-Variant-Quantization>/`を追加します。BAT名は`<Model-Identifier>_<Context>K.bat`形式とし、`Light`、`Normal`、`VRChat`などの用途語はREADMEで管理します。

## Runtime boundary

- BATはRTX3090 PC上で実行します。メインPCのRTX5090 LM Studioを操作するものではありません。
- 実行すると`lms unload --all`で、そのnode上のロード済みモデルを解除します。
- GGUF、Vision projector、LM Studio実データ、SDK dependencyはこのリポジトリに保存しません。
- Zoo Code Base URLは`http://192.168.0.104:1234`です。
- API identifierはモデルごとに一意にし、RTX5090 localhost CurrentのIDを流用しません。Zoo Codeが既定8Kの別instanceを暗黙ロードしないよう、loaderとprofileで同じnatural identifierを使用します。

各BATはnode外部の公式SDK環境に配置したmanaged loaderを使い、Q8_0/Q8_0、Flash Attention ON、KV GPU offload ON、parallel 1、embedded MTP max draft 2を明示します。`lms load` CLI単独ではK/V cache量子化を指定できないためです。ロード後は`lms ps`で単一モデル、意図したcontext、`PARALLEL 1`を確認してください。

32Kを通常値、64Kを単独長context用とします。96Kは24GBで安全余裕が不足するため作成していません。評価後の推奨はJonathan Q4_K_M 32Kです。
