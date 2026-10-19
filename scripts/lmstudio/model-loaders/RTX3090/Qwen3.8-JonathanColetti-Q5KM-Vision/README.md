# JonathanColetti Q5_K_M Vision 96K — BLUE Recommended

Daily operation starts from `../00-Daily-Profiles/Profile-Selector_REMOTE.bat` on MAIN or `../00-Daily-Profiles/Profile-Selector_LOCAL.bat` on BLUE. This directory remains the canonical Stable/Turbo implementation source; Daily wrappers do not duplicate its settings.

BLUE (`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`) のRTX 3090 24 GB + RTX 3060 12 GB dual-GPU専用loaderです。BLUEのRecommended Production profileであり、repository-wide CurrentはRTX5090 JonathanColetti Q6_Kのままです。

| Item | Value |
|---|---|
| Model | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Quantization | `Q5_K_M` |
| Model size / SHA-256 | `19,535,701,408 bytes` / `24780644A95F759A9AEEB228C3D852028F2FD40CE0B74D68134246EC4A959547` |
| Vision projector | `927,606,912 bytes` / `5AC423F8A29059DC24E51BC6A43E9380DCD57A9347F28B62591E0B3F60B7081C`; external LM Studio data only |
| Model key | `qwen3.8-27b-uncensored-vision-q5km` |
| API identifier | `qwen3.8-27b-uncensored-vision-q5km-blue` |
| Base URL | `http://192.168.0.104:1234/v1` |
| Effective profile | 98,304 context; Q8_0/Q8_0; priorityOrder RTX3090→RTX3060; full offload; Flash Attention ON; mmap OFF; keep in memory ON; MTP3; eval batch1024; effective ubatch512; parallel1; Vision true |
| Power | RTX3090 259W / RTX3060 170W |

`Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat`はBLUE上で実行し、`_REMOTE.bat`はMAINから実行します。いずれも最終的に同じ固定profileをロードします。REMOTE launcherはSSH Alias、hostname、IPv4、Power Limit、LAN API上のID/context/parallelを再確認します。

MAINの通常のGoose Desktop shortcutでStableを使う場合は、先に`../../00-Goose-Daily-Profiles.bat`でBLUE `96K / 16K`または`96K / 32K`を選択します。selectorは`custom_lm_studio_3090_remote`のidentityと`http://192.168.0.104:1234/v1/chat/completions`を照合し、API identifier `qwen3.8-27b-uncensored-vision-q5km-blue`、90,112 client context、16,384または32,768 max outputへ同期します。LM Studio runtimeとPower Limitは変更しません。

## Standalone MTP3 Turbo

Turboはofficial llama.cpp commit `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`の外部`sm_86` runtimeを使う明示選択項目です。BLUE localhost `127.0.0.1:18080`だけで待受し、MAINからはmanaged SSH tunnel `127.0.0.1:18081 -> BLUE 127.0.0.1:18080`を使用します。API aliasは`qwen3.8-27b-uncensored-vision-q5km-blue-turbo`です。FirewallとSSH設定は変更しません。

| Operation | BAT |
|---|---|
| BLUE local Turbo | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat` |
| BLUE local Stable | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable.bat` |
| MAIN remote Turbo | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.bat` |
| MAIN remote Stable | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable_REMOTE.bat` |
| MAIN Goose Turbo | `Start-Goose-Jonathan-Q5KM-Vision96K-BLUE-Turbo_REMOTE.bat` |

Turboは98,304 context、Q8_0/Q8_0、MTP3、batch1024、ubatch512、parallel1、Flash Attention、Vision、layer split `0.7108,0.2892`、mmap OFFです。起動時に`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`、両GPUの名前・Bus ID、259W/170W、runtime/model/projector SHAを照合します。StableはRecommendedのままで、Turboはselector `[2]`です。DFlash2は統合していません。詳細は`../../../../standalone-turbo/README.md`を参照してください。

## Quick Response 64K / 8K Candidate

BLUE localでは`Qwen3.8-JonathanColetti-Q5KM_64K_259W_Quick.bat`、MAINからは`Qwen3.8-JonathanColetti-Q5KM_64K_259W_Quick_REMOTE.bat`を使用します。同じQ5_K_M本体とF16 Vision projectorを65,536 runtime context、57,344 Goose client context、8,192 max output、Q8_0/Q8_0、MTP1、Prompt cache ON、Reasoning Low / budget 2,048、parallel 1で起動します。API aliasは`qwen3.8-27b-uncensored-vision-q5km-blue-quick-gpt-4o`です。ローカルQwen名を画面に保ち、末尾の`gpt-4o`だけをGoose Desktop v1.49のVision能力判定へ使用します。実モデルはJonathanColetti Qwen3.8 Q5_K_M Visionのままです。canonical-only `gpt-4o`と旧`qwen3.8-27b-uncensored-q5km-blue-quick`は安全なRelease移行だけに限定します。

GPU名・PCI Bus ID、RTX3090 259W / RTX3060 170W、既存layer split、localhost 18080とMAIN tunnel 18081を維持します。Gooseからは`../../00-Goose-Daily-Profiles.bat`のBLUE Quick Responseを選びます。画像入力に対応しますが、現時点は静的検証済み・Vision revision未実測であり、Codingや長いAgent loopには使用しません。

ローカルloaderはactive/queued predictionがある場合、Power Limitにもruntimeにも触れず停止します。GPUはindexではなく名前 + PCI Bus IDで照合し、RTX3090のUUIDだけを259Wへ設定します。ロード後は公式SDK readbackで全設定とVisionを監査し、`lms ps`のIDLE/queued 0/96K/parallel1、両GPUの専用VRAM residency、Power Limitを確認します。さらにWDDM Shared GPU Memoryを測定し、combined `< 4 GiB`かつ各GPU `<= 2 GiB`を満たさなければ対象instanceをunloadして失敗終了します。

実データとSDK dependencyはGit管理外です。

```text
C:\Users\Atsuki\.lmstudio\models\JonathanColetti\Qwen3.8-27B-Uncensored-GGUF-Vision-Q5KM\
  Qwen3.8-27B-Uncensored-Q5_K_M.gguf
  mmproj-Qwen3.8-27B-Uncensored-vision-f16.gguf

C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk\
  Load-ManagedModel.mjs
  Test-ManagedModel.mjs
  node_modules\@lmstudio\sdk\
```

採用根拠とQ6_K Balancedのfresh comparisonは`benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md`に記録します。Q6_K Balanced 64KはQuality/Performance Reference、Q6_K Safeはknown-good rollback、Coding-Fastと370W Performanceは明示選択用のまま保持します。
