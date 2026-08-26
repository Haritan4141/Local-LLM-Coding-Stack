[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
$storage = Get-TurboStorage -Manifest $manifest
$stopScript = Join-Path $PSScriptRoot 'Stop-ManagedTurbo.ps1'

Assert-TurboHostAndGpu -Manifest $manifest | Out-Null

# Refuse to release either runtime while LM Studio is generating or queued.
$lmsBefore = @(Assert-TurboLmsIdle)
$listeners = @(Get-TurboPortListeners -Port ([int]$manifest.server.port))
$turboRunning = $false

if (Test-Path -LiteralPath $storage.active_state -PathType Leaf) {
    $state = Get-Content -LiteralPath $storage.active_state -Raw -Encoding UTF8 | ConvertFrom-Json
    $process = Get-TurboProcessRecord -ProcessId ([int]$state.pid)

    if ($null -eq $process) {
        if ($listeners.Count -gt 0) {
            throw 'Managed Turbo PID is absent but its port is still owned. No runtime was released.'
        }

        Write-Host '[INFO] Archiving stale managed Turbo state before release...'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stopScript -Profile $Profile -AllowNotRunning
        if ($LASTEXITCODE -ne 0) { throw "Stale Turbo state cleanup failed with exit code $LASTEXITCODE." }
    }
    else {
        Assert-ManagedTurboProcess -State $state -Manifest $manifest -RequireListener | Out-Null
        Test-TurboApiState -Manifest $manifest | Out-Null

        # Windows PowerShell 5.1 returns a top-level JSON array as one Object[]
        # pipeline item. Flatten it before inspecting each slot's own properties.
        $slotResponse = Invoke-RestMethod -Uri "http://$($manifest.server.host):$($manifest.server.port)/slots" -TimeoutSec 10
        $slots = @($slotResponse | ForEach-Object { $_ })
        if ($slots.Count -ne [int]$manifest.configuration.parallel) {
            throw "Turbo slot count is $($slots.Count); expected $($manifest.configuration.parallel). No runtime was released."
        }
        $unsafeSlots = @($slots | Where-Object {
            $null -eq $_.PSObject.Properties['is_processing'] -or $_.is_processing -ne $false
        })
        if ($unsafeSlots.Count -gt 0) {
            throw 'Turbo has an active prediction. It was not interrupted and no runtime was released.'
        }
        $turboRunning = $true
    }
}
elseif ($listeners.Count -gt 0) {
    $owners = ($listeners | ForEach-Object OwningProcess | Sort-Object -Unique) -join ', '
    throw "Turbo port $($manifest.server.port) is owned by unknown PID(s) $owners. No process was stopped."
}

if ($turboRunning) {
    Write-Host '[INFO] Releasing the verified idle managed Turbo runtime...'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stopScript -Profile $Profile
    if ($LASTEXITCODE -ne 0) { throw "Managed Turbo release failed with exit code $LASTEXITCODE." }
}

# Re-read LM Studio after the Turbo stop. This also covers the normal Stable path.
$lmsModels = @(Assert-TurboLmsIdle)
if ($lmsModels.Count -gt 0) {
    Write-Host "[INFO] Releasing $($lmsModels.Count) idle LM Studio model(s)..."
    & lms unload --all
    if ($LASTEXITCODE -ne 0) { throw "lms unload --all failed with exit code $LASTEXITCODE." }
    Wait-TurboLmsEmpty
}
else {
    Write-Host '[OK] LM Studio already has no loaded model.' -ForegroundColor Green
}

if (@(Get-TurboPortListeners -Port ([int]$manifest.server.port)).Count -ne 0) {
    throw "Turbo port $($manifest.server.port) is still listening after release."
}
if (@(Get-TurboLmsModels).Count -ne 0) {
    throw 'LM Studio still reports a loaded model after release.'
}

Write-Host "[OK] $Profile model runtime released; LM Studio is empty and Turbo port $($manifest.server.port) is free." -ForegroundColor Green
