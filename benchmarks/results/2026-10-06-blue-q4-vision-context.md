# BLUE Q4 Vision / extended-context qualification

Status: RESEARCH_COMPLETE_WITH_LIMITATIONS / Candidate only; no Production/Current promotion. Memory gates PASS; original quality FAIL and instruction-selection failures remain preserved.

## Controlled scope

BLUE `DESKTOP-L9HAM1G / pc5700x / 192.168.0.104`, RTX3090+3060, 259W/170W. Pinned Jonathan revision `45d0fc0ad6cfcf9eeee6008ddaea925536409b18`, official F16 Vision projector, existing official llama.cpp `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`, isolated loopback18082, MTP3, batch1024, parallel1, no-mmap, Flash Attention ON, temperature0/seed42/reasoning OFF. Main comparison retains target Q8 KV; draft KV is F16. Every load has Vision enabled. Identity uses names/UUID/PCI Bus and live-counter LUID, not GPU index.

Gate unchanged: combined Shared <4GiB, each NVIDIA GPU <=2GiB, dedicated headroom >0; sampled every5sec. >=1GiB per-GPU daily margin is an additional recommendation. Restore observed empty runtime, never run unload-all/production loaders. Global client/model settings and MAIN experiments are out of scope.

## Capacity controls

| Quant | Context | Target KV | ubatch | CUDA3090:3060 split | Shared GiB | Result |
| --- | ---: | --- | ---: | --- | ---: | --- |
| Q4_K_M | 131,072 | Q8 | 512 | .7108:.2892 | 3.694 | load PASS |
| Q4_K_M | 196,608 | Q8 | 512 | .7108:.2892 | 4.688 | gate FAIL; no inference |
| Q4_K_M | 196,608 | Q4 | 512 | .7108:.2892 | 4.694 | gate FAIL; no inference |
| Q4_K_M | 196,608 | Q8 | 256 | .7108:.2892 | 3.123 | load PASS |
| Q4_K_M | 262,144 | Q8 | 256 | .7108:.2892 | 3.624 | load PASS; 3060 free991MiB |
| Q4_K_M | 262,144 | Q8 | 256 | .75:.25 | 3.623 | load PASS; free2930/2207MiB |
| IQ4_XS | 262,144 | Q8 | 256 | .75:.25 | 3.593 | inference memory PASS; minimum free3842/2627MiB |
| Q4_K_M | 196,608 | Q8 | 256 | .75:.25 | 3.166 | inference memory PASS; minimum free4890/3513MiB |
| IQ4_XS | 196,608 | Q8 | 256 | .75:.25 | 3.093 | inference memory PASS; minimum free5858/3939MiB |

Reducing ubatch solved Shared pressure without target KV Q4. Split75:25 avoids making the3060 the tight GPU. No existing preset is changed; Shared alone does not prove dedicated-VRAM spill. Maximum runtime context is not maximum input plus unrestricted output.

## Quality / latency checkpoint

Preliminary Q4/128K/original settings: Text3/3, Tool3/3, Vision3/3, six-fact retrieval PASS at104,773 prompt tokens, TTFT206.222sec, prefill508.335tok/s, generation35.252tok/s; Shared peak3.737GiB. That retrieval had no tool schema, so it is not a context-only A/B control for later tool-enabled prompts.

Q4/256K/ubatch256/split75:25: Text3/3, Tool3/3, Vision3/3, peak Shared3.666GiB, minimum dedicated free2874/2201MiB. At209,891 prompt tokens, TTFT573.649sec/prefill366.222tok/s, the model issued an unrequested inventory call instead of the six-field JSON answer. No truncation/OOM. Original controller `EXPERIMENT_ERROR`/raw response retained; cached follow-ups were not performed in that run.

Original coding0/3 at both Q4 contexts: adjacent integer intervals were merged although the evaluator expects continuous closed intervals. Preserve FAIL, but do not infer quantization-caused degradation: no same-prompt Q5 control exists, and interval-domain interpretation is ambiguous. New192K runs add a separately labeled domain-clarified diagnostic with unchanged edge cases. This never retroactively replaces original FAIL.

IQ4/256K: Text3/3, Tool3/3, Vision3/3; six-fact retrieval, cached long Tool Call and long-history Vision PASS at209,891 initial prompt tokens. Initial long-request SHA matches Q4 exactly (`ee837411383d6f1c84726cafb64431abe96494ba7e9a5526b5fc0da7c9175da9`), despite the later controller error-handling revision. Uncached TTFT556.361sec/prefill377.412tok/s; cached Tool TTFT2.440sec/elapsed5.019sec and Vision TTFT3.127sec/elapsed4.367sec. The server reused210,107/210,236 tokens respectively. Peak Shared3.593GiB, minimum free3842/2627MiB; RAM minimum7.747GiB, max core temperatures82/79C. Original coding0/3 means raw aggregate stays `QUALITY_FAIL`, not full PASS.

