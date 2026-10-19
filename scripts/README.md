# Scripts

通常のhelperはリポジトリ管理だけを行い、LM Studio、Zoo Code、VS Code、モデルファイル、GPU driverを変更しません。

`lmstudio/model-loaders/`のBATとGoose用PowerShell launcherは明示的なruntime操作です。Goose用launcherは正しいVision runtimeがない場合だけ`lms unload --all`とmanaged loadを行います。active / queued predictionは中断しません。

## LM Studio model loaders

loaderは `lmstudio/model-loaders/<GPU>/<Model-Variant-Quantization>/` のモデル別ディレクトリに置きます。RTX5090 Currentは`Qwen3.8-JonathanColetti-Q6K/`、Q6 Vision Reference/Safe/Coding-Fastは`Qwen3.8-JonathanColetti-Q6K-Vision/`、Q5_K_M Vision 96K Recommended Productionは`Qwen3.8-JonathanColetti-Q5KM-Vision/`、Candidate Q6_K_Pは`Qwen3.8-HauhauCS-Aggressive-Q6KP/`、Q5_K_P fallbackは`Qwen3.8-HauhauCS-Aggressive-Q5KP/`です。Selectorは個別loaderをCALLするだけで、設定ロジックを持ちません。共通設定と`lms unload --all`の副作用は各モデルディレクトリのREADMEを確認してください。

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

LM Studio公式TypeScript SDKを使い、CLIでは同時指定しにくいK/V cache、MTP draft、eval batch、Max Concurrent Predictions 1を含むmanaged loadを行います。repository rootで`npm install`を実行すると、固定済み`@lmstudio/sdk@1.5.0`が導入されます。このhelperはモデルをロードするため非破壊的なread-only helperではありません。先行モデルのunloadは行わないので、管理BATまたは明示的な`lms unload --all`と組み合わせます。

```powershell
node .\scripts\lmstudio\Load-ManagedModel.mjs `
  --model-key 'jonathancoletti/qwen3.8-27b-uncensored-gguf/qwen3.8-27b-uncensored-q4_k_m.gguf' `
  --identifier 'qwen3.8-27b-uncensored@q4_k_m' `
  --context 32768 `
  --mtp on `
  --mtp-draft 2 `
  --kv-k q8_0 `
  --kv-v q8_0
```

`--mtp-draft`は2/3/4、`--kv-k`/`--kv-v`はq8_0/q4_0/f16、`--eval-batch`は正の整数を受け付けます。従来引数を省略した場合はdraft2、Q8_0/Q8_0、eval batch未指定の既存挙動です。unsupported option/valueとF16/quantized mixed KVはfail closedします。独自ubatch設定は実装せず、effective valueをbackend/APIで監査します。full GPU offload、Flash Attention ON、KV GPU offload ON、parallel 1は維持します。

## Test-ManagedModel.mjs

ロード済みinstanceのSDK load configを読み取り、context、full offload、Flash Attention、K/V type、MTP、draft tokens、eval batch、parallel、必要に応じてmmap/GPU split/Visionを検査します。モデルのload/unloadは行いません。

```powershell
node .\scripts\lmstudio\Test-ManagedModel.mjs `
  --identifier 'qwen3.8-27b-uncensored-vision' `
  --context 65536 `
  --mtp on `
  --mtp-draft 4 `
  --kv-k q8_0 `
  --kv-v q8_0 `
  --eval-batch 2048 `
  --vision-required on
```

`tests/Test-QwenVisionProfileLoaders.ps1`はprofile明示値、selector mapping/Cancel、JavaScript/PowerShell構文、fail-closed引数を検査し、`Test-Repository.ps1`から実行されます。

## Goose Vision 64K one-click startup

`lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Start-Goose-Jonathan-Vision64K.ps1`は、Gooseの既定Vision IDとLM Studio runtimeをpreflightし、必要時だけVision 64Kをmanaged reloadしてGoose Desktopを起動します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\lmstudio\model-loaders\RTX5090\Qwen3.8-JonathanColetti-Q6K-Vision\Start-Goose-Jonathan-Vision64K.ps1 `
  -NoLaunch -InstallDesktopShortcut
```

通常運用はデスクトップの`Goose Vision 64K`を使用します。`-NoLaunch`はpreflightだけ、`-InstallDesktopShortcut`はショートカット作成、`-ForceReload`は推論中でないことを確認した上で再ロードする保守用です。

## Goose Q5_K_M Vision 96K Recommended Production one-click startup

互換性のため既存名を保持する`lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q5KM-Vision/Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1`は、Q5_K_M Vision / 96K / Q8_0 / MTP3 / batch1024 / effective ubatch512 / mmap+mlock / parallel 1をpreflightし、Goose子プロセス限定で90,112-token client limitを渡します。永続Goose configと既存Q6_K 64K shortcutは変更しません。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\lmstudio\model-loaders\RTX5090\Qwen3.8-JonathanColetti-Q5KM-Vision\Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1 `
  -NoLaunch -InstallDesktopShortcut
```

通常利用は互換名`Goose Q5KM Vision 96K Candidate`のデスクトップshortcutを使います。process-specific設定を確実に反映するため、実行前にGoose Desktopを完全終了してください。起動中は全`Goose` processを検知してruntime変更前に停止します。

## Goose Daily integrated entry

通常運用では`lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`だけを実行します。Gooseを完全終了した状態でProfileを選ぶと、既存canonical runtime wrapper、runtime/provider/model/endpoint cross-check、Goose client設定、Goose Desktop起動を順に実行します。

- Daily入口: `lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`
- Q5_K_M Vision 96K: `lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q5KM-Vision/Set-Goose-Profile-Q5KM-Vision96K.bat`
- Q6_K Vision 64Kへ復元: `lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Set-Goose-Profile-Q6K-Vision64K.bat`

Daily入口ではMAIN/BLUE Q5 Stableの`96K / 16K`・`96K / 32K`、Turboの`96K / 16K`・`96K / 32K`、Quick Response CandidateのVision対応`64K / 8K`、MAIN/BLUE Q6 Quality Referenceの`64K / 32K`を選択できます。Stable/Qualityは共通helper `goose/Set-GooseProfile.ps1`で永続configをbackup・同期し、Turbo/Quickは`standalone-turbo/Start-Goose-ManagedTurbo.ps1`のprocess-local `openai` providerだけを使用します。QuickはReasoning Low/2048、MTP1、Prompt cache、F16 projectorを使う未実測Candidateです。Goose v1.49ではローカルQwen名を含むaliasを表示し、末尾の`gpt-4o` tokenだけをVision能力判定に利用します。実モデルはローカルJonathan Q5_K_M Visionです。個別Set-Goose BATは互換・保守用として引き続き利用できます。詳細は`goose/README.md`を参照してください。

## Export-VisionFixture.ps1

決定論的なHTML fixtureをGoogle Chromeのheadless modeで960x540 PNGへ変換します。既定出力はGit管理外の`benchmarks/raw/vision-ui-v1.png`で、既存ファイルは明示的な`-Force`なしでは上書きしません。

```powershell
.\scripts\Export-VisionFixture.ps1
```

同じPNGをCurrentとCandidateのDirect API、LM Studio UI、Zoo Codeの各Visionテストへ渡します。
