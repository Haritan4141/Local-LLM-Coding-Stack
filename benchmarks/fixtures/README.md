# Benchmark Fixtures

CurrentとCandidateへ同じ入力を与えるための、秘密情報を含まない固定fixtureです。実行時のコピーと生成PNGは`benchmarks/raw/`またはOSの一時ディレクトリへ置きます。

- `api-speed-v1/`: generation speed、TTFT、日本語コーディング回答の固定prompt
- `agentic-coding-v1/`: Zoo Codeのread/edit/create/test/tool loopを測る小規模Node.js fixture
- `vision-ui-v1/`: OCRとUI配置認識用の決定論的HTML screenshot fixture
- `reasoning-v1/`: Reasoning Budget 8,192での収束、rollback不変条件、`undefined`値の扱いを確認する固定prompt

fixtureを変更した場合はIDのversionを上げ、過去結果と混在させません。

Vision用PNGはリポジトリへコミットせず、次のhelperで`benchmarks/raw/vision-ui-v1.png`へ生成します。

```powershell
.\scripts\Export-VisionFixture.ps1
```
