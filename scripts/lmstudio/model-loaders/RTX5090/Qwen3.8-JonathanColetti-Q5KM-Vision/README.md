# Qwen3.8 JonathanColetti Q5_K_M Vision loaders

Daily operation starts from `../00-Daily-Profiles/Profile-Selector.bat`. This directory remains the canonical Stable/Turbo implementation source; Daily wrappers do not duplicate its load settings.

RTX 5090 32 GBのRecommended Production / Operational ProfileはJonathanColetti Q5_K_M Vision 96Kです。Repository lifecycleは`Candidate`のままとし、唯一の`Current`であるQ6_K本体、Q6_K Vision model枠、loader、API IDを変更・削除しません。

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
| 96K Production MTP | ON / max draft tokens 3（96K final sweepで選定） |
| 96K Production eval / effective ubatch | 1024 / 512 |
| 96K Production mmap / keep in memory | ON / ON（既存mmap+mlock運用） |
| Parallel | 1 |
| Vision | LM Studio catalogで`vision = true`を確認 |

## Presets

| BAT | Context | Intended use | Status |
|---|---:|---|---|
| `Qwen3.8-JonathanColetti-Q5KM-Vision_32K.bat` | 32,768 | 軽量比較・fallback評価 | Loader検査済み / 推論未実測 |
| `Qwen3.8-JonathanColetti-Q5KM-Vision_64K.bat` | 65,536 | Q6_K Vision 64Kとの同Context比較 | Loader検査済み / 推論未実測 |
| `Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat` | 98,304 | 通常利用・長いGoose agent loop | **Recommended Production** |

32K/64Kは過去比較用のMTP OFF loaderとしてそのまま保持し、Production defaultにはしません。最終設定変更は96K loaderだけに適用します。

## Standalone MTP3 Turbo

`Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat`は、official llama.cpp commit `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`の外部runtimeを使う明示選択専用Turboです。Stableと同じmodel/projector、98,304 context、Q8_0/Q8_0、MTP3、batch1024、ubatch512、parallel1、Flash Attention、Visionを、`127.0.0.1:18080`のstandalone serverで実行します。API aliasは`qwen3.8-27b-uncensored-vision-q5km-turbo`です。

`Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat`はmanaged Turboだけを安全停止し、portとVRAM解放後に既存`_96K.bat`をCALLする復旧wrapperです。既存Stable BATは変更していません。selectorはStableをRecommendedの`[1]`、Turboを`[2]`とし、Q6 Balanced/Safe/Coding-Fastを保持します。

Turbo用Gooseは`Start-Goose-Jonathan-Q5KM-Vision96K-Turbo.bat`を使います。built-in `openai` providerへprocess-localで接続し、90,112 context / 16,384 output / compact 0.3を維持します。永続Goose configは変更しません。詳細は`../../../../standalone-turbo/README.md`と`benchmarks/results/2026-08-25-standalone-mtp3-turbo-integration.md`を参照してください。DFlash2は統合していません。

最終sweepは98,304 context、Q8_0/Q8_0、eval batch 2048、effective ubatch 512、parallel 1、Flash Attention/full offload、PL 402W、temperature 0、reasoning OFFを固定し、MTP OFF→2→3→4→OFF sentinelを各workload warm-up 1 + formal 3で比較しました。draft 3はText 46.54、Coding 63.09、Vision 59.10、Long 53.42 tok/s、4-workload geomean 55.18 tok/s、weighted acceptance 84.06%、formal quality 12/12でした。OFF比でTextは8.88%低下しましたが、Coding/Vision/Longは24.03%/16.05%/15.55%向上し、geomeanは約10.97%向上しました。draft 4はgeomean 55.06 tok/s、acceptance 79.93%、Peak 26,692 MiBで、draft 3より総合優位を示さなかったため採用していません。OFF sentinel driftは全workload 0.5%未満です。

draft 3固定のbatch 1024/2048比較では、約24Kの固有nonce付きLong Promptで1024が2,132.05 tok/s・TTFT 11.3648秒、2048が2,129.33 tok/s・11.3727秒でした。速度差がなく1024の方がShared/RAMをわずかに抑えたため、Productionはbatch 1024を採用します。最終設定のload時Dedicated使用量は26,432 MiB、raw headroom 6,175 MiB、420 MiB reserve差引後5,755 MiB（約5.62 GiB）、Shared増分0.309 GiBです。

最終設定ではText/Coding/Vision、69,139 input tokensのLong Context、exact Tool Calling、Gooseの隔離multi-file Agentic Coding（最終10/10）にPASSしました。今回の実用fixtureではPromotionを妨げる品質差を観測していない、という範囲の結論であり、Q5とQ6の完全な品質同等性は主張しません。詳細は`benchmarks/results/2026-08-25-rtx5090-q5km-vision-96k-production.md`を参照してください。過去のCandidate qualificationは`benchmarks/results/2026-08-24-rtx5090-jonathan-q5km-vision.md`に保持します。

互換性のため既存名を保持する`Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.bat`は、Goose Desktopが閉じていることを確認し、96K/Q8_0/Q8_0/MTP3/batch1024/mmap+mlock/Vision/parallel 1をpreflightしてから、子プロセス限定で`GOOSE_CONTEXT_LIMIT=90112`と`GOOSE_MAX_TOKENS=16384`を渡します。Gooseの永続configと既存`Goose Vision 64K`ショートカットは変更しません。

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
