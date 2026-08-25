# RTX3090 Remote Node Loaders

## Daily use

MAINからは `00-Daily-Profiles/Profile-Selector_REMOTE.bat`、BLUE実機上では `00-Daily-Profiles/Profile-Selector_LOCAL.bat` から Stable / Turbo / Quality Reference の3 Profileだけを選択してください。既存のmodel別directoryはAdvanced / Fallback / Researchとbenchmark再現用に保持します。

`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104 / RTX 3090 24 GB`上で実行するLM Studio loaderを、モデル・量子化別に管理します。

## Directory convention

```text
RTX3090/
  00-Daily-Profiles/
  Qwen3.8-JonathanColetti-Q5KM-Vision/
  Qwen3.8-JonathanColetti-Q6K-Vision/
  Qwen3.8-JonathanColetti-Q4KM/
  Qwen3.8-HauhauCS-Aggressive-Q4KP/
```

新しいモデルや量子化を評価する場合は既存ディレクトリを上書きせず、`<Model-Variant-Quantization>/`を追加します。通常のBAT名は`<Model-Identifier>_<Context>K.bat`形式とし、`Light`、`Normal`、`VRChat`などの用途語はREADMEで管理します。同一モデル・Contextに明示的PowerまたはOperational tierを分ける場合だけ、`_<Power>W`、`_<Power>W-Performance`、`_<Power>W-Balanced`、`_<Power>W-Coding-Fast`をContext後へ付加します。

## Runtime boundary

- BATはRTX3090 PC上で実行します。メインPCのRTX5090 LM Studioを操作するものではありません。
- 実行すると`lms unload --all`で、そのnode上のロード済みモデルを解除します。
- GGUF、Vision projector、LM Studio実データ、SDK dependencyはこのリポジトリに保存しません。
- Zoo Code Base URLは`http://192.168.0.104:1234`です。
- API identifierはモデルごとに一意にし、RTX5090 localhost CurrentのIDを流用しません。Zoo Codeが既定8Kの別instanceを暗黙ロードしないよう、loaderとprofileで同じnatural identifierを使用します。

各BATはnode外部の公式SDK環境に配置したmanaged loaderを使い、K/V cache、MTP draft、eval batch、Flash Attention ON、KV GPU offload ON、parallel 1をprofileごとに明示します。`lms load` CLI単独ではこれらを十分に固定できないためです。Q5_K_M Vision 96KとQ6_K Vision 64Kのloaderはさらにmmap OFFとRTX3090→RTX3060の正式なper-load `priorityOrder`を監査します。effective ubatch 512はbackend/API auditで確認し、helperへ独自ubatch設定機能は追加しません。runtime device IDは固定せずGPU名から解決します。

BLUE Recommended ProductionはJonathan Q5_K_M Vision / 96K / MTP3 / Q8_0 / eval batch1024 / dual GPUです。Q6_K Balanced 64KはQuality/Performance Reference、既存MTP2 / Q8 / batch512はSafe、MTP3 / Q4 / batch512は明示的Coding-Fastとして保持します。Jonathan Q4_K_M 32Kも旧fallbackとして残します。Q6_K Q8は80K～88Kもcapacity gateを通過しましたが、Q6_Kの96K/128KはShared gate FAILです。別量子化のQ5_K_M 96Kは独立qualificationでStrict PASSしたため、専用loaderを提供します。

Q6_K Vision 64KのSafe/Balanced/Coding-Fast Power LimitはRTX3090 `259W`、RTX3060 `170W`です。明示選択用にRTX3090 `370W` / RTX3060 `170W`のPerformance overrideを独立分離しています。Balanced/Coding-Fastと370Wは未A/Bのため組み合わせません。loaderはGPU indexを固定せず、GPU名・PCI Bus IDで照合したRTX3090 UUIDだけへPower Limitを設定し、RTX3060が170Wのままであることを確認してからモデルをロードします。MAINからはREMOTE個別loaderまたはREMOTE selectorを使い、SSH Alias、hostname、IPv4を照合して起動できます。旧`_64K.bat` / `_64K_REMOTE.bat`は259W Safe互換エイリアスです。
