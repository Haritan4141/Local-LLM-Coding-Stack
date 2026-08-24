# BLUE Shared GPU Memory investigation

Date: 2026-08-24 (Asia/Tokyo)

Scope: Jonathan Q6_K Vision on `DESKTOP-L9HAM1G`, RTX3090 24 GB + RTX3060 12 GB, LM Studio 0.4.21 / llama.cpp CUDA 2.29.1.

Method: existing controlled raw artifacts, LM Studio logs, `nvidia-smi`, Windows GPU performance counters, CUDA runtime capability queries, and primary documentation. No driver, Power Limit, BIOS, Firewall, LM Studio global setting, NVIDIA profile, or runtime configuration was changed for this investigation.

## Executive answer

The visible 8–10 GiB of aggregate Dedicated free memory is not an available pooled heap. Each GPU has its own allocations and WDDM residency budget, while the default multi-GPU layer split binds each layer’s KV cache to the GPU owning that layer. At 88K the smaller RTX3060 had only 2,061 MiB free even though the RTX3090 had 6,263 MiB. At 96K a fit/allocation boundary was crossed and approximately 1.78 GiB disappeared from Dedicated occupancy while Shared rose by 1.364 GiB. The larger post-load Dedicated “free” value is therefore partly a consequence of fallback/placement, not proof that the same allocation could have used the two GPUs’ combined free space.

LM Studio explicitly documents that model weights can fit in Dedicated VRAM while context buffers overflow into Shared GPU Memory. Its Dedicated-only control applies to model-weight offload; context may still use Shared. The 96K retry with that strict control enabled produced 5.013 GiB Shared versus 5.021 GiB without it, confirming that the control does not resolve this case.

The exact 96K buffer that crossed the threshold is not available in the current engine’s logs. The most defensible conclusion is a compound per-device fit/budget/allocation-boundary event involving context/KV and possibly compute/MTP workspace, with P2P-unavailable host staging as a possible secondary contributor.

## Observed

### Context matrix — Q8_0 KV

Shared is the Windows `GPU Adapter Memory(*)\Shared Usage` delta. `Dedicated delta` is the two-GPU after-load `nvidia-smi memory.used` total minus that run's 569–570 MiB pre-load display baseline. The per-GPU used/free columns are absolute after-load `nvidia-smi` values.

| Context | Shared | Dedicated delta | RTX3060 used / free | RTX3090 used / free | Gate |
|---:|---:|---:|---:|---:|---|
| 64K | 3.281 GiB | 26,574 MiB | 9,277 / 3,011 MiB | 17,867 / 6,709 MiB | PASS |
| 72K | 3.405 GiB | 27,042 MiB | 9,801 / 2,487 MiB | 17,811 / 6,765 MiB | PASS |
| 80K | 3.531 GiB | 27,505 MiB | 10,013 / 2,275 MiB | 18,061 / 6,515 MiB | PASS |
| 84K | 3.593 GiB | 27,738 MiB | 10,121 / 2,167 MiB | 18,187 / 6,389 MiB | PASS |
| 88K / 90,112 | 3.657 GiB | 27,970 MiB | 10,227 / 2,061 MiB | 18,313 / 6,263 MiB | PASS boundary |
| 96K / 98,304 | 5.021 GiB | 26,188 MiB | 9,379 / 2,909 MiB | 17,378 / 7,198 MiB | FAIL |
| 128K | 8.065 GiB | 25,954 MiB | 9,421 / 2,867 MiB | 17,102 / 7,474 MiB | FAIL |

From 88K to 96K:

- Shared increases by 1.364 GiB.
- Model-attributed Dedicated delta decreases by 1,782 MiB instead of increasing with context; absolute after-load usage falls from 28,540 to 26,757 MiB (1,783 MiB).
- Aggregate post-load Dedicated free therefore increases from 8,324 MiB to 10,107 MiB.

This inverse movement is direct evidence of a placement/residency regime change. It is not a normal linear KV-only slope.

### F16 comparison

| Context | KV | Shared | Dedicated delta |
|---:|---|---:|---:|
| 64K | Q8_0 | 3.281 GiB | 26,574 MiB |
| 64K | F16 | 3.286 GiB | 28,068 MiB |
| 128K | Q8_0 | 8.065 GiB | 25,954 MiB |
| 128K | F16 | 15.044 GiB | 23,364 MiB |

