[CmdletBinding()]
param(
    [ValidateSet(259, 370)]
    [int]$Rtx3090PowerLimit = 259,

    [ValidateSet('Safe', 'Balanced', 'Coding-Fast')]
    [string]$OperationalProfile = 'Safe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedHostname = 'DESKTOP-L9HAM1G'
$ExpectedIp = '192.168.0.104'
$ModelKey = 'qwen3.8-27b-uncensored@q6_k'
$Identifier = 'qwen3.8-27b-uncensored-vision-blue'
$ContextLength = 65536
$ExternalSdkRoot = 'C:\Users\Atsuki\Codex-RTX3090-Setup\lmstudio-sdk'
$ManagedLoader = Join-Path $ExternalSdkRoot 'Load-ManagedModel.mjs'
$ManagedTest = Join-Path $ExternalSdkRoot 'Test-ManagedModel.mjs'
$Rtx3090Name = 'NVIDIA GeForce RTX 3090'
$Rtx3090Bus = '00000000:0B:00.0'
$Rtx3060Name = 'NVIDIA GeForce RTX 3060'
$Rtx3060Bus = '00000000:01:00.0'
$Rtx3060PowerLimit = 170
$PowerProfile = if ($Rtx3090PowerLimit -eq 259) { 'Primary Operational' } else { 'Performance override' }

if ($Rtx3090PowerLimit -ne 259 -and $OperationalProfile -ne 'Safe') {
    throw 'Balanced and Coding-Fast are validated only at 259W; they cannot be combined with the 370W Performance override.'
}

$ProfileSettings = switch ($OperationalProfile) {
    'Safe' {
        [pscustomobject]@{ DraftTokens = 2; KCache = 'q8_0'; VCache = 'q8_0'; EvalBatch = 512 }
    }
    'Balanced' {
        [pscustomobject]@{ DraftTokens = 3; KCache = 'q8_0'; VCache = 'q8_0'; EvalBatch = 1024 }
    }
    'Coding-Fast' {
        [pscustomobject]@{ DraftTokens = 3; KCache = 'q4_0'; VCache = 'q4_0'; EvalBatch = 512 }
    }
}

function Get-LmsObjects {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $lines = @(& lms @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "lms $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    $text = $lines -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $parsed = $text | ConvertFrom-Json
    foreach ($item in $parsed) { $item }
}

function Get-GpuPowerState {
    $query = 'uuid,name,pci.bus_id,power.limit,power.default_limit,power.min_limit,power.max_limit'
    $rows = @(& nvidia-smi "--query-gpu=$query" --format=csv,noheader,nounits)
    if ($LASTEXITCODE -ne 0) { throw 'nvidia-smi GPU identity/power query failed.' }
    return @($rows | ConvertFrom-Csv -Header @(
        'uuid', 'name', 'pci_bus_id', 'power_limit_w', 'power_default_limit_w',
        'power_min_limit_w', 'power_max_limit_w'
    ))
}

function Resolve-GpuPowerState {
    $rows = @(Get-GpuPowerState)
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

function Set-Rtx3090PowerProfile {
    param([Parameter(Mandatory)]$GpuIdentity)
    Assert-PowerLimit -Gpu $GpuIdentity.rtx3060 -ExpectedWatts $Rtx3060PowerLimit
    $uuid = $GpuIdentity.rtx3090.uuid.Trim()
    Write-Host "[INFO] Setting $Rtx3090Name at $Rtx3090Bus to ${Rtx3090PowerLimit}W ($PowerProfile)..."
    $setOutput = @(& nvidia-smi -i $uuid -pl $Rtx3090PowerLimit)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set $Rtx3090Name Power Limit to ${Rtx3090PowerLimit}W."
    }
    foreach ($line in $setOutput) { Write-Host $line }
    Start-Sleep -Seconds 2
    $verified = Resolve-GpuPowerState
    Assert-PowerLimit -Gpu $verified.rtx3090 -ExpectedWatts $Rtx3090PowerLimit
    Assert-PowerLimit -Gpu $verified.rtx3060 -ExpectedWatts $Rtx3060PowerLimit
    Write-Host "[OK] Power Limits verified: RTX3090 ${Rtx3090PowerLimit}W / RTX3060 ${Rtx3060PowerLimit}W."
    return $verified
}

if ([Environment]::MachineName -ne $ExpectedHostname) {
    throw "This loader requires $ExpectedHostname; observed $([Environment]::MachineName)."
}
$addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object IPAddress)
if ($ExpectedIp -notin $addresses) {
    throw "Expected IPv4 $ExpectedIp was not found. No runtime state was changed."
}
foreach ($requiredCommand in @('lms', 'node', 'nvidia-smi')) {
    if ($null -eq (Get-Command $requiredCommand -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $requiredCommand"
    }
}
foreach ($requiredPath in @($ManagedLoader, $ManagedTest)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required managed loader file was not found: $requiredPath"
    }
}

$gpuIdentity = Resolve-GpuPowerState
Assert-PowerLimit -Gpu $gpuIdentity.rtx3060 -ExpectedWatts $Rtx3060PowerLimit

$survey = @(Get-LmsObjects -Arguments @('runtime', 'survey', '--json'))
$engine = @($survey.engines | Where-Object { $_.engine -eq 'llama.cpp' }) | Select-Object -First 1
if ($null -eq $engine) { throw 'The selected llama.cpp runtime survey was not found.' }
$runtimeGpus = @($engine.hardwareSurvey.gpuSurveyResult.gpuInfo)
$priority = [System.Collections.Generic.List[int]]::new()
foreach ($gpuName in @('NVIDIA GeForce RTX 3090', 'NVIDIA GeForce RTX 3060')) {
    $matches = @($runtimeGpus | Where-Object { $_.name -eq $gpuName })
    if ($matches.Count -ne 1) {
        throw "Expected one LM Studio runtime GPU named '$gpuName', found $($matches.Count)."
    }
    $priority.Add([int]$matches[0].deviceId)
}
$disabled = @($runtimeGpus | Where-Object { [int]$_.deviceId -notin $priority } | ForEach-Object { [int]$_.deviceId })
$priorityArg = $priority -join ','
$disabledArg = if ($disabled.Count -eq 0) { 'none' } else { $disabled -join ',' }

$catalog = Invoke-RestMethod -Uri 'http://127.0.0.1:1234/api/v1/models' -Method Get -TimeoutSec 10
$catalogMatches = @($catalog.models | Where-Object { $_.key -eq $ModelKey })
if ($catalogMatches.Count -ne 1) {
    throw "Expected one installed catalog model '$ModelKey', found $($catalogMatches.Count)."
}
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
if ($active.Count -gt 0) {
    throw 'An LM Studio prediction is active or queued. It was not interrupted.'
}

$gpuIdentity = Set-Rtx3090PowerProfile -GpuIdentity $gpuIdentity
Write-Host "[INFO] Identity, IP, runtime GPUs, model, and ${Rtx3090PowerLimit}W/170W Power Limits verified."
Write-Host '[INFO] Unloading idle models on BLUE before the managed load...'
& lms unload --all
if ($LASTEXITCODE -ne 0) { throw "lms unload --all failed with exit code $LASTEXITCODE." }

$loadArguments = @(
    $ManagedLoader,
    '--model-key', $ModelKey,
    '--identifier', $Identifier,
    '--context', [string]$ContextLength,
    '--mtp', 'on',
    '--mtp-draft', [string]$ProfileSettings.DraftTokens,
    '--kv-k', $ProfileSettings.KCache,
    '--kv-v', $ProfileSettings.VCache,
    '--mmap', 'off',
    '--keep-model-in-memory', 'on',
    '--strict-vram-cap', 'off',
    '--eval-batch', [string]$ProfileSettings.EvalBatch,
    '--priority', $priorityArg,
    '--disabled', $disabledArg
)
& node @loadArguments
if ($LASTEXITCODE -ne 0) { throw "Managed model load failed with exit code $LASTEXITCODE." }

$testArguments = @(
    $ManagedTest,
    '--identifier', $Identifier,
    '--context', [string]$ContextLength,
    '--mtp', 'on',
    '--mtp-draft', [string]$ProfileSettings.DraftTokens,
    '--kv-k', $ProfileSettings.KCache,
    '--kv-v', $ProfileSettings.VCache,
    '--mmap', 'off',
    '--keep-model-in-memory', 'on',
    '--strict-vram-cap', 'off',
    '--eval-batch', [string]$ProfileSettings.EvalBatch,
    '--priority', $priorityArg,
    '--disabled', $disabledArg,
    '--vision-required', 'on'
)
& node @testArguments
if ($LASTEXITCODE -ne 0) { throw "Managed model audit failed with exit code $LASTEXITCODE." }

$memoryRows = @(& nvidia-smi --query-gpu=name,memory.used --format=csv,noheader,nounits | ConvertFrom-Csv -Header @('name', 'memory_used_mib'))
foreach ($gpuName in @('NVIDIA GeForce RTX 3090', 'NVIDIA GeForce RTX 3060')) {
    $row = @($memoryRows | Where-Object { $_.name.Trim() -eq $gpuName }) | Select-Object -First 1
    if ($null -eq $row -or [double]$row.memory_used_mib -lt 4096) {
        throw "$gpuName does not show the expected loaded-model memory use."
    }
}
$gpuIdentity = Resolve-GpuPowerState
Assert-PowerLimit -Gpu $gpuIdentity.rtx3090 -ExpectedWatts $Rtx3090PowerLimit
Assert-PowerLimit -Gpu $gpuIdentity.rtx3060 -ExpectedWatts $Rtx3060PowerLimit

if ($Rtx3090PowerLimit -eq 259) {
    Write-Host "[OK] BLUE $OperationalProfile profile is ready at the Primary Operational Power Limit."
} else {
    Write-Host '[OK] BLUE 370W Performance override is ready.'
}
Write-Host "[OK] $Identifier / 64K / $($ProfileSettings.KCache)-$($ProfileSettings.VCache) / RTX3090+RTX3060 / MTP $($ProfileSettings.DraftTokens) / batch $($ProfileSettings.EvalBatch) / Vision / RTX3090 ${Rtx3090PowerLimit}W"
& lms ps
