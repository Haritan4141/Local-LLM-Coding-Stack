# AGENTS.md

## Purpose

This repository is the source of truth for the local coding stack built around VS Code, Zoo Code, LM Studio, and local LLMs on the RTX 5090 32 GB workstation. Maintain model selection, effective settings, benchmarks, research notes, and migration history here.

## Current baseline

- `current-qwen38-27b-uncensored-q6k` is the only `Current` model.
- `candidate-hauhaucs-aggressive-mtp` is a `Candidate`; it must not replace Current until its comparison is complete.
- A future HauhauCS Balanced-MTP release is `Watch`, not an available or validated model.
- `CURRENT_STATE.md` and `configs/current/` describe the operating baseline.

## Status semantics

- `Current`: the stable everyday configuration. There must be exactly one Current model unless a migration is explicitly in progress.
- `Candidate`: available for isolated evaluation; never describe it as adopted or stable without benchmark evidence.
- `Watch`: not yet ready for testing, not yet published, or still awaiting required metadata.
- `Retired`: previously used but no longer selected. Preserve its history.

## Repository rules

1. Never copy model weights, tokenizer payloads, LM Studio application data, runtime caches, or downloaded repositories into this repository.
2. Treat `configs/*.json` as management records, not guaranteed LM Studio import files. Do not invent undocumented LM Studio field names.
3. Do not fabricate benchmark values. Use `null`, `pending`, or `not measured` when evidence is missing.
4. Keep raw console output and transient logs under `logs/` or `benchmarks/raw/`; these paths are intentionally ignored. Commit only curated results and notes.
5. Do not include credentials, API keys, private URLs, personal prompts, or sensitive source code in benchmark artifacts.
6. Do not download a model or change VS Code, Zoo Code, LM Studio, NVIDIA driver, CUDA, BIOS/UEFI, or firmware settings unless the user explicitly requests it.
7. Do not change the stable Current profile while testing a Candidate. Create a separate Candidate profile and compare with controlled settings.
8. Prefer UTF-8 text, ISO 8601 timestamps with timezone, and invariant numeric formats.
9. Store RTX 5090 loader BAT files under `scripts/lmstudio/model-loaders/RTX5090/<Model-Name>/`; add a new model directory instead of overwriting another model's loaders.
10. Never execute a managed loader BAT without explicit user authorization. Current loaders call `lms unload --all` and therefore change LM Studio runtime state.
11. Every model-loader directory must document its model reference, API Model ID, presets, runtime side effects, shared settings, and external model-data boundary.

## Required update workflow

When registering a model:

1. Add or update its entry in `MODEL_REGISTRY.md`.
2. Add a management profile under `configs/candidates/` or `configs/current/`.
3. Create a research note that records claims, unknowns, and the evidence source.
4. Record measured runs under `benchmarks/results/` using the benchmark template.
5. Update `CHANGELOG.md` with the repository or runtime decision.

When promoting a Candidate to Current:

1. Confirm the benchmark matrix covers speed, VRAM, context stability, MTP, coding/agent behavior, and Vision when applicable.
2. Record regressions and operational tradeoffs, not only peak throughput.
3. Move the old Current to a preserved historical/retired record; do not erase it.
4. Update `CURRENT_STATE.md`, `MODEL_REGISTRY.md`, `configs/current/`, and `CHANGELOG.md` in the same change.
5. Promotion requires explicit user approval.

## Benchmark discipline

- Keep context length, cache type, GPU offload, prompt, temperature/sampling, reasoning budget, and concurrency constant for A/B runs unless the experiment tests that variable.
- Perform warm-up separately from measured runs.
- Record time to first token, generation throughput, MTP acceptance, peak/delta VRAM, stability, and task outcome when observable.
- Separate observed data from inference. Reference local raw artifacts by path without committing sensitive or oversized logs.
- For 128K context testing, note desktop responsiveness and memory pressure. The known 128K + Q8 KV result is unsuitable for routine use even if the model technically loads.

## File ownership

- `CURRENT_STATE.md`: concise operational truth.
- `MODEL_REGISTRY.md`: model lifecycle and selection record.
- `CHANGELOG.md`: chronological decisions and changes.
- `configs/`: reproducible management profiles.
- `benchmarks/`: protocol, templates, and curated measurements.
- `research/`: claims, sources, questions, and evaluation plans.
- `logs/`: ignored local diagnostic output only.
- `scripts/`: non-destructive repository helpers.
- `scripts/lmstudio/model-loaders/`: explicitly invoked LM Studio runtime loaders, separated by GPU and model.

Before completing work, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Repository.ps1` from the repository root.
