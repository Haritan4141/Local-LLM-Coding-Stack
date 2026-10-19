[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick', 'BLUE-IQ4XS256K', 'RTX5090-IQ4XS256K')][string]$Profile,
    [switch]$AllowNotRunning,
    [switch]$AllowLegacyApiAlias
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
$storage = Get-TurboStorage -Manifest $manifest
Assert-TurboHostAndGpu -Manifest $manifest | Out-Null
$listeners = @(Get-TurboPortListeners -Port ([int]$manifest.server.port))

if (-not (Test-Path -LiteralPath $storage.active_state -PathType Leaf)) {
    if ($listeners.Count -gt 0) {
        $owners = ($listeners | ForEach-Object OwningProcess | Sort-Object -Unique) -join ', '
        throw "Port $($manifest.server.port) is owned by unknown PID(s) $owners. No process was stopped."
    }
    if ($AllowNotRunning) {
        Write-Host '[OK] No managed Turbo process is running; port is free.' -ForegroundColor Green
        exit 0
    }
    throw 'Managed Turbo state is absent; no process was stopped.'
}

$state = Get-Content -LiteralPath $storage.active_state -Raw -Encoding UTF8 | ConvertFrom-Json
$process = Get-TurboProcessRecord -ProcessId ([int]$state.pid)
if ($null -eq $process) {
    if ($listeners.Count -gt 0) { throw 'Managed PID is absent but the Turbo port is still owned. No process was stopped.' }
    Move-TurboStateToHistory -StatePath $storage.active_state -HistoryRoot $storage.history -Reason 'stale-state-on-stop' | Out-Null
    if ($AllowNotRunning) {
        Write-Host '[OK] Stale managed state archived; no Turbo process was running.' -ForegroundColor Green
        exit 0
    }
    throw 'Managed Turbo PID is no longer running; stale state was archived.'
}

if ($AllowLegacyApiAlias -and -not (Test-TurboLegacyApiAlias -Manifest $manifest -Alias ([string]$state.api_model_alias))) {
    throw "Managed state alias '$($state.api_model_alias)' is not a declared legacy Quick alias. No process was stopped."
}
Assert-ManagedTurboProcess -State $state -Manifest $manifest -RequireListener -AllowLegacyApiAlias:$AllowLegacyApiAlias | Out-Null
if ($manifest.profile_class -eq 'extended-context') {
    $response = Invoke-RestMethod -Uri 'http://127.0.0.1:18080/slots' -TimeoutSec 10
    $slots = @($response | ForEach-Object { $_ })
    if ($slots.Count -ne 1 -or $null -eq $slots[0].PSObject.Properties['is_processing'] -or
        $slots[0].is_processing -ne $false) {
        throw 'Extended Context has active/unknown prediction state. No process was stopped.'
    }
}
Stop-Process -Id ([int]$state.pid)
$deadline = (Get-Date).AddSeconds(45)
do {
    if ($null -eq (Get-TurboProcessRecord -ProcessId ([int]$state.pid))) { break }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)
if ($null -ne (Get-TurboProcessRecord -ProcessId ([int]$state.pid))) {
    throw "Managed Turbo PID $($state.pid) did not stop before the timeout."
}

$deadline = (Get-Date).AddSeconds(45)
do {
    if (@(Get-TurboPortListeners -Port ([int]$manifest.server.port)).Count -eq 0) { break }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $deadline)
if (@(Get-TurboPortListeners -Port ([int]$manifest.server.port)).Count -ne 0) {
    throw "Port $($manifest.server.port) was not released after the managed process stopped."
}
$gpuReleased = @(Wait-TurboVramReleased -Manifest $manifest)
$history = Move-TurboStateToHistory -StatePath $storage.active_state -HistoryRoot $storage.history -Reason 'managed-stop'

Write-Host "[OK] Managed Turbo PID $($state.pid) stopped safely." -ForegroundColor Green
Write-Host "[OK] Port $($manifest.server.port) is free and VRAM returned to the managed baseline." -ForegroundColor Green
[pscustomobject]@{ stopped = $true; pid = [int]$state.pid; history = $history; gpu_released = $gpuReleased }
