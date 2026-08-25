[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..'))
& (Join-Path $repoRoot 'scripts\standalone-turbo\Start-BlueManagedTurboRemote.ps1')
