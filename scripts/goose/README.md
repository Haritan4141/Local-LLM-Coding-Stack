# Goose Daily Profiles

`scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`は、Gooseの日常統合入口です。Gooseを完全終了した状態でProfileを1つ選ぶと、既存canonical runtime wrapperの実行、runtime/provider/model/context/output/endpointのcross-check、Goose client設定、Goose Desktop起動までを順に行います。

## Menu

| Choice | Target / profile | Runtime | Goose provider | Runtime / output |
|---:|---|---|---|---:|
| 1 | MAIN Stable | LM Studio | `lmstudio` | 96K / 16K |
| 2 | MAIN Stable | LM Studio | `lmstudio` | 96K / 32K |
| 3 | MAIN Turbo | official llama.cpp | `openai`（process-local） | 96K / 16K |
| 4 | MAIN Turbo | official llama.cpp | `openai`（process-local） | 96K / 32K |
| 5 | MAIN Quick Response Candidate | official llama.cpp / Q5_K_M Vision | `openai`（process-local） | 64K / 8K |
| 6 | MAIN Quality Reference | LM Studio Q6_K Vision | `lmstudio` | 64K / 32K |
| 7 | BLUE Stable | BLUE LM Studio | `custom_lm_studio_3090_remote` | 96K / 16K |
| 8 | BLUE Stable | BLUE LM Studio | `custom_lm_studio_3090_remote` | 96K / 32K |
| 9 | BLUE Turbo | BLUE official llama.cpp + MAIN tunnel | `openai`（process-local） | 96K / 16K |
| 10 | BLUE Turbo | BLUE official llama.cpp + MAIN tunnel | `openai`（process-local） | 96K / 32K |
| 11 | BLUE Quick Response Candidate | BLUE official llama.cpp + MAIN tunnel / Q5_K_M Vision | `openai`（process-local） | 64K / 8K |
| 12 | BLUE Quality Reference | BLUE LM Studio Q6_K Vision | `custom_lm_studio_3090_remote` | 64K / 32K |
| 13 | BLUE Extended Context Candidate | BLUE official llama.cpp + MAIN tunnel / IQ4_XS Vision | `openai`（process-local） | 256K / 16K |
| 0 | Cancel | 変更なし | 変更なし | 起動なし |

BLUE Quality Referenceは、新規runtimeの発明ではありません。既存のBLUE Q6 Balanced REMOTE wrapper、既存API ID `qwen3.8-27b-uncensored-vision-blue`、既存custom provider model定義を組み合わせます。

## Runtime and provider behavior

Extended ContextはIQ4_XS＋F16 Vision、Q8 KV、draft F16、MTP3、batch1024/ubatch256、split75:25、Reasoning OFFの試用Candidateです。runtime262,144に対しGoose client237,568（232K）／output16,384／reserve8,192、compact0.6（user-approved trial）をprocess限定適用。既存Global configと通常shortcutは変更しません。別BLUE runtimeからはGoose終了後にruntime selector `[5] Release`を明示選択してください。起動/reuse時のShared/free-VRAM gateは維持し、watchdog/自動復旧は追加しません。Goose Vision/compaction/長時間受入はPendingで、Q5 Stableの置換ではありません。

StableとQuality ReferenceはLM Studioを使用します。既存`Set-GooseProfile.ps1`で永続Goose configを同期し、変更前ファイルを`%LOCALAPPDATA%\Local-LLM-Coding-Stack\goose-config-backups\`へ保存します。Q5のGoose client contextは90,112、Q6は64,512、compact thresholdは0.3です。

Turboは既存`Start-Goose-ManagedTurbo.ps1`をSource of Truthとして使用し、永続Goose configを変更しません。Goose Desktop子processだけへ`openai` provider、Turbo alias、client context 90,112、選択したmax output 16,384または32,768、compact threshold 0.3、temperature 0を渡します。MAIN endpointは`http://127.0.0.1:18080`、BLUEはMAIN tunnelの`http://127.0.0.1:18081`です。Turbo 32Kは両PCで17K超のGoose出力を完走した明示選択profileです。既存16Kを通常選択として維持します。

