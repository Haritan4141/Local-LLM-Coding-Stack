# RTX5090 Daily Profiles

## 3 Profile + Release operation

| Profile | Runtime | Model | Context | Use | Status |
|---|---|---|---:|---|---|
| Stable | LM Studio | Q5_K_M Vision | 96K | Recommended | ACTIVE / RECOMMENDED |
| Turbo | official pinned llama.cpp | Q5_K_M Vision | 96K | Fast | ACTIVE / EXPLICIT |
| Quality Reference | LM Studio | Q6_K Vision Balanced | 64K | Quality comparison | ACTIVE / REFERENCE |

- Stable: 迷ったらこれ。管理性とrollbackを優先した日常defaultです。
- Turbo: Coding / Agent / Vision / 長文生成を速くしたい時に明示選択します。
- Quality Reference: Q5の回答に違和感がある時、Q6_Kで比較します。
- Release: 作業終了時に、idle状態のLM Studio modelまたは管理対象Turboを解放します。新しいProfileはロードしません。

通常のGoose Desktop shortcutを使う場合は、先に`../../00-Goose-Daily-Profiles.bat`でMAIN `96K / 16K`、`96K / 32K`またはQ6 `64K / 32K`を同期します。Goose client profileとLM Studio runtimeは意図的に分離しており、このDaily selectorはGoose設定を変更しません。

Quality ReferenceはStableより常に高品質であることを保証する名称ではありません。より高精度なquantizationを比較基準にするProfileです。Contextは64Kなので、64Kを超えるtaskの直接比較には使用しません。

## Launchers

| File | Canonical target |
|---|---|
| `1-Stable.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat` |
| `2-Turbo.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat` |
| `3-Quality-Reference.bat` | safe managed-Turbo stop, then `../Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat` |
| `4-Release.bat` | release the idle LM Studio model or ownership-validated managed Turbo runtime |
| `Profile-Selector.bat` | the three Profile wrappers plus Release |

Daily wrapperにload configurationはありません。既存canonical BATをsingle source of truthとしてCALLします。Quality Referenceだけは、未知processを停止しないownership検証付きhelperでmanaged Turboとport 18080/VRAMを解放してからQ6 BalancedをCALLします。未知listener/processならfail closedです。

ReleaseはLM Studioの`status=idle/loaded`かつ`queued=0`、またはTurboの`is_processing=false`を確認してからだけ動作します。Windows PowerShell 5.1のtop-level JSON arrayもslot単位へ展開して判定します。推論中、queued request、未知listener/PID、管理state不一致では何も停止せずエラー終了します。LM Studio server自体は停止せず、loaded modelだけをunloadします。実行結果は`%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs`へ保存し、失敗時は画面を閉じる前にpauseします。

Q6 Safe、Coding-Fast、HauhauCS、旧context loader等はAdvanced / Fallback / Researchとして既存pathに保全されています。
