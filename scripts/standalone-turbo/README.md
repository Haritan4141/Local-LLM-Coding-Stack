# Standalone Turbo and Quick Response profiles

## BLUE IQ4_XS Vision256K Extended Context Candidate (2026-10-06)

`BLUE-IQ4XS256K`は独立manifestで262,144 context、Vision F16、target Q8 KV／draft F16、MTP3、batch1024/ubatch256、split75:25、Reasoning OFFを固定。BLUE loopback18080／MAIN既存SSH tunnel18081、259W/170W checked-only。Shared `<4GiB`／各GPU Shared `<=2GiB`／各GPU free`>=1024MiB`をexact UUID/DXGI/live-LUIDで起動前後/reuse時に検査し、プローブ不能はfail closed。常時watchdog/自動restartは行いません。

Gooseメニュー`[13]`はprocess限定232K input＋16K output＋8K reserve、compact0.6（user-approved trial）。BLUE runtime新項目`[6]`。異なるprofileならGoose終了後に明示`[5] Release`してから起動します。Release known BLUE profilesへ追加し、Q5/Quick条件は緩和しません。IQ4/projector/runtime SHA固定。CLI draft F16はpinned binary helpで確認済み。alias末尾`gpt-4o`は既存Goose Vision workaroundのみでクラウド接続ではありません。Goose長時間/compaction受入はPending。

詳細: IQ4_XS model-loader README。元のqualification: `benchmarks/results/2026-10-06-blue-q4-vision-context.md`。

This directory manages explicit-only standalone llama.cpp runtimes for the existing JonathanColetti Q5_K_M artifact. Stable remains LM Studio Recommended Production. Neither Turbo nor Quick Response changes the repository-wide `Current` model.

| Role | Runtime | Selection |
|---|---|---|
| Stable | LM Studio, Jonathan Q5_K_M Vision 96K | Recommended Production and rollback |
| Turbo | official pinned llama.cpp, Jonathan Q5_K_M Vision 96K, native MTP3 | Explicit selection only |
| Quick Response | same pinned runtime/model/projector, Vision 64K, native MTP1, Reasoning Low/2048, Goose output 8K | Unqualified Candidate for low-latency chat with images |
| DFlash2 | separate experimental work | Not integrated and not shown in selectors |

## Pinned external runtimes

Compiled binaries and DLLs remain outside Git. `Install-ManagedTurboRuntime.ps1` validates the qualification bundle before installation, refuses to overwrite a nonmatching populated destination, and writes a per-file SHA-256 bundle manifest beside the runtime.

| Target | Official source | CUDA | External path | `llama-server.exe` SHA-256 |
|---|---|---|---|---|
| RTX5090 | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | requested `120`, emitted `sm_120a` | `%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes\llama.cpp-f280b269-sm120` | `103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5` |
| BLUE | `f280b26983ad0fdb705a0d9ebf0503e76f2899b0` | `sm_86` | `%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes\llama.cpp-f280b269-sm86` | `970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4` |

Qualified Turbo manifests are `runtime-manifests/RTX5090.json` and `runtime-manifests/BLUE.json`. Quick Candidate manifests are `runtime-manifests/RTX5090-Quick.json` and `runtime-manifests/BLUE-Quick.json`. The launcher checks the server executable and model SHA on every start; Vision profiles also check the projector SHA before LM Studio is unloaded.

## Effective profiles

Both profiles use 98,304 context, Q8_0/Q8_0 KV, native target-contained MTP with draft max 3, eval batch 1024, ubatch 512, parallel 1, full GPU offload, Flash Attention, and Vision. DFlash2 is off.

| Target | GPU and power assertion | Load/split | Endpoint and alias |
|---|---|---|---|
| RTX5090 | RTX 5090 at `00000000:01:00.0`, 402 W | `CUDA0`, mmap+mlock, projector offload, draft KV Q8_0/Q8_0 | `http://127.0.0.1:18080/v1`; `qwen3.8-27b-uncensored-vision-q5km-turbo` |
| BLUE local | RTX 3090 at `00000000:0B:00.0`, 259 W; RTX 3060 at `00000000:01:00.0`, 170 W | `CUDA0,CUDA1`, layer split `0.7108,0.2892`, mmap off | BLUE `http://127.0.0.1:18080/v1`; `qwen3.8-27b-uncensored-vision-q5km-blue-turbo` |
| BLUE from MAIN | same BLUE runtime through managed SSH forwarding | MAIN `127.0.0.1:18081` to BLUE `127.0.0.1:18080` | `http://127.0.0.1:18081/v1` |