At 64K the additional F16 KV allocation is absorbed by Dedicated VRAM: Dedicated rises 1,494 MiB while Shared is effectively unchanged. At 128K the larger F16 cache produces about 6.98 GiB more Shared and 2.59 GiB less Dedicated than Q8, showing that cache size materially affects fallback once the threshold has been crossed.

The current engine did not log exact K/V buffer bytes. Under the controlled 64K comparison, the 1,494 MiB Dedicated difference is consistent with F16 requiring roughly one extra Q8-sized cache allocation, but this remains an inference because MTP/context workspaces are also present.

### Logs and fit behavior

The effective runs used:

- full/max offload (`n_gpu_layers=999999` equivalent)
- `priorityOrder` runtime IDs `[0,1]`, where 0=RTX3090 and 1=RTX3060
- KV GPU offload ON
- Flash Attention ON
- MTP ON / draft 2
- Vision projector loaded
- mmap OFF
- parallel 1

At context 90,112 the LM Studio server log contains:

```text
W common_fit_params: failed to fit params to free device memory:
n_gpu_layers already set by user to 999999, abort
```

The current 2.29.1 log does not expose the requested 96K/128K per-GPU breakdown for model buffer, KV cache, compute buffer, or `CUDA_Host`. Older engine logs prove those categories exist—CPU_Mapped/CUDA model buffers, CPU/CUDA KV buffers, CUDA_Host output/compute buffers—but their old 4K values are not reused as current evidence.

### Current 64K BAR1 and WDDM counters

After the managed 64K Operational Default load:

| GPU | FB used / free | BAR1 used / free | WDDM Dedicated | WDDM Shared | WDDM Total Committed |
|---|---:|---:|---:|---:|---:|
| RTX3090 | 17,858 / 6,468 MiB | 228 / 28 MiB | 18,733,969,408 B | 1,793,507,328 B | 20,670,582,784 B |
| RTX3060 | 9,275 / 2,841 MiB | 228 / 28 MiB | 9,733,013,504 B | 1,749,286,912 B | 11,482,316,800 B |

BAR1 is a PCIe aperture that maps framebuffer memory for CPU/peer access, not additional VRAM and not a Shared spill reservoir. Its 228/256 MiB use on both devices does not mean either device’s framebuffer is full.

Windows exposed Dedicated, Shared, and Total Committed performance counters. It did not expose a usable Budget counter in this environment. A read-only D3DKMT video-memory query returned `STATUS_INVALID_HANDLE`, so per-GPU `Budget / CurrentUsage / Reservation` values remain unknown.

### CUDA P2P and environment

CUDA runtime capability queries returned:

- RTX3090 → RTX3060: `cudaDeviceCanAccessPeer = 0`
- RTX3060 → RTX3090: `cudaDeviceCanAccessPeer = 0`
- P2P access/native atomic/CUDA array access attributes: 0 both directions

No `GGML_CUDA_P2P`, `GGML_CUDA_ENABLE_UNIFIED_MEMORY`, `CUDA_VISIBLE_DEVICES`, or related override was present in Process/User/Machine environment variables. The installed Windows `nvidia-smi` build did not implement the requested `topo` subcommands, but the direct CUDA runtime result is definitive for peer capability.

### NVIDIA System Memory Fallback control

No supported NVIDIA CLI/profile-inspector tool was installed that could read the NVIDIA Control Panel `CUDA - Sysmem Fallback Policy` value. Its exact profile setting is therefore **Unknown**. Shared allocation is occurring at runtime, but that observation does not prove which GUI profile value is selected. No NVIDIA setting was opened or changed.

The managed 64K per-load setting explicitly has `gpuStrictVramCap=false`. A separate 96K readout with `gpuStrictVramCap=true` still measured 5.013 GiB Shared, so that LM Studio control is not an effective remedy for context-buffer Shared use.

## Source-verified behavior

