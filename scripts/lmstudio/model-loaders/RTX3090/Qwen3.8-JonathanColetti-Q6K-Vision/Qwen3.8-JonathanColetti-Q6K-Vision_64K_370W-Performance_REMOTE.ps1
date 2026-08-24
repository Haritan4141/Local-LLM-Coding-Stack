[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'Qwen3.8-JonathanColetti-Q6K-Vision_64K_REMOTE.ps1'
& $launcher -Rtx3090PowerLimit 370
