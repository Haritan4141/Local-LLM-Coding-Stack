# MAIN IQ4_XS Vision 256K Candidate

Explicit-only MAIN (DESKTOP-5NPLIIV / 192.168.0.100 / RTX5090) standalone profile.
Weights and the F16 Vision projector remain outside Git under `%USERPROFILE%\.lmstudio\models\JonathanColetti\Qwen3.8-27B-Uncensored-GGUF`.
Both artifact SHA256 values and the existing sm120 runtime are pinned in `scripts/standalone-turbo/runtime-manifests/RTX5090-IQ4XS256K.json`.

API: `http://127.0.0.1:18080/v1`; model ID `qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o`.
Vision ON; runtime262144 / Goose input237568 / output16384 / growth reserve8192; compaction60%.
Q8_0 target KV; F16 MTP draft KV; MTP3; batch1024 / ubatch256 / parallel1; mmap+mlock; reasoning OFF.

Goose Daily Profiles option14 launches with process-only settings. DeepSeek Harness can use a separate `main-local` provider at the same API endpoint.
The gpt-4o suffix is a Goose capability hint, not a cloud request.

Side effects: explicitly selecting this loader releases only an exactly owned idle MAIN managed runtime and unloads idle LM Studio models before loading the Candidate. Active/unknown predictions, identity/hash failures, or memory pressure fail closed. It never manages BLUE, Firewall, GPU power, driver, or shared Global client settings.
Use a closed Goose Desktop when switching its process-only profile. Existing Q5/Q6 remain unchanged.
256K allocation and short smoke success are not certification of long-context task quality or loop-free operation.
