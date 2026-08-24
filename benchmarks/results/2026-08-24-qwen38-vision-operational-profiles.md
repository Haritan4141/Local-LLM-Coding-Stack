# Qwen3.8 Vision Phase 1 / 1.5 Operational Profiles

Date: 2026-08-24 (Asia/Tokyo)

## Decision

Repository lifecycle `Current` remains `current-qwen38-27b-uncensored-q6k`. The profiles below are operational tiers for the existing JonathanColetti Q6_K Vision model views; they do not create another Current model.

| System | Safe | Balanced — Recommended | Coding-Fast |
|---|---|---|---|
| RTX5090 MAIN | 64K, MTP2, Q8/Q8, batch2048, ubatch512, 402W | 64K, MTP4, Q8/Q8, batch2048, ubatch512, 402W | 64K, MTP4, Q4/Q4, batch2048, ubatch512, 402W |
| BLUE RTX3090+3060 | 64K, MTP2, Q8/Q8, batch512, ubatch512, 259W/170W | 64K, MTP3, Q8/Q8, batch1024, ubatch512, 259W/170W | 64K, MTP3, Q4/Q4, batch512, ubatch512, 259W/170W |

Safe is the permanent known-good rollback. Coding-Fast is an explicit workload-specific selection and is not the General Default. The existing BLUE 370W Performance override and Standard16K / Long32K client output profiles remain independent.

## Evidence boundary

RTX5090 source reports:

- `C:\Users\Haritan\Documents\LMStudio-Optimization-Phase1\RTX5090\PHASE1-READY-REPORT.md`
- `C:\Users\Haritan\Documents\LMStudio-Optimization-Phase1\RTX5090\phase1_5\PHASE1.5-READY-REPORT.md`

BLUE source data remains under ignored repository paths:

- `benchmarks/raw/blue-phase1-optimization/session-20260824/`
- `benchmarks/raw/blue-phase15-isolation/session-20260824/`
- `phase15-aggregate.json` and the Phase 1 Coding failure replay within those sessions

Raw artifacts, console streams, model data, and fixtures were not added to Git. Percentages below are curated from the controlled reports; they are not newly invented measurements.

## RTX5090 results

### Phase 1

The formal Phase 1 matrix completed 176/176 valid and quality-passing runs, including 44/44 Vision runs. From the MTP2/Q8 anchor to the Phase 1 MTP4/Q4 final candidate, median workload changes were Text `-3.54%`, Coding `+27.76%`, Vision `+3.24%`, Long `+6.18%`, and geometric mean `+7.81%`, with approximately `724 MiB` lower peak VRAM. That combined result did not isolate the MTP and KV effects, so Phase 1.5 determined the operational tiers.

### Phase 1.5 isolation

Conditions were A = MTP2/Q8, B = MTP4/Q8, and C = MTP4/Q4. Context was 65,536, eval batch 2048, effective ubatch 512, parallel 1, Flash Attention ON, full offload, and Vision ON.

| Comparison | Text | Coding | Vision | Long | Geomean | VRAM |
|---|---:|---:|---:|---:|---:|---:|
| Balanced B vs Safe A | +2.24% | +8.61% | -0.57% | +7.19% | +4.30% | same Q8 class |
| Coding-Fast C vs Balanced B | -13.59% | +8.95% | -2.86% | -12.73% | -5.48% | about 1.03 GiB lower |

The normal matrix completed 36/36 formal valid and quality-passing runs, including 9/9 Vision correctness. No MTP4-specific quality failure was observed. The `-0.57%` Vision value for Balanced is a speed measurement difference, not a correctness regression.

The additional 12-case coding matrix scored 7/12 under A, B, and C. The same failures occurred across conditions and there were zero Q4-only failures. This supports relative parity inside that matrix, not broad proof that Q4 equals Q8 on arbitrary coding or agent workloads.

Decision: B is Balanced / Operational Recommended. A is permanent Safe. C is Coding-Fast because its gain is coding-specific and its other workloads regress.

## BLUE results

### MTP2 to MTP3

At Q8, batch512, and otherwise controlled 64K settings, MTP3 changed Safe medians by Text `+2.81%`, Coding `+7.70%`, Vision `+6.24%`, and Long `+4.26%`. Both conditions passed 3/3 quality checks and 4/4 safety checks.

### Batch512 to batch1024 at MTP3/Q8

| Metric | Change |
|---|---:|
| Long prompt processing | +24.80% |
| Long TTFT | -19.81% |
| Text generation | -0.60% |
| Coding generation | -2.04% |
| Vision generation | +0.61% |
| Long generation | +0.25% |

Batch1024 completed 12/12 valid/quality runs and 4/4 safety checks. Its large long-prompt responsiveness gain with small generation variation supports Balanced at MTP3/Q8/batch1024.

### Q8 to Q4 isolation

Phase 1.5 conditions A/B/C/D isolated Q8/Q4 and batch512/1024 at MTP3. All four conditions completed 12/12 valid/quality runs and 4/4 safety checks. Q4/batch512 versus Q8/batch1024 changed Coding by `+10.25%` and Long by `-7.13%`, reinforcing a workload-specific role.

