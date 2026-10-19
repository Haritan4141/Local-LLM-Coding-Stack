# MAIN IQ4_XS Vision256K trial

Use the exact validated BLUE weight/projector snapshot, not an unverified latest update.
Publisher: https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/45d0fc0ad6cfcf9eeee6008ddaea925536409b18/README.md
Runtime: https://github.com/ggml-org/llama.cpp/commit/f280b26983ad0fdb705a0d9ebf0503e76f2899b0
These are pinned provenance references; no fresh publisher-version audit is claimed.

MAIN DESKTOP-5NPLIIV/192.168.0.100: RTX5090 UUID GPU-8dc7cc4e-ecb6-2e20-59d3-3d5acca86a8b, total32607MiB, existing402W limit. BLUE dual36GB qualification is not proof of MAIN capacity.
User approved ~15.3GB exact-artifact copy and MAIN isolated load/smoke. Projector is reused from existing MAIN Q5 package only after SHA match.

Candidate uses the existing pinned sm120 runtime, full GPU offload, native context262144, Vision, Q8 target KV, F16 MTP draft KV, MTP3, batch1024, ubatch256, parallel1, mmap+mlock, reasoningOFF.
Fixed gate: per-GPU Shared<2GiB, all-adapter Shared<4GiB, free VRAM>=1024MiB using live DXGI LUID + GPU counters and exact NVIDIA identity.
No power/driver/Firewall/BLUE/Goose/Kilo/Zoo/LM Studio Global modifications or benchmark winner inference. The additional DeepSeek MAIN provider patch is the sole intended client-config change. MAIN free-VRAM telemetry uses actual NVIDIA memory.free, excluding driver reservations, rather than total-minus-used.

Actual load/short smoke and unresolved long-input/compaction behavior: see qualification report. Context allocation alone does not certify recall/coding accuracy at256K, steady latency, compaction, or absence of tool loops.
