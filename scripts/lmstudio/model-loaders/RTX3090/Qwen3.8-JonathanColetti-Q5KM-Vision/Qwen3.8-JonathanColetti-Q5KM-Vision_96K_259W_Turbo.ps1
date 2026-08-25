[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$turboRoot = 'C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo'
& (Join-Path $turboRoot 'Start-ManagedTurbo.ps1') -Profile BLUE
