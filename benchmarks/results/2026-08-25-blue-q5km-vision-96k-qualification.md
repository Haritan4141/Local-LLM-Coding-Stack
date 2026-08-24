# BLUE Jonathan Q5_K_M Vision 96K Qualification

Date: 2026-08-24 to 2026-08-25 JST  
Node: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`  
Hardware: RTX 3090 24,576 MiB + RTX 3060 12,288 MiB; 31.93 GiB host RAM  
Runtime: LM Studio 0.4.21.0 / CLI `71bd99c`; NVIDIA 591.86  
Decision: **PASS — promote Q5_K_M Vision 96K to BLUE Recommended Production**

Repository lifecycle Current remains `current-qwen38-27b-uncensored-q6k` on RTX5090. This report changes only the independent BLUE Remote Node role.

## Artifact and registration

The exact RTX5090-tested model was copied from MAIN to BLUE over the existing SMB 3.1.1 LAN path. The transfer used a `.phase2-partial` name, was SHA-verified on BLUE, and was then atomically renamed. No Hugging Face re-download was performed.

| Artifact | Bytes | SHA-256 | Result |
|---|---:|---|---|
| `Qwen3.8-27B-Uncensored-Q5_K_M.gguf` | 19,535,701,408 | `24780644A95F759A9AEEB228C3D852028F2FD40CE0B74D68134246EC4A959547` | MAIN/BLUE exact match |
| F16 Vision projector | 927,606,912 | `5AC423F8A29059DC24E51BC6A43E9380DCD57A9347F28B62591E0B3F60B7081C` | existing BLUE artifact reused by NTFS hardlink |

- LM Studio model key: `qwen3.8-27b-uncensored-vision-q5km`
- BLUE API identifier: `qwen3.8-27b-uncensored-vision-q5km-blue`
- Existing Q6 model, projector, identifiers, and loaders were not overwritten.
- GGUF/projector and raw outputs remain outside Git.

## Controlled conditions

Unless a sweep row explicitly changed MTP or eval batch: context 98,304; Q8_0/Q8_0 KV on GPU; priorityOrder RTX3090→RTX3060; full offload; Flash Attention ON; mmap OFF; keep model in memory ON; strict VRAM cap OFF; ubatch512; parallel1; temperature0; reasoning OFF; RTX3090 259W; RTX3060 170W. Every performance condition used warm-up1 plus formal3 for Text, Coding, Vision, and Long Prompt.

GPU selection used name + PCI Bus ID and the resolved UUID, never a fixed index:

- RTX3090: `00000000:0B:00.0`
- RTX3060: `00000000:01:00.0`

## Capacity gate

Initial condition was MTP OFF / batch512 as required.

| Measurement | Observed | Gate | Result |
|---|---:|---:|---|
| Combined WDDM Shared | 2,801,164,288 bytes / 2.609 GiB | `< 4 GiB` | PASS |
| RTX3090 Shared | 1,414,676,480 bytes / 1.317 GiB | `<= 2 GiB` | PASS |
| RTX3060 Shared | 1,386,479,616 bytes / 1.291 GiB | `<= 2 GiB` | PASS |
| RTX3090 Dedicated used / headroom | 17,513 / 7,063 MiB | headroom > 0 | PASS |
| RTX3060 Dedicated used / headroom | 7,485 / 4,803 MiB | headroom > 0 | PASS |
| Dedicated delta | 24,263 MiB | full residency | PASS |
| Host RAM used / free | 9,797,550,080 / 24,483,471,360 bytes | no pressure/OOM | PASS |
| OOM | none | none | PASS |

Effective split was `split-mode=layer`, `main-gpu=0`, tensor split `0.7102068030844806 / 0.2897931969155194` for RTX3090/RTX3060. The capacity gate passed without weakening KV precision.

## MTP sweep at batch512

Values are formal-run medians. `Gen` and `Prompt` are tokens/second; TTFT is seconds. Acceptance is the aggregate across the four workloads for each enabled condition.

| MTP | Text Gen / Prompt / TTFT | Coding Gen / Prompt / TTFT | Vision Gen / Prompt / TTFT | Long Gen / Prompt / TTFT | Acceptance | Safety |
|---|---|---|---|---|---:|---|
| OFF start | 24.98 / 176.87 / 0.79 | 24.98 / 440.07 / 1.27 | 24.99 / 314.81 / 1.34 | 22.92 / 1048.65 / 14.78 | n/a | 12/12 valid |
| draft2 | 28.77 / 192.18 / 0.70 | 38.65 / 404.21 / 1.35 | 33.74 / 311.90 / 1.32 | 28.40 / 625.54 / 24.71 | 88.85% | 12/12 valid |
| **draft3** | **27.97 / 172.69 / 0.78** | **41.45 / 414.89 / 1.32** | **33.35 / 308.76 / 1.33** | **28.66 / 623.02 / 24.81** | **84.25%** | **12/12 valid** |
| draft4 | 27.09 / 170.54 / 0.79 | 41.73 / 379.49 / 1.45 | 33.44 / 296.80 / 1.39 | 28.96 / 624.05 / 24.77 | 81.26% | 12/12 valid |
| OFF sentinel | 24.99 / 191.52 / 0.73 | 24.99 / 427.85 / 1.31 | 24.99 / 325.50 / 1.29 | 22.92 / 1052.78 / 14.72 | n/a | 12/12 valid |

The OFF sentinel reproduced the start condition. MTP2→3 improved Coding generation about 7.2% and Long about 0.9%, while Text/Vision declined about 2.8/1.2%. MTP4 added no meaningful aggregate improvement and reduced acceptance further. MTP3 was selected. Enabled-MTP loads remained Strict: maximum combined Shared was about 3.51 GiB, maximum per-GPU Shared about 1.77 GiB, and minimum Dedicated headroom 3,371 MiB.

## Eval batch sweep at MTP3

| Batch | Text Gen / Prompt / TTFT | Coding Gen / Prompt / TTFT | Vision Gen / Prompt / TTFT | Long Gen / Prompt / TTFT | Aggregate acceptance | Safety |
|---|---|---|---|---|---:|---|
| 512 start | 28.06 / 182.26 / 0.74 | 41.31 / 388.15 / 1.41 | 33.32 / 295.13 / 1.39 | 28.48 / 624.39 / 24.75 | 83.98% class | 12/12 valid |
| **1024** | **27.92 / 175.90 / 0.77** | **39.16 / 406.14 / 1.35** | **33.35 / 294.95 / 1.40** | **28.33 / 773.78 / 19.99** | **83.98%** | **12/12 valid** |
| 512 sentinel | 27.93 / 194.88 / 0.69 | 41.32 / 413.65 / 1.32 | 33.32 / 293.52 / 1.40 | 28.67 / 624.45 / 24.75 | same class | 12/12 valid |

Batch1024 improved Long Prompt processing 23.9% and Long TTFT 19.3%, with essentially unchanged Long generation. Coding generation declined about 5.2%, but Coding quality remained 3/3. Maximum run Shared was 3.519 GiB; minimum headroom was 6,706 MiB on RTX3090 and 3,409 MiB on RTX3060. Median dual-GPU power across the batch1024 matrix was 312.93W and peak temperature was 78C. Batch1024 was selected.

## Final quality gate

| Gate | Result |
|---|---|
| Text | 3/3 PASS; no abnormal output |
| Coding | 3/3 PASS; exactly one dependency-free code block per run; syntax 3/3; public 30/30; hidden/edge 48/48; constraint and change-note adherence |
| Vision | 3/3 PASS; existing seven checks were all true in every run |
| Tool Calling | 3/3 PASS; exactly one `lookup_inventory` call with `{"sku":"BLUE-5700X","warehouse":"TOKYO-3"}` and no prose |
| Long Context | PASS at exactly 76,880 input tokens (>65,536); all six facts recovered; 512 output tokens; no OOM |
| Reasoning/temperature | reasoning OFF; temperature0; no anomalous output |

The 76,880-token run measured 613.91 prompt tok/s, 125.292s TTFT, and 22.881 generation tok/s. Combined Shared peaked at 3.527 GiB. RTX3090 averaged 67.64% utilization and 223.96W, peaked at 257.11W/78C, and used 17,856 MiB. RTX3060 averaged 58.16% and 111.28W, peaked at 145.13W/78C, and used 8,879 MiB. Average combined GPU power was 335.24W; host RAM peaked near 11.8 GiB.

The long-context response JSON was valid and independently parsed. Windows PowerShell 5.1 `ConvertFrom-Json` failed only in the session harness post-telemetry step on the large Unicode response; this did not affect inference, the raw response, token accounting, fact checks, or GPU CSV telemetry.

## Fresh Q5 versus current Q6 Balanced

Q6 was freshly loaded and remeasured with the same normal fixtures, temperature0, reasoning OFF, MTP3, Q8_0/Q8_0, batch1024, ubatch512, priorityOrder, and 259W/170W. Context remained each profile's operational value: Q5 96K versus Q6 64K.

| Workload | Q5 Gen / Prompt / TTFT | Q6 Gen / Prompt / TTFT | Q5 generation delta | Q5 prompt/TTFT decision |
|---|---|---|---:|---|
| Text | 27.921 / 175.897 / 0.774 | 24.825 / 178.245 / 0.757 | +12.5% | effectively equal prompt/TTFT |
| Coding | 39.163 / 406.140 / 1.351 | 37.922 / 379.587 / 1.450 | +3.3% | prompt +7.0%; TTFT -6.8% |
| Vision | 33.351 / 294.951 / 1.404 | 31.017 / 281.822 / 1.463 | +7.5% | prompt +4.7%; TTFT -4.0% |
| Long Prompt | 28.328 / 773.777 / 19.985 | 28.314 / 732.014 / 21.120 | +0.05% | prompt +5.7%; TTFT -5.4% |

| Resource | Q5 96K | Q6 64K | Interpretation |
|---|---:|---:|---|
| Dedicated peak | 26,779 MiB | 27,533 MiB | Q5 saves about 754 MiB despite larger context |
| Load Shared | 3.515 GiB | 3.332 GiB | Q5 higher due to 96K, still Strict |
| Maximum matrix Shared | 3.519 GiB | 3.335 GiB | both `< 4 GiB` |
| RTX3090 headroom | 6,706 MiB | 6,404 MiB | Q5 +302 MiB |
| RTX3060 headroom | 3,409 MiB | 2,957 MiB | Q5 +452 MiB |
| Median power: Text/Coding/Vision/Long | 310.69 / 320.73 / 309.13 / 326.46W | 303.86 / 309.16 / 309.10 / 328.24W | workload-dependent; no unsafe excursion |
| Peak temperature: Text/Coding/Vision/Long | 74 / 74 / 73 / 78C | 71 / 72 / 72 / 79C | Q5 max 78C in normal matrix |

All 12 Q5 and all 12 Q6 formal normal-fixture runs were valid and Strict. No Text, Coding, Vision, or constraint quality regression was observed.

## Promotion and preserved profiles

The combined decision prioritizes the requested 96K standardization and VRAM headroom while requiring unchanged quality gates. Q5_K_M passed every adoption gate and improved most measured throughput values versus the fresh Q6 control. It is therefore promoted to BLUE Recommended Production with fixed MTP3/Q8/batch1024/259W-170W.

- Q5_K_M Vision 96K: Recommended Production
- Q6_K Balanced 64K: permanent Quality/Performance Reference
- Q6_K Safe: permanent known-good fallback
- Q6_K Coding-Fast: existing explicit workload-specific profile
- Q6_K 370W Performance: existing explicit independent override
- Q5 370W: not tested and not created

Formal local/REMOTE loader deployment, switching regression, MAIN reachability, Windows toolchain readiness, repository validation, and final runtime state are recorded below.

## Evidence boundary

Session-local helpers, raw JSON/NDJSON, response bodies, loader logs, and GPU CSV telemetry are ignored under `benchmarks/raw/blue-q5km-96k-qualification/session-20260824/`. The curated values above were copied from those observed artifacts. No raw benchmark or model binary is committed.

## Completion verification

- Loader deployment: PASS. Local `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat/.ps1` was deployed to BLUE external loader storage; repository `_REMOTE.bat/.ps1` passed from MAIN. Source/deployed local loader SHA-256 matched. Existing Q6 loaders were preserved.
- Selector: PASS. Local/REMOTE mapping is Q5 Recommended, Q6 Balanced, Q6 Safe, Q6 Coding-Fast, Q6 370W Performance, Cancel. Static regression confirms selectors only `CALL` individual BATs.
- Switching regression: PASS in the required order: Q6 Safe (64K/Q8/MTP2/batch512) → Q5 Recommended (96K/Q8/MTP3/batch1024) → Q6 Balanced (64K/Q8/MTP3/batch1024) → Q5 Recommended. Every managed SDK audit returned `valid:true`, Vision true, correct priority/mmap/parallel, no residual setting, and 259W/170W.
- MAIN API reachability: PASS. The Q5 REMOTE launcher verified `pc5700x`→`DESKTOP-L9HAM1G / 192.168.0.104`, API model ID, 96K, Vision true, MTP3, batch1024, observed physical batch512, parallel1, IDLE, queued0, and both Power Limits.
- DFlash2 build toolchain: PASS. Official `Microsoft.VisualStudio.2022.BuildTools` 17.14.39 installed with C++ workload, MSVC v143, Windows SDK 26100, and CMake component. Developer x64 environment verified `cl` 19.44.35228, CMake 3.31.6-msvc6, Ninja 1.12.1, existing nvcc 12.9.41, and `sm_86`. Installer exit0; no CBS/Windows Update reboot-required key; no reboot performed.
- DFlash2 scope: respected. No llama.cpp clone, PR checkout, patch, DFlash2 build, Q4 Drafter, server18080, tunnel, or DFlash2 benchmark was started.
- Repository validation: PASS. `scripts/Test-Repository.ps1` reported 14 managed JSON files, exactly one Current, loader/selector tests PASS, and no model binaries.
- Final BLUE runtime: PASS. Exactly one `qwen3.8-27b-uncensored-vision-q5km-blue` instance, Q5_K_M, 98,304, Vision/tool-use true, Q8_0/Q8_0 SDK audit, MTP3, batch1024, effective physical batch512 readback, parallel1, IDLE, queued0; RTX3090 259W and RTX3060 170W. MAIN REST and SSH readback succeeded.
