# Qwen3.8 JonathanColetti Q6_K Vision loaders

Daily Quality Reference starts from `../00-Daily-Profiles/3-Quality-Reference.bat`, which safely releases any managed Turbo runtime before CALLing the canonical Balanced BAT in this directory. Safe, Coding-Fast, and older context loaders remain available here as Fallback / Advanced profiles.

RTX 5090 32 GBでCurrentのJonathanColetti Q6_K本体を共有し、公式Vision projectorだけを追加した明示切替用loaderです。通常CurrentのLM Studioモデル枠とloaderは変更しません。

| Item | Value |
|---|---|
| Model | `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF` |
| Quantization | `Q6_K` |
| Model SHA-256 | `a50aa1478295b58ee3d93eabe02c17f6d5fcf6cb787fd8a0ab07ac629a46cae6` |
| Vision projector | `Qwen3.8-27B-Uncensored-vision-f16.gguf` |
| Projector SHA-256 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |
| LM Studio model key | `qwen3.8-27b-uncensored-vision-q6k` |
| API identifier | `qwen3.8-27b-uncensored-vision` |
| KV cache | profile-specific `Q8_0 / Q8_0` or `Q4_0 / Q4_0`; GPU offload ON |
| Flash Attention | ON |
| GPU offload | maximum / all layers |
| MTP | embedded ON; profile-specific max draft tokens 2 or 4 |
| Parallel | 1 |
| Vision | LM Studio `capabilities.vision = true` verified |

## Presets

| Operational profile / BAT | Context | MTP | KV | Eval / effective ubatch | Intended use |
|---|---:|---:|---|---:|---|
| Safe — `Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat` | 65,536 | 2 | Q8_0/Q8_0 | 2048 / 512 | permanent known-good rollback; existing loader unchanged |
| **Balanced** — `Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat` | 65,536 | 4 | Q8_0/Q8_0 | 2048 / 512 | **Quality / Performance Reference** |
| Coding-Fast — `Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat` | 65,536 | 4 | Q4_0/Q4_0 | 2048 / 512 | explicit coding-speed selection only |

All three use API ID `qwen3.8-27b-uncensored-vision`, Flash Attention ON, full offload, mmap/mlock behavior matching Safe, parallel 1, Vision true, and RTX5090 402W. Q6 is not deprecated: Balanced remains the Quality/Performance Reference, Safe remains the permanent known-good fallback, and Coding-Fast remains explicit-only. `Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat` lists Q5 96K Recommended first, then CALLs these existing Q6 loaders without embedding runtime logic; `[0]` exits without changing runtime state.

The older context-specific presets remain available:

| BAT | Context | Intended use | Measured peak VRAM |
|---|---:|---|---:|
| `Qwen3.8-JonathanColetti-Q6K-Vision_32K.bat` | 32,768 | lightweight image/OCR check | 27,057 MiB |
| `Qwen3.8-JonathanColetti-Q6K-Vision_96K.bat` | 98,304 | long context plus Vision | 29,736 MiB |

32K、Safe 64K、96Kは固定PNG fixtureでVision 7/7に成功しました。Phase 1/1.5ではBalancedもformal qualityとVision correctnessにPASSしました。Coding-Fastは対象fixtureで生成破損を起こしませんでしたが、Q4のfixture外品質同等性は保証されません。96Kは動作しますが、測定時のGPU残量は約2.87 GBだったため、ゲーム、VR、画像生成などのGPU負荷と併用しません。128K loaderは作成しません。

## Goose one-click startup

RTX5090のgoose Desktopは64K Vision profileをapp-global既定runtimeとして使用します。デスクトップの`Goose Vision 64K`、または`Start-Goose-Jonathan-Vision64K.bat`を起動してください。

この既存one-click startupは既知GoodのSafe（MTP2/Q8）preflightを維持します。Q5 Recommended Production、Q6 Balanced Reference、またはCoding-Fastを使う場合はProfile Selectorで明示的にloadし、新しいtaskを開始してください。

launcherは次を行います。

1. Goose provider modelが`qwen3.8-27b-uncensored-vision`か確認する。
2. `lms ps`とSDK load configから、単一Vision instance、context 65,536、Q8_0/Q8_0、full offload、Flash Attention、MTP draft 2、parallel 1を確認する。
3. 正しければ再ロードしない。異なるidle runtimeならmanaged reloadする。active / queued predictionは中断しない。
4. Start MenuのGoose shortcutから現行実行ファイルを解決してDesktopを起動する。

`Start-Goose-Jonathan-Vision64K.ps1 -NoLaunch -InstallDesktopShortcut`でshortcutを再作成できます。Goose configを切り替える必要がある場合は、変更前configをrepository外の`%LOCALAPPDATA%\Local-LLM-Coding-Stack\goose-config-backups\`へ保存します。Secret fileは読み書きしません。

## Q5_K_M 96Kから通常起動へ戻す場合

`Set-Goose-Profile-Q6K-Vision64K.bat`は、通常のGoose shortcutを使用するための永続client profileをQ6_K Vision 64Kへ戻します。LM StudioのloadとGoose起動は行いません。

| Goose setting | Q6_K Vision 64K value |
|---|---:|
| Model | `qwen3.8-27b-uncensored-vision` |
| `GOOSE_CONTEXT_LIMIT` | 64,512 |
| `GOOSE_MAX_TOKENS` | 32,768 |
| `GOOSE_AUTO_COMPACT_THRESHOLD` | 0.3 |

Goose Desktopを完全終了し、このprofile selectorを実行してから`Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat`をloadし、通常のGoose shortcutで新しいchatを開始します。変更前configはrepository外へbackupされ、Goose起動中は変更しません。

## Runtime behavior

各BATは現在ロード中の全LM Studioモデルを解除した後、repository rootの`Load-ManagedModel.mjs`を使ってVisionモデル枠をロードします。実行には`npm install`済みの`@lmstudio/sdk` 1.5.0、LM Studio起動、`lms` CLI、外部モデルデータが必要です。

通常CurrentとVision枠は、同じQ6_KをNTFSハードリンクで共有します。Vision projectorもHugging Face cacheとのハードリンクです。モデル本体、projector、LM Studio application data、cacheはGitへ保存しません。

BAT実行はLM Studio runtime stateを変更します。別の推論中には実行しないでください。

Phase 1/1.5の選定根拠と実機switching regressionは`benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md`にあります。
