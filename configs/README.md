# Configuration Records

このディレクトリは、LM Studio と Zoo Code を含む「実際に有効な運用設定」を比較・再現するための管理用 JSON を保持します。

## Important boundary

- JSON はこのリポジトリ独自の管理形式です。LM Studio へ直接インポートできる形式とは限りません。
- モデルの実パスは記録しないか、必要な場合もローカル限定の外部参照として扱います。
- API key、認証情報、個人データは記録しません。
- 未確認値は推測せず `null` または `pending` にします。

## Layout

- `current/`: 現在の安定運用。通常は有効な Current profile を1件だけ置きます。
- `candidates/`: Current と分離された比較候補。
- `profile.schema.json`: 管理レコードの最小 JSON Schema。

## Change policy

Candidate の A/B 比較では、モデル固有要件を除いて Current の context、KV cache、Flash Attention、GPU offload、reasoning budget、concurrency を固定します。変更した変数はベンチマーク結果に必ず記録します。

Candidate の昇格時は、古い Current JSON を削除せず、状態と履歴を保持できる場所へ移して `MODEL_REGISTRY.md` と `CHANGELOG.md` を同時更新します。
