# Goose Daily Profiles

`scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`は、Gooseの日常統合入口です。Gooseを完全終了した状態でProfileを1つ選ぶと、既存canonical runtime wrapperの実行、runtime/provider/model/context/output/endpointのcross-check、Goose client設定、Goose Desktop起動までを順に行います。

## Menu

| Choice | Target / profile | Runtime | Goose provider | Runtime / output |
|---:|---|---|---|---:|
| 1 | MAIN Stable | LM Studio | `lmstudio` | 96K / 16K |
| 2 | MAIN Stable | LM Studio | `lmstudio` | 96K / 32K |
| 3 | MAIN Turbo | official llama.cpp | `openai`（process-local） | 96K / 16K |
| 4 | MAIN Quality Reference | LM Studio Q6_K Vision | `lmstudio` | 64K / 32K |
| 5 | BLUE Stable | BLUE LM Studio | `custom_lm_studio_3090_remote` | 96K / 16K |
| 6 | BLUE Stable | BLUE LM Studio | `custom_lm_studio_3090_remote` | 96K / 32K |
| 7 | BLUE Turbo | BLUE official llama.cpp + MAIN tunnel | `openai`（process-local） | 96K / 16K |
| 8 | BLUE Quality Reference | BLUE LM Studio Q6_K Vision | `custom_lm_studio_3090_remote` | 64K / 32K |
| 0 | Cancel | 変更なし | 変更なし | 起動なし |

BLUE Quality Referenceは、新規runtimeの発明ではありません。既存のBLUE Q6 Balanced REMOTE wrapper、既存API ID `qwen3.8-27b-uncensored-vision-blue`、既存custom provider model定義を組み合わせます。

## Runtime and provider behavior

StableとQuality ReferenceはLM Studioを使用します。既存`Set-GooseProfile.ps1`で永続Goose configを同期し、変更前ファイルを`%LOCALAPPDATA%\Local-LLM-Coding-Stack\goose-config-backups\`へ保存します。Q5のGoose client contextは90,112、Q6は64,512、compact thresholdは0.3です。

Turboは既存`Start-Goose-ManagedTurbo.ps1`をSource of Truthとして使用し、永続Goose configを変更しません。Goose Desktop子processだけへ`openai` provider、Turbo alias、client context 90,112、max output 16,384、compact threshold 0.3、temperature 0を渡します。MAIN endpointは`http://127.0.0.1:18080`、BLUEはMAIN tunnelの`http://127.0.0.1:18081`です。Turbo 32Kは未qualificationのためDaily menuへ追加しません。

16Kは通常作業、32Kは16K到達で不完全終了したAgent作業向けです。Max outputを変更してもLM Studio load時のKV CacheやモデルVRAM割当は変わりませんが、実際に長く生成すればsession contextと処理時間を多く消費します。

## Safety

- Goose processが1件でもあれば、runtime変更前にfail closedします。Gooseを自動終了しません。
- Stable/Qualityは、LM Studioで対象modelだけがcontext・parallel 1・Vision・idle/queued 0条件を満たすことと、API endpointのeffective stateを確認してからGooseを起動します。
- Turboはmanaged runtimeのownership、health、alias、context、parallel 1、Vision、portを確認し、永続Goose configのSHA-256が不変であることを確認します。
- BLUEは`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`を照合します。
- 不一致時はGooseを起動しません。Firewall、Power Limitの既定値、driver、モデル本体は変更しません。
- `[0] Cancel`はruntime、provider、Goose config、processを変更せずexit code 0で終了します。

既存`Set-Goose-Profile-Q5KM-Vision96K.bat`、`Set-Goose-Profile-Q6K-Vision64K.bat`、個別Daily runtime selector、Turbo専用launcherは互換・保守用入口として保持します。
