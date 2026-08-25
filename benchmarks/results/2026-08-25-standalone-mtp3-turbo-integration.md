# Standalone MTP3 Turbo formal integration

Date: 2026-08-25 (Asia/Tokyo)
Hosts: `DESKTOP-5NPLIIV` and `DESKTOP-L9HAM1G`
Decision: **PASS — explicit-only Turbo profiles integrated; Stable Production unchanged**

## Scope and lifecycle

The official-mainline parity builds qualified in Phase 2B are installed as managed external runtime bundles and exposed through explicit profile selector entries. RTX5090 and BLUE retain LM Studio Jonathan Q5_K_M Vision 96K as Recommended Production and rollback. The sole repository lifecycle `Current` remains unchanged. DFlash2 remains Experimental and is not integrated.

The work started from `origin/main` commit `bc8b86ebddeb2c44fee868733eb3b638e732ee57` in the dedicated `feat/standalone-mtp3-turbo` worktree. The original dirty worktree was not edited, staged, stashed, reset, or committed.

## Pinned runtime and target

| Target | Official llama.cpp commit | Runtime path | Executable SHA-256 | Device result |
|---|---|---|---|---|
| RTX5090 | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | `%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes\llama.cpp-f280b269-sm120` | `103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5` | `CUDA0` RTX 5090; requested arch 120, emitted `sm_120a` |
| BLUE | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | `%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes\llama.cpp-f280b269-sm86` | `970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4` | `CUDA0` RTX 3090 and `CUDA1` RTX 3060; `sm_86` |

Install-time external bundle manifests contain SHA-256 records for the executable, core DLLs, and CUDA backend DLLs. Both installs passed executable SHA, required-DLL, `--version`, and `--list-devices` validation. The repository contains manifests but no executable, DLL, GGUF, projector, runtime state, log, or raw response.

The common target model SHA-256 is `24780644a95f759a9aeeb228c3d852028f2fd40ce0b74d68134246ec4a959547`; projector SHA-256 is `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c`.

## Effective Turbo profiles

| Dimension | RTX5090 | BLUE |
|---|---|---|
| Host / GPU identity | `DESKTOP-5NPLIIV`; RTX 5090 `00000000:01:00.0` | `DESKTOP-L9HAM1G / pc5700x / 192.168.0.104`; RTX 3090 `00000000:0B:00.0`, RTX 3060 `00000000:01:00.0` |
| Power assertion | 402 W | 259 W / 170 W |
| Context / KV | 98,304 / Q8_0-Q8_0 | 98,304 / Q8_0-Q8_0 |
| MTP / batch / ubatch / parallel | ON, draft 3 / 1024 / 512 / 1 | ON, draft 3 / 1024 / 512 / 1 |
| GPU mode | full offload, Flash Attention, mmap+mlock, Vision | full offload, Flash Attention, mmap off, layer split `0.7108,0.2892`, Vision |
| Endpoint | MAIN `127.0.0.1:18080` | BLUE `127.0.0.1:18080`; MAIN managed tunnel `127.0.0.1:18081` |
| Alias | `qwen3.8-27b-uncensored-vision-q5km-turbo` | `qwen3.8-27b-uncensored-vision-q5km-blue-turbo` |

DFlash2 is off and absent from all selectors. No firewall, router, SSH configuration, service, autostart, driver, BIOS/firmware, or effective Power Limit change was made.

## Qualification baseline retained

| Target | Phase 2B generation geomean improvement | Official-mainline parity |
|---|---:|---|
| RTX5090 | **+60.49%** versus Stable LM Studio | Text +0.53%, Coding +0.18%; parity PASS |
| BLUE | **+16.32%** versus Stable LM Studio | Text -0.02%, Coding +2.68%, Vision 7/7; parity PASS |

These performance values are reused from the curated Phase 2B reports. This integration run was a functional and switching regression, not a new long benchmark.

