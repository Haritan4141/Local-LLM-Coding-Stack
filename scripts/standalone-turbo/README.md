# Standalone MTP3 Turbo profiles

This directory manages the explicit-only standalone llama.cpp Turbo runtime for the existing JonathanColetti Q5_K_M Vision 96K target. Stable remains LM Studio Recommended Production. Turbo does not change the repository-wide `Current` model.

| Role | Runtime | Selection |
|---|---|---|
| Stable | LM Studio, Jonathan Q5_K_M Vision 96K | Recommended Production and rollback |
| Turbo | official pinned llama.cpp, Jonathan Q5_K_M Vision 96K, native MTP3 | Explicit selection only |
| DFlash2 | separate experimental work | Not integrated and not shown in selectors |

## Pinned external runtimes

Compiled binaries and DLLs remain outside Git. `Install-ManagedTurboRuntime.ps1` validates the qualification bundle before installation, refuses to overwrite a nonmatching populated destination, and writes a per-file SHA-256 bundle manifest beside the runtime.

| Target | Official source | CUDA | External path | `llama-server.exe` SHA-256 |
|---|---|---|---|---|
| RTX5090 | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | requested `120`, emitted `sm_120a` | `%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes\llama.cpp-f280b269-sm120` | `103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5` |
| BLUE | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | `sm_86` | `%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes\llama.cpp-f280b269-sm86` | `970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4` |

Repository manifests are `runtime-manifests/RTX5090.json` and `runtime-manifests/BLUE.json`. The launcher checks the server executable SHA on every start; model and projector SHA-256 are also checked before LM Studio is unloaded.

## Effective profiles

Both profiles use 98,304 context, Q8_0/Q8_0 KV, native target-contained MTP with draft max 3, eval batch 1024, ubatch 512, parallel 1, full GPU offload, Flash Attention, and Vision. DFlash2 is off.

| Target | GPU and power assertion | Load/split | Endpoint and alias |
|---|---|---|---|
| RTX5090 | RTX 5090 at `00000000:01:00.0`, 402 W | `CUDA0`, mmap+mlock, projector offload, draft KV Q8_0/Q8_0 | `http://127.0.0.1:18080/v1`; `qwen3.8-27b-uncensored-vision-q5km-turbo` |
| BLUE local | RTX 3090 at `00000000:0B:00.0`, 259 W; RTX 3060 at `00000000:01:00.0`, 170 W | `CUDA0,CUDA1`, layer split `0.7108,0.2892`, mmap off | BLUE `http://127.0.0.1:18080/v1`; `qwen3.8-27b-uncensored-vision-q5km-blue-turbo` |
| BLUE from MAIN | same BLUE runtime through managed SSH forwarding | MAIN `127.0.0.1:18081` to BLUE `127.0.0.1:18080` | `http://127.0.0.1:18081/v1` |

BLUE's detached runtime launcher is created through `Win32_Process.Create` so native Windows OpenSSH session cleanup does not terminate the server. It creates no service, Scheduled Task, autorun entry, firewall rule, or persistent SSH change. The server remains bound to BLUE localhost only.

## Start, stop, and recovery

Use the profile selectors or the named BAT files. Selectors only dispatch to a BAT; Stable remains option 1 and Turbo is option 2.

| Operation | Launcher |
|---|---|
| RTX5090 Turbo | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat` |
| RTX5090 Stable recovery | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat` |
| BLUE local Turbo | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat` |
| BLUE local Stable recovery | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable.bat` |
| BLUE Turbo from MAIN | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.bat` |
| BLUE Stable from MAIN | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable_REMOTE.bat` |

Startup fails closed unless host/IP, GPU name and PCI Bus ID, current Power Limit, runtime SHA, runtime commit/device mapping, GGUF/projector SHA, ports, LM Studio idle/queued state, and released VRAM agree. A generating or queued LM Studio model is never unloaded. An unknown listener or process is never stopped.

State, archived state, logs, bundle manifests, and smoke evidence are outside Git under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo` and the managed runtime directories. Stop verifies PID, executable path, command line, model, alias, port ownership, and tunnel target before terminating only the managed process. Stable recovery waits for port and VRAM release before calling the unchanged Stable loader.

## Goose

The Turbo Goose launchers use Goose's built-in `openai` provider and process-local environment only. RTX5090 uses localhost 18080; BLUE uses the managed MAIN tunnel on localhost 18081. Settings remain context limit 90,112, max output 16,384, compact threshold 0.3, and temperature 0. Persistent Goose configuration is not edited.

## Validation and evidence

`Test-QwenVisionProfileLoaders.ps1` covers file presence, selector mapping and Cancel, manifest pins, static safety rules, JSON, JavaScript, and Windows PowerShell syntax. `Test-StandaloneTurboFailClosed.ps1` is an RTX5090 hardware test that proves unknown port and unknown PID preservation with test-owned dummy processes.

Formal integration evidence is in `benchmarks/results/2026-08-25-standalone-mtp3-turbo-integration.md`. Qualification baselines are:

- `benchmarks/results/2026-08-25-rtx5090-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-25-blue-standalone-mtp3-turbo-phase2b.md`
