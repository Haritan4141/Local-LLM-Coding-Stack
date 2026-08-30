# BLUE Daily Profiles

## 3 Profile + Release operation

| Profile | Runtime | Model | Context | Use | Status |
|---|---|---|---:|---|---|
| Stable | LM Studio | Q5_K_M Vision | 96K | Recommended | ACTIVE / RECOMMENDED |
| Turbo | official pinned llama.cpp | Q5_K_M Vision | 96K | Fast | ACTIVE / EXPLICIT |
| Quality Reference | LM Studio | Q6_K Vision Balanced | 64K | Quality comparison | ACTIVE / REFERENCE |

- Stable: 迷ったらこれ。BLUE Recommended Productionとrollbackです。
- Turbo: Coding / Agent / Vision / 長文生成を速くしたい時に明示選択します。
- Quality Reference: Q5の回答に違和感がある時、Q6_Kで比較します。
- Release: 作業終了時に、idle状態のBLUE LM Studio modelまたは管理対象Turboを解放します。新しいProfileはロードしません。

MAINの通常のGoose Desktop shortcutでStableを使う場合は、先に`../../00-Goose-Daily-Profiles.bat`でBLUE `96K / 16K`または`96K / 32K`を同期します。Goose client profileとBLUE LM Studio runtimeは意図的に分離しており、このDaily selectorはGoose設定を変更しません。

Quality ReferenceはStableより常に高品質であることを保証しません。より高精度なquantizationの比較基準です。Contextは64Kなので、64Kを超えるtaskの直接比較には使用しません。

MAINからの日常運用は `Profile-Selector_REMOTE.bat` を使用します。BLUE実機上では `Profile-Selector_LOCAL.bat` を使用します。

## Local and remote launchers

| Profile | BLUE local | MAIN to BLUE remote |
|---|---|---|
| Stable | `1-Stable.bat` | `1-Stable_REMOTE.bat` |
| Turbo | `2-Turbo.bat` | `2-Turbo_REMOTE.bat` |
| Quality Reference | `3-Quality-Reference.bat` | `3-Quality-Reference_REMOTE.bat` |
| Release | `4-Release.bat` | `4-Release_REMOTE.bat` |

Daily wrapperは既存canonical BATをCALLし、load configurationを複製しません。Quality Referenceはownership確認付きhelperでmanaged BLUE Turboを安全停止します。REMOTEはさらにMAIN tunnelを検証付きで停止し、MAIN 18081 / BLUE 18080の解放後だけQ6 Balanced REMOTEをCALLします。Firewallは変更しません。

ReleaseはBLUE側のLM Studioが`status=idle/loaded`かつ`queued=0`、またはTurboの`is_processing=false`を確認してからだけ動作します。Windows PowerShell 5.1のtop-level JSON arrayもslot単位へ展開して判定します。推論中、queued request、未知listener/PID、host/IP不一致では何も停止せずエラー終了します。REMOTEでは管理対象Turboの停止後に、ownershipを検証したMAIN tunnel 18081も解放します。LM Studio server自体とFirewallは変更しません。実行結果は各実行PCの`%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs`へ保存し、失敗時は画面を閉じる前にpauseします。

Q6 Safe、Coding-Fast、370W Performance、Jonathan Q4、HauhauCS、旧aliasはAdvanced / Fallback / Researchとして既存pathに保全されています。

## Turbo起動時のGPUメモリー検査エラー

`[2] Turbo`で`[TURBO_VRAM_RESIDENCY]`が出た場合、各GPUの現在使用量と最低基準値を確認してください。基準はRTX3090が12,000 MiB、RTX3060が6,000 MiBです。「空きVRAMが不足」という意味ではなく、起動済みモデルに期待するGPU使用量を確認できない状態です。APIが応答していても、再利用時にこの検査へ通らなければ起動成功とは表示しません。

Gooseの生成・待ち行列を終了してから、**このruntimeメニューの`[4] Release` → `[2] Turbo`**を明示選択してください。Goose側メニューの番号とは異なります。自動停止・自動再試行はせず、Releaseが推論中や未知PID等を理由に拒否した場合は強制終了しないでください。

Remote起動失敗の全文はMAINの`%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo\logs\blue-remote-start-failed-*.log`へ保存し、パスを画面に表示します。BLUE側の起動ログがある場合はそのパスも表示します。失敗時の画面はキーを押すまで残ります。
