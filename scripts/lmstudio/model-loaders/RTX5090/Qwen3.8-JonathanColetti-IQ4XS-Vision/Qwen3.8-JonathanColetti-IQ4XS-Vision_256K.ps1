[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$turbo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\standalone-turbo'))
Import-Module (Join-Path $turbo 'Turbo.Common.psm1') -Force
$candidate = Get-TurboProfileManifest -Profile 'RTX5090-IQ4XS256K'
$storage = Get-TurboStorage -Manifest $candidate
# Preserve an already selected Candidate/cache; Start still verifies exact
# ownership/API/memory and never kills an existing runtime on reuse failure.
if (-not (Test-Path -LiteralPath $storage.active_state -PathType Leaf)) {
    & (Join-Path $turbo 'Release-ManagedRuntime.ps1') -Profile 'RTX5090-IQ4XS256K'
}
& (Join-Path $turbo 'Start-ManagedTurbo.ps1') -Profile 'RTX5090-IQ4XS256K'