Both192K variants: text/Tool/Vision and domain-clarified coding3/3 each; original coding0/3. Tool-enabled retrieval failed at both8,372 and157,481 prompt tokens, and the long follow-up used literal vault labels rather than values. Long-history Vision PASS. Q4 uncached long TTFT370.104sec, IQ4 TTFT355.697sec. The short failures disprove a claim that the error is exclusive to256K; control nonce/tool availability differences limit causal interpretation. Both variants used identical harness SHA `ca1d6615517032c69df85ac1d2396144b2eee7ab85ecf2a692281ba2b6f81934` and initial long-request SHA `874f4d6b64807fdef9213a44d9f0778dc38d2f0db3a4627f68cbc70e71de08bb`.

Deterministic three-time repeats test reproducibility, not independent task diversity. Long input targets80% of context, reserves16K output+8K growth; actual16K output generation is not tested. Latency across these contexts uses different actual input lengths, so it is not a same-input context-allocation speed comparison.

## Provenance / limits

Unique immutable run folders preserve original preflight rejection, capacity failures, requests, SSE, results, memory, logs and harness SHA. Invalid JSON/arguments now produce assertion FAIL rather than controller abort. Unexpected tool actions are retained with explicit mock-error responses; no inventory API is invoked. Initial prompts/tool schema/expected answers remain unchanged. New192K protocol also adds an ~8K tool-enabled retrieval control and independent long-history Vision. Restricted coding VM rejects escape/import surfaces, disables string/wasm code generation and injects primitive JSON; not a general sandbox.

BLUE raw: `C:\Users\Atsuki\AppData\Local\Local-LLM-Coding-Stack\qualification\blue-q4-vision-20261006`. MAIN ignored copy/backups/config hashes: `benchmarks/raw/blue-q4-vision-20261006/`. Download staging/HF credentials/cache/model/runtime payloads stay outside Git. Curated source details: [research note](../../research/2026-10-06-blue-q4-vision-context.md); separate Candidate records under `configs/candidates/blue-jonathan-*-vision-extended-context.json` are not import files/loaders.

## Decision and preservation

- Maximum **tested memory-safe runtime context**:262,144, both quantizations, Vision ON, target Q8 KV, ubatch256/split75:25. This is not a certified maximum **daily practical** Goose context. Largest successful tested initial long input:209,891 tokens with IQ4_XS; later Tool+Vision prompt210,623 tokens also succeeded.
- IQ4_XS is the next extended-context **trial Candidate** to prioritize: it saves1.398GiB of model-file space, leaves more GPU headroom and had the successful256K long chain. Do not claim it is globally smarter/equivalent to Q5/Q6: its192K and short controls failed, the256K corpus is one sample and output/temperature/order differences limit broad speed/quality conclusions.
- For latency/headroom,192K is a conservative next **capacity** trial (actual157K prompt~5.9min versus209K~9.3min). It is not already a quality-approved daily preset.256K is a large-history trial; cache-preserving continuations can be fast, but new prefixes/compaction may require costly fresh prefill. Do not increase Goose context or compact threshold by inference from this API test.
- Q4_K_M remains available, but its tool-enabled long selection failures are not solved by reducing context. Do not promote either variant to Production/Current at this stage. Original raw aggregates:128K Q4 `QUALITY_FAIL`,256K Q4 `EXPERIMENT_ERROR`,256K IQ4 `QUALITY_FAIL`,192K both `QUALITY_FAIL`.
- Final BLUE check2026-10-06T09:58:56Z: LM Studio loaded instances0, standalone processes0 and no listeners on18080/18081/18082, NVIDIA591.86 unchanged, RTX3090 259W/RTX3060 170W, idle used685/0MiB. Existing9 protected BLUE configuration/loader hashes remain unchanged in completed final-protocol runs; MAIN Global10 locations and unrelated repository files are checked separately. Intentional changes are external IQ4 download/new isolated harness/evidence and repository Candidate records, not a return to the historical loaded Q5 snapshot.

Pending: native LM Studio acceptance (SDK1.5.0 has eval batch but no explicit public microbatch field; do not invent a setting), Goose Desktop context/output readback and end-to-end Vision/compaction, diverse coding/reasoning, sustained real tool loops, near-full input, reserved16K generation, human desktop responsiveness and concurrent GPU workloads. MAIN/5090 deferred; no Q5 capacity retest or daily promotion.

## Final repository validation

- `scripts/Test-Repository.ps1`: PASS, 25 managed JSON records and exactly one Current; isolated fixtures/mocks only, no MAIN model operation.
- Dedicated qualification regression: 16/16 PASS; curated four-run JSON agrees with immutable raw record SHA/status/context/memory/timing/results.
- `git diff --check`: PASS. Secret scan: 239 text files, zero secret findings; four unchanged public loopback dummy-key placeholders reviewed against the pre-task SHA baseline.
- MAIN Global10 locations: SHA changes0. Pre-task234 repository-file baseline: unexpected changes0; pre-existing unrelated dirty work remains intact. Raw evidence/backups are Git-ignored.
- Model quality failures above remain failures; passing harness validation does not convert a Candidate into operational acceptance. No commit/push performed.
