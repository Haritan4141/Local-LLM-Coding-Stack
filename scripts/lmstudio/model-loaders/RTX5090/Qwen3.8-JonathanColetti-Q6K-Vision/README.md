# Qwen3.8 JonathanColetti Q6_K Vision loaders

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
| KV cache | `Q8_0 / Q8_0`, GPU offload ON |
| Flash Attention | ON |
| GPU offload | maximum / all layers |
| MTP | embedded ON, max draft tokens 2 |
| Parallel | 1 |
| Vision | LM Studio `capabilities.vision = true` verified |

## Presets

| BAT | Context | Intended use | Measured peak VRAM |
|---|---:|---|---:|
| `Qwen3.8-JonathanColetti-Q6K-Vision_32K.bat` | 32,768 | 軽量な画像/OCR確認 | 27,057 MiB |
| `Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat` | 65,536 | 推奨。画像を含む通常のコーディング | 28,339 MiB |
| `Qwen3.8-JonathanColetti-Q6K-Vision_96K.bat` | 98,304 | 長い文脈と画像が同時に必要な場合 | 29,736 MiB |

32K、64K、96Kは固定PNG fixtureでVision 7/7に成功しました。96Kは動作しますが、測定時のGPU残量は約2.87 GBだったため、ゲーム、VR、画像生成などのGPU負荷と併用しません。128K loaderは作成しません。

## Goose one-click startup

RTX5090のgoose Desktopは64K Vision profileをapp-global既定runtimeとして使用します。デスクトップの`Goose Vision 64K`、または`Start-Goose-Jonathan-Vision64K.bat`を起動してください。

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
