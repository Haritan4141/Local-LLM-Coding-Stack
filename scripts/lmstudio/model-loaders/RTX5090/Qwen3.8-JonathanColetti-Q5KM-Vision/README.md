# Qwen3.8 JonathanColetti Q5_K_M Vision Candidate loaders

RTX 5090 32 GBで96K contextとWindows操作余裕の両立を評価する、JonathanColetti Q5_K_M専用Candidateです。CurrentのQ6_K本体、Q6_K Vision model枠、loader、API IDは変更しません。

| Item | Value |
|---|---|
| Model | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Revision | `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3` |
| Quantization | `Q5_K_M` |
| Model size | 19,535,701,408 bytes |
| Model SHA-256 | `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547` |
| Vision projector | `Qwen3.8-27B-Uncensored-vision-f16.gguf` |
| Projector size | 927,606,912 bytes |
| Projector SHA-256 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |
| LM Studio model key | `qwen3.8-27b-uncensored-vision-q5km` |
| API identifier | `qwen3.8-27b-uncensored-vision-q5km` |
| KV cache | `Q8_0 / Q8_0`, GPU offload ON |
| Flash Attention | ON |
| GPU offload | maximum / all layers |
| MTP | OFF（Q5_K_M 96K実測でONより18.1%高速） |
| Draft setting | max draft tokens 2（MTP OFF時は非使用） |
| Parallel | 1 |
| Vision | LM Studio catalogで`vision = true`を確認 |

## Presets

| BAT | Context | Intended use | Status |
|---|---:|---|---|
| `Qwen3.8-JonathanColetti-Q5KM-Vision_32K.bat` | 32,768 | 軽量比較・fallback評価 | Loader検査済み / 推論未実測 |
| `Qwen3.8-JonathanColetti-Q5KM-Vision_64K.bat` | 65,536 | Q6_K Vision 64Kとの同Context比較 | Loader検査済み / 推論未実測 |
| `Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat` | 98,304 | 通常利用Candidate。長いGoose agent loop向け | 実測PASS / 推奨Candidate |

96Kの固定text fixtureでは、MTP OFFが53.74 tok/s・Peak 25,876 MiB、MTP ONが45.52 tok/s・Peak 27,265 MiBでした。MTP ONのdraft acceptanceは78.25%でしたが、この量子化では速度とVRAMの両方で不利なため、全Candidate loaderをMTP OFFに統一します。同条件のQ6_K Vision / MTP ONは60.82 tok/s・Peak 29,720 MiBで、Q5_K_Mは約11.6%遅い代わりに3,844 MiBのPeak VRAMを節約しました。

96Kでは70,081 input tokensのneedle test、Vision fixture 7/7、direct Tool Calling、Gooseの複数ファイルAgentic Coding fixture（最終10/10）に成功しました。Reasoning Budget 8,192ではQ5_K_Mと同条件Q6_Kの双方が最終回答前に上限へ達したため、量子化固有の回帰とは断定せず未解決事項として残します。詳細は`benchmarks/results/2026-08-24-rtx5090-jonathan-q5km-vision.md`を参照してください。

`Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.bat`は、Goose Desktopが閉じていることを確認し、96K/Q8_0/Q8_0/MTP OFF/Vision/parallel 1をpreflightしてから、子プロセス限定で`GOOSE_CONTEXT_LIMIT=90112`と`GOOSE_MAX_TOKENS=16384`を渡します。Gooseの永続configと既存`Goose Vision 64K`ショートカットは変更しません。

## 通常のGoose起動を使う場合

黒いlauncher consoleとGooseを分離し、LM Studio loaderと通常のGoose shortcutを手動で使う場合は、先に`Set-Goose-Profile-Q5KM-Vision96K.bat`を実行します。このprofile selectorはLM Studioをloadせず、Gooseを起動しません。永続Goose configの`lmstudio` model、client context limit、max output、compact thresholdだけを次へ切り替えて終了します。

| Goose setting | Q5_K_M Vision 96K value |
|---|---:|
| Model | `qwen3.8-27b-uncensored-vision-q5km` |
| `GOOSE_CONTEXT_LIMIT` | 90,112 |
| `GOOSE_MAX_TOKENS` | 16,384 |
| `GOOSE_AUTO_COMPACT_THRESHOLD` | 0.3 |

1. Goose Desktopを完全終了する。
2. `Set-Goose-Profile-Q5KM-Vision96K.bat`を実行する。
3. `Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat`でLM Studioをloadする。
4. 通常のGoose shortcutから起動し、新しいchatを開始する。

変更前configはrepository外の`%LOCALAPPDATA%\Local-LLM-Coding-Stack\goose-config-backups\`へ日時付きで保存します。Goose起動中は変更しません。Q6_K Vision 64Kへ戻す場合は、隣の`Qwen3.8-JonathanColetti-Q6K-Vision\Set-Goose-Profile-Q6K-Vision64K.bat`を使ってから64K loaderを実行します。

## Runtime behavior and data boundary

各BATは`lms unload --all`後にrepository rootの`Load-ManagedModel.mjs`を実行するため、LM Studio runtime stateを変更します。別の推論中には実行しないでください。

Q5_K_M本体と公式Vision projectorはHugging Face cacheおよびLM Studio外部モデル領域に置き、LM Studio用model枠ではNTFSハードリンクを使用します。GGUF、projector、LM Studio application data、cacheをGitへ保存しません。
