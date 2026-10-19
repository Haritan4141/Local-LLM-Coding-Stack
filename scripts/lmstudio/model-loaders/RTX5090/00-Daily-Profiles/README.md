# RTX5090 Daily Profiles

## 5 Profiles + Release operation

| Profile | Runtime | Model | Context | Use | Status |
|---|---|---|---:|---|---|
| Stable | LM Studio | Q5_K_M Vision | 96K | Recommended | ACTIVE / RECOMMENDED |
| Turbo | official pinned llama.cpp | Q5_K_M Vision | 96K | Fast | ACTIVE / EXPLICIT |
| Quick Response | official pinned llama.cpp | Q5_K_M Vision | 64K / Output 8K | Low-latency chat with images | CANDIDATE / STATIC-ONLY |
| Quality Reference | LM Studio | Q6_K Vision Balanced | 64K | Quality comparison | ACTIVE / REFERENCE |
| Extended Context `[6]` | official pinned llama.cpp | IQ4_XS Vision | 256K / Output 16K | Explicit long-context trial / DeepSeek MAIN | CANDIDATE / SHORT-TESTED |

- Stable: 迷ったらこれ。管理性とrollbackを優先した日常defaultです。
- Turbo: Coding / Agent / Vision / 長文生成を速くしたい時に明示選択します。
- Quick Response: 通常会話・画像入力向けの64K/8K候補です。Reasoning Low（上限2,048）、MTP1、Prompt cache、F16 Vision projectorを使用します。
- Quality Reference: Q5の回答に違和感がある時、Q6_Kで比較します。
- Extended Context: `[6]`で既存MAIN IQ4_XS Vision256K Candidateを起動します。長時間・最大context品質は未合格で、Stableの置換ではありません。
- Release: 作業終了時に、idle状態のLM Studio modelまたは管理対象Turboを解放します。新しいProfileはロードしません。

通常のGoose Desktop shortcutを使う場合は、先に`../../00-Goose-Daily-Profiles.bat`でMAIN `96K / 16K`、`96K / 32K`またはQ6 `64K / 32K`を同期します。Goose client profileとLM Studio runtimeは意図的に分離しており、このDaily selectorはGoose設定を変更しません。

Quality ReferenceはStableより常に高品質であることを保証する名称ではありません。より高精度なquantizationを比較基準にするProfileです。Contextは64Kなので、64Kを超えるtaskの直接比較には使用しません。

## Launchers

| File | Canonical target |
|---|---|
| `1-Stable.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat` |
| `2-Turbo.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat` |
| `Quick-Response.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM_64K_Quick.bat` |
| `3-Quality-Reference.bat` | safe managed-Turbo stop, then `../Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat` |
| `4-Release.bat` | release the idle LM Studio model or ownership-validated managed Turbo runtime |
| `Extended-Context.bat` | `../Qwen3.8-JonathanColetti-IQ4XS-Vision/Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.bat` |
| `Profile-Selector.bat` | the five Profile wrappers plus Release; existing `[1]`–`[5]` / `[0]` mappings unchanged |

DeepSeek Harnessでは`../../00-RTX5090-Daily-Profiles.bat`の`[6]`を選び、起動成功後に新規Sessionで`MAIN RTX5090 - IQ4XS Vision 256K` / `Qwen3.8 27B IQ4_XS Vision - MAIN 256K`を選びます。APIは`http://127.0.0.1:18080/v1`、model IDは`qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o`です。この入口はサーバー用で、Goose / DeepSeekの起動・設定変更はしません。Gooseを同条件で起動する場合は統合入口`../../00-Goose-Daily-Profiles.bat`の`[14]`を使用します。

DeepSeekのMAIN 256K選択はStable / Turbo / Quick / Qualityには自動追従しません。別profileへ切り替える前にClientの処理を停止・終了し、対応する接続先とmodel IDを別途設定してください。Goose / DeepSeekが同じparallel1 serverへ同時推論しないようにします。

Quick ResponseはVision revisionのruntime実測前Candidateです。`[3]`で選択し、Stable/Turbo/Qualityは従来どおり保持します。切替前にはGooseを完全終了し、旧text-only Quickまたは別のmanaged runtimeが動いている場合は`[5] Release`を使用します。

Daily wrapperにload configurationはありません。既存canonical BATをsingle source of truthとしてCALLします。Quality Referenceだけは、未知processを停止しないownership検証付きhelperでmanaged Turboとport 18080/VRAMを解放してからQ6 BalancedをCALLします。未知listener/processならfail closedです。

ReleaseはLM Studioの`status=idle/loaded`かつ`queued=0`、またはTurboの`is_processing=false`を確認してからだけ動作します。Windows PowerShell 5.1のtop-level JSON arrayもslot単位へ展開して判定します。推論中、queued request、未知listener/PID、管理state不一致では何も停止せずエラー終了します。LM Studio server自体は停止せず、loaded modelだけをunloadします。実行結果は`%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs`へ保存し、失敗時は画面を閉じる前にpauseします。

Q6 Safe、Coding-Fast、HauhauCS、旧context loader等はAdvanced / Fallback / Researchとして既存pathに保全されています。
