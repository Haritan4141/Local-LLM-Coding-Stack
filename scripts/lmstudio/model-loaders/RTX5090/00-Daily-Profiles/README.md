# RTX5090 Daily Profiles

## 普段はこの3 Profileだけ使う

| Profile | Runtime | Model | Context | Use | Status |
|---|---|---|---:|---|---|
| Stable | LM Studio | Q5_K_M Vision | 96K | Recommended | ACTIVE / RECOMMENDED |
| Turbo | official pinned llama.cpp | Q5_K_M Vision | 96K | Fast | ACTIVE / EXPLICIT |
| Quality Reference | LM Studio | Q6_K Vision Balanced | 64K | Quality comparison | ACTIVE / REFERENCE |

- Stable: 迷ったらこれ。管理性とrollbackを優先した日常defaultです。
- Turbo: Coding / Agent / Vision / 長文生成を速くしたい時に明示選択します。
- Quality Reference: Q5の回答に違和感がある時、Q6_Kで比較します。

Quality ReferenceはStableより常に高品質であることを保証する名称ではありません。より高精度なquantizationを比較基準にするProfileです。Contextは64Kなので、64Kを超えるtaskの直接比較には使用しません。

## Launchers

| File | Canonical target |
|---|---|
| `1-Stable.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat` |
| `2-Turbo.bat` | `../Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat` |
| `3-Quality-Reference.bat` | safe managed-Turbo stop, then `../Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat` |
| `Profile-Selector.bat` | the three wrappers above only |

Daily wrapperにload configurationはありません。既存canonical BATをsingle source of truthとしてCALLします。Quality Referenceだけは、未知processを停止しないownership検証付きhelperでmanaged Turboとport 18080/VRAMを解放してからQ6 BalancedをCALLします。未知listener/processならfail closedです。

Q6 Safe、Coding-Fast、HauhauCS、旧context loader等はAdvanced / Fallback / Researchとして既存pathに保全されています。