The Phase 1 Q4/batch1024 Coding failure replay reproduced the historical result: public checks `5/10`, hidden checks `14/16`; the Q8/batch512 control passed `10/10` and `16/16`. The fresh Phase 1.5 matrix did not reproduce a Q4-specific failure. Both observations are retained: the fresh matrix is favorable, but fixture-external Q4 parity is not established.

Decision: MTP3/Q8/batch1024 is Balanced / Operational Recommended. MTP2/Q8/batch512 remains Safe. MTP3/Q4/batch512 is Coding-Fast only.

## Managed loader behavior

`Load-ManagedModel.mjs` and `Test-ManagedModel.mjs` now accept optional MTP draft 2/3/4, independent K/V cache types Q8_0/Q4_0/F16, and eval batch. Omitted values retain the prior draft2, Q8_0/Q8_0, and unspecified-eval defaults. Unknown options, unsupported values, and mixed F16/quantized K/V fail closed. No ubatch mutation path was added; effective ubatch 512 was read from the LM Studio native model catalog/backend audit.

Each Balanced/Coding-Fast loader explicitly supplies its profile-specific fields. The pre-existing RTX5090 64K Safe BAT and BLUE `_64K_259W.bat` were not renamed, removed, or overwritten. Selectors only CALL individual loader BATs and Cancel exits without runtime mutation.

## Runtime validation

Controlled switching was performed on 2026-08-24 with explicit user authorization.

### RTX5090 MAIN

Identity: `DESKTOP-5NPLIIV`, RTX5090 PCI Bus `00000000:01:00.0`, Power Limit `402W`, API ID `qwen3.8-27b-uncensored-vision`.

| Loaded profile | Effective audit |
|---|---|
| Safe | 64K, MTP2, Q8/Q8, eval batch2048, ubatch512, parallel1, Flash ON, full offload, mmap+mlock backend behavior, Vision true, 402W |
| Balanced | 64K, MTP4, Q8/Q8, eval batch2048, ubatch512, parallel1, Flash ON, full offload, mmap+mlock, Vision true, 402W |
| Coding-Fast | 64K, MTP4, Q4/Q4, eval batch2048, ubatch512, parallel1, Flash ON, full offload, mmap+mlock, Vision true, 402W |
| Safe after Coding-Fast | Q8/Q8, MTP2, batch2048, and ubatch512 restored; no Q4/MTP4 residue |

The selector sequence Safe → Balanced → Coding-Fast → Safe passed. Balanced passed short Text, Coding, and Vision API smoke checks; Vision returned the expected serial, shape count, table values/total, and arrow direction. Coding-Fast reused the Phase 1 duration fixture through LM Studio native v1 with reasoning OFF and produced all five required markers, both functions, and a code block.

The OpenAI-compatible endpoint defaults this Qwen model to reasoning ON. An initial long fixture attempt exhausted its completion allowance in reasoning and returned no message content; this was an API prediction-mode issue, not a load/profile failure. The final fixture smoke used the same native `reasoning: off` path as Phase 1 and recorded zero reasoning tokens.

Final MAIN runtime: 0 loaded models.

### BLUE RTX3090 + RTX3060

Identity was verified before every remote mutation: SSH alias `pc5700x`, IPv4 `192.168.0.104`, COMPUTERNAME `DESKTOP-L9HAM1G`. GPU Power Limit targeting used GPU name + PCI Bus ID and the resolved UUID: RTX3090 `00000000:0B:00.0` at 259W, RTX3060 `00000000:01:00.0` at 170W.

| Loaded profile | Effective audit |
|---|---|
| Safe | 64K, MTP2, Q8/Q8, batch512, ubatch512, priorityOrder, mmap OFF, parallel1, Vision true, 259W/170W |
| Balanced | 64K, MTP3, Q8/Q8, batch1024, ubatch512, priorityOrder, mmap OFF, parallel1, Vision true, 259W/170W |
| Coding-Fast | 64K, MTP3, Q4/Q4, batch512, ubatch512, priorityOrder, mmap OFF, parallel1, Vision true, 259W/170W |
| Safe after Coding-Fast | Q8/Q8, MTP2, batch512, and ubatch512 restored; no Q4/MTP3 residue |

The MAIN REMOTE selector sequence Safe → Balanced → Coding-Fast → Safe passed, then Balanced was loaded as the final Recommended state. MAIN reached `http://192.168.0.104:1234`, native API smoke responses used the unchanged BLUE API ID, and Coding-Fast reproduced all Phase 1 duration fixture markers/functions with reasoning OFF. The final `lms ps` showed one intended model, `IDLE`, 65,536 context, and parallel 1.

Final BLUE runtime: Balanced, one model IDLE, queued work absent, MTP3/Q8/Q8/batch1024/ubatch512/64K/259W/170W.

## Quality and scope caveats

- Formal fixture correctness is evidence for the tested prompts and images, not universal model-quality equivalence.
- MAIN Balanced is the general recommendation; its small Vision speed variation had no correctness loss.
- MAIN and BLUE Coding-Fast are opt-in because Q4 benefits coding while regressing other workloads and BLUE has a historical reproduced Q4 failure.
- No DFlash2, SGLang, vLLM, NVFP4, driver, firmware, BIOS, Firewall, SSH, LM Studio global GPU setting, or client output-profile change was made.
- Model weights, projectors, LM Studio data, and raw benchmark output remain outside Git.
