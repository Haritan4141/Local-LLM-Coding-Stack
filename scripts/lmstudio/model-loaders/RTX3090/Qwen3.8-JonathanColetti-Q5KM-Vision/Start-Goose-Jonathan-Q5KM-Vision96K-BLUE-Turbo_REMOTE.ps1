[CmdletBinding()]
param([switch]$NoLaunch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..'))
& (Join-Path $repoRoot 'scripts\standalone-turbo\Start-Goose-ManagedTurbo.ps1') -Profile BLUE -NoLaunch:$NoLaunch
