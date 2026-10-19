# 現行構成とGitHub反映前監査 — 2026-10-19

監査時点の状態: `REVIEW_READY_WITH_RUNTIME_AUDIT_DEVIATION`。文書整理・ローカル検証後、ユーザー指定によりstage / commit / push前で停止した。

公開承認追記（2026-10-19）: 監査報告の確認後、ユーザーがcommit / pushを明示指示した。確認済み109ファイルを公開対象とし、下記の監査結果・未確認事項・runtime副作用をそのまま保持する。GitHub反映は実機への配布、runtime操作、Candidate昇格を含まない。

## 範囲と状態の区別

対象は本repositoryの設定・loader・実測・研究記録。隣接する`Local-AI-Agent-Stack`はClient / MCP / Skills / DeepSeekの根拠として読み取り、編集・取込み・commitはしない。家庭内Sheets / Slidesやglobal AGENTSの更新は不要。

| 区分 | 内容 | 今回の扱い |
|---|---|---|
| lifecycle Current | text Jonathan Q6_K、LM Studio、Normal96K / 64K / 32K | 唯一のCurrentとして保持。今日のloaded stateとは別 |
| Recommended Production | MAIN / BLUE Q5_K_M Vision96K、Q8 KV、MTP3 | 2026-08のqualificationに基づく役割を保持。repository lifecycleはCandidate |
| Reference / fallback | Q6 Vision Balanced、permanent Safe、explicit Coding-Fast / BLUE370W | loaderや設定を削除・変更しない |
| Quick Candidate | Q5_K_M Vision64K、Goose入力57,344 / 出力8,192、MTP1 | 初期loadと修正版Desktop画像受入を分ける。昇格しない |
| Extended Candidate | MAIN / BLUE IQ4_XS Vision262,144、Goose入力237,568 / 出力16,384 / reserve8,192 / compact0.6 | BLUEは今回稼働確認。Current / Production昇格ではない |
| Client choice | Goose保存profile、DeepSeek保存default、実session | runtime稼働からClient使用中・defaultを推定しない |

## 実機観測

確認日時: 2026-10-19T17:42–17:48+09:00。hostname、期待IPv4、SSH aliasを照合してから各Nodeを読む。推論、loader、release、retest harnessは実行しない。

