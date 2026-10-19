Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
if ($env:COMPUTERNAME -ne 'DESKTOP-L9HAM1G') { throw 'BLUE-only telemetry.' }
$rows = @(& nvidia-smi '--query-gpu=uuid,name,pci.bus_id,memory.total,memory.used,temperature.gpu,power.limit' '--format=csv,noheader,nounits')
if ($LASTEXITCODE -ne 0) { throw 'NVIDIA telemetry failed.' }
$gpus = @($rows | ConvertFrom-Csv -Header uuid,name,bus,total_mib,used_mib,temperature_c,power_w)
$memory = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory |
    Select-Object Name,DedicatedUsage,SharedUsage,TotalCommitted)
$os = Get-CimInstance Win32_OperatingSystem
[ordered]@{
    recorded_at_utc = [DateTime]::UtcNow.ToString('o')
    gpus = $gpus
    adapters = $memory
    ram_free_bytes = [int64]$os.FreePhysicalMemory * 1024
    ram_total_bytes = [int64]$os.TotalVisibleMemorySize * 1024
} | ConvertTo-Json -Depth 6 -Compress
