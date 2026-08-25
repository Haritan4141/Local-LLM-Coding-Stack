[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile,
    [switch]$AllowNotRunning
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

Assert-ManagedTurboProcess -State $state -Manifest $manifest -RequireListener | Out-Null
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
