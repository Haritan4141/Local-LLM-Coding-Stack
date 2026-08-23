# JonathanColetti Q6_K Vision integration research

Date: 2026-08-23

## Conclusion

The existing JonathanColetti Q6_K remains unchanged and can be paired with the repository's separate F16 Vision projector. On LM Studio 0.4.21+2 and RTX 5090 32 GB, the combination was recognized as `capabilities.vision = true` and passed the fixed PNG test at 32K, 64K, and 96K.

This is managed as a separate Vision model key and API identifier so the stable text-only Current can still be selected without projector overhead.

## Verified upstream artifacts

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Qwen3.8-27B-Uncensored-Q6_K.gguf` | 22,430,999,968 bytes | `a50aa1478295b58ee3d93eabe02c17f6d5fcf6cb787fd8a0ab07ac629a46cae6` |
| `Qwen3.8-27B-Uncensored-vision-f16.gguf` | 927,606,912 bytes | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |

The projector was downloaded from revision `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3` with `hf download`. The Q6_K local hash was also verified. Sources:

- [Model card](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/README.md)
- [Vision projector](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/main/Qwen3.8-27B-Uncensored-vision-f16.gguf)
- [Projector addition commit](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/commit/ade635f5c9c48e63ac5d42b4580761094b1630c4)

## Local storage design

No GGUF is stored in Git. LM Studio has two model views:

- text-only Current: `qwen3.8-27b-uncensored`
- explicit Vision profile: `qwen3.8-27b-uncensored-vision-q6k`

The Vision directory contains an NTFS hardlink to the existing Q6_K and an `mmproj-` hardlink to the verified Hugging Face cached projector. This avoids a second 22.43 GB model copy and keeps projector presence from changing the normal Current model directory.

API identifier for the loaded Vision instance: `qwen3.8-27b-uncensored-vision`.

## Runtime findings

- LM Studio native model API reports Vision, tool-use training, and reasoning capability.
- Effective load configuration was audited through `@lmstudio/sdk` 1.5.0: Q8_0/Q8_0, Flash Attention ON, all GPU offload, KV GPU offload ON, embedded MTP ON with max draft 2, parallel 1.
- The first CLI-only load omitted explicit Q8/Q8. It was discarded as a formal measurement and reloaded through the managed SDK loader.
- 64K is the preferred Vision preset. 96K passed but leaves materially less GPU headroom. 128K was not tested and remains excluded.

## Client findings

### Kilo Code

A separate `lmstudio/qwen3.8-27b-uncensored-vision` entry was added with `attachment: true` and image input modality. The text Current remains the default. Kilo successfully transported the PNG, but misread `VRAM-96K-042` as `VRAM-96K-Q42`; result 6/7. Its agent system context expanded the request to 23,000 input tokens and then triggered an extra compaction continuation.

### goose

Two CLI 1.46.0 attempts using Windows backslashes and forward slashes left the image path as plain text, so CLI image transport is not verified on that version. The bundled 1.47.0 CLI was version-checked but was not rerun for image transport.

Goose Desktop 1.47.0 successfully attached the PNG through the paperclip flow, displayed its thumbnail, accepted the custom API identifier `qwen3.8-27b-uncensored-vision`, and logged an outgoing image-bearing request. The first inference returned HTTP 400 because LM Studio resolved the request while the text-only `qwen3.8-27b-uncensored` instance was loaded (`vision = false`, context 64,512). This is a runtime-instance selection failure, not a Goose attachment failure.

The managed Vision 64K loader was then run again. `lms ps` reported the Vision model key, `vision = true`, context 65,536, Q8_0/Q8_0, MTP draft 2, and parallel 1; `GET /v1/models` exposed both the custom API identifier and the Vision model key. A direct recovery request using the same identifier and PNG returned exact `VRAM-96K-042` in 2.079 seconds. A successful Desktop resend was not completed, so Goose Desktop is recorded as conditional rather than fully passed. Operationally, load and verify the Vision instance before selecting the Vision ID in Goose; do not rely on LM Studio just-in-time loading to preserve the projector.

The temporary Goose model selection was restored to the normal text default after the check. The app-global config returned to its known SHA-256 `43c24e259e0c5f3aadc5ca2d1f4eaa1ca86c30164a22706b3eed67561bcefad8`.

### Zoo Code

Zoo documentation supports image mentions for Vision-capable models, but VS Code was not open during this controlled run. Zoo transport remains pending and must not be claimed as verified.

## Open items

1. Create or select a Zoo profile using `qwen3.8-27b-uncensored-vision`, refresh its LM Studio model metadata, and run `@/path/to/image.png`.
2. Complete one successful Goose Desktop resend after the managed Vision loader and `lms ps` preflight; keep the text model as the app-global default.
3. Keep tool calling and long agent-loop validation separate from the basic image recognition result.
