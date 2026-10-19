[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..'))
try {
    & (Join-Path $repoRoot 'scripts\standalone-turbo\Start-ManagedTurbo.ps1') -Profile BLUE-IQ4XS256K
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