## Integration validation

| Gate | RTX5090 | BLUE | Result |
|---|---|---|---|
| Managed preflight | host/GPU/PL/SHA/port/LM Studio/VRAM/API PASS | alias/hostname/IP/GPU/PL/SHA/port/LM Studio/VRAM/API PASS | PASS |
| Simultaneous endpoint marker, cycle 1 | `MAIN-CYCLE1-TURBO-PASS` at 18080 | `BLUE-CYCLE1-TURBO-PASS` at 18081 | PASS; no endpoint crossover |
| Simultaneous endpoint marker, cycle 2 | `MAIN-CYCLE2-TURBO-PASS` at 18080 | `BLUE-CYCLE2-TURBO-PASS` at 18081 | PASS; reproducible |
| Vision fixture | 7/7 | 7/7 | PASS through managed runtime paths |
| Tool Calling | `lookup_inventory`, exact `MAIN-5090 / TOKYO-1`, schema valid, no prose | exact `BLUE-5700X / TOKYO-3`, schema valid, no prose | PASS |
| Goose tool use | built-in `openai`, developer tool read exact random marker | built-in `openai` through tunnel, developer tool read exact random marker | PASS |
| Goose persistence | process-local environment restored | process-local environment restored | PASS; no persistent config/env change |
| Unknown port | unrelated test listener preserved | static and shared implementation guard | PASS / fail closed |
| Unknown PID | unrelated test process preserved | shared PID/path/command/port guard | PASS / fail closed |
| Tunnel ownership | n/a | PID, `ssh.exe`, command, alias, local/remote ports verified | PASS |

External smoke evidence was written under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo\smoke` and remains outside Git. The Vision 7/7 evidence was recorded at `rtx5090-vision-20260825-133241-870` and `blue-vision-20260825-133241-952`; Tool evidence at `rtx5090-tool-20260825-133302-722` and `blue-tool-20260825-133302-809`; Goose evidence at `rtx5090-goose-20260825-133337-711` and `blue-goose-20260825-133337-806`.

Windows PowerShell 5.1 compatibility fixes made during integration include explicit JSON-array flattening, native stderr string normalization, waitable Chrome fixture rendering, multilingual layout-check matching, and a WMI-detached BLUE launcher so OpenSSH session teardown cannot terminate the managed server. No service or persistent task is created.

## Switching regression and final state

Both targets completed the required sequence:

`Stable -> Turbo -> Stable -> Turbo -> Stable`

At each successful Turbo stage, the runtime executable, command line, model alias, 98,304 context, Q8/Q8, MTP3, batch1024, ubatch512, parallel1, Vision, API, port ownership, GPU identity, Power Limit, VRAM release, and loaded residency were audited. Stable restoration used new wrappers which first stopped only the validated managed PID/tunnel, waited for port and VRAM release, and then called the unchanged Stable BAT.

After the stop guard was tightened to cross-check state metadata and paths against the pinned manifest, an additional managed start/stop/Stable-restoration regression passed on both targets.

Final verified state:

| Item | Final state |
|---|---|
| RTX5090 LM Studio | `qwen3.8-27b-uncensored-vision-q5km`, IDLE, queued 0, context 98,304, parallel 1, 402 W |
| BLUE LM Studio | `qwen3.8-27b-uncensored-vision-q5km-blue`, IDLE, queued 0, context 98,304, parallel 1, 259 W / 170 W |
| Standalone server | 0 on both hosts |
| MAIN port 18080 / 18081 | free / free |
| BLUE port 18080 | free |
| Managed SSH Turbo tunnel | 0 |
| Active Turbo state files | 0 on both hosts; stopped records archived outside Git |

Stable remains LM Studio Q5_K_M Vision 96K Recommended Production. Turbo remains official llama.cpp MTP3 explicit-only. DFlash2 remains Experimental / not integrated. Repository lifecycle `Current` is unchanged.
