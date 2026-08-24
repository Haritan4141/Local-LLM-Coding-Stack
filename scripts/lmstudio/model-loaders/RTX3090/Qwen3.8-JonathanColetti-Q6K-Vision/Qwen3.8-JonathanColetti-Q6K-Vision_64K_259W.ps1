[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$loader = Join-Path $PSScriptRoot 'Qwen3.8-JonathanColetti-Q6K-Vision_64K.ps1'
& $loader -Rtx3090PowerLimit 259
