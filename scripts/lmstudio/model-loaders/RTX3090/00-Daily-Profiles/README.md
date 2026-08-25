# BLUE Daily Profiles

## 普段はこの3 Profileだけ使う

| Profile | Runtime | Model | Context | Use | Status |
|---|---|---|---:|---|---|
| Stable | LM Studio | Q5_K_M Vision | 96K | Recommended | ACTIVE / RECOMMENDED |
| Turbo | official pinned llama.cpp | Q5_K_M Vision | 96K | Fast | ACTIVE / EXPLICIT |
| Quality Reference | LM Studio | Q6_K Vision Balanced | 64K | Quality comparison | ACTIVE / REFERENCE |

- Stable: 迷ったらこれ。BLUE Recommended Productionとrollbackです。
- Turbo: Coding / Agent / Vision / 長文生成を速くしたい時に明示選択します。
- Quality Reference: Q5の回答に違和感がある時、Q6_Kで比較します。

Quality ReferenceはStableより常に高品質であることを保証しません。より高精度なquantizationの比較基準です。Contextは64Kなので、64Kを超えるtaskの直接比較には使用しません。

MAINからの日常運用は `Profile-Selector_REMOTE.bat` を使用します。BLUE実機上では `Profile-Selector_LOCAL.bat` を使用します。

## Local and remote launchers

| Profile | BLUE local | MAIN to BLUE remote |
|---|---|---|
| Stable | `1-Stable.bat` | `1-Stable_REMOTE.bat` |
| Turbo | `2-Turbo.bat` | `2-Turbo_REMOTE.bat` |
| Quality Reference | `3-Quality-Reference.bat` | `3-Quality-Reference_REMOTE.bat` |

Daily wrapperは既存canonical BATをCALLし、load configurationを複製しません。Quality Referenceはownership確認付きhelperでmanaged BLUE Turboを安全停止します。REMOTEはさらにMAIN tunnelを検証付きで停止し、MAIN 18081 / BLUE 18080の解放後だけQ6 Balanced REMOTEをCALLします。Firewallは変更しません。

Q6 Safe、Coding-Fast、370W Performance、Jonathan Q4、HauhauCS、旧aliasはAdvanced / Fallback / Researchとして既存pathに保全されています。