Quick Responseは同じprocess-local経路を使うCandidateです。総合受入は未完了で、圧縮の限定評価とは区別します。Q5_K_M本体と既存F16 Vision projectorを65,536 context、Q8_0/Q8_0、MTP draft 1、Reasoning ON / effort low / budget 2,048、Prompt cache ONで起動します。Gooseへは57,344 client contextと8,192 max outputを渡します。Goose Desktop v1.49ではMAINを`qwen3.8-27b-uncensored-vision-q5km-quick-gpt-4o`、BLUEを`qwen3.8-27b-uncensored-vision-q5km-blue-quick-gpt-4o`として表示します。末尾の`gpt-4o`だけがVision能力判定用で、実際に動くモデルはJonathanColetti Qwen3.8 Q5_K_M Visionです。これはOpenAIモデルへ切り替える設定ではありません。画像経路の再実測完了までは「Vision検証済み」ではなく評価対象として扱い、Codingや長いAgent loopにはStable/Turboを使用してください。

16Kは通常作業、32Kは16K到達で不完全終了したAgent作業向けです。Max outputを変更してもLM Studio load時のKV CacheやモデルVRAM割当は変わりませんが、実際に長く生成すればsession contextと処理時間を多く消費します。

## Safety

- Goose processが1件でもあれば、runtime変更前にfail closedします。Gooseを自動終了しません。
- Stable/Qualityは、LM Studioで対象modelだけがcontext・parallel 1・Vision・idle/queued 0条件を満たすことと、API endpointのeffective stateを確認してからGooseを起動します。
- Turbo/Quickはmanaged runtimeのownership、health、alias、context、parallel 1、期待するVision状態、portを確認し、永続Goose configのSHA-256が不変であることを確認します。
- BLUEは`pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`を照合します。
- 不一致時はGooseを起動しません。Firewall、Power Limitの既定値、driver、モデル本体は変更しません。
- `[0] Cancel`はruntime、provider、Goose config、processを変更せずexit code 0で終了します。

既存`Set-Goose-Profile-Q5KM-Vision96K.bat`、`Set-Goose-Profile-Q6K-Vision64K.bat`、個別Daily runtime selector、Turbo専用launcherは互換・保守用入口として保持します。

## Compaction evaluation helpers

`Measure-GooseCompactionBudget.ps1`は読み取り専用です。Dailyの13プロファイルをASTとcanonical manifestで読み、次の最大出力と追加8Kの増分を予約して圧縮候補値を計算します。モデルをロードせず、Goose設定も変更しません。8Kの増分は計画上の仮定であり、無制限のTool loopに対する安全保証ではありません。

`Invoke-GooseCompactionQualification.ps1`は**実機評価用**です。Goose Desktopを完全終了し、別途明示的にロードしたidle endpointだけに合成入力を送ります。`GOOSE_PATH_ROOT`でuser設定・session・extensionから隔離し、system configが存在する場合は停止、追加configの環境変数は評価process内だけで除外します。対象CLIのv1.52.0と、個人の設定ファイルのSHA-256不変も確認します。モデルの起動・停止や本番プロファイル変更は行いませんが、モデルに推論負荷をかけるため通常の読み取りチェックではありません。`Read-GooseCompactionEvidence.py`はその隔離sessionのSQLiteをread-onlyで照合します。

ここでのQuick圧縮・短い再開の測定は、上記Quick CandidateのVision end-to-end、応答速度、長いAgent loopの総合受入とは別です。「全機能の実測完了」やProduction昇格として扱いません。

評価方針と実測の限界は[2026-10-01の調査](../../research/2026-10-01-goose-compaction-evaluation.md)に記録します。候補値はDailyへ自動適用しておらず、既存12組の圧縮閾値は30%のままです。例外はユーザー承認の新BLUE IQ4_XS256K trialだけで、60%をprocess限定適用します。
