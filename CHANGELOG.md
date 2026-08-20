# Changelog

重要な管理構造、設定、ベンチマーク、モデル選定の変更を記録します。アプリの自動生成ログではなく、人が確認した判断履歴です。

## [Unreleased]

### Added

- Current Qwen3.8 JonathanColetti用の96K Normal / 64K VRChat / 32K Light LM Studio loader BATを追加。
- RTX 5090配下で今後のモデルごとにloaderディレクトリを分離する管理規約を追加。
- 各BATの用途、`lms unload --all` の副作用、共通LM Studio/Zoo Code設定、GGUF非保存方針をREADMEへ記録。

### Runtime impact

- なし。BATは管理対象として追加しただけで実行しておらず、LM Studioのロード状態や保存済み設定は変更していない。

### Planned

- HauhauCS Aggressive-MTP Candidate の正確な variant とランタイム要件を確認する。
- Current と Candidate の固定条件 A/B ベンチマークを実施する。
- Balanced-MTP-GGUF の公開有無を確認後、必要なら Watch から Candidate へ変更する。

## [2026-08-20] - Initial management baseline

### Added

- VS Code + Zoo Code + LM Studio + local LLM 専用の管理構造を作成。
- `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` Q6_K を Current として登録。
- 32K / 64K / 96K の context profile と Q8_0 KV、Flash Attention、65-layer offload、MTP 設定を記録。
- MTP ON 63.92 tok/s、MTP OFF 48.30 tok/s、acceptance 約 40–50% の既存実測を baseline として記録。
- 128K + Q8 KV は Windows 操作性を損なうため常用しないという運用制約を記録。
- HauhauCS Aggressive-MTP を Candidate、将来の Balanced-MTP を Watch として登録。
- モデル本体、LM Studio データ、raw logs をリポジトリ外に保つ除外規則を追加。
- ベンチマーク記録生成とリポジトリ検査の PowerShell スクリプトを追加。

### Runtime impact

- なし。この変更は管理ファイルの新規作成のみで、LM Studio、Zoo Code、VS Code、モデル配置、ドライバー設定は変更していない。
