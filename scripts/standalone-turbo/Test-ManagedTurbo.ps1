[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile,
    [ValidateSet('Local', 'Tunnel')][string]$Mode = 'Local',
    [string]$BaseUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $port = if ($Mode -eq 'Tunnel') { [int]$manifest.server.main_tunnel_port } else { [int]$manifest.server.port }
    $BaseUrl = "http://127.0.0.1:$port"
}

if ($Mode -eq 'Local') {
    Assert-TurboHostAndGpu -Manifest $manifest | Out-Null
    $runtime = Get-TurboRuntimeInfo -Manifest $manifest
    $storage = Get-TurboStorage -Manifest $manifest
    if (-not (Test-Path -LiteralPath $storage.active_state -PathType Leaf)) { throw 'Managed Turbo state is absent.' }
    $state = Get-Content -LiteralPath $storage.active_state -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.ready -ne $true) { throw 'Managed Turbo state is not ready.' }
    if ((Get-FileHash -LiteralPath $runtime.executable -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.runtime.executable_expected_sha256) {
        throw 'Managed runtime executable SHA changed after startup.'
    }
    Assert-ManagedTurboProcess -State $state -Manifest $manifest -RequireListener | Out-Null
    Assert-TurboVramLoaded -Manifest $manifest | Out-Null
    if (@(Get-TurboLmsModels).Count -ne 0) { throw 'LM Studio has a loaded model while managed Turbo is active.' }
}

$api = Test-TurboApiState -Manifest $manifest -BaseUrl $BaseUrl
Write-Host "[OK] Managed Turbo preflight passed at $BaseUrl." -ForegroundColor Green
Write-Host '[OK] Alias/context/parallel/Vision and pinned process state match.' -ForegroundColor Green
$api
