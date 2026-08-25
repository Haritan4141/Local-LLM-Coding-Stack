[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$turboRoot = Join-Path $repoRoot 'scripts\standalone-turbo'
$startScript = Join-Path $turboRoot 'Start-ManagedTurbo.ps1'
$stopScript = Join-Path $turboRoot 'Stop-ManagedTurbo.ps1'
$manifestPath = Join-Path $turboRoot 'runtime-manifests\RTX5090.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$commonModule = Join-Path $turboRoot 'Turbo.Common.psm1'
Import-Module $commonModule -Force
$stateRoot = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\turbo'
$statePath = Join-Path $stateRoot "$($manifest.profile_id).json"
$runtimeExe = [Environment]::ExpandEnvironmentVariables($manifest.runtime.external_path) |
    ForEach-Object { Join-Path $_ $manifest.runtime.executable }
$modelPath = [Environment]::ExpandEnvironmentVariables($manifest.model.path)

if ([Environment]::MachineName -ne $manifest.target_host.computer_name) {
    throw "This hardware fail-closed test requires $($manifest.target_host.computer_name)."
}
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    throw "Managed Turbo state already exists; test refused: $statePath"
}
if (@(Get-NetTCPConnection -State Listen -LocalPort 18080 -ErrorAction SilentlyContinue).Count -ne 0) {
    throw 'Port 18080 is already in use; test refused.'
}
$lmsModels = @(Assert-TurboLmsIdle)
if ($lmsModels.Count -gt 0 -and $null -eq $lmsModels[0].PSObject.Properties['status']) {
    throw 'LM Studio JSON records were not flattened correctly by Windows PowerShell.'
}

$powershellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$results = [ordered]@{}

function Start-TestPowerShell {
    param([Parameter(Mandatory)][string]$Command)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    return Start-Process -FilePath $powershellExe -ArgumentList @('-NoProfile', '-EncodedCommand', $encoded) -WindowStyle Hidden -PassThru
}

$listenerProcess = $null
try {
    $listenerProcess = Start-TestPowerShell -Command '$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 18080); $listener.Start(); try { while ($true) { Start-Sleep -Seconds 5 } } finally { $listener.Stop() }'
    $deadline = (Get-Date).AddSeconds(15)
    do {
        $listener = @(Get-NetTCPConnection -State Listen -LocalPort 18080 -ErrorAction SilentlyContinue)
        if (@($listener | Where-Object { [int]$_.OwningProcess -eq $listenerProcess.Id }).Count -eq 1) { break }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    if (@($listener | Where-Object { [int]$_.OwningProcess -eq $listenerProcess.Id }).Count -ne 1) {
        throw 'The test listener did not bind to 127.0.0.1:18080.'
    }

    $message = $null
    try { & $startScript -Profile RTX5090 | Out-Null }
    catch { $message = $_.Exception.Message }
    $listenerProcess.Refresh()
    if ([string]::IsNullOrWhiteSpace($message) -or
        $message -notmatch 'owned by unknown PID' -or
        $listenerProcess.HasExited) {
        throw 'Unknown-port protection did not fail closed while preserving the unrelated listener.'
    }
    $results['unknown_port'] = [ordered]@{ pass = $true; preserved_pid = $listenerProcess.Id; error = $message }
}
finally {
    if ($null -ne $listenerProcess) {
        $listenerProcess.Refresh()
        if (-not $listenerProcess.HasExited) {
            Stop-Process -Id $listenerProcess.Id
            Wait-Process -Id $listenerProcess.Id -Timeout 15 -ErrorAction SilentlyContinue
        }
    }
}

if (@(Get-NetTCPConnection -State Listen -LocalPort 18080 -ErrorAction SilentlyContinue).Count -ne 0) {
    throw 'The test listener did not release port 18080.'
}

$sleepProcess = $null
try {
    $sleepProcess = Start-TestPowerShell -Command 'Start-Sleep -Seconds 600'
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    [ordered]@{
        schema_version = 1
        profile_id = $manifest.profile_id
        pid = $sleepProcess.Id
        executable_path = $runtimeExe
        model_path = $modelPath
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8

    $message = $null
    try { & $stopScript -Profile RTX5090 | Out-Null }
    catch { $message = $_.Exception.Message }
    $sleepProcess.Refresh()
    if ([string]::IsNullOrWhiteSpace($message) -or
        $message -notmatch 'executable mismatch' -or
        $sleepProcess.HasExited) {
        throw 'Unknown-PID protection did not fail closed while preserving the unrelated process.'
    }
    $results['unknown_pid'] = [ordered]@{ pass = $true; preserved_pid = $sleepProcess.Id; error = $message }
}
finally {
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        Remove-Item -LiteralPath $statePath -Force
    }
    if ($null -ne $sleepProcess) {
        $sleepProcess.Refresh()
        if (-not $sleepProcess.HasExited) {
            Stop-Process -Id $sleepProcess.Id
            Wait-Process -Id $sleepProcess.Id -Timeout 15 -ErrorAction SilentlyContinue
        }
    }
}

if (@(Get-NetTCPConnection -State Listen -LocalPort 18080 -ErrorAction SilentlyContinue).Count -ne 0) {
    throw 'Port 18080 is not free after fail-closed tests.'
}
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    throw 'Temporary managed state was not removed after fail-closed tests.'
}

Write-Host 'Standalone Turbo fail-closed tests passed: unknown port and unknown PID were preserved.' -ForegroundColor Green
[pscustomobject]$results
