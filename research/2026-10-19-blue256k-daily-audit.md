# BLUE IQ4_XS Vision256K — 日常優先構成と追加監査

記録日: 2026-10-19 Asia/Tokyo。ユーザー報告、read-only実機確認、過去の正式qualificationを別々の根拠として扱う。監査完了時点では公開・push未承認だった。後続の公開承認と配布判断は末尾に記録する。

## 運用方針

ユーザーはDeepSeek HarnessでBLUEのRTX3090 24GB + RTX3060 12GBを使う256Kモデルを日常使用し、現在問題なく利用でき、大きなcontextが普段使いに適していると明示確認した。

| 管理上の役割 | 選択 | 根拠と維持する境界 |
|---|---|---|
| Daily Preferred Runtime / User Confirmed | DeepSeek + BLUE IQ4_XS Vision256K | ユーザーの実運用選択。今後の通常案内で優先し、過去benchmarkを理由に96Kへ戻さない |
| Historical Recommended Production / 手動fallback | MAIN / BLUE Q5_K_M Vision96K | 実測済みprofileを保存。自動fallback・runtime切替はしない |
| Repository Model Lifecycle Current | JonathanColetti text Q6_K | 唯一のCurrentを保持。IQ4_XSの技術lifecycleはCandidateのまま |
| Reference / Safe / explicit選択 | Q6 Vision Balanced / Safe / Coding-Fast、既存別profile | 削除・Retired化・自動選択をしない。GooseのCoding Agent役割も別概念として維持 |

ユーザー確認によるdaily preferenceは、未測定項目を技術PASSへ変更するものではない。過去のTool/Coding失敗、MAIN / BLUEそれぞれのqualificationの範囲は保持する。

## 実機確認

2026-10-19T18:27–18:29+09:00の読み取り。既存SSH alias、hostname、期待IPv4、CPU、GPU名 / PCI Bus ID / UUIDを照合した。

| 項目 | 観測値 |
|---|---|
| MAIN | DESKTOP-5NPLIIV / 192.168.0.100 / RTX5090、PL402W、driver610.62 |
| BLUE | BLUE-5700X / pc5700x / DESKTOP-L9HAM1G / 192.168.0.104 / Ryzen7 5700X |
| GPUs | RTX3090 `0B:00.0` / RTX3060 `01:00.0`、UUIDも既存recordと一致 |
| Runtime process | PID23744、start2026-10-18T19:31:16.9788499+09:00、既存standalone llama.cpp |
| Executable | `%LOCALAPPDATA%/Local-LLM-Coding-Stack/runtimes/llama.cpp-f280b269-sm86/llama-server.exe`、build `b10615-f280b2698` |
| Server / transport | BLUE loopback127.0.0.1:18080、MAINの既存SSH forward127.0.0.1:18081 → 同BLUE loopback18080 |
| API alias | `qwen3.8-27b-uncensored-vision-iq4xs-blue-256k-gpt-4o` |
| API readback | context262,144、Vision true、total_slots1、観測時idle。最終GETでもhealth=ok、model_ftype=`IQ4_XS - 4.25 bpw` |
| Process args | parallel1、target KV Q8_0/Q8_0、MTP draft3、batch1024 / ubatch256、layer split0.75,0.25、no-mmap、Flash Attention / Jinja / prompt cache、reasoning budget0 |
| LM Studio | 別process / 既存port1234、native loaded instances0。standaloneと混同しない |
| Power / temperature | RTX3090 PL259W / 45°C、RTX3060 PL170W / 33°C、driver591.86 |
| NVIDIA actual free | RTX3090 3,276MiB、RTX3060 2,445MiB |
| RAM | total31.927GiB、free約8.77–8.94GiB（異なるsnapshotの範囲） |

SHA確認はslot idleをGETで確認してから、監査用processをBelowNormal priorityとして既存ファイルを読むだけで行った。model / projectorをコピー、置換、downloadしていない。

| 実ファイル | Bytes | 今回再計算したSHA-256 |
|---|---:|---|
| `Qwen3.8-27B-Uncensored-IQ4_XS.gguf` | 15,309,039,008 | `53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5` |
| `Qwen3.8-27B-Uncensored-vision-f16.gguf` | 927,606,912 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |
| `llama-server.exe` | manifestで管理 | `970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4` |

本体とprojectorはBLUE `%USERPROFILE%/.lmstudio/models/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/`にあり、API path / process args / bytes / SHAを照合した。ユーザーの「Q4」はこのIQ4_XSを指す。別のQ4_K_Mへの切替は行わない。