Quick Response uses 65,536 runtime context, 57,344 Goose client context, 8,192 max output, Q8_0/Q8_0 KV, MTP draft max 1, eval batch 1024, ubatch 512, parallel 1, Flash Attention, Prompt cache ON/reuse 0, and Reasoning ON with effort `low`, budget 2,048 and preserve OFF. It loads the same pinned F16 Vision projector as Turbo and verifies its SHA-256 before startup. MAIN retains 402 W; BLUE retains 259 W / 170 W and the qualified layer split. These are configured Candidate values, not measured latency or Vision qualification claims.

BLUE's detached runtime launcher is created through `Win32_Process.Create` so native Windows OpenSSH session cleanup does not terminate the server. It creates no service, Scheduled Task, autorun entry, firewall rule, or persistent SSH change. The server remains bound to BLUE localhost only.

## Start, stop, and recovery

Use the profile selectors or the named BAT files. Selectors only dispatch to a BAT; Stable remains option 1, Turbo is option 2, and Release is option 4.

| Operation | Launcher |
|---|---|
| RTX5090 Turbo | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat` |
| RTX5090 Stable recovery | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat` |
| BLUE local Turbo | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat` |
| BLUE local Stable recovery | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable.bat` |
| BLUE Turbo from MAIN | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.bat` |
| BLUE Stable from MAIN | `Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable_REMOTE.bat` |
| RTX5090 Quick Response | `Qwen3.8-JonathanColetti-Q5KM_64K_Quick.bat` |
| BLUE local Quick Response | `Qwen3.8-JonathanColetti-Q5KM_64K_259W_Quick.bat` |
| BLUE Quick Response from MAIN | `Qwen3.8-JonathanColetti-Q5KM_64K_259W_Quick_REMOTE.bat` |
| RTX5090 runtime release | Daily selector `[5]` / `RTX5090/00-Daily-Profiles/4-Release.bat` |
| BLUE local runtime release | Daily selector `[5]` / `RTX3090/00-Daily-Profiles/4-Release.bat` |
| BLUE runtime release from MAIN | Daily selector `[5]` / `RTX3090/00-Daily-Profiles/4-Release_REMOTE.bat` |

Startup fails closed unless host/IP, GPU name and PCI Bus ID, current Power Limit, runtime SHA, runtime commit/device mapping, GGUF/projector SHA, ports, LM Studio idle/queued state, and released VRAM agree. A process-wide named Mutex serializes Turbo and Quick operations for each host/port family, so overlapping launches wait rather than passing the empty-state preflight together. A generating or queued LM Studio model is never unloaded. An unknown listener or process is never stopped.

State, archived state, logs, bundle manifests, and smoke evidence are outside Git under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo` and the managed runtime directories. Stop verifies PID, executable path, command line, model, alias, port ownership, and tunnel target before terminating only the managed process. Stable recovery waits for port and VRAM release before calling the unchanged Stable loader.

Release is a fail-closed end-of-session operation. It recognizes both Turbo and Quick state for the selected host, refuses active or queued predictions, flattens the Windows PowerShell 5.1 top-level `/slots` JSON array before checking every slot for `is_processing=false`, and preserves unknown listeners or processes. If an overlapping failed start archived the successful process's state, Release may restore it only when the history PID, process creation time, host, executable/model paths and SHA-256, command line, API alias/context/parallel/Vision and listener ownership all match the pinned profile. Migration exceptions are limited to a declared legacy Quick alias and, for the earlier text-only revision, `Vision=false` with exact `--no-mmproj`; both still require ownership, path, hash, listener and API verification. New startup accepts only the current alias. Release then unloads idle LM Studio models or stops only the ownership-validated managed process. BLUE Remote also removes only its validated MAIN tunnel. It does not stop the LM Studio server or change Firewall, Power Limit, model files, or Goose configuration. Daily wrappers save output under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\release-logs` and pause on failure so the error remains visible.

### BLUE Turbo reports GPU memory verification failure

Since 2026-08-30, reusing an existing Turbo process also runs the local read-only preflight; a responding API alone is insufficient. Reusing an existing MAIN tunnel checks BLUE locally over SSH before reporting success. Failure preserves the existing process/tunnel; there is no automatic Release, restart, or threshold relaxation.

