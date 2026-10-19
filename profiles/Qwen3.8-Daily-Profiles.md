# Daily Profiles

2026-10-19 daily preference: DeepSeek + BLUE IQ4_XS Vision256K is the User-selected Daily Preferred Workflow. The selectable Stable Q5 entries below retain their Historical Recommended Production / manual fallback role; the menus and Goose Coding Agent settings are unchanged. See [runtime audit](../research/2026-10-19-blue256k-daily-audit.md). Runtime-only menus do not change DeepSeek defaults or its selected session.

2026-10-19 audit: these are selectable managed profiles, not a list of currently loaded models. BLUE IQ4_XS256K was active; MAIN standalone was absent. See [current state](../CURRENT_STATE.md) for live observations and saved Client defaults. The runtime-only menus do not select a DeepSeek model.

2026-10-11 MAIN extended Candidate: shared Goose menu `[14]` / `MAIN-Extended256K16K` / manifest `RTX5090-IQ4XS256K`.
MAIN-only IQ4_XS Vision256K, input232K/output16K/reserve8K, compact60%; standalone localhost18080. BLUE option13 and Q5/Q6 options retain their prior mapping.
DeepSeek uses separate `main-local` provider at localhost18080/v1; the existing BLUE route at localhost18081/v1 is retained. Its saved default is a separately observed Client choice, not fixed by these loaders.
Read the MAIN qualification report before treating this as normal long-context operation.

2026-10-11 navigation repair: MAIN runtime-only selector now exposes `[6] Extended Context - IQ4XS Vision 256K`, matching BLUE runtime choice6. Root `00-RTX5090-Daily-Profiles.bat` reaches the existing canonical loader; no runtime/Client configuration is duplicated or changed. For DeepSeek start either MAIN / BLUE runtime choice6, wait for success, then select that Host's 256K model in a new Session. MAIN is localhost18080/v1; BLUE uses the existing localhost18081/v1 SSH forward. Other runtime choices do not match these two DeepSeek256K routes automatically. Goose integrated choices14/13 are a separate Client-launch workflow.

These are the official daily Operational Profile entry points for Qwen3.8. They do not change the sole repository lifecycle `Current` model.

Goose daily integrated entry: `scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat`. It selects the canonical runtime, cross-checks the effective provider/model/context/output/endpoint, and then launches Goose Desktop. Stable/Quality use persistent LM Studio profiles; Turbo/Quick use the built-in `openai` provider with process-local settings and do not change persistent Goose configuration.

| Goose choice | Runtime | Provider / endpoint | Client limit / output |
|---|---|---|---:|
| MAIN Stable | MAIN LM Studio Stable | `lmstudio` / `127.0.0.1:1234` | 90,112 / 16K or 32K |
| MAIN Turbo | MAIN official llama.cpp | `openai` / `127.0.0.1:18080` | 90,112 / 16K or 32K |
| MAIN Quick Candidate | MAIN official llama.cpp / Q5_K_M Vision | `openai` / `127.0.0.1:18080` | 57,344 / 8K |
| MAIN Quality | MAIN LM Studio Q6 Balanced | `lmstudio` / `127.0.0.1:1234` | 64,512 / 32K |
| BLUE Stable | BLUE LM Studio Stable | `custom_lm_studio_3090_remote` / `192.168.0.104:1234` | 90,112 / 16K or 32K |
| BLUE Turbo | BLUE official llama.cpp + MAIN tunnel | `openai` / `127.0.0.1:18081` | 90,112 / 16K or 32K |
| BLUE Quick Candidate | BLUE official llama.cpp + MAIN tunnel / Q5_K_M Vision | `openai` / `127.0.0.1:18081` | 57,344 / 8K |
| BLUE Quality | BLUE LM Studio Q6 Balanced | `custom_lm_studio_3090_remote` / `192.168.0.104:1234` | 64,512 / 32K |
| BLUE Extended Context Candidate `[13]` | BLUE official llama.cpp / IQ4_XS + F16 Vision | `openai` / MAIN `127.0.0.1:18081` | 237,568 / 16K (runtime262,144; reserve8K) |
| MAIN Extended Context Candidate `[14]` | MAIN official llama.cpp / IQ4_XS + F16 Vision | `openai` / `127.0.0.1:18080` | 237,568 / 16K (runtime262,144; reserve8K) |

## RTX5090 MAIN

| Profile | Backend / model | Effective settings | Endpoint / power | Launcher | Intended use |
|---|---|---|---|---|---|
| Stable | LM Studio / Jonathan Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | `http://127.0.0.1:1234/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/1-Stable.bat` | Historical Q5 Recommended Production / manual recovery |
| Turbo | official pinned llama.cpp / same Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | `http://127.0.0.1:18080/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/2-Turbo.bat` | Explicit fast Coding, Agent, Vision, long generation |
| Quick Response | official pinned llama.cpp / same Q5_K_M + F16 projector | 65,536 context; MTP1; Q8_0/Q8_0; Reasoning Low/2048; prompt cache; parallel1; Vision | `http://127.0.0.1:18080/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/Quick-Response.bat` | Candidate for low-latency chat with image input |
| Quality Reference | LM Studio / Jonathan Q6_K Vision Balanced | 65,536 context; MTP4; Q8_0/Q8_0; batch2048; ubatch512; parallel1; Vision | `http://127.0.0.1:1234/v1`; 402 W | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/3-Quality-Reference.bat` | Compare a questionable Q5 output |
| Extended Context `[6]` | official pinned llama.cpp / Jonathan IQ4_XS + F16 Vision | 262,144 context; output16K; MTP3; Q8 target/F16 draft; batch1024/ubatch256; parallel1; reasoning OFF; Vision | `http://127.0.0.1:18080/v1`; existing 402 W checked-only | `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/Extended-Context.bat` | Explicit Candidate / DeepSeek MAIN256K; sustained long-context quality Pending |