## Memoryと安定性の扱い

既存sourceとhash一致のread-only DXGI / PDH probeだけを使用。model実験harnessのmain関数は実行していない。

- exact live LUIDのShared: RTX3090 1,965,043,712 bytes（約1.830GiB）、RTX3060 1,914,105,856 bytes（約1.783GiB）。全adapter合計3,879,157,760 bytes（約3.613GiB）。
- 過去Strict Gateは全adapter Shared `<4GiB`、各NVIDIA Shared `<=2GiB`。今回snapshotは範囲内で、actual freeも各1GiB以上。高いShared使用量だけを故障・OOMとしない。
- 既存BLUE probeの`headroom_mib`はtotal−usedで、actual NVIDIA freeより大きい。今回はactual freeを別に読み、driver reserveを含む差を区別した。probeやgateを変更していない。
- ユーザーの日常利用「問題なく使えている」は`User Confirmed`として記録する。今回のidle GET / memory snapshotは、最大256K付近の長時間品質、連続Tool loop、画像を含む長い会話、compaction後の継続、Shared変動、error recoveryの正式試験ではない。
- 2026-10-06の209,891-token Tool/Vision chain成功、元のcodingと短いtool controlの失敗をそのまま保持する。新しい200K–256K stress / generation / benchmarkは行っていない。

## 配置済み5スクリプトの意味上の差分

比較対象はBLUE `C:/Users/Atsuki/Codex-RTX3090-Setup/standalone-turbo/`。5本すべてLF正規化後も不一致。外部版の更新日は2026-10-06、Git側はMAIN256K対応を含む後続内容で、外部版はHEAD / HEAD^ / 関連過去commitの単純なコピーとは一致しない。独立した未同期配置snapshotとして扱い、「過去commitと同じ」「実機独自修正」とどちらにも根拠なく断定しない。

| File | Git側に追加・拡張された内容 | BLUE稼働への判断 |
|---|---|---|
| `Turbo.Common.psm1` | `RTX5090-IQ4XS256K`、MAIN用host/GPU/memory/Goose検査、BLUE固定memory処理からmanifest駆動へ一般化 | BLUE分岐は実質同等。外部版はMAIN用profileを扱わない。現在BLUEを止める理由にならない |
| `Start-ManagedTurbo.ps1` | ValidateSetへMAIN256Kを追加 | BLUE選択の意味は維持。新しいMAIN選択のみ外部版にない |
| `Stop-ManagedTurbo.ps1` | 同じValidateSet追加 | BLUE停止経路は維持。実行中processへの自動影響なし |
| `Release-ManagedRuntime.ps1` | ValidateSetとMAIN用profile一覧へMAIN256K追加 | BLUE Release経路は維持。同期時はownership / recoveryも別途検証する |
| `Test-ManagedTurbo.ps1` | MAIN選択追加と`Assert-TurboExtendedMemory`呼出追加 | 外部版はmanual Testのmemory確認範囲が狭い。起動済みruntimeを自動変更するものではない |

BLUE / BLUE-Quick / BLUE-IQ4XS256Kの3 manifestsと`Read-BlueExtendedMemory.py`はbyte一致。現行の主要args / artifact / listenerも期待値と一致する。差分だけから現在の256K稼働を危険とする証拠はないが、全配置物の完全同等性・将来のStart/Stop操作の再受入を証明したものではない。今回5ファイルを同期しない。

将来の別承認作業は、同期範囲（BLUE専用か共通MAIN対応込みか）を確定し、外部snapshotの保全、ownership / active判定 / memory / history recoveryのoffline比較、対象ファイル限定配置とhash再読込を行う。runtime停止・再起動の承認は配置承認と分ける。稼働中への自動deployは禁止する。

## Client側の責任境界と日常運用

DeepSeekのinstalled version、実session provider、保存default、input / output / image / compaction / overflow / fallbackの実装調査は`Local-AI-Agent-Stack/docs/deepseek-blue256k-daily-20261019.md`を正とする。Runtime contractはこのrepositoryの`BLUE-IQ4XS256K.json`を参照し、Client設定をここへ複製しない。

