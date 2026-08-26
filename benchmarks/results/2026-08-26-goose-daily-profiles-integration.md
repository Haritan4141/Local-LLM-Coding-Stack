# Goose Daily Profiles integration regression

Date: 2026-08-26 (Asia/Tokyo)

## Scope

`scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat` was exercised as the single daily entry point for MAIN and BLUE Stable, Turbo, and Quality Reference. The regression covered canonical runtime switching, Goose provider/model/context/output selection, endpoint cross-checks, Goose Desktop launch, short prompts, the required 10K+ MAIN Turbo prompt, fail-closed behavior, and final Stable recovery.

Repository lifecycle `Current` was not changed. Model files, LM Studio application data, and raw runtime logs remain outside Git.

## Integrated menu result

| Choice | Target / profile | Runtime | Provider / endpoint | Result |
|---:|---|---|---|---|
| 1 | MAIN Stable 96K / Output 16K | LM Studio Q5_K_M Vision | `lmstudio` / `127.0.0.1:1234` | PASS |
| 2 | MAIN Stable 96K / Output 32K | LM Studio Q5_K_M Vision | `lmstudio` / `127.0.0.1:1234` | Static/profile test PASS; same canonical runtime as choice 1 |
| 3 | MAIN Turbo 96K / Output 16K | managed official llama.cpp | `openai` / `127.0.0.1:18080` | PASS |
| 4 | MAIN Quality Reference 64K / Output 32K | LM Studio Q6_K Vision | `lmstudio` / `127.0.0.1:1234` | PASS |
| 5 | BLUE Stable 96K / Output 16K | BLUE LM Studio Q5_K_M Vision | `custom_lm_studio_3090_remote` / `192.168.0.104:1234` | PASS |
| 6 | BLUE Stable 96K / Output 32K | BLUE LM Studio Q5_K_M Vision | `custom_lm_studio_3090_remote` / `192.168.0.104:1234` | Static/profile test PASS; same canonical runtime as choice 5 |
| 7 | BLUE Turbo 96K / Output 16K | BLUE managed official llama.cpp plus MAIN tunnel | `openai` / `127.0.0.1:18081` | PASS |
| 8 | BLUE Quality Reference 64K / Output 32K | BLUE LM Studio Q6_K Vision | `custom_lm_studio_3090_remote` / `192.168.0.104:1234` | PASS |
| 9 | MAIN Turbo 96K / Output 32K | managed official llama.cpp | `openai` / `127.0.0.1:18080` | Added after separate 17K+ Output32K qualification; PASS |
| 10 | BLUE Turbo 96K / Output 32K | BLUE managed official llama.cpp plus MAIN tunnel | `openai` / `127.0.0.1:18081` | Added after separate 17K+ Output32K qualification; PASS |
| 0 | Cancel | no change | no change | PASS, exit code 0 |

Invalid menu input returned exit code 2. The BAT remains a thin selector; runtime settings stay in the existing canonical wrappers and Turbo manifests.

## Observed Goose regressions

| Profile | Observed model in Goose | Short smoke |
|---|---|---|
| MAIN Stable | `qwen3.8-27b-uncensored-vision-q5km` | `STABLE_SMOKE_OK` displayed and completed |
| MAIN Turbo | `qwen3.8-27b-uncensored-vision-q5km-turbo` | requested marker displayed and request completed |
| MAIN Quality Reference | `qwen3.8-27b-uncensored-vision` | `MAIN_QUALITY_SMOKE_OK` displayed and completed |
| BLUE Stable | `qwen3.8-27b-uncensored-vision-q5km-blue` | `BLUE_STABLE_RETRY_OK` displayed and completed |
| BLUE Turbo | `qwen3.8-27b-uncensored-vision-q5km-blue-turbo` | `BLUE_TURBO_SMOKE_OK` displayed and completed |
| BLUE Quality Reference | `qwen3.8-27b-uncensored-vision-blue` | `BLUE_QUALITY_SMOKE_OK` displayed and completed |

One earlier BLUE Stable run and one earlier MAIN Quality run left a transient Goose `processing`/loading indication after the backend had already returned to `idle / queued 0`. Repeating each profile completed normally and displayed the requested marker. This was observed as a Goose Desktop UI completion residue, not a runtime context or endpoint failure.

## 10K+ MAIN Turbo context regression

The integrated MAIN Turbo choice was launched from Goose Desktop with a 14,581-character marker prompt. Server-side observations were:

- processed prompt: 17,936 tokens
- `n_ctx_slot`: 98,304
- Goose process-local client limit: 90,112
- max output: 16,384
- `truncated`: 0
- `400 exceed_context_size`: not observed
- server slot returned to not-processing after the response
- observed prompt processing throughput: approximately 1,942.73 tok/s

This passes the required regression for the former 9,000 > 8,192 ambiguity. A Goose loading label remained visible once after the backend had completed; the server-side context and completion state were correct.

## Safety and cross-check results

- A running Goose process was detected before canonical wrapper invocation and failed closed without switching runtime or provider. Goose was not killed automatically.
- Stable and Quality required the exact LM Studio alias, context, parallel 1, Vision, idle/queued 0, provider, client context/output, and endpoint before launch.
- Turbo required managed process ownership, health, exact `-turbo` alias, context 98,304, parallel 1, Vision, and port 18080/18081 before launch.
- Turbo persistent Goose configuration SHA-256 was unchanged before and after launch.
- BLUE identity was verified as `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`.
- No Firewall, driver, firmware, model-file, or repository lifecycle Current change was made.

## Final verified state

| Target | Final runtime state |
|---|---|
| MAIN RTX5090 | LM Studio Q5_K_M Vision, context 98,304, Vision true, parallel 1, `idle`, queued 0, RTX5090 402 W |
| BLUE RTX3090 + RTX3060 | LM Studio Q5_K_M Vision, context 98,304, Vision true, parallel 1, `idle`, queued 0, RTX3090 259 W / RTX3060 170 W |

Goose process count was 0. MAIN ports 18080/18081 and BLUE port 18080 were free. Managed Turbo process and MAIN tunnel counts were 0. The persistent Goose profile was returned to MAIN Stable 96K / Output 16K.

## Automated validation

- `scripts/tests/Test-GooseProfileSelector.ps1`: PASS
- `scripts/tests/Test-QwenVisionProfileLoaders.ps1`: PASS
- `scripts/Test-Repository.ps1`: PASS
- PowerShell parse, BAT mapping, relative paths, Cancel, invalid input, running-Goose guard, and provider/model/endpoint fail-closed fixtures: PASS