- MAIN: `DESKTOP-5NPLIIV / 192.168.0.100`。RTX5090 / PCI `01:00.0`、PL402W、driver610.62。LM Studio実行ファイルProductVersion `0.4.26.0`。standalone `:18080`待受なし。native model APIは全loaded instances空、v0 stateも全not-loaded。model catalogには未登録の別model名もあるが、存在だけで採用・Currentへ登録しない。
- BLUE: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`。RTX3090 / PCI `0B:00.0` / PL259WとRTX3060 / PCI `01:00.0` / PL170W、driver591.86。LM Studio ProductVersion `0.4.25.0`、既存`:1234`待受、native loaded instances0。
- BLUEの既存standalone: external `llama.cpp-f280b269-sm86/llama-server.exe`、loopback `127.0.0.1:18080`。実行ファイルSHAはmanifestの`970fa271...f64154ca4`と一致、build表示`b10615-f280b2698`。API alias `qwen3.8-27b-uncensored-vision-iq4xs-blue-256k-gpt-4o`、Vision true、context262,144、parallel1、1 slot idle。process argsでQ8 K/V、batch1024、ubatch256、MTP draft3、layer split75:25、reasoning budget0を確認。新しいmodel hash再計算、Shared-memory受入、性能・品質測定はしていない。
- MAIN既存SSH forward: `127.0.0.1:18081`から上記BLUE runtimeに到達。`/v1/models`、`/props`、`/slots`とBLUE process / listenerを照合。SSHやFirewallの変更はない。
- GREEN: `pc7600x / DESKTOP-LMB720F / 192.168.0.103`。LM Studio processあり、監査対象port1234 / 18080 / 18081 / 18082の待受なし。モデルロード状態はAPI取得不能で`UNVERIFIED`。本repositoryの旧label REDと`-red` API IDは同一PCを指し、そのまま保持する。
- MAIN Client: Goose Desktop実行ファイル1.52.0、process0。DeepSeek Harness実行ファイルProductVersion0.2.1.0、既存processあり。0.2.0-rc.2で実施した10月11日・18日の受入を今日の版へ自動継承しない。
- Goose保存設定: `custom_lm_studio_3090_remote`、model `qwen3.8-27b-uncensored-vision-q5km-blue`、context90,112 / output16,384 / compact0.3。LM Studio BLUE向け保存profileであり、稼働中standalone256Kとは別。起動していないGooseを接続成功と記録しない。
- DeepSeek保存default: `deepseek-account / deepseek-flash`。`blue-local`の`127.0.0.1:18081/v1`と`main-local`の`127.0.0.1:18080/v1`、各context262,144 / maxTokens16,384は保持。BLUE画像の`requestImageMaxBytes=4194304`も残る。実session選択、履歴、credentialsは監査対象外。

`/v1/models`はLM Studioの未ロードcatalogを返すことがある。loaded0の根拠にはnative `/api/v1/models`のloaded_instancesと`/api/v0/models`のstateを使用した。GREENではAPI取得失敗をloaded0としない。

## 監査中に生じたruntime副作用

読み取り目的のMAIN `lms ps --json`が`Waking up LM Studio service...`を出力し、LM Studio processが2026-10-19T17:42:54+09:00に起動した。返却値は`[]`、後続native APIもloaded0だった。ユーザーの無変更条件から逸脱したため、監査全体を「runtime完全無変更」と記録しない。

監査開始前のMAIN process / listener snapshotがないため、起動前の厳密な状態は復元できない。独断の停止やrollbackは追加のruntime変更になるため行わず、そのまま保持した。以降はLMS CLIを使わず既存listenerへのGETとprocessの読取りに限定した。model load / unload、BLUE server / tunnel操作、Client起動停止、GPU / driver / Firewall / SSH設定変更、downloadはしていない。

## Local-AI-Agent-Stackとの照合

同repositoryの`CURRENT_STATE.md` / `README.md` / `docs/goose.md`には過去の1.50.0やQ6 Vision64K / context64,512の説明が残る。今日の実機設定より優先しない。同repository自身も未コミット変更を含むため、参照した作業ツリー記録がGitHubに公開済みとは限らない。

| 参照した記録 | 得られる根拠 | 今日へ継承しない事項 |
|---|---|---|
| `docs/goose-update-20261001.md` | Goose1.52.0の導入、署名、静的検証 | 当時runtime到達不能。Desktop更新成功は推論・Tool・compactionの合格ではない |
| `docs/goose-shell-guard-20261008.md` / `docs/goose-shell-guard-repair-20261011.md` | process PATH / Git sh / launch-only修復 | mockの起動受入を実モデル新規sessionの合格にしない |
| `docs/deepseek-harness-local-20261011.md` | BLUE standalone18080 → MAIN forward18081、short CLI/native Tool/Image | 長時間loop・compaction・旧session回復は未受入 |
| `docs/main-iq4xs256k-20261011.md` | MAIN独立Candidate、runtime menu6 / Goose14、API/parser修復 | 当時のMAIN default保存は今日のdefaultではない。MAIN Desktop UXはPending |
| `docs/deepseek-image-compatibility-20261018.md` | BLUE PNG/WebP問題の局所回避、4MiB per-image / aggregate20MiB | 全WebP対応・元54-turn session回復・新installed版全受入を意味しない |
| `CURRENT_STATE.md` / formal benchmark | Zoo5/5、Goose4/5、Kilo3/5という歴史的technical completion | 現行Client / modelの順位やwinnerを示さない |

本repositoryの2026-10-06 BLUE256Kはmemoryと209,891-token Tool/Vision chainが成功した一方、coding / 短いtool-enabled control失敗を保持する。MAIN256Kは10月11日のshort API/CLIとmemoryのみ。今日のidle応答で未受入のlong loop、live compaction、Desktop Vision、full256K品質をPASSへ変更しない。

## BLUE配置済みコードと作業ツリーの差

既存配布先`C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo`を読み取り、9ファイルを比較した。`Turbo.Common.psm1`、`Start-ManagedTurbo.ps1`、`Stop-ManagedTurbo.ps1`、`Release-ManagedRuntime.ps1`、`Test-ManagedTurbo.ps1`の5本はbyte hashとLF正規化後hashが両方不一致。単なる改行差ではない。差分の導入経緯・全関数の動作同等性は今回未確定。

`runtime-manifests/BLUE.json`、`BLUE-Quick.json`、`BLUE-IQ4XS256K.json`と`Read-BlueExtendedMemory.py`はbyte一致。稼働processの主要args / alias / contextは上記実機観測とも一致する。この限定比較を全配置物の完全同期や現行loader再試験のPASSとは記録しない。勝手にcopy / deploy / restartせず、将来配布する場合は別途対象・差分・稼働状況を確認する。

## GitHubと未コミット変更

2026-10-19に`git ls-remote`でGitHubを照合した。fetch / pull / resetは不要で、作業ツリーを保持した。

| Repository | local HEAD / origin/main / GitHub main | 差分 |
|---|---|---|
| Local-LLM-Coding-Stack | `8222a56577f65c7e4c38552d7996d968d36a0ec6`（2026-08-30） | ahead0 / behind0。監査開始時はtracked変更45、untracked実ファイル60、staged0 |
| Local-AI-Agent-Stack（参照のみ） | `adde044bb11760d2f6cc4a6de67f2863b1433f9f`（2026-08-24） | local origin/mainとGitHub mainが一致。未コミット文書・Client関連作業あり。本作業では変更しない |

### 既存変更の公開候補群

| 変更群 | 対象と依存関係 | 公開時の意味 |
|---|---|---|
| 2026-09-01 archive routing | research1件 + 既存benchmark4件の外部path更新 | 外部実験記録の移動先を示す。archive実体を含めない |
| 2026-09-07 Quick / lifecycle | Candidate config、MAIN / BLUE manifests、Quick loaders / selectors、common / start / stop / release、tests | profile-family mutex、所有PID cleanup、alias互換、64K/8K。実行コードの変更としてレビューが必要 |
| 2026-10-01 compaction | curated JSON / MD、budget計算、usage-ledger reader、qualification harness、fixtures | 12 profiles×3回の過去isolated実測。候補rateを既存production30%へ適用しない |
| 2026-10-06 BLUE256K | Q4 / IQ4 config、research / results、memory probe、独立manifest / loader、Goose13、offline tests | capacityとqualityの失敗を分ける。live harnessは今回実行しない |
| 2026-10-08 / 11 Client launch | Goose shortcut argument forwarding / process PATH、tests | AgentStackのshell guardと連携。Global Client設定やhookの実体をコピーしない |
| 2026-10-11 MAIN256K | config / manifest / loader / memory probe / transcript verifier、Goose14 / MAIN menu6、results / research / tests | short acceptanceのみ。BLUEやQ5/Q6を上書きしない |
| 2026-10-19 reconciliation | README、CURRENT_STATE、MODEL_REGISTRY、project AGENTS、profiles案内、CHANGELOG、本監査 | 今日の観測と過去baselineの意味を分離。runtimeを配布・変更する作業ではない |

全公開候補のpath / size / SHAと作業開始時からの変更一覧はignored `logs/audit-20261019/`へ保存する。`git add .`で一括選択せず、承認後に対象群を明示し、stageしたdiffを再確認してからcommitする。将来のcommitはmodel downloadやBLUEへのdeployを兼ねない。

## 公開除外と検証

- モデル / tokenizer / projector本体、runtime EXE / DLL、LM Studio app data / cache、downloaded repositoriesを含めない。
- `.local-backups/`、raw evidence、`logs/`、`benchmarks/raw/`、private config / credentials、session DB / personal prompts、node_modules / Python cacheはGit対象外。外部pathとhashの管理記録はpayloadではない。
- 既存追跡ファイルとignoreされない新規ファイルを対象に、禁止payload名・拡張子、private-key / service-token / credential-URL等の高確度patternを検査する。scanは既知patternと対象ファイル範囲の検査であり、任意のSecret不存在の証明とはしない。
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Repository.ps1`はJSON / single Current / no binaryとoffline fixtureを検査する。temp fixture / 子processは使用するが実loader、SSH、GPU設定、推論は実行しない。live qualification、managed runtime start/test/releaseは今回実行禁止。

