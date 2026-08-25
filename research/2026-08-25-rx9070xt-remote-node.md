# RX 9070 XT Remote Node research — 2026-08-25

## Decision

Jonathan公式artifactに限定する場合、RX 9070 XT 16 GBの第一候補は`IQ4_XS`です。`Q4_K_M`は16.8 GBでweightだけでも余裕がなく、`IQ2_M`は10.6 GBまで下がる代わりに公開PPLが7.8581まで悪化します。`IQ4_XS`は15.3 GB、公開PPL 7.1583で、Q4_K_Mの7.1814と同等以上の公開値です。

初回backendはAMD ROCm 2.29.1を採用しました。RX 9070 XT / gfx1201のhardware surveyが成功し、LM StudioがiGPUを除外してdGPUだけをvisible deviceにしました。既存Vulkan 2.29.1は削除せずfallbackとして保持しています。

## Context and KV choice

16 GBで96Kを確保するため、K/VはQ4_0/Q4_0です。IQ4_XSでもDedicated VRAM内だけには収まらず、96K load時Shared 3.542 GiB、生成中peak 3.570 GiBでした。Q8 KVやVision projectorを加える余地は小さいため、REDの初期profileはtext/tool専用です。

## Observed

- LM Studio 0.4.21+2、ROCm runtime 2.29.1、AMD Software 26.7.1
- IQ4_XS 15,309,039,008 bytes、SHA-256 `53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5`
- 64K: Dedicated 14.814 GiB / Shared 2.604 GiB
- 96K: Dedicated 14.816 GiB / Shared 3.542 GiB
- 96K generation peak: Dedicated 14.845 GiB / Shared 3.570 GiB
- MTP2 36.71–36.82 tok/s、MTP OFF 29.61–29.72 tok/s
- 70,082-token入力: 246.93秒TTFT、3点回収3/3
- OpenAI-compatible Tool Calling: exact function name/arguments PASS
- Goose simple inferenceとDeveloper shell tool: PASS

## Known limitations

- Shared GPU Memory依存がある。Strict VRAM cap ONでもWDDM Sharedはゼロにならない。
- 70K入力のTTFTは約247秒で、長文収容は可能だが即応用途では遅い。
- Vision projectorは未導入・未評価。
- IQ4_XSとQ6_K Currentの包括的quality A/Bは未実施。Remote補助nodeでありCurrent代替ではない。

## Sources

- Jonathan model/files: https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF
- IQ4_XS artifact: https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/Qwen3.8-27B-Uncensored-IQ4_XS.gguf
- AMD Windows compatibility: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/windows/windows_compatibility.html
- LM Studio changelog: https://lmstudio.ai/changelog/lmstudio
- LM Studio LAN server: https://lmstudio.ai/docs/developer/core/server/serve-on-network
- LM Studio native chat: https://lmstudio.ai/docs/developer/rest/chat
- llama.cpp RX 9070 XT HIP/Vulkan issue: https://github.com/ggml-org/llama.cpp/issues/26663
- LM Studio RX 9070 XT runtime issue history: https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1906