Daily selector: `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/Profile-Selector.bat`

End-of-session Release: selector `[5]` / `scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles/4-Release.bat`

Root one-click: `scripts/lmstudio/model-loaders/00-RTX5090-Daily-Profiles.bat`

## BLUE RTX3090 + RTX3060

| Profile | Backend / model | Effective settings | Endpoint / power | MAIN remote launcher | Intended use |
|---|---|---|---|---|---|
| Stable | LM Studio / Jonathan Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | BLUE `http://192.168.0.104:1234/v1`; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/1-Stable_REMOTE.bat` | Historical Q5 Recommended Production / manual node recovery |
| Turbo | official pinned llama.cpp / same Q5_K_M Vision | 98,304 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | BLUE 18080; MAIN `http://127.0.0.1:18081/v1` tunnel; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/2-Turbo_REMOTE.bat` | Explicit fast Coding, Agent, Vision, long generation |
| Quick Response | official pinned llama.cpp / same Q5_K_M + F16 projector | 65,536 context; MTP1; Q8_0/Q8_0; Reasoning Low/2048; prompt cache; parallel1; Vision | BLUE 18080; MAIN `http://127.0.0.1:18081/v1`; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/Quick-Response_REMOTE.bat` | Candidate for low-latency chat with image input |
| Quality Reference | LM Studio / Jonathan Q6_K Vision Balanced | 65,536 context; MTP3; Q8_0/Q8_0; batch1024; ubatch512; parallel1; Vision | BLUE `http://192.168.0.104:1234/v1`; 259 W / 170 W | `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/3-Quality-Reference_REMOTE.bat` | Compare a questionable Q5 output |

MAIN remote selector: `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/Profile-Selector_REMOTE.bat`

BLUE local selector: `scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles/Profile-Selector_LOCAL.bat`

End-of-session Release: selector `[5]`; MAIN REMOTE uses `4-Release_REMOTE.bat`, BLUE local uses `4-Release.bat`.

BLUE runtime selectors append `[6] Extended Context`: IQ4_XS + F16 Vision,262,144 context,Q8/Q8 target KV,F16 draft,MTP3,batch1024/ubatch256,split75:25,Reasoning OFF,parallel1,259W/170W checked-only. Goose integrated `[13]` uses process-only232K input/16K output/8K reserve/compact0.6（user-approved trial）. Close Goose and explicitly Release another BLUE runtime first. Shared/free-VRAM gates apply to this Candidate only; no watchdog/restart. Native LM Studio/Goose long-session acceptance stays Pending. Details: IQ4_XS model-loader README.

Root MAIN one-click: `scripts/lmstudio/model-loaders/00-BLUE-Daily-Profiles-REMOTE.bat`

## Profile meaning and retained roles

Quality Reference is not a guarantee that every Q6_K answer is better than Stable. It is a higher-precision quantization reference for investigating a questionable Q5_K_M result. Because the Reference context is 64K, do not use it as a direct comparison for a task over 64K.

Stable is **ACTIVE / RECOMMENDED**. Turbo is **ACTIVE / EXPLICIT** and does not replace Stable despite its measured speed. Quick Response is **CANDIDATE / STATIC-ONLY** until latency and quality qualification. Quality Reference is **ACTIVE / REFERENCE**.

QuickはローカルQwen名を含むAPI表示名を使い、その末尾の`gpt-4o` tokenだけを過去のGoose Desktop v1.49互換問題に対するVision能力判定へ利用します。MAIN/BLUEとも実モデルはローカルのJonathanColetti Qwen3.8 Q5_K_M Visionであり、OpenAIへ接続しません。canonical-only `gpt-4o`と旧Quick aliasは検証付きRelease移行にだけ使用します。

Release is an operation, not a model Profile. It loads nothing: after fail-closed idle/ownership checks it unloads the active LM Studio model or stops the managed Turbo/Quick runtime. BLUE REMOTE also removes its validated MAIN tunnel. It leaves LM Studio server, Firewall, Power Limit, Goose configuration, and model files unchanged.

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

The integrated Goose entry was separately validated on 2026-08-26 across MAIN/BLUE Stable, Turbo, and Quality Reference, including short Goose Desktop prompts and a 17,936-token MAIN Turbo prompt at `n_ctx_slot = 98,304`. Output32K was then qualified through Goose at 17,100 output tokens on MAIN and 17,183 on BLUE, with complete sequences and unchanged persistent config. See `benchmarks/results/2026-08-26-goose-daily-profiles-integration.md` and `benchmarks/results/2026-08-26-goose-turbo-output32k-qualification.md`.
