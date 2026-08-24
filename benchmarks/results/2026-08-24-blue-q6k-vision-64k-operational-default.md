# BLUE Jonathan Q6_K Vision — 64K Operational Default

- Date: 2026-08-24 (Asia/Tokyo)
- Node: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`
- GPUs: RTX 3090 24,576 MiB + RTX 3060 12,288 MiB; VRAM is not pooled
- Power Limit: RTX3090 370W / RTX3060 170W; observed only, not changed
- Runtime: LM Studio 0.4.21.0 / CLI `71bd99c`
- Model: JonathanColetti Qwen3.8 27B Uncensored Q6_K + F16 Vision projector
- Model SHA-256: `a50aa1478295b58ee3d93eabe02c17f6d5fcf6cb787fd8a0ab07ac629a46cae6`
- Projector SHA-256: `5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c`
- API identifier: `qwen3.8-27b-uncensored-vision-blue`

## Selected configuration

| Setting | Value |
|---|---|
| Context | 65,536 |
| K/V cache | Q8_0 / Q8_0 |
| KV GPU offload | ON |
| GPU offload | max |
| GPU split | `priorityOrder`: RTX3090 → RTX3060; IDs resolved by GPU name |
| Flash Attention | ON |
| mmap | OFF |
| Keep model in memory | ON |
| Eval batch | 512 |
| MTP | ON / max draft tokens 2 |
| Concurrent predictions | 1 |
| GPU strict VRAM cap | OFF, explicitly audited per load |

The repository lifecycle status remains `Candidate`. “Operational Default” is a BLUE node role and does not create a second repository-wide Current model.

## Context capacity gate

The existing strict gate requires exact load/runtime settings, model-byte coverage by selected Dedicated VRAM within 256 MiB, and Shared GPU Memory at or below 2 GiB per GPU / 4 GiB combined.

| Context | KV | Shared | Shared gate margin | RTX3090 used / headroom | RTX3060 used / headroom | Result |
|---:|---|---:|---:|---:|---:|---|
| 64K | Q8_0 | 3.281 GiB | 0.719 GiB | 17,867 / 6,709 MiB | 9,277 / 3,011 MiB | PASS / selected |
| 72K | Q8_0 | 3.405 GiB | 0.595 GiB | 17,811 / 6,765 MiB | 9,801 / 2,487 MiB | PASS |
| 80K | Q8_0 | 3.531 GiB | 0.469 GiB | 18,061 / 6,515 MiB | 10,013 / 2,275 MiB | PASS |
| 84K | Q8_0 | 3.593 GiB | 0.407 GiB | 18,187 / 6,389 MiB | 10,121 / 2,167 MiB | PASS |
| 88K | Q8_0 | 3.657 GiB | 0.343 GiB | 18,313 / 6,263 MiB | 10,227 / 2,061 MiB | PASS / boundary evidence |
| 96K | Q8_0 | 5.021 GiB | -1.021 GiB | 17,378 / 7,198 MiB | 9,379 / 2,909 MiB | FAIL |
| 128K | Q8_0 | 8.065 GiB | -4.065 GiB | recorded in raw telemetry | recorded in raw telemetry | FAIL |
| 128K | F16 | 15.044 GiB | -11.044 GiB | recorded in raw telemetry | recorded in raw telemetry | FAIL |

Although 80K–88K passed, they leave only 0.469–0.343 GiB before the Shared gate and 2.0–2.3 GiB on the smaller RTX3060. The selected 64K profile keeps 0.719 GiB of Shared-gate margin and 9,720 MiB combined Dedicated headroom. Capacity maximum was deliberately not adopted as the everyday default.

## Q8_0 versus F16 at the same 64K context

| KV | Shared | RTX3090 headroom | RTX3060 headroom | Total Dedicated headroom | Short generation |
|---|---:|---:|---:|---:|---:|
| Q8_0 | 3.281 GiB | 6,709 MiB | 3,011 MiB | 9,720 MiB | 26.13 tok/s |
| F16 | 3.286 GiB | 5,911 MiB | 2,315 MiB | 8,226 MiB | 26.11 tok/s |

Q8_0 was selected because measured speed was equivalent while it retained 1,494 MiB more Dedicated headroom.

## 64K results

| Workload | Prompt processing | Generation | TTFT | MTP acceptance | Result |
|---|---:|---:|---:|---:|---|
| Short text | 128.12 tok/s | 26.13 tok/s | 0.796 s | 79.41% | PASS |
| Vision PNG | 1,087.25 tok/s | 33.60 tok/s | 0.375 s | 90.62% | 7/7 PASS |

## Output profiles

The deterministic fixture contained 30,889 input tokens and a 100,113-character target with SHA-256 `82650e643032200e05b947689b52e9140c431d4f86e5782bfc67ec7d8bc34f78`.

| Profile | Client limit | Observed output | Completion | Generation | Shared peak delta |
|---|---:|---:|---|---:|---:|
| Standard16K | 16,384 | 16,384 tokens | stopped at configured limit as expected | 37.81 tok/s | 8.1 MiB |
| Long32K | 32,768 | 30,803 tokens | natural completion; exact text/SHA match | 36.57 tok/s | 8.3 MiB |

Long32K generated well beyond 16K without a server-side 16K stop. The table above is the deterministic native-API validation. Kilo Code 7.4.22 also recognizes both managed aliases:

- `openai-compatible/blue-jonathan-vision-64k-standard16k`
- `openai-compatible/blue-jonathan-vision-64k-long32k`

An actual Kilo `run --pure` with the Long32K alias completed its first generation step at 29,001 output tokens (`reason=length`), so the Kilo client path is not capped at 16K. The emitted text contained 28,999 characters, from `00001` through the partial `04833` sequence. Kilo then opened an automatic continuation/summary turn (305 output tokens); the test was stopped only after the >16K result had completed and LM Studio returned to IDLE. This is a client-loop caution, not a server-side 16K limit.

The pre-existing Kilo localhost model remains the default. Goose was not changed because it uses a single active output limit. Zoo Code requires a manual saved profile in its UI; no undocumented repository schema was invented.

## Operational validation

The BLUE local launcher and MAIN remote launcher both completed successfully. Post-load audit reported:

- exactly one loaded instance
- `qwen3.8-27b-uncensored-vision-blue`
- context 65,536
- Q8_0/Q8_0
- full offload
- Flash Attention ON
- mmap OFF
- MTP ON / draft 2
- parallel 1
- `priorityOrder` `[RTX3090 runtime ID, RTX3060 runtime ID]`
- Vision `true`
- both GPUs above the loaded-model memory-use floor
- Power Limits unchanged at 370W / 170W

Existing Jonathan Q4_K_M 32K loaders remain installed as the fallback. No GGUF, projector, LM Studio application data, driver setting, global GPU setting, Firewall rule, BIOS setting, or Power Limit was changed or added to Git.

The expanded managed-loader helper was also tested with the existing Q4_K_M 32K argument set. Its Q8_0/Q8_0, full-offload, MTP draft 2, parallel 1 audit passed; the managed remote launcher then restored and re-audited the Q6_K Vision 64K Operational Default.

Raw telemetry and prompts remain under ignored `benchmarks/raw/` and the BLUE external evaluation directory.