`[TURBO_VRAM_RESIDENCY]` reports both GPU names/PCI Bus IDs, current `nvidia-smi memory.used`, and the unchanged minimums (RTX3090: 12,000 MiB; RTX3060: 6,000 MiB). Missing/duplicate GPUs and unavailable measurements are reported as unknown, not zero. These are total per-GPU usage checks, not process-specific residency or free-memory checks. Low usage alone does not prove an OOM, model corruption, or Windows paging.

When this occurs, finish/stop Goose generation and confirm there is no queued work. In **`00-BLUE-Daily-Profiles-REMOTE.bat`**, explicitly select **`[5] Release`**, then **`[2] Turbo`**. These are the runtime menu numbers, not the Goose profile menu numbers. If Release refuses active work, unknown ownership, or an identity mismatch, do not force-stop processes; investigate that error first. This is a recovery procedure, not a guaranteed fix for every startup failure.

Remote launch/preflight/timeout errors now retain their original details instead of only saying the detached launcher exited. The complete diagnostic is printed and saved on MAIN under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\turbo\logs\blue-remote-start-failed-*.log`. When a detached BLUE launch was attempted, its `blue-detached-launch-*.log` path on BLUE is also shown. The canonical Remote BAT retains the failure exit code and pauses. GPU/Power Limit/context/output settings are unchanged.

Deployment verification: on 2026-08-30, `Start-ManagedTurbo.ps1`, `Test-ManagedTurbo.ps1` and `Turbo.Common.psm1` were synchronized to BLUE's external `C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo` with matching SHA-256. Previous copies are in its `backups\before-launcher-diagnostics-20260830-135118` directory. At 13:52:10 JST, read-only local preflight passed on BLUE; PID 8324 (started 13:42:31 JST) and its state-file hash were unchanged by verification. GPU usage was RTX3090 17,921 MiB / RTX3060 8,865 MiB, with PL 259W/170W. No loader, Release, inference, or restart was executed for this maintenance validation; failed-start diagnostics were exercised with offline fixtures.

## Goose

The Turbo Goose launchers use Goose's built-in `openai` provider and process-local environment only. RTX5090 uses localhost 18080; BLUE uses the managed MAIN tunnel on localhost 18081. Settings use context limit 90,112, selectable max output 16,384 or 32,768, compact threshold 0.3, and temperature 0. Persistent Goose configuration is not edited. Output16K remains the normal selection; Output32K is explicit long-output use after both systems completed a 17K+ Goose-path qualification.

Quick uses the same process-local mechanism with context limit 57,344 and max output 8,192. It does not edit persistent Goose configuration. Goose Desktop v1.49 treats an unknown OpenAI-compatible model ID as non-Vision even when llama.cpp reports `Vision=true`, and replaces the attachment with `[image omitted: model does not support vision]` before sending the request. MAIN and BLUE Quick therefore expose a friendly local Qwen identity ending in `-gpt-4o`; the UI keeps the local model identity visible while the trailing token maps to Goose's canonical Vision metadata. The runtime still serves the pinned JonathanColetti Qwen3.8 Q5_K_M model and F16 projector. The prior canonical-only `gpt-4o` and original Quick IDs are accepted only by the verified Release migration path. Qualification status and the planned A/B are recorded in `research/2026-09-07-qwen38-quick-response-64k-8k.md`.

## Validation and evidence

`Test-QwenVisionProfileLoaders.ps1` covers file presence, selector mapping and Cancel, manifest pins, static safety rules, JSON, JavaScript, and Windows PowerShell syntax. `Test-StandaloneTurboFailClosed.ps1` is an RTX5090 hardware test that proves unknown port and unknown PID preservation with test-owned dummy processes.

`Test-TurboLauncherDiagnostics.ps1` is an offline regression test using isolated mocks/fixtures. `Test-ManagedRuntimeLifecycle.ps1` additionally verifies cross-process operation locking, PID-owned failure archiving, exact history recovery, and wrong-PID rejection. Neither test runs real loaders, SSH, GPU queries, or inference. Both are included in `Test-Repository.ps1`; the hardware fail-closed test is not.

Formal integration evidence is in `benchmarks/results/2026-08-25-standalone-mtp3-turbo-integration.md`. Qualification baselines are:

- `benchmarks/results/2026-08-25-rtx5090-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-25-blue-standalone-mtp3-turbo-phase2b.md`
- `benchmarks/results/2026-08-26-goose-turbo-output32k-qualification.md`
