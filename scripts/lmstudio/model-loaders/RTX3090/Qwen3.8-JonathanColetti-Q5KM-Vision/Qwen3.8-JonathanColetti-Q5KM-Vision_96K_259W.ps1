[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedHostname = 'DESKTOP-L9HAM1G'
$ExpectedIp = '192.168.0.104'
$ModelKey = 'qwen3.8-27b-uncensored-vision-q5km'
$Identifier = 'qwen3.8-27b-uncensored-vision-q5km-blue'
$ContextLength = 98304
$DraftTokens = 3
$EvalBatch = 1024
$ExternalSdkRoot = 'C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk'
$ManagedLoader = Join-Path $ExternalSdkRoot 'Load-ManagedModel.mjs'
$ManagedTest = Join-Path $ExternalSdkRoot 'Test-ManagedModel.mjs'
$Rtx3090Name = 'NVIDIA GeForce RTX 3090'
$Rtx3090Bus = '00000000:0B:00.0'
$Rtx3090PowerLimit = 259
$Rtx3060Name = 'NVIDIA GeForce RTX 3060'
$Rtx3060Bus = '00000000:01:00.0'
$Rtx3060PowerLimit = 170
$CombinedSharedLimitBytes = [int64]4GB
$PerGpuSharedLimitBytes = [int64]2GB

function Get-LmsObjects {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $lines = @(& lms @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "lms $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    $text = $lines -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $parsed = $text | ConvertFrom-Json
    foreach ($item in @($parsed)) { $item }
}

function Get-GpuState {
    $query = 'uuid,name,pci.bus_id,power.limit,power.default_limit,memory.total,memory.used'
    $rows = @(& nvidia-smi "--query-gpu=$query" --format=csv,noheader,nounits)
    if ($LASTEXITCODE -ne 0) { throw 'nvidia-smi GPU identity, power, and memory query failed.' }
    return @($rows | ConvertFrom-Csv -Header @(
        'uuid', 'name', 'pci_bus_id', 'power_limit_w', 'power_default_limit_w',
        'memory_total_mib', 'memory_used_mib'
    ))
}

function Resolve-GpuState {
    $rows = @(Get-GpuState)
    $rtx3090 = @($rows | Where-Object {
        $_.name.Trim() -eq $Rtx3090Name -and
        $_.pci_bus_id.Trim().ToUpperInvariant() -eq $Rtx3090Bus
    })
    $rtx3060 = @($rows | Where-Object {
        $_.name.Trim() -eq $Rtx3060Name -and
        $_.pci_bus_id.Trim().ToUpperInvariant() -eq $Rtx3060Bus
    })
    if ($rtx3090.Count -ne 1) {
        throw "Expected one $Rtx3090Name at PCI Bus $Rtx3090Bus, found $($rtx3090.Count)."
    }
    if ($rtx3060.Count -ne 1) {
        throw "Expected one $Rtx3060Name at PCI Bus $Rtx3060Bus, found $($rtx3060.Count)."
    }
    return [pscustomobject]@{ rtx3090 = $rtx3090[0]; rtx3060 = $rtx3060[0] }
}

function Assert-PowerLimit {
    param(
        [Parameter(Mandatory)]$Gpu,
        [Parameter(Mandatory)][double]$ExpectedWatts
    )
    $actual = [double]::Parse($Gpu.power_limit_w.Trim(), [Globalization.CultureInfo]::InvariantCulture)
    if ([Math]::Abs($actual - $ExpectedWatts) -gt 0.5) {
        throw "$($Gpu.name.Trim()) at $($Gpu.pci_bus_id.Trim()) has Power Limit ${actual}W; expected ${ExpectedWatts}W."
    }
}

function Set-AndVerify-PowerLimits {
    param([Parameter(Mandatory)]$GpuIdentity)
    Assert-PowerLimit -Gpu $GpuIdentity.rtx3060 -ExpectedWatts $Rtx3060PowerLimit
    $uuid = $GpuIdentity.rtx3090.uuid.Trim()
    Write-Host "[INFO] Setting $Rtx3090Name at $Rtx3090Bus to ${Rtx3090PowerLimit}W..."
    $setOutput = @(& nvidia-smi -i $uuid -pl $Rtx3090PowerLimit)
    if ($LASTEXITCODE -ne 0) { throw "Failed to set RTX3090 Power Limit to ${Rtx3090PowerLimit}W." }
    foreach ($line in $setOutput) { Write-Host $line }
    Start-Sleep -Seconds 2
    $verified = Resolve-GpuState
    Assert-PowerLimit -Gpu $verified.rtx3090 -ExpectedWatts $Rtx3090PowerLimit
    Assert-PowerLimit -Gpu $verified.rtx3060 -ExpectedWatts $Rtx3060PowerLimit
    Write-Host '[OK] Power Limits verified: RTX3090 259W / RTX3060 170W.'
    return $verified
}

function Get-SharedMemoryState {
    param([Parameter(Mandatory)][object[]]$NvidiaRows)

    $samples = @(Get-Counter -Counter @(
        '\GPU Adapter Memory(*)\Dedicated Usage',
        '\GPU Adapter Memory(*)\Shared Usage'
    ) -ErrorAction Stop).CounterSamples
    $rawAdapters = @($samples | Group-Object InstanceName | ForEach-Object {
        $dedicated = @($_.Group | Where-Object { $_.Path -match 'dedicated usage$' } | Select-Object -First 1)
        $shared = @($_.Group | Where-Object { $_.Path -match 'shared usage$' } | Select-Object -First 1)
        [pscustomobject]@{
            instance = $_.Name
            dedicated_bytes = if ($dedicated.Count) { [int64]$dedicated[0].CookedValue } else { 0 }
            shared_bytes = if ($shared.Count) { [int64]$shared[0].CookedValue } else { 0 }
        }
    })
    if ($rawAdapters.Count -lt 2) { throw 'WDDM GPU Adapter Memory counters did not expose both NVIDIA adapters.' }

    $available = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $rawAdapters) { $available.Add($row) }
    $mapped = @()
    foreach ($gpu in @($NvidiaRows | Sort-Object { [double]$_.memory_used_mib } -Descending)) {
        $target = [double]$gpu.memory_used_mib * 1MB
        $best = @($available | Sort-Object { [Math]::Abs([double]$_.dedicated_bytes - $target) } | Select-Object -First 1)
        if ($best.Count -ne 1) { throw "Could not map WDDM counters for $($gpu.name.Trim())." }
        $mapped += [pscustomobject]@{
            name = $gpu.name.Trim()
            pci_bus_id = $gpu.pci_bus_id.Trim().ToUpperInvariant()
            instance = $best[0].instance
            dedicated_bytes = [int64]$best[0].dedicated_bytes
            shared_bytes = [int64]$best[0].shared_bytes
        }
        $null = $available.Remove($best[0])
    }
    return [pscustomobject]@{
        combined_shared_bytes = [int64]($rawAdapters | Measure-Object shared_bytes -Sum).Sum
        adapters = $mapped
    }
}

function Assert-StrictMemoryGate {
    $gpuState = Resolve-GpuState
    $rows = @($gpuState.rtx3090, $gpuState.rtx3060)
    foreach ($gpu in $rows) {
        $used = [double]::Parse($gpu.memory_used_mib.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        $total = [double]::Parse($gpu.memory_total_mib.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        if ($used -lt 4096 -or $used -ge $total) {
            throw "$($gpu.name.Trim()) has invalid loaded-model VRAM state: used ${used}MiB / total ${total}MiB."
        }
    }

    $shared = Get-SharedMemoryState -NvidiaRows $rows
    if ($shared.combined_shared_bytes -ge $CombinedSharedLimitBytes) {
        throw "Combined Shared GPU Memory is $($shared.combined_shared_bytes) bytes; gate requires less than $CombinedSharedLimitBytes bytes."
    }
    foreach ($expected in @(
        [pscustomobject]@{ name = $Rtx3090Name; bus = $Rtx3090Bus },
        [pscustomobject]@{ name = $Rtx3060Name; bus = $Rtx3060Bus }
    )) {
        $matches = @($shared.adapters | Where-Object { $_.name -eq $expected.name -and $_.pci_bus_id -eq $expected.bus })
        if ($matches.Count -ne 1) { throw "Expected one WDDM Shared-memory mapping for $($expected.name), found $($matches.Count)." }
        if ([int64]$matches[0].shared_bytes -gt $PerGpuSharedLimitBytes) {
            throw "$($expected.name) Shared GPU Memory is $($matches[0].shared_bytes) bytes; gate requires no more than $PerGpuSharedLimitBytes bytes."
        }
    }
    Write-Host ("[OK] Strict Shared gate: combined {0:N3} GiB; RTX3090 {1:N3} GiB; RTX3060 {2:N3} GiB." -f @(
        ($shared.combined_shared_bytes / 1GB),
        ((@($shared.adapters | Where-Object name -eq $Rtx3090Name)[0].shared_bytes) / 1GB),
        ((@($shared.adapters | Where-Object name -eq $Rtx3060Name)[0].shared_bytes) / 1GB)
    ))
}

if ([Environment]::MachineName -ne $ExpectedHostname) {
    throw "This loader requires $ExpectedHostname; observed $([Environment]::MachineName)."
}
$addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object IPAddress)
if ($ExpectedIp -notin $addresses) { throw "Expected IPv4 $ExpectedIp was not found. No runtime state was changed." }
foreach ($requiredCommand in @('lms', 'node', 'nvidia-smi')) {
    if ($null -eq (Get-Command $requiredCommand -ErrorAction SilentlyContinue)) { throw "Required command is unavailable: $requiredCommand" }
}
foreach ($requiredPath in @($ManagedLoader, $ManagedTest)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Required managed loader file was not found: $requiredPath" }
}

$gpuIdentity = Resolve-GpuState
Assert-PowerLimit -Gpu $gpuIdentity.rtx3060 -ExpectedWatts $Rtx3060PowerLimit

$survey = @(Get-LmsObjects -Arguments @('runtime', 'survey', '--json'))
$engine = @($survey.engines | Where-Object { $_.engine -eq 'llama.cpp' }) | Select-Object -First 1
if ($null -eq $engine) { throw 'The selected llama.cpp runtime survey was not found.' }
$runtimeGpus = @($engine.hardwareSurvey.gpuSurveyResult.gpuInfo)
$priority = [System.Collections.Generic.List[int]]::new()
foreach ($gpuName in @($Rtx3090Name, $Rtx3060Name)) {
    $matches = @($runtimeGpus | Where-Object { $_.name -eq $gpuName })
    if ($matches.Count -ne 1) { throw "Expected one LM Studio runtime GPU named '$gpuName', found $($matches.Count)." }
    $priority.Add([int]$matches[0].deviceId)
}
$disabled = @($runtimeGpus | Where-Object { [int]$_.deviceId -notin $priority } | ForEach-Object { [int]$_.deviceId })
$priorityArg = $priority -join ','
$disabledArg = if ($disabled.Count -eq 0) { 'none' } else { $disabled -join ',' }

$catalog = Invoke-RestMethod -Uri 'http://127.0.0.1:1234/api/v1/models' -Method Get -TimeoutSec 10
$catalogMatches = @($catalog.models | Where-Object { $_.key -eq $ModelKey })
if ($catalogMatches.Count -ne 1) { throw "Expected one installed catalog model '$ModelKey', found $($catalogMatches.Count)." }
if ($null -ne $catalogMatches[0].PSObject.Properties['vision'] -and $catalogMatches[0].vision -ne $true) {
    throw "The installed model '$ModelKey' is not reported as Vision-capable."
}

$loaded = @(Get-LmsObjects -Arguments @('ps', '--json'))
$active = @($loaded | Where-Object {
    ($null -eq $_.PSObject.Properties['queued']) -or
    ($null -eq $_.PSObject.Properties['status']) -or
    [int]$_.queued -gt 0 -or
    $_.status -notin @('idle', 'loaded')
})
if ($active.Count -gt 0) { throw 'An LM Studio prediction is active or queued. It was not interrupted.' }

$gpuIdentity = Set-AndVerify-PowerLimits -GpuIdentity $gpuIdentity
Write-Host '[INFO] Identity, IP, runtime GPUs, model, and 259W/170W Power Limits verified.'
Write-Host '[INFO] Unloading idle models on BLUE before the managed load...'
& lms unload --all
if ($LASTEXITCODE -ne 0) { throw "lms unload --all failed with exit code $LASTEXITCODE." }

$loadArguments = @(
    $ManagedLoader,
    '--model-key', $ModelKey,
    '--identifier', $Identifier,
    '--context', [string]$ContextLength,
    '--mtp', 'on',
    '--mtp-draft', [string]$DraftTokens,
    '--kv-k', 'q8_0',
    '--kv-v', 'q8_0',
    '--mmap', 'off',
    '--keep-model-in-memory', 'on',
    '--strict-vram-cap', 'off',
    '--eval-batch', [string]$EvalBatch,
    '--priority', $priorityArg,
    '--disabled', $disabledArg
)
& node @loadArguments
if ($LASTEXITCODE -ne 0) { throw "Managed model load failed with exit code $LASTEXITCODE." }

try {
    $testArguments = @(
        $ManagedTest,
        '--identifier', $Identifier,
        '--context', [string]$ContextLength,
        '--mtp', 'on',
        '--mtp-draft', [string]$DraftTokens,
        '--kv-k', 'q8_0',
        '--kv-v', 'q8_0',
        '--mmap', 'off',
        '--keep-model-in-memory', 'on',
        '--strict-vram-cap', 'off',
        '--eval-batch', [string]$EvalBatch,
        '--priority', $priorityArg,
        '--disabled', $disabledArg,
        '--vision-required', 'on'
    )
    & node @testArguments
    if ($LASTEXITCODE -ne 0) { throw "Managed model audit failed with exit code $LASTEXITCODE." }

    $loadedAfter = @(Get-LmsObjects -Arguments @('ps', '--json'))
    $target = @($loadedAfter | Where-Object { $_.identifier -eq $Identifier })
    if ($target.Count -ne 1) { throw "Expected exactly one lms ps entry '$Identifier', found $($target.Count)." }
    if ([int]$target[0].contextLength -ne $ContextLength -or [int]$target[0].parallel -ne 1) {
        throw 'lms ps did not report the required 96K context and parallel 1.'
    }
    if ([int]$target[0].queued -ne 0 -or $target[0].status -ne 'idle') {
        throw 'The Q5_K_M instance is not IDLE with zero queued predictions.'
    }

    Assert-StrictMemoryGate
    $gpuIdentity = Resolve-GpuState
    Assert-PowerLimit -Gpu $gpuIdentity.rtx3090 -ExpectedWatts $Rtx3090PowerLimit
    Assert-PowerLimit -Gpu $gpuIdentity.rtx3060 -ExpectedWatts $Rtx3060PowerLimit
} catch {
    Write-Warning "Q5_K_M 96K post-load gate failed; unloading '$Identifier'."
    & lms unload $Identifier 2>&1 | ForEach-Object { Write-Warning $_ }
    throw
}

Write-Host '[OK] BLUE Q5_K_M Vision 96K Recommended is ready.'
Write-Host '[OK] Q8_0/Q8_0 / priorityOrder RTX3090->RTX3060 / MTP3 / batch1024 / ubatch512 effective / parallel1 / Vision / 259W-170W'
& lms ps
