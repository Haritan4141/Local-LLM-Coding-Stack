[CmdletBinding()]
param()

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
$ExpectedPowerLimits = @{
    'NVIDIA GeForce RTX 3090' = 370.0
    'NVIDIA GeForce RTX 3060' = 170.0
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

function Get-PowerState {
    $rows = @(& nvidia-smi --query-gpu=name,power.limit --format=csv,noheader,nounits)
    if ($LASTEXITCODE -ne 0) { throw 'nvidia-smi power-limit query failed.' }
    return @($rows | ConvertFrom-Csv -Header @('name', 'power_limit_w'))
}

function Assert-PowerState {
    $rows = @(Get-PowerState)
    foreach ($expectedName in $ExpectedPowerLimits.Keys) {
        $matches = @($rows | Where-Object { $_.name.Trim() -eq $expectedName })
        if ($matches.Count -ne 1) {
            throw "Expected one '$expectedName' in nvidia-smi, found $($matches.Count)."
        }
        $actual = [double]::Parse($matches[0].power_limit_w.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        $expected = [double]$ExpectedPowerLimits[$expectedName]
        if ([Math]::Abs($actual - $expected) -gt 0.5) {
            throw "$expectedName Power Limit is ${actual}W; expected ${expected}W. No setting was changed."
        }
    }
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

Assert-PowerState

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

Write-Host '[INFO] Identity, IP, runtime GPUs, model, and 370W/170W Power Limits verified.'
Write-Host '[INFO] Unloading idle models on BLUE before the managed load...'
& lms unload --all
if ($LASTEXITCODE -ne 0) { throw "lms unload --all failed with exit code $LASTEXITCODE." }

$loadArguments = @(
    $ManagedLoader,
    '--model-key', $ModelKey,
    '--identifier', $Identifier,
    '--context', [string]$ContextLength,
    '--mtp', 'on',
    '--kv', 'q8_0',
    '--mmap', 'off',
    '--keep-model-in-memory', 'on',
    '--strict-vram-cap', 'off',
    '--eval-batch', '512',
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
    '--kv', 'q8_0',
    '--mmap', 'off',
    '--keep-model-in-memory', 'on',
    '--strict-vram-cap', 'off',
    '--eval-batch', '512',
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
Assert-PowerState

Write-Host '[OK] BLUE Operational Default is ready.'
Write-Host "[OK] $Identifier / 64K / Q8_0 / RTX3090+RTX3060 / MTP 2 / Vision"
& lms ps
