# Goose Turbo Output32K qualification

Date: 2026-08-26 (Asia/Tokyo)

## Decision

MAIN RTX5090 and BLUE RTX3090+RTX3060 both passed an isolated Goose client-path generation beyond 16K output tokens. `Turbo 96K / Output 32K` is therefore qualified for explicit long-output selection on both systems. Existing `Turbo 96K / Output 16K` remains the normal/default Turbo choice.

Repository lifecycle `Current`, the Q5_K_M model artifacts, Turbo runtime manifests, LM Studio global settings, Firewall, driver, and Power Limits were not changed. Raw Goose output and diagnostic files remain outside Git under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo\qualification\`.

## Controlled settings

| Setting | MAIN | BLUE |
|---|---|---|
| Runtime | pinned official llama.cpp | pinned official llama.cpp through managed MAIN tunnel |
| Model alias | `qwen3.8-27b-uncensored-vision-q5km-turbo` | `qwen3.8-27b-uncensored-vision-q5km-blue-turbo` |
| Runtime context | 98,304 | 98,304 |
| Goose client context | 90,112 | 90,112 |
| Goose max output | 32,768 | 32,768 |
| KV / MTP / parallel | Q8_0-Q8_0 / draft 3 / 1 | Q8_0-Q8_0 / draft 3 / 1 |
| Vision | true | true |
| Power | RTX5090 402 W | RTX3090 259 W / RTX3060 170 W |

Goose CLI ran with process-local `openai` provider variables, no persistent profile, no tools, one turn, temperature 0, and a deterministic five-digit sequence request. PASS required more than 16,384 output tokens, `n_predict=32,768`, exact full-sequence validation, completed status, one idle slot after generation, 98,304 server context, zero stderr, and an unchanged persistent Goose configuration SHA-256.

## Results

| Check | MAIN RTX5090 | BLUE RTX3090+RTX3060 |
|---|---:|---:|
| Result | **PASS** | **PASS** |
| Goose output tokens | **17,100** | **17,183** |
| Input / total tokens | 447 / 17,547 | 478 / 17,661 |
| Requested sequence | `00001` through `02850` | `00001` through `02850` |
| Full sequence valid | PASS | PASS |
| Goose status / process exit | completed / 0 | completed / 0 |
| Observed `n_predict` | 32,768 | 32,768 |
| Observed runtime `n_ctx` | 98,304 | 98,304 |
| Final slot | idle | idle |
| Persistent config | SHA-256 unchanged | SHA-256 unchanged |
| stderr | 0 bytes | 0 bytes |

The managed runtime had already passed direct API long-output qualification before this Goose-specific test: MAIN completed 18,432 output tokens at 109.90 tok/s, and BLUE completed 24,000 output tokens at 41.840 tok/s. Those server-path rates are retained as the controlled throughput evidence; the Goose qualification focused on proving that the client does not stop at 16K.

During the BLUE run, host identity was rechecked as `pc5700x / DESKTOP-L9HAM1G`. A read-only GPU sample during generation observed RTX3090 at 215.55 W of the unchanged 259 W limit, 17,871/24,576 MiB and 73 C; RTX3060 at 126.89 W of the unchanged 170 W limit, 8,875/12,288 MiB and 77 C.

## Operational interpretation

- Output32K raises the maximum allowed completion; it does not force every response to be 32K.
- It does not change the 98,304-token runtime allocation or model/KV load profile.
- Input plus generated output must still fit the runtime context. A request cannot simultaneously consume the entire 90,112-token client window and another 32,768 output tokens without compaction or input reduction.
- A genuinely long completion consumes more time and session context and can allow an unproductive agent loop to continue longer. Use Output16K for normal work and select Output32K only when a task previously stopped at the 16K client limit or clearly needs a long uninterrupted result.

## Integration

The Goose Daily selector was renumbered sequentially from top to bottom on 2026-08-27. The qualified Output32K choices are now:

- `[4] MAIN Turbo - Q5KM Vision 96K / Output 32K`
- `[9] BLUE Turbo - Q5KM Vision 96K / Output 32K`

Both selections reuse the already-qualified runtime manifests and canonical Turbo wrappers. Only the Goose child process receives `GOOSE_MAX_TOKENS=32768`; the 16K choices continue to pass 16,384 and persistent Goose configuration remains unchanged.

## Final recovery

After qualification and integrated `NoLaunch` selection checks, both managed Turbo processes and the BLUE tunnel were ownership-validated and stopped. Final state was:

- MAIN LM Studio: Q5_K_M Vision, context 98,304, Vision true, parallel 1, idle, queued 0, RTX5090 402 W.
- BLUE LM Studio: Q5_K_M Vision, context 98,304, Vision true, parallel 1, idle, queued 0, RTX3090 259 W / RTX3060 170 W.
- Goose process count: 0; MAIN ports 18080/18081 and BLUE port 18080: free.
- Persistent Goose profile: MAIN Stable 96K / Output16K (`GOOSE_CONTEXT_LIMIT=90112`, `GOOSE_MAX_TOKENS=16384`).
