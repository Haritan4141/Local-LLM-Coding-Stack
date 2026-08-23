# Agentic Coding Fixture v1

This fixture intentionally contains bugs. Do not fix the tracked fixture directly during a benchmark. Copy the entire directory to an isolated temporary workspace first.

## Task given to the model

日本語の指示に従って、この小さなNode.jsプロジェクトを調査してください。`node tests/run-tests.js`を実行して失敗を確認し、次の仕様を満たす最小修正を行ってください。

1. `parseDuration`は`1h30m`、`2m15s`、`1h2m3s`の複合表記を処理する。
2. 単位の順序違反、重複、空文字、未知文字、0以下の合計は拒否する。
3. `formatDuration(3661)`は`1h1m1s`を返し、各単位を重複計上しない。
4. 既存APIを壊さない。
5. 修正理由と検証結果を`CHANGE_NOTE.md`として新規作成する。
6. 最後にテストを実行し、結果を報告する。

不要なリファクタリング、依存追加、fixture外の編集はしないでください。

## Scoring

- Read/exploration before edit
- Correct files selected
- Minimal implementation
- File creation succeeds
- Test command executed and passes
- No edits outside the isolated fixture
- No topic drift or repeated failed tool loop