今回の検証結果（2026-10-19）:

| 検証 | 結果 | 範囲 |
|---|---|---|
| `Test-Repository.ps1` | PASS / exit0 | 29 managed JSON、Current1件、model binaryなし、既存offline回帰一式 |
| `Test-GooseShortcutLaunch.ps1` | PASS / exit0 | shortcut2例 + process PATH3例。実Goose起動なし |
| `Test-GooseCompactionEvidence.py` | PASS / 9 tests | synthetic session DB fixture。実Goose履歴・推論は使用しない |
| publication scan | PASS / 269 files / findings0 | tracked208 + untracked61。禁止payload / 高確度Secret pattern。ignored資料は読まない |
| `git diff --check` | PASS | whitespace検証。既存LF/CRLF自動変換警告はruntime変更ではない |

今回編集したのは8既存文書と新規監査記録1件のみ。開始時の全268公開候補をSHAで比較し、それ以外の既存260ファイル（runtime scripts / configs / resultsを含む）が不変であることを確認済み。最終公開候補はtracked変更48 + untracked実ファイル61 = 109、staged0。検証ログ、`publication-paths.txt` allowlist、前後hash inventoryはignored `logs/audit-20261019/`に保持する。

保護対象の最終readback: 意図せずMAINを起動した後に取得したGoose / DeepSeek / LM Studio設定と既存SSH tunnel stateの4 hashは不変。BLUEもserver PID / state hash / LM Studio設定hashが不変で、context262,144 / 1 slot / native LM Studio loaded0を再確認した。これらの比較をMAIN起動前からの完全無変更の証拠にしない。

## 残る確認事項

- MAIN LM Studio起動の副作用を開示。起動前状態を推測せず、勝手に停止しない。
- MAIN driver610.62 / LM Studio0.4.26.0、DeepSeek ProductVersion0.2.1.0は実測metadata。更新経緯・受入は今回の範囲外。
- BLUE稼働Candidateの長時間品質、Shared-memory長時間推移、Goose Desktop受入、compaction未受入項目を維持。今日のmemory-free snapshotは新規qualificationではない。
- GREENのloaded stateは`UNVERIFIED`。既存Clientの実session選択、BLUE外部配置物全件との完全同期、Firewall規則再監査は行っていない。確認したBLUEスクリプト5本の配置差は未解消として保持。
- Local-AI-Agent-Stackの古い版・default記述は同repository側の整合作業が別途必要。本作業に混ぜない。
- 監査はreview可能な作業ツリーと検証報告で一度停止した。その後の明示承認に基づくcommit / pushは上記公開承認追記の範囲で行う。
