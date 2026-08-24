# BLUE RTX3090 Power Limit A/B — 259W Primary adoption

Date: 2026-08-24
Node: `pc5700x / DESKTOP-L9HAM1G / 192.168.0.104`
Decision: RTX3090 `259W` Primary Operational; `370W` explicit Performance override. RTX3060 remains `170W`.

## Fixed runtime

- JonathanColetti Qwen3.8-27B-Uncensored Vision Q6_K
- context 65,536
- Q8_0/Q8_0 KV, KV GPU offload
- RTX3090 then RTX3060 `priorityOrder`, full offload
- Flash Attention ON, mmap OFF, keep in memory ON
- embedded MTP ON / draft 2, parallel 1
- reasoning OFF, temperature 0

The same loaded model instance and effective settings were used. The measured order was 370W initial, 259W, then 370W verification. Formal condition starts were at or below 59C. Warm-up was excluded.

## Result

| Metric | 370W | 259W | Difference at 259W |
|---|---:|---:|---:|
| Text generation median | 25.765 tok/s | 24.623 tok/s | -4.43% |
| Vision generation median | 33.266 tok/s | 31.612 tok/s | -4.97% |
| 30.9K prompt processing median | 592.03 tok/s | 553.84 tok/s | -6.45% |
| 30.9K generation median | 39.301 tok/s | 37.580 tok/s | -4.38% |
| Sustained generation | 25.321 tok/s | 24.493 tok/s | -3.27% |
| Sustained RTX3090 average | 262.3W | 210.1W | -19.9% |
| Sustained RTX3060 average | 118.5W | 116.6W | -1.7% |
| Sustained total GPU average | 380.9W | 326.7W | -14.23% |
| Sustained RTX3090 peak temperature | 83C | 79C | -4C |
| Sustained RTX3090 average clock | 1,759 MHz | 1,556 MHz | -11.52% |
| Sustained generation / GPU watt | 0.0665 | 0.0750 | +12.78% |

The 370W verification Text median was 25.678 tok/s, only 0.34% below the initial 370W median. All six Vision runs passed the deterministic 7/7 fixture. MTP acceptance was materially unchanged.

The sustained fixture naturally ended at 2,753 output tokens in both conditions with the same response SHA-256. It did not reach the requested 4,096-token minimum, but provided 110–114 seconds of stable thermal/power load without OOM, crash, or output divergence.

The original repeated long prompt entered LM Studio prompt-cache reuse. Those cached observations were excluded and replaced by two unique nonce-prefixed prompts per condition. Input length varied by at most five tokens out of about 30.9K.

## Power and thermal interpretation

At the 370W setting, the RTX3090 did not sustain anything close to 370W: its sustained average was 262.3W and the maximum observed across formal samples was 298.4W. Reducing the limit to 259W lowered sustained RTX3090 power by 52.2W while generation fell only 3.27%. The RTX3060 power and sustained utilization were nearly unchanged.

SW Power Cap activity was more frequent at 259W, as expected. No new cumulative HW Thermal Slowdown or HW Power Brake event was recorded. The dual-GPU split, memory-bound generation, synchronization, RTX3060 work, and Gen3 x4 link are plausible contributors to the sublinear scaling, but this A/B does not isolate one as the sole bottleneck.

Dedicated memory remained about 18,097 MiB on RTX3090 and 9,287 MiB on RTX3060. Shared GPU Memory stayed around 3.328–3.335 GiB with no Power Limit-dependent classification change.

Telemetry was requested by a one-second collection loop; Windows counter and `nvidia-smi` overhead produced an effective median interval of about 2.08 seconds. Raw JSON, CSV, and LM Studio stats remain under ignored `benchmarks/raw/blue-q6k-power-ab/`.

## Operational decision

The small performance loss is outweighed by the lower power, temperature, fan demand, and higher efficiency for normal BLUE use. Therefore:

- Primary: RTX3090 259W / RTX3060 170W
- Performance override: RTX3090 370W / RTX3060 170W, explicit loader only
- Model/runtime settings: unchanged
- Standard16K / Long32K client output profiles: unchanged and independent of Power Limit
- Repository Current and MAIN RTX5090 Operational Default: unchanged
