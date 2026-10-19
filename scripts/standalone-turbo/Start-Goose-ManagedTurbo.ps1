[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick', 'BLUE-IQ4XS256K', 'RTX5090-IQ4XS256K')][string]$Profile,
    [ValidateSet(8192, 16384, 32768)][int]$MaxOutputTokens = 16384,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
if ($null -ne $manifest.PSObject.Properties['goose'] -and
    $MaxOutputTokens -ne [int]$manifest.goose.max_output_tokens) {
    throw "Profile $Profile requires Goose max output $($manifest.goose.max_output_tokens); no runtime state changed."
}
if (@(Get-Process -Name 'Goose' -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'Goose is already running. Close it completely before changing any runtime.'
}
$isBlue = $Profile.StartsWith('BLUE', [StringComparison]::OrdinalIgnoreCase)
if (-not $isBlue) {
    & (Join-Path $PSScriptRoot 'Start-ManagedTurbo.ps1') -Profile $Profile | Out-Null
    $baseUrl = 'http://127.0.0.1:18080'
    & (Join-Path $PSScriptRoot 'Test-ManagedTurbo.ps1') -Profile $Profile -Mode Local -BaseUrl $baseUrl | Out-Null
}
else {
    & (Join-Path $PSScriptRoot 'Start-BlueManagedTurboRemote.ps1') -Profile $Profile | Out-Null
    $baseUrl = 'http://127.0.0.1:18081'
    & (Join-Path $PSScriptRoot 'Test-ManagedTurbo.ps1') -Profile $Profile -Mode Tunnel -BaseUrl $baseUrl | Out-Null
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
        $gooseDesktop = [pscustomobject]@{ path = $shortcut.TargetPath; working_directory = $shortcut.WorkingDirectory; arguments = $shortcut.Arguments }
    }
}
if ($null -eq $gooseDesktop) {
    $fallback = Join-Path $env:USERPROFILE 'Applications\goose\v1.47.0\dist-windows\Goose.exe'
    if (-not (Test-Path -LiteralPath $fallback -PathType Leaf)) { throw 'Goose Desktop could not be resolved.' }
    $gooseDesktop = [pscustomobject]@{ path = $fallback; working_directory = Split-Path -Parent $fallback; arguments = '' }
}

$clientContext = 90112
if ($null -ne $manifest.PSObject.Properties['goose']) {
    $clientContext = [int]$manifest.goose.client_context_tokens
    if ($MaxOutputTokens -ne [int]$manifest.goose.max_output_tokens) {
        throw "Profile $Profile requires Goose max output $($manifest.goose.max_output_tokens)."
    }
}

$overrides = [ordered]@{
    GOOSE_PROVIDER = 'openai'
    GOOSE_MODEL = [string]$manifest.server.api_model_alias
    GOOSE_CONTEXT_LIMIT = [string]$clientContext
    GOOSE_MAX_TOKENS = [string]$MaxOutputTokens
    GOOSE_AUTO_COMPACT_THRESHOLD = '0.3'
    GOOSE_TEMPERATURE = '0'
    OPENAI_HOST = $baseUrl
    OPENAI_BASE_PATH = '/v1/chat/completions'
    OPENAI_API_KEY = 'managed-turbo-local-only'
}
# Keep the existing default for manifests without Goose overrides. The
# canonical manifest owns profile-specific rates; never persist this to Global.
if ($null -ne $manifest.PSObject.Properties['goose']) {
    $overrides['GOOSE_AUTO_COMPACT_THRESHOLD'] = ([double]$manifest.goose.auto_compact_threshold).ToString([Globalization.CultureInfo]::InvariantCulture)
}
# Shell guard PATH compatibility: also protect direct/fallback shortcut targets.
$gooseGuardHooks = Join-Path $env:USERPROFILE '.agents\plugins\goose-shell-repetition-guard\hooks\hooks.json'
if (Test-Path -LiteralPath $gooseGuardHooks -PathType Leaf) {
    $gooseGuardShellDirectory = 'C:\Program Files\Git\usr\bin'
    if (-not (Test-Path -LiteralPath (Join-Path $gooseGuardShellDirectory 'sh.exe') -PathType Leaf)) {
        throw 'Shell guard requires existing Git sh.exe; Goose was not launched.'
    }
    $overrides['PATH'] = "$gooseGuardShellDirectory;$env:PATH"
}
# End shell guard PATH compatibility.
$saved = @{}
foreach ($name in $overrides.Keys) {
    $item = Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    $saved[$name] = if ($null -eq $item) { [pscustomobject]@{ exists = $false; value = $null } } else { [pscustomobject]@{ exists = $true; value = $item.Value } }
    Set-Item -LiteralPath "Env:$name" -Value $overrides[$name]
}
try {
    $launch = @{ FilePath = $gooseDesktop.path; WorkingDirectory = $gooseDesktop.working_directory }
    if (-not [string]::IsNullOrWhiteSpace($gooseDesktop.arguments)) {
        $launch.ArgumentList = $gooseDesktop.arguments
        if ([IO.Path]::GetFileName($gooseDesktop.path) -ieq 'powershell.exe') { $launch.WindowStyle = 'Hidden' }
    }
    Start-Process @launch
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
Write-Host "[OK] Process-only limits: context $clientContext, max output $MaxOutputTokens, compact threshold $($overrides['GOOSE_AUTO_COMPACT_THRESHOLD'])." -ForegroundColor Green
if ($manifest.profile_class -eq 'quick-response') {
    Write-Host "[INFO] Goose local model alias: $($manifest.server.api_model_alias)."
    Write-Host '[INFO] The trailing gpt-4o token supplies Goose v1.49 Vision capability metadata only; served weights are JonathanColetti Qwen3.8 Q5_K_M Vision.'
}
if ($manifest.profile_class -eq 'extended-context') {
    Write-Host "[CANDIDATE] $($manifest.target_host.computer_name) IQ4_XS Vision256K; Goose input budget232K + output16K + reserve8K. Reasoning OFF; user-approved compact threshold0.6 trial."
    Write-Host '[INFO] Trailing gpt-4o supplies existing Goose Vision metadata only; model and API remain local.'
}
Write-Host '[INFO] Persistent Goose configuration was not changed.'