- [LM Studio multi-GPU controls](https://lmstudio.ai/blog/lmstudio-v0.3.14): weights and conversation context are major memory consumers; Dedicated-only weight offload can still leave context buffers in Shared memory; Priority Order fills GPUs in the selected order.
- [LM Studio model load API](https://lmstudio.ai/docs/developer/rest/load): context length, eval batch, Flash Attention, and KV GPU offload are per-load controls.
- [llama.cpp multi-GPU guide](https://github.com/ggml-org/llama.cpp/blob/master/docs/multi-gpu.md): default layer split gives each GPU contiguous layers, keeps each layer’s KV on its owning GPU, and grows KV roughly with context; `parallel` also multiplies sequence-cache needs.
- [llama.cpp CUDA implementation](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cuda/ggml-cuda.cu): CUDA device allocations, managed allocations, and pinned CUDA host buffers are separate paths; `CUDA_Host` is not synonymous with VRAM spill.
- [Microsoft graphics-memory calculation](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/calculating-graphics-memory): Dedicated video memory and Shared system memory are distinct WDDM accounting categories.
- [DXGI video-memory information](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_4/ns-dxgi1_4-dxgi_query_video_memory_info): WDDM tracks Budget, CurrentUsage, reservation availability, and current reservation separately.
- [WDDM GPU virtual memory](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/gpu-virtual-memory-in-wddm-2-0): GPU virtual addresses may be backed by local device memory or system memory.
- [NVIDIA SMI reference](https://docs.nvidia.com/deploy/nvidia-smi/index.html): framebuffer memory and BAR1 are separate counters; WDDM controls Windows memory accounting.
- [CUDA multi-GPU guide](https://docs.nvidia.com/cuda/cuda-programming-guide/03-advanced/multi-gpu-systems.html): GPU device memories are independent; P2P capability determines whether direct peer access is available.
- [NVIDIA System Memory Fallback policy](https://nvidia.custhelp.com/app/answers/detail/a_id/5490): system-memory fallback trades an out-of-memory failure for slower system-memory use; disabling it can instead cause allocation failure.

## Inferred

1. The 36 GiB headline VRAM figure cannot satisfy one arbitrary allocation. A buffer assigned to the RTX3060 cannot borrow the RTX3090’s 6–7 GiB free as if it were a single heap.
2. Priority/layer ownership constrains weights and KV placement. Rebalancing requires a different split/load, not post-allocation pooling.
3. The 88K→96K discontinuity is most consistent with a per-device fit/residency/allocation boundary. Candidate contributors are a KV chunk boundary, prompt/generation compute arena growth, MTP draft workspace, allocator fragmentation, or WDDM budget pressure.
4. P2P unavailability can require host-staged transfers and may contribute host/Shared traffic, but it is not proven to cause the 1.364 GiB jump. Default layer splitting minimizes inter-GPU communication relative to tensor parallelism, so P2P is secondary to the capacity/placement evidence.
5. The 90,112 fit warning and forced maximum layer count explain why the runtime did not solve pressure by reducing GPU layers. Reducing offload could avoid some Shared use but would intentionally move compute/weights to RAM/CPU and lower performance.

## Unknown

- Exact model/KV/compute/MTP/vision/`CUDA_Host` byte allocation at 96K and 128K.
- Which single buffer or allocator event caused the 88K→96K step.
- Per-GPU WDDM Budget and reservation values during those historical loads.
- Historical per-context BAR1 values.
- Exact NVIDIA Control Panel Sysmem Fallback Policy selection.
- Whether a different formal split ratio would reduce Shared without worsening throughput or the RTX3060 boundary.
- The motherboard/root-complex reason for P2P capability being unavailable.

## Improvement candidates — proposal only

| Proposal | Expected effect | Risk / effect on 64K default | Decision |
|---|---|---|---|
| Keep 64K/Q8/parallel 1 | preserves measured margin | none; current selected profile | adopted |
| Dedicated-only weight cap | may prevent weight spill | context can still use Shared; 96K true retry did not help | do not change |
| Different priority/custom split | may move pressure away from RTX3060 | can reduce RTX3090 margin or throughput; requires isolated A/B | proposal only |
| Lower GPU layer offload | lets auto-fit avoid Shared for weights | large performance regression and changes operational semantics | fallback experiment only |
| KV CPU offload | reduces device pressure | likely TTFT/tok/s regression | proposal only |
| Disable NVIDIA Sysmem Fallback | forces OOM instead of slow fallback | higher failure risk; does not fix per-device fit | do not apply |
| Enable P2P override | direct capability is unavailable; likely no benefit | llama.cpp warns unsupported topology can crash/corrupt output | do not apply |
| 80K/84K/88K | more context | only 0.469/0.407/0.343 GiB Shared-gate margin | capacity evidence, not default |

No improvement was automatically applied. The existing 64K Operational Default remains the safe choice.
