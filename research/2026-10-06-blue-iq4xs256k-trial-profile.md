# BLUE IQ4_XS Vision256K trial profile — implementation acceptance

Date: 2026-10-06 (Asia/Tokyo). Status: **STATIC_AND_DEPLOYMENT_PASS / RUNTIME_ACCEPTANCE_PENDING**. User requested a selectable trial; no Production/Current promotion, real loader/Goose launch, commit or push in this implementation phase.

## Entry points and exact contract

- MAIN `scripts/lmstudio/model-loaders/00-Goose-Daily-Profiles.bat` → `[13] Extended Context - IQ4XS Vision 256K / Output 16K (Candidate)`.
- BLUE runtime LOCAL/REMOTE Daily selector → `[6] Extended Context`; existing choices1–5 retained. Integrated Goose choices1–12 retained.
- Canonical loader directory: `scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-IQ4XS-Vision/`; manifest: `scripts/standalone-turbo/runtime-manifests/BLUE-IQ4XS256K.json`.
- BLUE `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104` only. CUDA0 RTX3090 + CUDA1 RTX3060, name/PCI/UUID checked,259W/170W checked-only. MAIN's runtime profiles are not changed.
- Pinned official llama.cpp `f280b26983ad0fdb705a0d9ebf0503e76f2899b0`, IQ4_XS and F16 Vision projector reuse the external artifacts from the prior qualification. No application/model/runtime downloads or LM Studio native import in these loaders.
- Runtime262,144, parallel1, target Q8/Q8, explicit draft F16/F16, MTP3, batch1024/ubatch256, split75:25, no-mmap, Flash Attention/Jinja/cache ON, reasoning OFF/budget0. Pinned runtime help confirmed `default` reasoning effort and draft F16 support.
- BLUE loopback18080 → existing managed SSH tunnel MAIN loopback18081. No Firewall/listen-bind changes. API alias ends `iq4xs-blue-256k-gpt-4o`; trailing token reuses the existing Goose Vision capability workaround, not OpenAI inference.
- Goose **process-only** input237,568 (232K), output16,384, reserve8,192 =262,144. UI input context is deliberately not256K. Temperature0; user-approved automatic compaction0.6 trial. First static eligibility142,541 usage tokens, with95,027 tokens left after next max output and the planning8K growth reserve; not a bound on actual payload or immediate trigger timing. Do not infer that 256K fixes tool repetition or all compaction failures.

## Safety and deployment

Startup checks artifact hashes and idle runtime before transition. Candidate memory probe runs before any LM Studio unload and after load/reuse: exact DXGI/live-LUID/UUID mapping, total Shared `<4GiB`, each GPU Shared `<=2GiB`, each free VRAM `>=1024MiB`. Missing/invalid telemetry fails closed. No background watchdog or automatic retry/restart. Existing reuse failures preserve runtime/tunnel; failed new start cleans only its owned process. Candidate Release also checks idle slots. Unknown/different/active runtimes require explicit safe Release, not automatic termination.

BLUE external deployment root: `C:\Users\Atsuki\Codex-RTX3090-Setup`.

Nine files deployed: five shared managed-runtime scripts, new manifest, read-only memory helper and two qualification telemetry dependencies. Staged source/destination SHA matched; old BLUE/BLUE-Quick manifests and runtime binary not replaced. Five replaced scripts backed up to:

`C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\backups\before-blue-iq4xs256k-profile-20261006-2010`.

Local pre-edit copies/SHA-only audit, staged deployment manifest and post-deployment evidence: Git-ignored `benchmarks/raw/blue-iq4xs256k-profile-20261006/`. A long encoded SSH deployment command exceeded the Windows command-line limit before execution; deployment proceeded by a verified staged script file instead. No runtime was started by deployment.

Post-deployment read-only observation2026-10-06T11:11:50.5454833Z: host/IP matched; LM Studio loaded instances0, standalone processes0, managed listeners0, runtime binary and BLUE LM Studio configuration hashes unchanged. The idle memory helper PASS is **not** a loaded256K memory test.

## Actual verification / retained evidence

