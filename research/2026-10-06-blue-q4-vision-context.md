# BLUE Q4 Vision / extended-context qualification

Status: RESEARCH_COMPLETE_WITH_LIMITATIONS; explicit user-approved isolated experiment, not Production promotion. Both256K and both controlled192K trials completed; BLUE restored empty.

## Scope and preserved baseline

- BLUE only: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`, RTX3090 24GB plus RTX3060 12GB, UUID and PCI Bus identity checked.
- MAIN/RTX5090 model experiments are deferred. No Q5 capacity retest.
- Observed start: LM Studio 0.4.25+1 running, zero loaded instances, no standalone server. Restore that empty runtime after every experiment.
- Power limits remain RTX3090 259W / RTX3060 170W. No driver, firewall, model presets, Goose, Kilo, Zoo, or current loader changes.
- Existing Q5 Recommended Production and Q6 Current/Reference/Safe profiles remain unchanged; new results remain Candidate.
- Prior unrelated dirty changes are retained. SHA-only local preflight and document backups: ignored `benchmarks/raw/blue-q4-vision-20261006/`.

## Official upstream audit (2026-10-06 JST)

GGUF latest revision remains `45d0fc0ad6cfcf9eeee6008ddaea925536409b18` (2026-08-29). Compared with historical `dee0a3164d9e11bbbebf5b63f52ba99443d14fc3`, both fused-MTP candidate files are byte-identical:

| Artifact | Bytes | LFS SHA-256 |
| --- | ---: | --- |
| Q4_K_M | 16,810,714,528 | `4c5e2db039e9325ac7724c8846c71356a24ad1cdfa28002d73ecb6be645f9675` |
| IQ4_XS | 15,309,039,008 | `53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5` |
| F16 Vision projector | 927,606,912 | `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c` |

The projector was renamed for discovery but not replaced. Draft-Q4_0 and README updates are not target-weight updates. The original safetensors repository tip is `5bb7aa90f0efef548e87005b1fb7658e522b6b7f`; later commits are README-only and do not provide a new checkpoint.

Sources: [GGUF history](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/commits/main), [old file tree](https://huggingface.co/api/models/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/tree/dee0a3164d9e11bbbebf5b63f52ba99443d14fc3?expand=true), [current file tree](https://huggingface.co/api/models/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/tree/45d0fc0ad6cfcf9eeee6008ddaea925536409b18?expand=true), [projector rename](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/commit/a4aabef22981c3067245c535dc0461dc58953c3b), [original checkpoint history](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored/commits/main).

Native context is 262,144 with native Vision; no RoPE scaling experiment is needed. The publisher's Q4_K_M and IQ4_XS PPL error bars overlap and do not establish an agent/coding/Vision winner. IQ4_XS saves 1.398 GiB of model-file space, not a guaranteed proportional context increase. Sources: [fixed publisher card](https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/blob/45d0fc0ad6cfcf9eeee6008ddaea925536409b18/README.md), [upstream Qwen card](https://huggingface.co/Qwen/Qwen3.8-27B).

## Protocol and limits

- Reuse the existing audited official llama.cpp `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`, executable SHA `970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4`.
- Isolated loopback port 18082, one explicitly owned process with Windows Job cleanup, new alias, no MCP/Agent Client invocation. Refuse an existing server or loaded LM Studio model; never call unload-all or release existing processes.
- Vision F16 projector enabled for every load. MTP3, Flash Attention ON, batch1024, parallel1, no-mmap, all layers on CUDA0=3090 plus CUDA1=3060. Initial controls use ubatch512 and split `0.7108,0.2892`. Separately labeled Candidates test ubatch256 and split `0.75,0.25`; no existing preset is changed.
- First test Q8_0/Q8_0 KV. Stop before inference on the existing strict gate: combined WDDM Shared `<4 GiB`, each NVIDIA GPU `<=2 GiB`, dedicated memory not exhausted. Exact DXGI name/LUID to live counter mapping; no nearest-VRAM or fixed-index mapping.
- Q4_0/Q4_0 KV is a **separate** Candidate condition if Q8 cannot reach larger contexts. Model-weight quantization and KV quantization are different variables; no automatic global adoption.
- Load/capacity success is not quality/practical acceptance. Warm-up is separate; text, exact mock Tool Calling, deterministic image-shape recognition and code evaluation repeat three times. Long-input six-fact retrieval uses ~80% of runtime context with at least 16K output plus 8K growth reserved. Requests use actual server tokenizer/usage, temperature0, seed42, reasoning OFF. The initial long retrieval is uncached; the final protocol adds explicitly cached Tool Call and Vision follow-ups, with cache usage and timings recorded. Output reservation is a budget calculation, not a tested 16K generation.
- Coding interval fixture includes non-overlap, touching boundaries, nested intervals, empty input, ordering, fresh arrays and no mutation. Do not revise expectations after a candidate failure.
- Raw synthetic requests, SSE, timing, MTP draft acceptance, exact context/vision readback, memory samples, errors, config hashes and restored state stay outside Git on BLUE under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\qualification\blue-q4-vision-20261006`.
- No heavy formal Agent Benchmark, no winner declaration. A single synthetic long-input retrieval is not a sustained Goose/Desktop or broad reasoning-quality acceptance.

