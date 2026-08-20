# Current State

State captured: 2026-08-20 (Asia/Tokyo)

## Operational status

- Current model: `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF`
- Variant: `Q6_K`
- Status: `Current / stable`
- Hardware: NVIDIA GeForce RTX 5090 32 GB
- Client path: VS Code -> Zoo Code -> LM Studio -> local model
- Max concurrent predictions: 1

## Effective profiles

| Profile | Context tokens | Intended use |
|---|---:|---|
| Normal | 98,304 | 通常のコーディング。現在の標準 |
| VRChat | 65,536 | VRChat/Unity 関連作業 |
| Light | 32,768 | 軽量・応答重視の作業 |

全プロファイルの共通設定:

| Setting | Current value |
|---|---:|
| K cache | Q8_0 |
| V cache | Q8_0 |
| Flash Attention | ON |
| GPU offload | all 65 layers |
| MTP | ON |
| Max draft tokens | 2 |
| Reasoning budget | 8,192 |

管理用の機械可読レコードは `configs/current/qwen38-27b-uncensored-q6k.json` にあります。この JSON は状態記録であり、LM Studio へ直接インポートできることを保証するものではありません。

## Managed loader presets

Currentの起動BATは `scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/` で管理します。

| Preset | Context tokens | Purpose |
|---|---:|---|
| 96K Normal | 98,304 | Current標準 |
| 64K VRChat | 65,536 | VRChat / Unity作業 |
| 32K Light | 32,768 | VRAM余裕・軽快さ優先 |

各BATは現在ロード中の全LM Studioモデルを解除してから、API Model ID `qwen3.8-27b-uncensored` で再ロードします。BATの登録は管理上の変更であり、この構築時には実行していません。

## Existing measurements

| Mode | Generation speed | MTP acceptance | Evidence |
|---|---:|---:|---|
| MTP ON | 63.92 tok/s | approximately 40–50% | user-provided measured result |
| MTP OFF | 48.30 tok/s | not applicable | user-provided measured result |

同条件と仮定した単純差分では、MTP ON は MTP OFF より 15.62 tok/s、約 32.3% 高速です。元測定のプロンプト、サンプリング、試行回数、VRAM 値は未記録のため、この差分は既存結果の整理値であり、再現性を保証する比較結果ではありません。

## Stability and capacity

- 96K context: 安定運用済み。
- 128K + Q8 KV: モデル実行で VRAM が圧迫され、Windows 操作がカクついたため常用しない。
- 128K は「不可能」ではなく「日常運用の安定条件を満たさない」と扱う。
- VRAM の定量的な baseline/peak/delta は未記録。次回ベンチマークで取得する。

## Active candidate

`HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF` を Candidate として比較予定です。

- Claimed/expected comparison features: Vision, FastMTP
- Adoption status: not adopted
- Quantization/file selection: pending
- LM Studio compatibility: pending verification
- Zoo Code integration: pending verification
- Speed, VRAM, context stability, coding quality: not measured

Candidate の評価完了までは Current のモデル・設定を変更しません。

## Next decision gates

1. Candidate の正確な GGUF variant、Vision 構成、LM Studio/FastMTP 要件を確認する。
2. Current と近い量子化・同じプロンプト・同じ context/cache 条件で A/B 測定する。
3. 32K、64K、96K の VRAM と Windows 応答性を確認する。
4. MTP ON/OFF の throughput、acceptance、品質差を複数回測る。
5. Vision の正答性と、Zoo Code 経由の Agentic Coding 完遂率を評価する。
6. HauhauCS Balanced-MTP-GGUF が実際に公開された場合のみ Watch から Candidate へ移す。