- Required `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Repository.ps1`: PASS, one Current, no model binaries. Includes existing loader/lifecycle/diagnostic suites.
- New profile tests13 PASS; memory validator tests10 PASS; existing BLUE qualification tests16 PASS. Invalid context/ubatch/split/Vision/host/model SHA/KV/output and wrong UUID/LUID/Shared/free-memory cases rejected.
- Initial creation compaction static budget13 profiles PASS; old12 exact expectations unchanged. The initial new-profile rate30% was subsequently amended to the user-approved60% trial below; live compaction remains unqualified.
- Menu mappings and Cancel/invalid handling PASS, syntax/fail-closed checks PASS.
- Source/deployed hashes9/9 matched; protected BLUE manifests2/2 and MAIN Global configuration paths10/10 unchanged (including absent files remaining absent). Pre-edit240 repository files: no changes outside the owned implementation paths.
- `git diff --check`: PASS. Secret scan: PASS, no findings; four pre-existing public loopback dummy constants reviewed against pre-edit provenance, not credentials.

Prior measured model results in `benchmarks/results/2026-10-06-blue-q4-vision-context.md/json` are unchanged: memory/one209K Tool+Vision chain PASS does not erase original coding and short/192K tool selection failures. Cold209K prefill~9min16sec. Actual16K output, Goose Desktop Tool/Vision, compaction and long-session quality remain Pending. No daily quality winner declared.

## User-approved60% amendment (2026-10-06)

Scope: only `BLUE-IQ4XS256K` / Goose Daily `BLUE-Extended256K16K` uses0.6. Existing12 Daily profiles remain0.3; runtime262,144, Goose client237,568, output16,384, reserve8,192 and all model/cache/Vision settings are unchanged. No Global config, feature toggle, explicit tool-call cutoff, model load/unload, inference, Goose launch/restart or commit/push.

The launcher reads the canonical manifest rate, formats it with invariant culture, passes it to the child process and restores its own environment. The static budget reader now follows that same manifest. First eligibility142,541 tokens is based on232K client input, not60% of256K runtime; after output16K and assumed growth8K the planning margin is95,027 tokens. This is not a compaction payload bound or an instant trigger promise. If optional Tool Pair Summarization is enabled later without an explicit cutoff, the derived cutoff changes10→21; this amendment does not enable that feature or claim it is active.

Verification: required full repository suite PASS; extended contract16 checks PASS, including stale30% and unapproved65% rejection plus actual isolated launcher-resolution block in en-US/ja-JP/fr-FR; static budgets13 PASS with old12 exact expectations retained; memory validator10 and qualification16 tests remain PASS. Secret scan252 files PASS, four pre-existing public loopback dummy constants unchanged; diff check PASS. MAIN10 Global paths and all non-owned files from the252-file pre-edit snapshot are unchanged.

BLUE hostname/IP/GPU identity checked; only `Turbo.Common.psm1` and `runtime-manifests/BLUE-IQ4XS256K.json` were replaced, after backup and staged/deployed SHA verification. Read-only observation2026-10-06T11:34:31.9632305Z: LM Studio loaded0, no standalone process, existing LM Studio PIDs unchanged; old BLUE/BLUE-Quick manifests, LM Studio config2 files, runtime binary and GPU/Power Limits unchanged. No runtime acceptance test was performed.

Local pre-edit backup and SHA-only provenance: `benchmarks/raw/blue-iq4xs256k-compact60-20261006-1791286195266/`. BLUE two-file backup: `C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\backups\before-blue-iq4xs256k-compact60-20261006-1791286195266`. To revert this amendment if separately requested, restore just those two verified BLUE files and the corresponding MAIN edited files from the backup; do not restore Global config or reset prior dirty work. Earlier model test evidence and initial30% deployment history above remain intact.

Status: **STATIC_AND_DEPLOYMENT_PASS / LIVE60_PERCENT_COMPACTION_PENDING**. Exit Goose after finishing work, select integrated menu13 and open a new chat to inherit60%; the ordinary shortcut and already-running process do not inherit it.

## User trial and rollback

1. Finish generated/queued work and completely exit Goose.
2. If another BLUE runtime is active, use BLUE Remote Daily `[5] Release`; if it refuses ownership/active work, stop and inspect rather than force-stop.
3. MAIN integrated Goose entry `[13]`; start a **new chat**. The standard Goose shortcut does not inherit these process-only settings.
4. Confirm local IQ4_XS256K alias and232K input/16K output. Begin with a short chat, small image and safe Tool Call; only then try a longer practical task. Preserve failures as evidence.
5. To return to Q5, finish work, exit Goose, runtime `[5] Release`, integrated `[7] Stable` or `[9] Turbo`. Q6 Reference/Safe are preserved.

Code rollback, if separately requested: with all managed runtimes idle/stopped, restore the five BLUE scripts from the verified backup and remove only new Candidate definitions/helpers after exact target checks. Restore MAIN files from the pre-edit local backup; keep prior unrelated dirty work and original qualification artifacts. Do not copy old Global config or reset the repository.
