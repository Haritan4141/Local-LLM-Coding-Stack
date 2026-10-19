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

DeepSeek Harness用IQ4_XS Vision256Kは、MAIN入口`00-RTX5090-Daily-Profiles.bat`の`[6]`、またはBLUE入口`00-BLUE-Daily-Profiles-REMOTE.bat`の`[6]`を選択します。起動成功後にDeepSeekの新規Sessionで同じHostのMAIN / BLUE 256Kモデルを選びます。MAIN APIはloopback18080/v1、BLUEは既存SSH forwardのloopback18081/v1です。これらの入口はClientを起動せず、Client設定も変更しません。Stable / Turbo等を選んでもDeepSeekの256K設定は自動で対応するモデルへ変わりません。Goose統合の対応番号はMAIN `[14]` / BLUE `[13]`です。

StableはLM StudioのRecommended、Turboはofficial pinned llama.cppの明示選択、Quality ReferenceはQ6_K Vision 64K Balancedによる品質比較です。Operational Profileの整理であり、repository lifecycle `Current`は変更しません。

## Implementation / Advanced

BLUE追加試用項目: Goose統合`[13] IQ4XS Vision256K / Output16K (Candidate)`、BLUE runtime`[6] Extended Context`。新規`RTX3090/Qwen3.8-JonathanColetti-IQ4XS-Vision/`LOCAL/REMOTE wrapperを使用します。LM Studio標準ロードではなく実測条件のmanaged llama.cpp＋既存SSH tunnelです。Gooseは232K client／16K output／8K reserve／compact0.6（user-approved trial）をprocess限定適用。Q5/Q6/MAINは保全し、別BLUE runtimeからは先に`[5] Release`。詳細とSide effectsは新directory READMEを参照してください。

既存model directoryとloader pathはbenchmark再現・rollback・互換性のため保持します。Daily selectorへ表示しない項目も削除・改名・移動しません。

各Daily selectorの`[5] Release`はProfileではなく終了操作です。idle/queued/prediction状態とmanaged process ownershipを検証し、LM Studioのloaded modelまたはmanaged Turbo/Quickだけを解放します。BLUE REMOTEでは管理対象MAIN tunnelも解放します。LM Studio server、Firewall、Power Limit、Goose設定は変更しません。

| Category | Retained examples |
|---|---|
| Fallback | Q6 Safe、Jonathan Q4_K_M、旧alias |
| Advanced | Q6 Coding-Fast、BLUE 370W Performance、旧context-specific loader |
| Research / Candidate | HauhauCS variants |
| Experimental | DFlash2 separate research track |
| Research result only | n-gram Coding specialization — NO PROFILE |

実装・設定値・runtime side effectの詳細は、各host README、各model directory README、および `scripts/standalone-turbo/README.md` を参照してください。Daily wrapperは設定を複製せず、既存canonical BATだけをCALLします。