- 正常な既存sessionを継続するためにReleaseやmodel再ロードは不要。
- 健全性確認は、既存のMAIN18081またはBLUE18080へのGET `/health` / `/v1/models` / `/props`を使用する。`/slots`を読む場合はid / n_ctx / is_processing等だけを選択し、prompt本文やcacheを保存しない。processing=trueは通常の使用状態であり、停止要求ではない。
- エラー時はendpoint / alias / slotとClientの非本文error metadataを確認し、sessionを削除せず保持する。自動restart / 自動model switch / 自動fallback / process killを導入しない。
- 手動Q5 Vision96K fallbackは保持するが、userが明示選択し、生成・queueを完了してから既存のownership / idle確認付き手順を別工程で行う。96Kへ戻すことを日常の既定にしない。`research/2026-10-06-blue-iq4xs256k-trial-profile.md`と既存loader READMEのrollback条件を維持する。

## 変更範囲と検証

今回の変更はdaily preference・過去のbaseline・実機snapshot・配置差分を整理する管理資料のみ。runtime manifests / loader実装 / GPU / driver / Firewall / SSH / listen / context / cache / MTP / split / model / projector / Client defaultは変更しない。

家庭内管理Sheetの`LAN_運用ルール`（A1:H50、2026-10-19 read）を確認した。SSH-001の対象照合、SEC-001～003、SYNC-003 / 005等と矛盾する変更は行わない。Sheet / Slides / global AGENTSは更新しない。

最低限のoffline検証・公開候補Secret検査・前後hash比較は作業終了時に実結果を記録する。個人の会話本文、session title / private path、Token / Secret / raw session log、backup、model/projector/runtime本体は公開対象外。

| 検証 | 実結果 / 範囲 |
|---|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Repository.ps1` | PASS / exit0、managed JSON29、Current1、no binary、既存offline fixture一式 |
| BLUE profile / memory、MAIN profile / memory、Goose transcript | 上記suite内で16 / 10 / 25 / 11 / 8 checks PASS。real loader / runtimeを実行しない |
| public JSON syntax | 全30件PASS。管理record以外のpackageも構文確認 |
| Client tests | AgentStackの最終full suite99 PASS / fail0 / skip0。新規context fixture1件に内部15 checks。runtime品質試験とは分離 |
| Secret / diff / protected hash | LLM公開候補270件 + AgentStack185件で高確度Secret pattern / 禁止payload検出0。両repo diff-check PASS。MAIN保護8 pathとBLUE runtime / state / settings / 確認済み配置9ファイルに変更なし |

新規推論・stressは実行していない。検証のsynthetic結果をbenchmark値へ記録しない。

最終実機readbackは2026-10-19T18:45:36+09:00。同じserver PID、state / runtime / LM Studio config hash、loopback18080、262,144 context / 1 slot / health okを再確認した。process argsのdraft K/V F16/F16とreasoning offも確認した。既存MAIN設定7ファイル + 不存在1 path、既存tunnel stateは開始時から不変。初回17:42監査のLMS wake履歴を今回の無変更確認で上書きしない。

今回のLLM変更は既存文書8件と新規監査1件のみ。開始時269公開候補のうちそれ以外の261ファイルはSHA不変。Benchmark / Raw / runtime manifests / loader実装 / configsは変更していない。Local-LLM HEAD / GitHub mainは`770d104`、Local-AI-Agent HEAD / GitHub mainは`adde044`のまま。両repo staged0 / commitなし / pushなし。Agent側の既存37件のdirty workは保持した。

## 残る承認・未測定事項

- 監査完了時点ではGitHub push / merge / 外部公開は未承認だった。既存未コミット変更を保持し、両repositoryの最終diffとGit状態を報告した。
- 監査完了時点ではBLUE5スクリプトの同期・deploy、runtime lifecycle操作、DeepSeek保存default変更も未承認だった。
- ユーザーの正常な日常運用報告は維持。追加の正式long-context / compaction / loop試験は必要時に実案件の非本文metadataから評価し、今回の監査に追加しない。

## 後続のGit公開承認とBLUE配布判断（2026-10-19）

ユーザーが両repositoryのcommit / pushと、必要な場合のBLUE配布を明示承認した。LLM側は本監査の文書9件だけを公開対象とする。Agent側の既存メンテナンス記録と今回のdaily更新は別commitに分け、Secret / backup / model / runtime本体 / raw evidenceを含めない。

BLUEへの配布は今回は不要と判断した。3 manifestsとmemory helperは既にGitと一致し、稼働中256Kの主要設定も期待どおり。5 wrapperの差分は主にMAIN対応と手動Testの検査拡張で、今回の文書・Client側offline検証を使うためにBLUEを更新する必要はない。既存配置を維持し、配布・再起動・設定変更を実行しない。runtime lifecycle操作とDeepSeek default / compaction設定変更はこのGit公開承認に含めない。
