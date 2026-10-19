# Goose profile-specific compaction qualification

Measured: 2026-10-01, Asia/Tokyo. **Exploratory matrix complete — 36/36 bounded CLI repeats passed; not adopted.**

## Scope

Installed Goose CLI **v1.52.0**, default legacy loop, MAIN RTX5090 and BLUE RTX3090 + RTX3060. Three isolated synthetic user turns per repeat, no personal extensions, no tools, text only. Each profile is repeated three times. Model runtime settings are selected through existing canonical loaders; only the test Goose process receives the proposed compaction rate.

This is a functional auto-compaction and short-continuation check, **not** Desktop / Vision / long agent-loop / full-output qualification. No production rate is changed. All production Daily profiles remain at 30%; repository Current remains Q6_K.

## Proposed rates and output reserve

The percentage is relative to the **Goose client limit**, not the runtime context.

| MAIN and BLUE profile | Runtime / client limit | Max output | Existing | Evaluated candidate | First eligible current usage | Margin after next full output + 8K growth |
|---|---:|---:|---:|---:|---:|---:|
| Quick 64K/8K | 65,536 / 57,344 | 8,192 | 30% | 60% | 34,407 | 14,745 |
| Stable, Turbo 96K/16K | 98,304 / 90,112 | 16,384 | 30% | 65% | 58,573 | 15,155 |
| Stable, Turbo 96K/32K | 98,304 / 90,112 | 32,768 | 30% | 50% | 45,057 | 12,287 |
| Quality Reference 64K/32K | 65,536 / 64,512 | 32,768 | 30% | retain 30% | 19,354 | 5,222 |

The 8K growth reserve is an engineering assumption, not an observed upper bound. Quality fails a 16K-growth sensitivity check by 2,970 tokens. At the official default 80%, both 32K-output configurations fail this conservative output-aware budget; those are arithmetic rejections, not observed runtime crashes.

## Acceptance and interpretation

- Actual first-call usage stays below the trigger; second-call usage crosses it through real input, not edited usage or an imported conversation.
- Read-only SQLite ledger must be exactly `[normal, normal, compaction, normal]`, with compaction input plus a full output allowance below runtime capacity, internally additive ledger rows, selected pre-/post-probe current-usage matches and continuation below the trigger. This does not compare accumulated CLI/session totals with ledger sums. Actual pre-probe usage must also preserve the next full output plus the assumed 8K growth.
- All ten immutable facts must survive, including negative operational instructions.
- Isolated session `max_tokens` must match 8K/16K/32K. Captured standalone slot caps must match too; missing samples remain unknown.
- Prompt sizing revisions are recorded. Probe seconds include summary generation, short continuation and CLI overhead; they are not TTFT or a controlled speed A/B.

