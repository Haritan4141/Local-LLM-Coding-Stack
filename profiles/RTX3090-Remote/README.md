# RTX3090 Remote LLM Node

メインPCのVS Code / Zoo Codeから家庭内LAN経由で利用する独立LM Studio nodeです。RTX5090 localhost環境とは別のBase URLとAPI identifierを使用します。

## Identity

| Item | Value |
|---|---|
| COMPUTERNAME | `DESKTOP-L9HAM1G` |
| IP | `192.168.0.104` |
| SSH Alias | `pc5700x` |
| GPU | NVIDIA GeForce RTX 3090, 24,576 MiB |
| RAM | 31.93 GiB |
| NVIDIA driver | 591.86 |
| LM Studio | 0.4.21.0 / CLI commit `71bd99c` |
| Model storage | LM Studio外部領域。リポジトリには保存しない |
| LAN URL | `http://192.168.0.104:1234` |

## Phase 1 baseline

- SSH alias、IP、hostnameの3点照合に成功。
- LM Studio serverは起動中だが`127.0.0.1:1234`だけで待受。
- メインPCからTCP 1234は到達不可。
- NetworkCategoryはPrivate。TCP 1234の既存Firewall ruleは0件。
- ロード中LLMはなし。既存モデルはNomic Embed Text Q4_K_Mのみ。
- C:空き容量は992.64 GiB。

## LAN server

- LM Studio serverは`0.0.0.0:1234`で待受し、メインPCから`GET /v1/models`へ到達確認済み。
- Windows Firewall rule: `Local-LLM-LMStudio-In-TCP-1234-Private-LocalSubnet`
- Scope: Inbound / Allow / TCP 1234 / Private / LocalSubnet / Edge Traversal Block / LM Studio実行ファイル限定。
- 変更前Firewall backup: `C:\Users\Atsuki\Codex-RTX3090-Setup\firewall-before-lmstudio-20260820-114203.wfw`
- Public profileまたはRemoteAddress AnyでTCP 1234を許可する規則は追加していない。

## Managed models

| Role | Model | Quant | API identifier | Default context | Vision |
|---|---|---|---|---:|---|
| **Remote coding default** | JonathanColetti Qwen3.8 27B Uncensored | Q4_K_M | `qwen3.8-27b-uncensored@q4_k_m` | 32,768 | separate F16 projector; direct API 7/7 |
| Optional Candidate | HauhauCS Aggressive | Q4_K_P | `qwen3.8-27b-uncensored-hauhaucs-aggressive-mtp` | 32,768 | separate BF16 projector; direct API 7/7 |

64Kは両モデルで3回生成を完了しましたが、idle VRAM余裕はJonathan約3.2 GiB、HauhauCS約2.1 GiBです。単独の長context作業だけに限定します。96KはQ8 KVで安全余裕が不足すると判断し、ロードもloader作成も行っていません。

## Results

| Model / context / MTP | Generation median | Peak VRAM | MTP acceptance | Result |
|---|---:|---:|---:|---|
| Jonathan Q4_K_M / 32K / ON | 36.31 tok/s | 19,737 MiB | 578/782 = 73.91% | stable; recommended |
| Jonathan Q4_K_M / 32K / OFF | 33.37 tok/s | 18,902 MiB | n/a | stable; ON is 8.8% faster |
| Jonathan Q4_K_M / 64K / ON | 35.88 tok/s | 21,106 MiB | not sampled | stable; solo use |
| HauhauCS Q4_K_P / 32K / ON | 35.47 tok/s | 20,867 MiB | 546/750 = 72.80% | stable Candidate |
| HauhauCS Q4_K_P / 32K / OFF | 31.86 tok/s | 19,932 MiB | n/a | stable; ON is 11.3% faster |
| HauhauCS Q4_K_P / 64K / ON | 36.28 tok/s | 22,156 MiB | not sampled | stable; narrow margin |

15,478-token promptの中央値はJonathan 905.17 prompt tok/s、HauhauCS 897.60 prompt tok/sで実質同等です。Direct Tool Callingは両方pass、Direct Visionも各projectorで両方7/7でした。Reasoning Budget 8,192は両方とも上限を使い切り、usable final answerへ到達しませんでした。

Zoo Codeの同一multi-file fixtureは両モデルとも5/10から10/10へ修正し、read/command/edit/createを完遂しました。HauhauCSはcorrected 32K load後約320秒です。Jonathanも完遂しましたが、途中で旧HauhauCS会話が8K/parallel 4モデルを暗黙ロードしてVRAMを圧迫したため、所要時間は比較値に採用しません。

Zoo Code Code modeでHauhauCSへPNGを添付する経路は成立しましたが、画像へ答えずdirectory/README tool callを反復したため129秒で停止しました。Direct API Vision 7/7との切り分けから、projector不良ではなくZoo Codeの画像＋agent tool loop相互作用として記録します。

## Zoo Code operation

- 保存profile: `RTX3090 Jonathan Q4KM`、`RTX3090 Hauhau Q4KP`
- 評価後のactive profile: `default`（RTX5090 localhost Current）
- profileのmodel IDにはloaderと同じnatural identifierを選ぶ。indexed repository pathを選ぶと、LM Studioが既定8Kで別instanceを暗黙ロードすることがある。
- profile切替後は旧会話を再開せず、`lms ps`で単一モデル、意図したcontext、`PARALLEL 1`を確認する。
- 3090側の通常終了状態はJonathan Q4_K_M / 32K / Q8 KV / embedded MTP ON。

全結果: `benchmarks/results/2026-08-20-rtx3090-remote-node.md`
