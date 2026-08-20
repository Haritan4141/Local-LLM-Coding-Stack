# Benchmark Protocol

目的はピーク速度の競争ではなく、RTX 5090 32 GB 上で日常の Agentic Coding に使えるモデルを、再現可能な条件で選ぶことです。

## Result classes

- `curated baseline`: 過去の実測を整理した値。元条件が不足している場合はその旨を明記します。
- `controlled run`: 固定した設定・workload・測定手順で取得した値。
- `exploratory run`: 設定探索用。Current 昇格の直接根拠にはしません。

## Minimum run procedure

1. GPU を使用する他の重い処理を止め、Windows の電源状態を揃えます。
2. モデル repository、正確な GGUF filename/variant、LM Studio version、Zoo Code version、GPU driver を記録します。
3. context、K/V cache、Flash Attention、offload layers、MTP、draft tokens、reasoning budget、concurrency、sampling を記録します。
4. warm-up run は測定値から分離します。
5. 同じ workload を原則3回以上実行し、各 run と median を残します。
6. tok/s だけでなく TTFT、MTP acceptance、VRAM baseline/peak/delta、Windows 応答性、完遂可否を記録します。
7. raw output は `benchmarks/raw/`、整形済み結果は `benchmarks/results/` に置きます。

## Standard comparison matrix

| Dimension | Required checks |
|---|---|
| Speed | MTP ON/OFF generation tok/s、TTFT、3-run median |
| VRAM | load後 baseline、生成中 peak、delta、OOM/OS paging |
| MTP | acceptance %、draft tokens、品質差、stalls |
| Context | 32K、64K、96K の load/生成安定性。128K は探索扱い |
| Coding | 単一ファイル修正、複数ファイル修正、テスト修復、指示遵守 |
| Agentic | tool call、編集、検証、再試行、最終状態の正確さ |
| Vision | 画像理解、UI screenshot、コード/エラー screenshot。対応候補のみ |
| UX | Windows 応答性、Zoo Code 接続、LM Studio server stability |

## Suggested workload IDs

- `speed-fixed-v1`: 同一のテキスト生成 prompt で throughput と TTFT を測る。
- `coding-fixed-v1`: 隔離した小規模 fixture に対する修正とテスト。
- `agentic-repo-v1`: 複数ファイルの探索、編集、テスト、説明までを評価。
- `long-context-recall-v1`: 長文中の事実回収と指示追従を context 別に測る。
- `vision-ui-v1`: 同一 screenshot を使う Vision 比較。

fixture や prompt を追加する場合は、秘密情報や第三者の非公開コードを含めず、バージョンを固定してください。

## Promotion gate

Candidate は少なくとも 32K/64K/96K の安定性、MTP ON/OFF、VRAM、coding、agentic、該当時 Vision を完了するまで Current に昇格しません。速度向上があっても、品質退行、VRAM 圧迫、Zoo Code 不安定化、Windows 操作性低下が大きければ不採用または用途限定とします。
