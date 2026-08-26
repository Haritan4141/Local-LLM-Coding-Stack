[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile,
    [ValidateSet(16384, 32768)][int]$MaxOutputTokens = 16384,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
if ($Profile -eq 'RTX5090') {
    & (Join-Path $PSScriptRoot 'Start-ManagedTurbo.ps1') -Profile RTX5090 | Out-Null
    $baseUrl = 'http://127.0.0.1:18080'
    & (Join-Path $PSScriptRoot 'Test-ManagedTurbo.ps1') -Profile RTX5090 -Mode Local -BaseUrl $baseUrl | Out-Null
}
else {
    & (Join-Path $PSScriptRoot 'Start-BlueManagedTurboRemote.ps1') | Out-Null
    $baseUrl = 'http://127.0.0.1:18081'
    & (Join-Path $PSScriptRoot 'Test-ManagedTurbo.ps1') -Profile BLUE -Mode Tunnel -BaseUrl $baseUrl | Out-Null
}

if ($NoLaunch) {
    Write-Host "[OK] Goose Turbo preflight passed for $Profile; launch skipped." -ForegroundColor Green
    exit 0
}
if (@(Get-Process -Name 'Goose' -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'Goose is already running. Close it completely before launching a process-local Turbo profile.'
}

$shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Goose.lnk'
$gooseDesktop = $null
if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ($shortcut.TargetPath -and (Test-Path -LiteralPath $shortcut.TargetPath -PathType Leaf)) {
        $gooseDesktop = [pscustomobject]@{ path = $shortcut.TargetPath; working_directory = $shortcut.WorkingDirectory }
    }
}
if ($null -eq $gooseDesktop) {
    $fallback = Join-Path $env:USERPROFILE 'Applications\goose\v1.47.0\dist-windows\Goose.exe'
    if (-not (Test-Path -LiteralPath $fallback -PathType Leaf)) { throw 'Goose Desktop could not be resolved.' }
    $gooseDesktop = [pscustomobject]@{ path = $fallback; working_directory = Split-Path -Parent $fallback }
}

$overrides = [ordered]@{
    GOOSE_PROVIDER = 'openai'
    GOOSE_MODEL = [string]$manifest.server.api_model_alias
    GOOSE_CONTEXT_LIMIT = '90112'
    GOOSE_MAX_TOKENS = [string]$MaxOutputTokens
    GOOSE_AUTO_COMPACT_THRESHOLD = '0.3'
    GOOSE_TEMPERATURE = '0'
    OPENAI_HOST = $baseUrl
    OPENAI_BASE_PATH = '/v1/chat/completions'
    OPENAI_API_KEY = 'managed-turbo-local-only'
}
$saved = @{}
foreach ($name in $overrides.Keys) {
    $item = Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    $saved[$name] = if ($null -eq $item) { [pscustomobject]@{ exists = $false; value = $null } } else { [pscustomobject]@{ exists = $true; value = $item.Value } }
    Set-Item -LiteralPath "Env:$name" -Value $overrides[$name]
}
try {
    Start-Process -FilePath $gooseDesktop.path -WorkingDirectory $gooseDesktop.working_directory
}
finally {
    foreach ($name in $overrides.Keys) {
        if ($saved[$name].exists) { Set-Item -LiteralPath "Env:$name" -Value $saved[$name].value }
        else { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
    }
}

Start-Sleep -Seconds 2
if (@(Get-Process -Name 'Goose' -ErrorAction SilentlyContinue).Count -eq 0) { throw 'Goose Desktop did not remain running.' }
Write-Host "[OK] Goose started through built-in openai provider at $baseUrl." -ForegroundColor Green
Write-Host "[OK] Process-only limits: context 90112, max output $MaxOutputTokens, compact threshold 0.3." -ForegroundColor Green
Write-Host '[INFO] Persistent Goose configuration was not changed.'
