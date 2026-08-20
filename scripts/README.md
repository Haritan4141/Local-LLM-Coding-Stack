# Scripts

リポジトリ管理だけを行う非破壊的な PowerShell helper です。LM Studio、Zoo Code、VS Code、モデルファイル、GPU driver の設定は変更しません。

`lmstudio/model-loaders/` のBATは例外として、ユーザーが明示的に実行したときにLM Studioのロード状態を変更します。このREADMEに記載するPowerShell helperからBATを自動実行することはありません。

## LM Studio model loaders

RTX 5090向けloaderは `lmstudio/model-loaders/RTX5090/<Model-Name>/` のモデル別ディレクトリに置きます。現在のセットは `Qwen3.8-JonathanColetti/` です。用途、共通設定、`lms unload --all` の副作用は各モデルディレクトリのREADMEを確認してください。

## New-BenchmarkRecord.ps1

測定前の結果 JSON を `benchmarks/results/` に作成します。既存ファイルは上書きしません。

```powershell
.\scripts\New-BenchmarkRecord.ps1 `
  -ModelId 'candidate-hauhaucs-aggressive-mtp' `
  -ConfigPath 'configs/candidates/hauhaucs-qwen38-27b-aggressive-mtp.json' `
  -WorkloadId 'speed-fixed-v1' `
  -ContextTokens 32768
```

生成後に LM Studio/runtime version、model artifact、settings、metrics、outcome を実測で埋めます。

## Test-Repository.ps1

必須構造、JSON 構文、Current profile の一意性、モデル重量ファイルの混入を検査します。

```powershell
.\scripts\Test-Repository.ps1
```

成功時は exit code 0、違反時は exit code 1 を返します。
