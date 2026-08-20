# HauhauCS Balanced-MTP Watch

Status: Watch
Created: 2026-08-20

将来的に HauhauCS Balanced-MTP-GGUF が公開された場合の比較候補です。現時点では正確な repository、公開状態、variant、Vision/FastMTP 対応、runtime 要件を確定情報として扱いません。

## Watch trigger

次の情報を確認できた時点で、Watch のまま継続するか Candidate へ進めるか判断します。

- 公式の repository と release/revision
- モデル説明と Aggressive-MTP との差分
- GGUF variant、容量、checksum
- Vision 関連 artifact の有無
- FastMTP と LM Studio/llama.cpp の互換要件
- license と既知の制約

Candidate 化する場合は専用 config と評価ノートを作り、Aggressive-MTP と Current の両方を比較対象にします。公開前の名称を前提にモデルを検索・ダウンロードしたり、Current を変更したりしません。
