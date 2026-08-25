# Daily Profiles

These are the official daily Operational Profile entry points for Qwen3.8. They do not change the sole repository lifecycle `Current` model.

## RTX5090 MAIN

| Profile | Backend / model | Effective settings | Endpoint / power | Launcher | Intended use |
|---|---|---|---|---|---|
| Stable | LM Studio / Jonathan Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | `http://127.0.0.1:1234/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/1-Stable.bat` | Recommended everyday default and recovery |
| Turbo | official pinned llama.cpp / same Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | `http://127.0.0.1:18080/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/2-Turbo.bat` | Explicit fast Coding, Agent, Vision, long generation |
| Quality Reference | LM Studio / Jonathan Q6_K Vision Balanced | 65,536 context; MTP4; Q8_0/Q8_0; batch2048; ubatch512; parallel1; Vision | `http://127.0.0.1:1234/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/3-Quality-Reference.bat` | Compare a questionable Q5 output |

Daily selector: `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/Profile-Selector.bat`

Root one-click: `scripts/lmstudio/model-loaders/00-RTX5090-Daily-Profiles.bat`

## BLUE RTX3090 + RTX3060

| Profile | Backend / model | Effective settings | Endpoint / power | MAIN remote launcher | Intended use |
|---|---|---|---|---|---|
| Stable | LM Studio / Jonathan Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | BLUE `http://192.168.0.104:1234/v1`; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/1-Stable_REMOTE.bat` | Recommended everyday node default and recovery |
| Turbo | official pinned llama.cpp / same Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | BLUE 18080; MAIN `http://127.0.0.1:18081/v1` tunnel; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/2-Turbo_REMOTE.bat` | Explicit fast Coding, Agent, Vision, long generation |
| Quality Reference | LM Studio / Jonathan Q6_K Vision Balanced | 65,536 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | BLUE `http://192.168.0.104:1234/v1`; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/3-Quality-Reference_REMOTE.bat` | Compare a questionable Q5 output |

MAIN remote selector: `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/Profile-Selector_REMOTE.bat`

BLUE local selector: `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/Profile-Selector_LOCAL.bat`

Root MAIN one-click: `scripts/lmstudio/model-loaders/00-BLUE-Daily-Profiles-REMOTE.bat`

## Profile meaning and retained roles

Quality Reference is not a guarantee that every Q6_K answer is better than Stable. It is a higher-precision quantization reference for investigating a questionable Q5_K_M result. Because the Reference context is 64K, do not use it as a direct comparison for a task over 64K.

Stable is **ACTIVE / RECOMMENDED**. Turbo is **ACTIVE / EXPLICIT** and does not replace Stable despite its measured speed. Quality Reference is **ACTIVE / REFERENCE**.

Q6 Safe remains **FALLBACK**; Coding-Fast remains **ADVANCED**; BLUE 370W remains **ADVANCED PERFORMANCE**; HauhauCS remains **RESEARCH / CANDIDATE**; DFlash2 remains **EXPERIMENTAL**; n-gram Coding remains **REJECTED FOR PROFILE / RESEARCH RESULT ONLY**.

All existing Advanced, Fallback, Research, compatibility, and rollback loader paths remain available outside the Daily selectors.

## Finalization switching regression

Validated on 2026-08-25 through the new Daily selectors:

| Target | Sequence | Result |
|---|---|---|
| RTX5090 MAIN | Stable → Turbo → Quality Reference → Stable | PASS |
| BLUE from MAIN | Stable → Turbo → Quality Reference → Stable | PASS |

RTX5090 Turbo-to-Quality stopped only the ownership-validated managed PID, released port 18080 and VRAM, and then loaded Q6 Balanced. BLUE Remote stopped the ownership-validated MAIN tunnel and BLUE managed PID, verified MAIN 18081 and BLUE 18080 free, and then loaded Q6 Balanced REMOTE.

All three Daily selectors and all three root one-click launchers were also run with `0`/Cancel. MAIN and BLUE runtime, port, and Power Limit snapshots were unchanged.

Final verified state:

- RTX5090: LM Studio Q5_K_M Vision 98,304, Q8_0/Q8_0, MTP3, batch1024, ubatch512, parallel1, IDLE, queued0, 402 W; MAIN ports 18080/18081 free; active Turbo state/process 0.
- BLUE: LM Studio Q5_K_M Vision 98,304, Q8_0/Q8_0, MTP3, batch1024, ubatch512, priorityOrder RTX3090→RTX3060, parallel1, IDLE, queued0, 259 W / 170 W; BLUE 18080 and MAIN 18081 free; active Turbo/tunnel state/process 0.