Individual measured runs are recorded in [curated JSON](2026-10-01-goose-profile-compaction.json); raw prompts, session DBs and console output stay outside Git under `%LOCALAPPDATA%\Local-LLM-Coding-Stack\compaction-qualification\`.

## Measured matrix — 36 repeats

All 12 combinations passed three repeats of the bounded CLI test. Every run retained 10/10 facts and a positive next-output-plus-assumed-8K reserve. This is not a Production promotion.

| Target | Profile | Rate | Repeats | Usage before → after | Minimum 8K-growth margin | Probe wall seconds |
|---|---|---:|---|---|---:|---|
| MAIN | Quick 64K/8K | 60% | 3/3 PASS | 39633 → 1278 | 9519 | 20.071–40.158 |
| MAIN | Stable 96K/16K | 65% | 3/3 PASS | 70738–70950 → 1593–1791 | 2778 | 130.618–138.693 |
| MAIN | Stable 96K/32K | 50% | 3/3 PASS | 46752–46864 → 1443–1680 | 10480 | 68.324–102.458 |
| MAIN | Turbo 96K/16K | 65% | 3/3 PASS | 66162 → 1273 | 7566 | 16.062–52.232 |
| MAIN | Turbo 96K/32K | 50% | 3/3 PASS | 51281 → 1310 | 6063 | 14.101–42.239 |
| MAIN | Quality 64K/32K | 30% | 3/3 PASS | 20910–20946 → 1584–1589 | 3630 | 74.369–104.568 |
| BLUE | Quick 64K/8K | 60% | 3/3 PASS | 35585 → 1277 | 13567 | 45.475–90.509 |
| BLUE | Stable 96K/16K | 65% | 3/3 PASS | 60387–60391 → 1790–1808 | 13337 | 325.343–327.527 |
| BLUE | Stable 96K/32K | 50% | 3/3 PASS | 46753–46888 → 1453–1662 | 10456 | 249.179–343.586 |
| BLUE | Turbo 96K/16K | 65% | 3/3 PASS | 66282–66397 → 1544–1546 | 7331 | 299.384–305.545 |
| BLUE | Turbo 96K/32K | 50% | 3/3 PASS | 46400 → 1939–1956 | 10944 | 260.441–322.614 |
| BLUE | Quality 64K/32K | 30% | 3/3 PASS | 20926–20927 → 1785 | 3649 | 180.903–212.967 |

Probe time includes compaction, short continuation and CLI overhead, with mixed padding revisions and warm/cold effects. It is not ordinary chat latency, TTFT, or a hardware performance ranking.

Server output cap was sampled and matched for MAIN/BLUE Turbo32K and BLUE Quick8K (nine runs). The other 27 runs have **server cap not sampled**; all 36 isolated session caps matched their requested values. Quick session metadata records its friendly Qwen alias and Vision flag, not an image-input result.

At **actual observed usage**, replacing the 8K growth assumption with 16K rejects 18/36 rows in six cases: MAIN Stable16K, MAIN Turbo16K, MAIN Turbo32K, BLUE Turbo16K and both Quality cases. This differs from the ideal first-eligible-point calculation because some real turns overshot the threshold. These are sensitivity arithmetic rejections, not measured crashes. Large tool/image additions therefore remain an explicit additional gate.

## Final decision and restoration

- Candidate rates passed the bounded functional test; do not apply them automatically to Daily profiles. Keep production rates at 30% pending a separate adoption decision and Desktop/tool-loop/multimodal/long-output acceptance.
- 2026-10-01T13:12:15+09:00: identity and both LM Studio apps verified, both `lms ps` arrays and API loaded-instance counts empty, MAIN 18080/18081 and BLUE 18080 listeners absent; Goose Desktop remains closed.
- GPU name + PCI Bus ID matched: MAIN RTX5090 `00000000:01:00.0` PL402W; BLUE RTX3090 `00000000:0B:00.0` PL259W, RTX3060 `00000000:01:00.0` PL170W. Post-unload VRAM is a restoration snapshot, not a benchmark peak.
- Production Goose config hash remained unchanged in every harness and against the live checkpoint. Approved BLUE module source/target and preserved old-backup hashes matched at restoration.
- Current/model lifecycle, production compaction rates, drivers, Firewall and persistent execution policy were not changed. No model weights, application data or raw session DBs were added to Git.


## Operational limits

Goose v1.52.0 legacy proactive compaction runs before a reply's inner tool loop, not at every tool boundary. A lower rate can leave more room but does not guarantee an arbitrarily long tool loop cannot overflow. A per-response output-token-limit warning is separate; increasing or reducing the compaction rate alone cannot remove every output truncation.

These runs do not generate a full 32K response after compaction, send images, exercise GUI sessions, or measure peak VRAM, TTFT, tok/s and MTP acceptance. They must not be described as those gates passing. The earlier [Turbo 32K output test](2026-08-26-goose-turbo-output32k-qualification.md) is separate evidence.

## Runtime restoration and deployment

Initial state was both LM Studio applications running, no loaded models and no managed standalone/tunnel listener. Restore that state after the matrix; do not guess a previous profile. Maintain MAIN PL402W and BLUE 259W/170W.

BLUE Quick was blocked by an old deployed `Turbo.Common.psm1` alias validator. With explicit approval, only that module was synchronized using a backup and SHA-256 checks; its subsequent canonical Quick startup passed. No persistent Goose configuration, model configuration, GPU limits, Firewall or driver changes were made by the repair. Full details, primary sources and reproduction steps: [research note](../../research/2026-10-01-goose-compaction-evaluation.md).
