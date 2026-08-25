[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
$runtime = Get-TurboRuntimeInfo -Manifest $manifest
$storage = Get-TurboStorage -Manifest $manifest
$listeners = @(Get-TurboPortListeners -Port ([int]$manifest.server.port))
$stateExists = Test-Path -LiteralPath $storage.active_state -PathType Leaf

if ($stateExists) {
    $existingState = Get-Content -LiteralPath $storage.active_state -Raw -Encoding UTF8 | ConvertFrom-Json
    $existingProcess = Get-TurboProcessRecord -ProcessId ([int]$existingState.pid)
    if ($listeners.Count -gt 0) {
        Assert-ManagedTurboProcess -State $existingState -Manifest $manifest -RequireListener | Out-Null
        $api = Test-TurboApiState -Manifest $manifest
        Write-Host "[OK] $($manifest.display_name) is already running as managed PID $($existingState.pid)." -ForegroundColor Green
        $api
        exit 0
    }
    if ($null -ne $existingProcess) {
        throw "Managed Turbo PID $($existingState.pid) exists without the expected listener. Refusing a second start."
    }
    Move-TurboStateToHistory -StatePath $storage.active_state -HistoryRoot $storage.history -Reason 'stale-state-before-start' | Out-Null
}
elseif ($listeners.Count -gt 0) {
    $owners = ($listeners | ForEach-Object OwningProcess | Sort-Object -Unique) -join ', '
    throw "Port $($manifest.server.port) is owned by unknown PID(s) $owners. No process was stopped."
}

Assert-TurboHostAndGpu -Manifest $manifest | Out-Null
foreach ($path in @($runtime.executable, $runtime.bundle_manifest, $runtime.model, $runtime.projector)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Turbo artifact is missing: $path" }
}
foreach ($required in @($manifest.runtime.required_files)) {
    if (-not (Test-Path -LiteralPath (Join-Path $runtime.root $required) -PathType Leaf)) {
        throw "Managed runtime bundle is incomplete; missing $required"
    }
}
$exeHash = (Get-FileHash -LiteralPath $runtime.executable -Algorithm SHA256).Hash.ToLowerInvariant()
if ($exeHash -ne $manifest.runtime.executable_expected_sha256) {
    throw "Managed llama-server.exe SHA mismatch: $exeHash"
}
$bundle = Get-Content -LiteralPath $runtime.bundle_manifest -Raw -Encoding UTF8 | ConvertFrom-Json
if ($bundle.source_commit -ne $manifest.runtime.source_commit -or
    $bundle.executable_expected_sha256 -ne $manifest.runtime.executable_expected_sha256) {
    throw 'External runtime bundle manifest does not match the pinned source/SHA.'
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$version = @(& $runtime.executable --version 2>&1 | ForEach-Object { $_.ToString() })
$versionExit = $LASTEXITCODE
$devices = @(& $runtime.executable --list-devices 2>&1 | ForEach-Object { $_.ToString() })
$devicesExit = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($versionExit -ne 0 -or ($version -join "`n") -notmatch 'commit f280b2698') {
    throw 'Pinned runtime --version validation failed.'
}
if ($devicesExit -ne 0) { throw 'Pinned runtime --list-devices validation failed.' }
foreach ($gpu in @($manifest.gpus)) {
    $mapping = "$($gpu.llama_device): $($gpu.name)"
    if (($devices -join "`n").IndexOf($mapping, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "llama.cpp device mapping mismatch; expected '$mapping'."
    }
}

Write-Host '[INFO] Verifying target GGUF SHA-256...'
$modelHash = (Get-FileHash -LiteralPath $runtime.model -Algorithm SHA256).Hash.ToLowerInvariant()
if ($modelHash -ne $manifest.model.sha256) { throw "Target GGUF SHA mismatch: $modelHash" }
Write-Host '[INFO] Verifying Vision projector SHA-256...'
$projectorHash = (Get-FileHash -LiteralPath $runtime.projector -Algorithm SHA256).Hash.ToLowerInvariant()
if ($projectorHash -ne $manifest.model.projector_sha256) { throw "Vision projector SHA mismatch: $projectorHash" }

$lmsBefore = @(Assert-TurboLmsIdle)
$gpuBefore = @(Get-TurboGpuState)
if ($lmsBefore.Count -gt 0) {
    Write-Host "[INFO] LM Studio is IDLE with queued 0. Unloading $($lmsBefore.Count) model(s) for explicit Turbo selection..."
    & lms unload --all
    if ($LASTEXITCODE -ne 0) { throw 'lms unload --all failed; Turbo was not started.' }
    Wait-TurboLmsEmpty
}
$gpuReleased = @(Wait-TurboVramReleased -Manifest $manifest)

$arguments = @(
    '--model', $runtime.model,
    '--mmproj', $runtime.projector,
    '--alias', [string]$manifest.server.api_model_alias,
    '--host', [string]$manifest.server.host,
    '--port', [string]$manifest.server.port,
    '--ctx-size', [string]$manifest.configuration.context_tokens,
    '--parallel', [string]$manifest.configuration.parallel,
    '--batch-size', [string]$manifest.configuration.eval_batch_size,
    '--ubatch-size', [string]$manifest.configuration.ubatch_size,
    '--flash-attn', 'on',
    '--cache-type-k', [string]$manifest.configuration.kv_cache_k,
    '--cache-type-v', [string]$manifest.configuration.kv_cache_v,
    '--gpu-layers', 'all'
)
if ($Profile -eq 'RTX5090') {
    $arguments += @(
        '--mmproj-offload',
        '--device', 'CUDA0',
        '--load-mode', 'mmap+mlock',
        '--spec-type', 'draft-mtp',
        '--spec-draft-n-max', '3',
        '--spec-draft-n-min', '0',
        '--spec-draft-p-min', '0.00',
        '--spec-draft-ngl', 'all',
        '--spec-draft-device', 'CUDA0',
        '--spec-draft-type-k', 'q8_0',
        '--spec-draft-type-v', 'q8_0',
        '--metrics', '--no-webui', '--jinja',
        '--reasoning', 'off', '--reasoning-budget', '0'
    )
}
else {
    $arguments += @(
        '--no-mmap',
        '--device', 'CUDA0,CUDA1',
        '--split-mode', 'layer',
        '--tensor-split', [string]$manifest.configuration.tensor_split,
        '--fit', 'off',
        '--spec-type', 'draft-mtp',
        '--spec-draft-n-max', '3',
        '--spec-draft-n-min', '0',
        '--spec-draft-p-min', '0',
        '--metrics', '--no-webui'
    )
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRoot = Join-Path $storage.logs "$($manifest.profile_id)-$stamp"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$stdout = Join-Path $logRoot 'stdout.log'
$stderr = Join-Path $logRoot 'stderr.log'
$process = Start-Process -FilePath $runtime.executable -ArgumentList $arguments -WorkingDirectory $runtime.root -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru

$state = [ordered]@{
    schema_version = 1
    profile_id = $manifest.profile_id
    host = [Environment]::MachineName
    pid = [int]$process.Id
    executable_path = $runtime.executable
    executable_sha256 = $exeHash
    source_commit = $manifest.runtime.source_commit
    server_host = $manifest.server.host
    server_port = [int]$manifest.server.port
    api_model_alias = $manifest.server.api_model_alias
    model_path = $runtime.model
    model_sha256 = $modelHash
    projector_path = $runtime.projector
    projector_sha256 = $projectorHash
    start_time = (Get-Date).ToString('o')
    command_line_sanitized = @($runtime.executable) + $arguments
    stdout_log = $stdout
    stderr_log = $stderr
    runtime_version = $version
    runtime_devices = $devices
    lms_before = $lmsBefore
    gpu_before = $gpuBefore
    gpu_released = $gpuReleased
    ready = $false
}
Write-TurboJson -InputObject $state -Path $storage.active_state -Depth 15

try {
    $deadline = (Get-Date).AddMinutes(8)
    $health = $null
    do {
        $process.Refresh()
        if ($process.HasExited) { throw "Turbo server exited during load with code $($process.ExitCode). See $stderr" }
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$($manifest.server.port)/health" -TimeoutSec 5
            if ($health.status -eq 'ok') { break }
        }
        catch {}
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if ($null -eq $health -or $health.status -ne 'ok') { throw 'Turbo server did not become healthy before the timeout.' }

    $api = Test-TurboApiState -Manifest $manifest
    $gpuLoaded = @(Assert-TurboVramLoaded -Manifest $manifest)
    if (@(Get-TurboLmsModels).Count -ne 0) { throw 'LM Studio unexpectedly has a loaded model while Turbo is active.' }
    $processRecord = Assert-ManagedTurboProcess -State ([pscustomobject]$state) -Manifest $manifest -RequireListener
    $state['ready'] = $true
    $state['ready_at'] = (Get-Date).ToString('o')
    $state['effective_api'] = $api
    $state['gpu_loaded'] = $gpuLoaded
    $state['observed_command_line'] = $processRecord.command_line
    Write-TurboJson -InputObject $state -Path $storage.active_state -Depth 15
}
catch {
    $process.Refresh()
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        Wait-Process -Id $process.Id -Timeout 30 -ErrorAction SilentlyContinue
    }
    Move-TurboStateToHistory -StatePath $storage.active_state -HistoryRoot $storage.history -Reason 'start-failed' | Out-Null
    throw
}

Write-Host "[OK] $($manifest.display_name) is healthy." -ForegroundColor Green
Write-Host "[OK] Endpoint: http://127.0.0.1:$($manifest.server.port)/v1" -ForegroundColor Green
Write-Host "[OK] Model alias: $($manifest.server.api_model_alias)" -ForegroundColor Green
Write-Host '[OK] 96K / Q8-Q8 / MTP3 / batch1024 / ubatch512 / parallel1 / Vision.' -ForegroundColor Green
[pscustomobject]$state
