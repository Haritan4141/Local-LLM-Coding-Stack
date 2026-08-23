# Scripts

通常のhelperはリポジトリ管理だけを行い、LM Studio、Zoo Code、VS Code、モデルファイル、GPU driverを変更しません。

`lmstudio/model-loaders/`のBATと`Start-Goose-Jonathan-Vision64K.ps1`は明示的なruntime操作です。Goose用launcherは正しいVision runtimeがない場合だけ`lms unload --all`とmanaged loadを行います。active / queued predictionは中断しません。

## LM Studio model loaders

loaderは `lmstudio/model-loaders/<GPU>/<Model-Variant-Quantization>/` のモデル別ディレクトリに置きます。RTX5090 Currentは`Qwen3.8-JonathanColetti-Q6K/`、同じQ6_Kへ公式projectorを追加するVision profileは`Qwen3.8-JonathanColetti-Q6K-Vision/`、Candidate Q6_K_Pは`Qwen3.8-HauhauCS-Aggressive-Q6KP/`、Q5_K_P fallbackは`Qwen3.8-HauhauCS-Aggressive-Q5KP/`です。RTX3090 Remote Nodeは`RTX3090/Qwen3.8-JonathanColetti-Q4KM/`と`RTX3090/Qwen3.8-HauhauCS-Aggressive-Q4KP/`に分離します。BAT名は`<Model-Identifier>_<Context>K.bat`形式とし、用途名はREADMEで管理します。共通設定と`lms unload --all`の副作用は各モデルディレクトリのREADMEを確認してください。

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

必須構造、管理対象JSON構文、Current profileの一意性、モデル重量ファイルの混入を検査します。Git管理外の`benchmarks/raw/`と`logs/`はJSON構文検査から除外しますが、モデル重量ファイルの混入検査はリポジトリ全体へ適用します。

```powershell
.\scripts\Test-Repository.ps1
```

成功時は exit code 0、違反時は exit code 1 を返します。

## Invoke-LMStudioBenchmark.ps1

ロード済みモデルへ固定promptを送り、LM Studio REST APIのgeneration tok/s、TTFT、token usage、通常回答、reasoning出力と、`nvidia-smi`のrequest中peak VRAMをraw JSONへ記録します。モデルのload/unloadやLM Studio設定変更は行いません。completion tokenがあるのに通常回答とreasoningの双方が取得できない場合は警告します。

```powershell
.\scripts\Invoke-LMStudioBenchmark.ps1 `
  -ModelIdentifier 'qwen3.8-27b-hauhaucs-aggressive' `
  -PromptPath 'benchmarks/fixtures/api-speed-v1/prompt.txt' `
  -Iterations 3 `
  -MaxTokens 512
```

Remote NodeではBase URLとGPU telemetry用SSH identityを明示します。

```powershell
.\scripts\Invoke-LMStudioBenchmark.ps1 `
  -ModelIdentifier 'qwen3.8-27b-uncensored@q4_k_m' `
  -PromptPath 'benchmarks/fixtures/api-speed-v1/prompt.txt' `
  -BaseUrl 'http://192.168.0.104:1234' `
  -GpuSshAlias 'pc5700x' `
  -ExpectedGpuHostname 'DESKTOP-L9HAM1G'
```

出力先は既定でGit管理外の`benchmarks/raw/`です。モデルload条件、MTP ON/OFF、contextは実行前に別途固定し、curated resultへ転記してください。

## Load-ManagedModel.mjs

LM Studio公式TypeScript SDKを使い、CLIでは同時指定できないQ8_0 K/V cacheとMax Concurrent Predictions 1を含む評価ロードを行います。repository rootで`npm install`を実行すると、固定済み`@lmstudio/sdk@1.5.0`が導入されます。このhelperはモデルをロードするため非破壊的なread-only helperではありません。先行モデルのunloadは行わないので、管理BATまたは明示的な`lms unload --all`と組み合わせます。

```powershell
node .\scripts\lmstudio\Load-ManagedModel.mjs `
  --model-key 'jonathancoletti/qwen3.8-27b-uncensored-gguf/qwen3.8-27b-uncensored-q4_k_m.gguf' `
  --identifier 'qwen3.8-27b-uncensored@q4_k_m' `
  --context 32768 `
  --mtp on
```

指定値はfull GPU offload、Flash Attention ON、Q8_0/Q8_0、KV GPU offload ON、parallel 1、MTP max draft 2です。loaderとZoo Codeで同じnatural identifierを使い、ロード後は`lms ps`とLM Studio log/APIで実効設定を確認します。indexed repository pathをZoo Codeで選ぶと既定8Kの別instanceが暗黙ロードされる場合があります。

## Test-ManagedModel.mjs

ロード済みinstanceのSDK load configを読み取り、context、full offload、Flash Attention、Q8_0/Q8_0、MTP、draft tokens、parallelを検査します。モデルのload/unloadは行いません。

```powershell
node .\scripts\lmstudio\Test-ManagedModel.mjs `
  --identifier 'qwen3.8-27b-uncensored-vision' `
  --context 65536 `
  --mtp on
```

## Goose Vision 64K one-click startup

`lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Start-Goose-Jonathan-Vision64K.ps1`は、Gooseの既定Vision IDとLM Studio runtimeをpreflightし、必要時だけVision 64Kをmanaged reloadしてGoose Desktopを起動します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\lmstudio\model-loaders\RTX5090\Qwen3.8-JonathanColetti-Q6K-Vision\Start-Goose-Jonathan-Vision64K.ps1 `
  -NoLaunch -InstallDesktopShortcut
```

通常運用はデスクトップの`Goose Vision 64K`を使用します。`-NoLaunch`はpreflightだけ、`-InstallDesktopShortcut`はショートカット作成、`-ForceReload`は推論中でないことを確認した上で再ロードする保守用です。

## Export-VisionFixture.ps1

決定論的なHTML fixtureをGoogle Chromeのheadless modeで960x540 PNGへ変換します。既定出力はGit管理外の`benchmarks/raw/vision-ui-v1.png`で、既存ファイルは明示的な`-Force`なしでは上書きしません。

```powershell
.\scripts\Export-VisionFixture.ps1
```

同じPNGをCurrentとCandidateのDirect API、LM Studio UI、Zoo Codeの各Visionテストへ渡します。
