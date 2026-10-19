[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick', 'BLUE-IQ4XS256K', 'RTX5090-IQ4XS256K')][string]$Profile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$profileFamily = if ($Profile.StartsWith('BLUE', [StringComparison]::OrdinalIgnoreCase)) { 'BLUE' } else { 'RTX5090' }
$knownProfiles = if ($profileFamily -eq 'BLUE') { @('BLUE', 'BLUE-Quick', 'BLUE-IQ4XS256K') } else { @('RTX5090', 'RTX5090-Quick', 'RTX5090-IQ4XS256K') }
$lockManifest = Get-TurboProfileManifest -Profile $Profile
$operationLock = Enter-TurboOperationLock -Manifest $lockManifest -TimeoutSeconds 30
try {
Assert-TurboHostAndGpu -Manifest $lockManifest | Out-Null

$knownStates = @()
foreach ($knownProfile in $knownProfiles) {
    $knownManifest = Get-TurboProfileManifest -Profile $knownProfile
    $knownStorage = Get-TurboStorage -Manifest $knownManifest
    if (Test-Path -LiteralPath $knownStorage.active_state -PathType Leaf) {
        $knownStates += [pscustomobject]@{ profile = $knownProfile; manifest = $knownManifest; storage = $knownStorage }
    }
}

# A failed overlapping launcher may have archived the successful process's
# state. Recover only a history record that exactly matches the live listener,
# process creation time, pinned hashes, command line and runtime API.
if ($knownStates.Count -eq 0) {
    $familyListeners = @(Get-TurboPortListeners -Port ([int]$lockManifest.server.port))
    if ($familyListeners.Count -gt 0) {
        foreach ($knownProfile in $knownProfiles) {
            $knownManifest = Get-TurboProfileManifest -Profile $knownProfile
            $knownStorage = Get-TurboStorage -Manifest $knownManifest
            $recovered = Restore-TurboStateFromHistory -Manifest $knownManifest -Storage $knownStorage
            if ($null -ne $recovered) {
                $knownStates += [pscustomobject]@{ profile = $knownProfile; manifest = $knownManifest; storage = $knownStorage }
            }
        }
    }
}
if ($knownStates.Count -gt 1) {
    throw "Multiple managed $profileFamily state files exist. No runtime was released."
}
$resolvedProfile = if ($knownStates.Count -eq 1) { [string]$knownStates[0].profile } else { $Profile }
$manifest = Get-TurboProfileManifest -Profile $resolvedProfile
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
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stopScript -Profile $resolvedProfile -AllowNotRunning
        if ($LASTEXITCODE -ne 0) { throw "Stale Turbo state cleanup failed with exit code $LASTEXITCODE." }
    }
    else {
        $allowLegacyQuickApiAlias = Test-TurboLegacyApiAlias -Manifest $manifest -Alias ([string]$state.api_model_alias)
        Assert-ManagedTurboProcess -State $state -Manifest $manifest -RequireListener -AllowLegacyApiAlias:$allowLegacyQuickApiAlias | Out-Null
        $allowLegacyQuickTextOnly = $manifest.profile_class -eq 'quick-response' -and
            $manifest.configuration.vision -eq $true -and
            $process.command_line.IndexOf('--no-mmproj', [StringComparison]::OrdinalIgnoreCase) -ge 0
        if ($allowLegacyQuickTextOnly) {
            Write-Host '[INFO] Releasing a verified legacy text-only Quick instance before the Vision profile takes effect.'
        }
        if ($allowLegacyQuickApiAlias) {
            Write-Host "[INFO] Releasing a verified legacy Quick API alias '$($state.api_model_alias)' before the Goose Vision compatibility alias takes effect."
        }
        Test-TurboApiState -Manifest $manifest -AllowLegacyQuickTextOnly:$allowLegacyQuickTextOnly -AllowLegacyApiAlias:$allowLegacyQuickApiAlias | Out-Null

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
    Write-Host '[INFO] Releasing the verified idle managed runtime...'
    $stopArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $stopScript, '-Profile', $resolvedProfile)
    if ($allowLegacyQuickApiAlias) { $stopArguments += '-AllowLegacyApiAlias' }
    & powershell.exe @stopArguments
    if ($LASTEXITCODE -ne 0) { throw "Managed runtime release failed with exit code $LASTEXITCODE." }
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

Write-Host "[OK] $profileFamily model runtime released; LM Studio is empty and managed port $($manifest.server.port) is free." -ForegroundColor Green
}
finally {
    Exit-TurboOperationLock -Lock $operationLock
}