## Initial checkpoint

Initial Q4_K_M/Q8 KV/ubatch512: 128K load passed (Shared 3.694 GiB); 192K load failed the unchanged strict gate (Shared 4.688 GiB, both GPUs over 2 GiB). That failed run performed no inference and restored empty runtime. Switching only the target KV to Q4 did **not** reduce Shared enough (4.694 GiB), despite lower dedicated use. These failed configurations are not escalated to 256K.

A separate ubatch256 Candidate passed at 192K with Q8 KV (Shared 3.123 GiB), then passed 256K (Shared 3.624 GiB). At 256K the original split left only 991 MiB free on the 3060 before inference. The separately tested `0.75,0.25` split passed with 2,930 MiB free on the 3090 and 2,207 MiB on the 3060. Completed quality/latency outcomes are recorded below and in the curated result; capacity PASS does not override quality failures.

Preliminary 128K / original settings: text, Tool Call and Vision 3/3 each; six-fact retrieval PASS at 104,773 actual prompt tokens. Uncached long-input TTFT 206.222 seconds / prompt 508.335 tok/s. Coding 0/3: the deterministic answer wrongly merged disjoint closed intervals `[1,10]` and `[11,12]`. Preserve this failure; no same-prompt Q5 control exists, so it does not establish a quantization-caused regression. Peak Shared 3.737 GiB, minimum per-GPU headroom 7,532/3,199 MiB; empty runtime and protected hashes restored.

IQ4_XS was downloaded through the existing HF CLI to external staging, exact byte count and official LFS SHA checked before moving to an absent external LM Studio model path. No authentication, client config, or production model file was replaced.

### Why ubatch is a different variable

