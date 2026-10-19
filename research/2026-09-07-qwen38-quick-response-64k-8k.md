# Qwen3.8 Quick Response 64K / 8K Candidate

Date: 2026-09-07

## Objective

Add an isolated, response-latency-oriented chat profile for MAIN RTX5090 and BLUE RTX3090+RTX3060 without replacing Stable, Turbo, Quality Reference, or the repository-wide Current. The intended workload is ordinary Japanese conversation with modest reasoning and routine image attachment; coding and long agent loops remain out of scope.

## Decision

The Candidate keeps the installed JonathanColetti Qwen3.8-27B-Uncensored Q5_K_M artifact and uses the already pinned official llama.cpp runtimes. Its initial text-only revision was replaced on the same day by a Vision revision that loads the existing F16 projector because image attachment is a default user requirement.

| Setting | Candidate value | Reason |
|---|---:|---|
| Runtime context | 65,536 | Retains useful conversation history while reducing KV allocation from the 96K profiles |
| Goose client context | 57,344 | Leaves an explicit 8,192-token runtime margin |
| Goose max output | 8,192 | Bounds runaway output while preserving a substantial answer budget |
| KV cache | Q8_0 / Q8_0 | Existing Q4 KV tests traded away non-coding performance; Quick does not change this variable |
| Reasoning | ON, effort low, budget 2,048 | Keeps modest reasoning but bounds the former 8,192-token failure mode |
| MTP | ON, draft max 1 | Upstream chat data favors draft 1; local draft 1 still requires measurement |
| Prompt cache | ON, reuse minimum 0 | Existing local cache evidence shows large warm-prefix TTFT reductions |
| Vision | ON, F16 projector | Keeps image attachment available in the normal Quick workflow; projector size is 927,606,912 bytes |
| Parallel | 1 | Matches the existing latency-oriented and VRAM-safe baseline |

MAIN keeps the existing 402 W assertion. BLUE keeps RTX3090 259 W and RTX3060 170 W, plus the existing PCI Bus ID matching, layer split `0.7108,0.2892`, mmap OFF, localhost server, and MAIN SSH tunnel design.

## Evidence

### Observed locally

- RTX5090 Q5_K_M 96K text fixture: MTP OFF measured 53.7446 tok/s and 0.0837 s median TTFT; draft 2 measured 45.5164 tok/s and 0.1132 s. This prevents assuming that more draft tokens are always faster.
- RTX5090 Standalone Turbo text generation measured 83.75 tok/s, but it is a Reasoning-OFF/MTP3 96K profile and is not the same workload as this Candidate.
- BLUE Standalone Turbo improved the text fixture from 28.538 to 32.409 tok/s and TTFT from 0.735 to 0.292 s.
- Exact-prefix cache reuse at 32K changed RTX5090 TTFT from 17.411 s cold to 0.172 s warm, and BLUE from 35.270 s to 0.334 s.
- On 2026-09-07, read-only `llama-server.exe --help` checks on both MAIN and identity-verified `pc5700x / DESKTOP-L9HAM1G` confirmed support for `--reasoning-effort`, `--reasoning-budget`, `--cache-prompt`, `--cache-reuse`, `--spec-draft-n-max`, and `--no-mmproj`.
- The initial text-only MAIN revision loaded at 65,536 context with MTP1, Reasoning Low/2,048, reached health/idle, and reported Vision false. This is historical lifecycle evidence only and does not qualify the later Vision revision.
- Repository validation passed after the initial integration. The BLUE text-only payload was hash-verified and copied to `DESKTOP-L9HAM1G / 192.168.0.104` with a timestamped backup; `llama-server` was absent before and after, so this static deployment did not load a model or change the active runtime.
- The later BLUE Vision manifest/common/release update was copied after re-verifying `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`. Target SHA-256 values matched, the F16 projector matched `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c`, and `llama-server` remained stopped. The backup is `C:\Users\Atsuki\Codex-RTX3090-Setup\backups\before-quick-vision-20260907-162040`.

Local evidence:

