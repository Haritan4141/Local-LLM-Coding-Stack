# Qwen3.8 Model Loader Navigation

## Daily entry points

普段は Stable / Turbo / Quality Reference の3 Profileを使い、作業終了時は同じselectorのReleaseでloaded modelを解放できます。

Goose Desktopから使う場合の日常統合入口は`00-Goose-Daily-Profiles.bat`です。MAIN/BLUEのruntime選択、provider/model/context/output/endpoint cross-check、Goose設定、Goose Desktop起動まで一括実行します。Stable/QualityはLM Studio provider、Turboは永続configを変更しないprocess-local `openai` providerです。

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

各Daily selectorの`[4] Release`はProfileではなく終了操作です。idle/queued/prediction状態とmanaged process ownershipを検証し、LM Studioのloaded modelまたはmanaged Turboだけを解放します。BLUE REMOTEでは管理対象MAIN tunnelも解放します。LM Studio server、Firewall、Power Limit、Goose設定は変更しません。

| Category | Retained examples |
|---|---|
| Fallback | Q6 Safe、Jonathan Q4_K_M、旧alias |
| Advanced | Q6 Coding-Fast、BLUE 370W Performance、旧context-specific loader |
| Research / Candidate | HauhauCS variants |
| Experimental | DFlash2 separate research track |
| Research result only | n-gram Coding specialization — NO PROFILE |

実装・設定値・runtime side effectの詳細は、各host README、各model directory README、および `scripts/standalone-turbo/README.md` を参照してください。Daily wrapperは設定を複製せず、既存canonical BATだけをCALLします。
