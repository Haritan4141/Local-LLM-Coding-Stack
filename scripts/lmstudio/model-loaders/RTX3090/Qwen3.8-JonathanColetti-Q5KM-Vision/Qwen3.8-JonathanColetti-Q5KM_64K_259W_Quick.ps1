[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runtimeRoot = 'C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo'
& (Join-Path $runtimeRoot 'Start-ManagedTurbo.ps1') -Profile BLUE-Quick
