# Qwen3.8 Model Loader Navigation

## Daily entry points

普段は Stable / Turbo / Quality Reference の3 Profileだけを使います。

| Target | Recommended entry point |
|---|---|
| RTX5090 MAIN | `RTX5090/00-Daily-Profiles/Profile-Selector.bat` |
| BLUE from MAIN | `RTX3090/00-Daily-Profiles/Profile-Selector_REMOTE.bat` |
| BLUE local | `RTX3090/00-Daily-Profiles/Profile-Selector_LOCAL.bat` |

Directory直下のone-click入口も同じselectorをCALLします。

- `00-RTX5090-Daily-Profiles.bat`
- `00-BLUE-Daily-Profiles-REMOTE.bat` — MAINからの日常入口
- `00-BLUE-Daily-Profiles-LOCAL.bat` — BLUE実機上で使う場合

StableはLM StudioのRecommended、Turboはofficial pinned llama.cppの明示選択、Quality ReferenceはQ6_K Vision 64K Balancedによる品質比較です。Operational Profileの整理であり、repository lifecycle `Current`は変更しません。

## Implementation / Advanced

既存model directoryとloader pathはbenchmark再現・rollback・互換性のため保持します。Daily selectorへ表示しない項目も削除・改名・移動しません。

| Category | Retained examples |
|---|---|
| Fallback | Q6 Safe、Jonathan Q4_K_M、旧alias |
| Advanced | Q6 Coding-Fast、BLUE 370W Performance、旧context-specific loader |
| Research / Candidate | HauhauCS variants |
| Experimental | DFlash2 separate research track |
| Research result only | n-gram Coding specialization — NO PROFILE |

実装・設定値・runtime side effectの詳細は、各host README、各model directory README、および `scripts/standalone-turbo/README.md` を参照してください。Daily wrapperは設定を複製せず、既存canonical BATだけをCALLします。
