[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$loaderRoot = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\RX9070XT\Qwen3.8-JonathanColetti-IQ4XS'
$core = Join-Path $loaderRoot 'Qwen3.8-JonathanColetti-IQ4XS_REMOTE.ps1'
$bat96 = Join-Path $loaderRoot 'Qwen3.8-JonathanColetti-IQ4XS_96K_REMOTE.bat'
$bat64 = Join-Path $loaderRoot 'Qwen3.8-JonathanColetti-IQ4XS_64K_REMOTE.bat'
$selector = Join-Path $loaderRoot 'Qwen3.8-JonathanColetti-IQ4XS_REMOTE-Profile-Selector.bat'
$profilePath = Join-Path $repoRoot 'configs\candidates\rx9070xt-jonathan-iq4xs-96k.json'
$failures = [Collections.Generic.List[string]]::new()

foreach ($path in @($core, $bat96, $bat64, $selector, $profilePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing RED path: $path") }
}

if ($failures.Count -eq 0) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($core, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { $failures.Add("RED PowerShell syntax error: $($errors[0].Message)") }

    $coreText = Get-Content -LiteralPath $core -Raw
    foreach ($pattern in @(
        "`$SshAlias = 'pc7600x'",
        "`$ExpectedHostname = 'DESKTOP-LMB720F'",
        "`$ExpectedIp = '192.168.0.103'",
        "`$ExpectedGpuName = 'AMD Radeon RX 9070 XT'",
        "`$ExpectedRuntimeName = 'llama.cpp-win-x86_64-amd-rocm-avx2'",
        "`$ExpectedQuantization = 'IQ4_XS'",
        "`$Identifier = 'qwen3.8-27b-uncensored-iq4xs-red'",
        "'--kv-k', 'q4_0'",
        "'--kv-v', 'q4_0'",
        "'--strict-vram-cap', 'on'",
        "'--priority', `$priorityArg",
        "'--disabled', `$disabledArg"
    )) {
        if (-not $coreText.Contains($pattern)) { $failures.Add("Missing RED loader contract: $pattern") }
    }
    if ($coreText -match '(?i)nvidia-smi|power.?limit') { $failures.Add('RED loader contains NVIDIA-specific logic.') }

    $bat96Text = Get-Content -LiteralPath $bat96 -Raw
    $bat64Text = Get-Content -LiteralPath $bat64 -Raw
    if ($bat96Text -notmatch '-Profile 96K') { $failures.Add('RED 96K BAT mapping is missing.') }
    if ($bat64Text -notmatch '-Profile 64K') { $failures.Add('RED 64K BAT mapping is missing.') }

    $profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
    if ($profile.status -ne 'Candidate' -or $profile.profile_id -ne 'candidate-rx9070xt-jonathan-iq4xs-96k' -or
        $profile.effective_settings.context_tokens -ne 98304 -or $profile.effective_settings.kv_cache.k -ne 'Q4_0' -or
        $profile.effective_settings.kv_cache.v -ne 'Q4_0' -or $profile.effective_settings.mtp.max_draft_tokens -ne 2) {
        $failures.Add('RED management profile does not preserve the Candidate 96K/Q4/MTP2 contract.')
    }
}

foreach ($helperName in @('Load-ManagedModel.mjs', 'Test-ManagedModel.mjs')) {
    $helperPath = Join-Path $repoRoot "scripts\lmstudio\$helperName"
    $helperText = Get-Content -LiteralPath $helperPath -Raw
    if ($helperText -notmatch '"base-url"' -or $helperText -notmatch 'new LMStudioClient\(baseUrl') {
        $failures.Add("Remote base URL support is missing from $helperName")
    }
    & node --check $helperPath 2>$null
    if ($LASTEXITCODE -ne 0) { $failures.Add("JavaScript syntax error: $helperName") }
}

if ($failures.Count -gt 0) {
    Write-Host "RX9070XT loader tests failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'RX9070XT loader tests passed: identity, ROCm/IQ4_XS, 96K/64K, Q4 KV, remote SDK, and no NVIDIA logic.' -ForegroundColor Green