- `benchmarks/results/2026-08-24-rtx5090-jonathan-q5km-vision.md`
- `benchmarks/results/2026-08-25-rtx5090-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-25-blue-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-25-rtx5090-prefix-cache-phase3.md`
- `benchmarks/results/2026-08-25-blue-prefix-cache-phase3.md`

### Verified upstream

- The JonathanColetti artifact is Qwen3.8-27B-Uncensored Q5_K_M, 19,535,701,408 bytes, with native context 262,144 and embedded MTP. Its optional F16 Vision projector is 927,606,912 bytes.
- The model card's chat benchmark reports MTP draft 1 ahead of no MTP and draft 2/3 in that author's environment. Hardware equivalence is not claimed.
- Qwen documents `low` reasoning effort as a speed/cost-oriented reasoning level.
- llama.cpp documents independent reasoning mode, effort, positive token budget, prompt cache, and MTP draft controls.

Sources:

- [JonathanColetti model card](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF)
- [Qwen3.8-27B base model](https://huggingface.co/Qwen/Qwen3.8-27B)
- [llama.cpp CLI reference](https://github.com/ggml-org/llama.cpp/blob/master/tools/cli/README.md)
- [llama.cpp speculative decoding](https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md)

### Inferred

- A 64K Vision load should retain more VRAM headroom than the corresponding 96K Vision profile because its KV allocation is smaller, but the projector removes the earlier text-only saving and exact headroom remains unmeasured.
- The shorter reasoning budget should reduce worst-case response completion time. It does not guarantee a lower TTFT because TTFT is dominated by prompt processing and actual history size.
- MTP draft 1 may improve short-chat generation, but it may still lose to MTP OFF on these GPUs. This remains the first controlled runtime A/B.

### Unknown / promotion blockers

- Cold and warm TTFT, short-answer completion time, generation tok/s, MTP acceptance, and VRAM on both targets.
- Whether a 2,048-token reasoning budget gives an acceptable Japanese response-quality/latency balance.
- Whether MTP draft 1 beats MTP OFF on MAIN and BLUE for the intended chat fixture.
- Whether Goose image transport, model recognition quality, projector VRAM overhead, and desktop responsiveness pass on both targets under the new Vision revision.

The Candidate must not be described as faster, stable, or Recommended until these are measured. Runtime loaders were not executed during creation because managed loaders unload existing LM Studio models and require explicit execution authorization.

## Planned qualification

1. With Goose closed and no active prediction, load Quick on one target at a time.
2. Confirm `/props` reports Vision true, attach the fixed PNG fixture through Goose, and verify recognition before text latency testing.
3. Compare Quick against the same target's current Turbo using fixed Japanese chat prompts at approximately 128, 1,024, and 8,192 input tokens.
4. Record cold/warm TTFT, 128/512-token completion time, generation tok/s, reasoning tokens, MTP acceptance, projector/Dedicated/Shared memory, and desktop responsiveness.
5. Repeat Quick once with MTP OFF. Adopt draft 1 only if it improves end-to-end latency without a quality regression.
6. Require 20 short-turn requests, a successful Goose image request, no output-limit termination, coherent final answers, and clean Release before considering the Candidate operational.

## 2026-09-07 lifecycle incident and correction

MAIN received two Quick startup requests at 15:38:23 and 15:38:24. Both passed the initial empty state/port check before either had published ownership. One server completed successfully as PID 65172, while the failing launcher's cleanup archived the shared active state with `archive_reason: start-failed`. Release correctly preserved the listener because it no longer had an active ownership record.

The managed runtime now serializes Turbo and Quick operations with a profile-family/port named Mutex. Failed startup cleanup may archive active state only when its PID matches the process being cleaned up. Release also passes the detected Turbo/Quick profile to Stop rather than the menu's family-default profile.

For this incident only, Release recovered the archived state after matching PID 65172, process creation time, hostname, pinned executable/model SHA-256, executable/model path, command line, listener ownership, and live API alias/context/parallel/Vision. The slot was idle and Goose was closed. PID 65172 then stopped normally, port 18080 became free, and VRAM returned to the release baseline. BLUE received the same three-script correction with a timestamped backup and matching hashes; no BLUE runtime was started.

## 2026-09-07 Vision revision

After a Goose image attachment reached the Quick endpoint but the text-only runtime could not inspect it, the user selected Vision as the default Quick behavior. Both Quick manifests now require the same pinned F16 projector and SHA-256 as the corresponding Turbo profile, pass `--mmproj` to llama.cpp, and require the live API to report Vision true. The 64K runtime context, 57,344 Goose client context, 8K output, Q8_0/Q8_0, MTP1, Reasoning Low/2,048, prompt cache, power limits, and BLUE GPU split are unchanged.

The internal profile IDs remain unchanged so an earlier Quick process can still be located. Release permits Vision false only for the text-only transition when the exact managed command line contains `--no-mmproj`; new startup and normal reuse still require Vision true. The Vision revision remains Candidate until it is loaded and its image path, latency, VRAM, and stability are measured on each target. Static artifacts and projector hashes are verified on both targets.

## 2026-09-07 Goose v1.49 image-transport correction

### Observed

- The live Quick llama.cpp `/props` endpoint reported `modalities.vision=true`, context 65,536, and the expected F16 projector.
- Goose's local request log did not contain an image content block. It replaced the attachment before transport with `[image omitted: model does not support vision]`.
- Goose Desktop was v1.49.0. In that release, the built-in OpenAI-compatible formatter evaluates `ModelConfig.supports_vision.unwrap_or_default()`. An arbitrary local alias has no canonical capability record, so the missing value becomes false even when the server itself reports Vision true.
- Renaming a local alias to include the word `vision` cannot fix this because the lookup is by canonical provider/model identity, not by substring and not by llama.cpp `/props`.

### Correction

New MAIN and BLUE Quick launches expose a friendly local Qwen identity ending in `-gpt-4o`. Goose v1.49 strips the prefix from the first recognized family marker, so the trailing token maps to the canonical Vision metadata while Goose's UI keeps the actual local model identity visible. `OPENAI_HOST` and `OPENAI_BASE_PATH=/v1/chat/completions` still route the request to the local managed llama.cpp endpoint. The loaded weights remain JonathanColetti Qwen3.8 Q5_K_M and the pinned F16 projector; no OpenAI service or model is contacted. Process-local context 57,344, output 8,192, temperature 0, MTP1, Reasoning Low/2,048, power limits and GPU split are unchanged.

The canonical-only `gpt-4o` value and old MAIN/BLUE Quick aliases are declared separately as legacy values. They are accepted only when Release has identified the exact managed Quick profile and has revalidated process ownership, path, hashes, command line, listener, context, parallel and live API. Normal startup accepts only the target-specific friendly alias; an arbitrary alias cannot use this exception.

This corrects the identified pre-transport omission. End-to-end image recognition remains unqualified until Goose is fully closed, the old Quick runtime is explicitly released, the revised Quick profile is started, and a fixed PNG is successfully recognized on each target.

The BLUE external runtime received `BLUE-Quick.json`, `Turbo.Common.psm1`, `Release-ManagedRuntime.ps1`, and `Stop-ManagedTurbo.ps1` after exact host/IP verification. The previous files are preserved under `C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\backups\before-goose-vision-alias-20260907-171616`; all four destination hashes match the repository. This static synchronization did not start or stop a runtime. A subsequent read-only BLUE preflight found a stale Turbo state whose recorded PID was no longer running, so it was not treated as live runtime evidence and was not cleaned up during this correction.

The later friendly display alias update re-verified `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`, preserved the previous BLUE manifest under `C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\backups\before-friendly-goose-alias-20260907-180735`, and synchronized `BLUE-Quick.json` with SHA-256 `d3ee9d2a104c1badf1b0da8b96befaf285f1f8bf4d23d84c1fcbd98912d7a868`. No model or runtime was started or stopped.

Additional evidence:

- [Goose issue #11814](https://github.com/block/goose/issues/11814)
- [Goose v1.49.0 model capability type](https://github.com/block/goose/blob/v1.49.0/crates/goose-provider-types/src/model.rs)
- [Goose v1.49.0 OpenAI-compatible formatter](https://github.com/block/goose/blob/v1.49.0/crates/goose-providers/src/openai_compatible.rs)