The pinned runtime reserves compute graphs based on `min(n_ctx,n_ubatch)` and creates attention-mask/workspace buffers. Reducing ubatch changes workspace/processing granularity, not the target weight quantization or selected context capacity; throughput can change and outputs need not be bit-identical. The observations support a workspace-related explanation, but do **not** prove that the entire WDDM Shared allocation is a particular mask or dedicated-VRAM spill. Sources: [context/graph reservation](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/src/llama-context.cpp), [graph inputs](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/src/llama-graph.cpp), [CUDA buffers](https://github.com/ggml-org/llama.cpp/blob/f280b26983ad0fdb705a0d9ebf0503e76f2899b0/ggml/src/ggml-cuda/ggml-cuda.cu).

Verbose 192K readback: target KV Q8/Q8 = 6,528 MiB over 16 attention layers (CUDA0 4,488 / CUDA1 2,040); MTP draft KV remains F16/F16 = 768 MiB. Target CUDA compute buffers are 1,213.09 MiB each, host compute 395.10 MiB, draft host compute 409.04 MiB; projector compute is also present. Model quantization, target KV and draft KV are recorded separately.

First preflight attempted before loading exposed stale/duplicate DXGI adapters in the SSH session. The probe now requires one exact **live-counter LUID intersection** per physical NVIDIA device; ambiguity is fail-closed. No model was started by the rejected preflight. Evidence folders are retained rather than overwritten.

## 256K quality checkpoint

Q4_K_M / Q8 KV / ubatch256 / split75:25 / Vision: peak Shared 3.666 GiB, minimum dedicated headroom 2,874/2,201 MiB, protected hashes unchanged and empty runtime restored. Short text/Tool/Vision passed 3/3 each; the original interval coding contract failed 0/3 again.

The 209,891-token prompt took 573.649 seconds to first output (366.222 prompt tok/s). Instead of the requested six-field JSON answer the model issued an unrequested `lookup_inventory` call with literal `vault_0` rather than the archived nonce value. This is a **long-input instruction-following failure**, not a load/OOM failure. The controller's JSON parser then aborted, so cached follow-ups were not performed in this run. Original `EXPERIMENT_ERROR`, raw response and logs are retained in `20261006-181753-Q4_K_M-262144-q8_0-b22c18`.

The controller was minimally amended to record invalid JSON/arguments as failed assertions rather than aborting the series, preserving actual unrequested tool calls in message history with explicit mock-error responses (no real tool execution). Initial prompts, allowed tool schema, expected answers and coding cases were not changed. Subsequent runs use this same revised harness; older runs retain their original harness SHA and evidence.

IQ4_XS / same256K settings passed text3/3, Tool3/3, Vision3/3, six-fact retrieval, cached long Tool Call and long-history Vision. Original coding remained0/3, so raw aggregate status stays `QUALITY_FAIL`, not rewritten as full PASS. The initial long-request SHA is identical to Q4_K_M (`ee837411383d6f1c84726cafb64431abe96494ba7e9a5526b5fc0da7c9175da9`); controller validation changes do not change this model input. Uncached209,891-token TTFT556.361sec; cached follow-up Tool TTFT2.440sec/210,107 cached tokens and Vision TTFT3.127sec/210,236 cached tokens. Peak Shared3.593GiB, minimum dedicated free3842/2627MiB, RAM minimum7.747GiB, max core temperatures82/79C, empty runtime restored/config hashes unchanged. Cumulative thermal counters cannot attribute earlier events to this test; a later readback showed thermal slowdown not active, power-cap enforcement active and GPU operating limit93C, without tuning.

New192K protocol retains the original coding failures but separately clarifies the continuous-real-interval domain and adds an ~8K tool-enabled retrieval control. Q4_K_M already returned an unrequested tool call in that short control, so its256K error cannot be attributed solely to expanded context. Different nonces/tool availability in preliminary controls limit causal comparisons; results are observational, not a model-quality ranking. Both192K variants use the same revised harness/source snapshot and settings.

## Final192K results and recommendation

Both192K variants passed basic Text/Tool/Vision3/3 and clarified coding3/3, but retained original coding0/3; both failed the8,372-token tool-enabled control and157,481-token long retrieval/argument lookup. Long-history Vision passed in both. Peak Shared Q4_K_M3.166/IQ4_XS3.093GiB; minimum dedicated free4890/3513 versus5858/3939MiB. Cold long TTFT370.104/355.697sec; cached Tool TTFT2.161/2.052sec (incorrect arguments), cached Vision2.687/2.582sec (correct). Same harness and initial request hashes are retained in the result and raw source snapshots.

Maximum observed memory-safe runtime context is262,144 with Vision and Q8 KV in both variants. Maximum successful long chain in this corpus is IQ4_XS at256K (initial209,891, later image prompt210,623 tokens), but there is no certified daily Goose maximum or broad model-quality winner. Prioritize IQ4_XS for the next isolated extended-context trial;192K offers more headroom/lower actual-input latency,256K is a large-history Candidate. Its192K/short selection failures still prevent blanket promotion. Cache reuse in this server does not prove that Goose compaction will preserve the same prefix.

Native LM Studio and Goose Desktop acceptance, reasoning ON, diverse inputs, actual16K output, near-full history, sustained/concurrent workload and human responsiveness remain pending. MAIN/5090 and Q5 capacity are not tested. Final BLUE readback2026-10-06T09:58:56Z confirmed loaded0/standalone0/managed listeners0, unchanged591.86 driver and259W/170W. Protected config/loader hashes unchanged. See [curated result](../benchmarks/results/2026-10-06-blue-q4-vision-context.md) for the full distinction between memory, model failures and future operational acceptance.
