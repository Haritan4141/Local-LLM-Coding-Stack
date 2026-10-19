# BLUE Jonathan IQ4_XS Vision256K — explicit trial Candidate

Extended-context trial, not Production/Current. Uses qualified official standalone llama.cpp, not LM Studio native loading. Q5 Stable/Turbo and Q6 Reference/Safe remain unchanged.

2026-10-19運用追記: DeepSeek + BLUE256Kはユーザー確認済みDaily Preferred Workflowです。下記Goose手順は別Clientの明示選択手順として保持します。現在正常なDeepSeek sessionを使う際にReleaseやGoose起動を行う必要はありません。Runtime / model lifecycleはCandidateのまま、Q5 / Q6 fallbackを保持します。最新監査は`research/2026-10-19-blue256k-daily-audit.md`、DeepSeek Client手順は`Local-AI-Agent-Stack/docs/deepseek-blue256k-daily-20261019.md`を参照してください。

## Use from MAIN（Gooseを明示選択する場合）

1. Finish generated/queued work and completely exit Goose Desktop.
2. If another BLUE model/runtime is active, open `00-BLUE-Daily-Profiles-REMOTE.bat` → `[5] Release`. Active predictions, unknown owners and identity mismatches are refused; never force-stop them.
3. Open `scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat` → **`[13] Extended Context - IQ4XS Vision 256K / Output 16K (Candidate)`**.
4. Start a new Goose chat; confirm the local alias ending `iq4xs-blue-256k-gpt-4o`, input237,568 and output16,384. Try a short chat, small image and safe Tool Call first. The usual Goose shortcut does not inherit this process-only profile.

Model-only: `_256K_REMOTE.bat` from MAIN; `_256K.bat` on BLUE only when this repository is available. BLUE runtime selectors append `[6] Extended Context`; choices1–5 are unchanged. Runtime-only selection does not launch/reconfigure Goose. To return to Q5: finish work, exit Goose, runtime `[5] Release`, then Goose `[7]` Stable or `[9]` Turbo. Q6 Safe is preserved.

## Exact settings / external data

- Target `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`; CUDA0=RTX3090, CUDA1=RTX3060, UUID/name/PCI checked. Power Limit259W/170W is checked, not changed.
- Jonathan revision `45d0fc0ad6cfcf9eeee6008ddaea925536409b18`; IQ4_XS SHA `53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5`.
- BLUE `%USERPROFILE%\.lmstudio\models\JonathanColetti\Qwen3.8-27B-Uncensored-GGUF\Qwen3.8-27B-Uncensored-IQ4_XS.gguf`; F16 projector `Qwen3.8-27B-Uncensored-vision-f16.gguf`, SHA `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c`.
- Pinned runtime `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`: context262,144, parallel1, target Q8/Q8, draft F16/F16 explicitly set, MTP3, batch1024/**ubatch256**, split**0.75,0.25**, no-mmap, Flash Attention/Jinja/cache ON, Reasoning OFF. No download in the loader.
- Manifest Source of Truth: `scripts/standalone-turbo/runtime-manifests/BLUE-IQ4XS256K.json`. BLUE binds loopback18080; MAIN uses existing managed SSH tunnel loopback18081. No Firewall/LAN listener changes. Model/runtime payloads stay outside Git.
- API alias `qwen3.8-27b-uncensored-vision-iq4xs-blue-256k-gpt-4o`. Trailing token reuses existing Goose Vision metadata workaround; weights/inference are local, not OpenAI.
- Process-only Goose `openai`: input237,568 (232K) + output16,384 (16K) + growth reserve8,192 =262,144. UI context is deliberately smaller than runtime. Temperature0; user-approved compact0.6 trial. First static eligibility142,541 tokens uses the232K client budget, not a guarantee about trigger timing or actual payload.

## Safety and pending acceptance

Before any LM Studio unload and after standalone load/reuse, existing Python reads exact DXGI/live-LUID telemetry. Gate: total Shared `<4GiB`, each NVIDIA Shared `<=2GiB`, each free VRAM `>=1024MiB`. Missing/ambiguous telemetry fails closed. No background watchdog/automatic restart. Reuse failure preserves existing processes; only a newly started process failing acceptance is cleaned up through its owned handle.

Explicit selection may unload idle/queued0 BLUE LM Studio models through the existing managed start. Active or different standalone profiles are not automatically released. Checksums precede transition. Persistent Goose/LM Studio/Kilo/Zoo settings, driver, PL and Firewall are not edited.

Prior memory/one synthetic209K retrieval→Tool→Vision chain passed, but short/192K tool selection and original coding failures remain. Goose Desktop Vision/compaction/long-session acceptance is PENDING. Cold209K prefill took~9min16sec; actual16K generation was not qualified. See `benchmarks/results/2026-10-06-blue-q4-vision-context.md`.
