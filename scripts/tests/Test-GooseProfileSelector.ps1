[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$selector = Join-Path $repoRoot 'scripts\goose\Set-GooseProfile.ps1'
$dailyOrchestrator = Join-Path $repoRoot 'scripts\goose\Start-GooseDailyProfile.ps1'
$dailySelector = Join-Path $repoRoot 'scripts\goose\Goose-Daily-Profile-Selector.bat'
$dailyEntry = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\00-Goose-Daily-Profiles.bat'
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryRoot ('goose-profile-selector-' + [guid]::NewGuid().ToString('N'))
$configPath = Join-Path $testRoot 'config.yaml'
$backupDirectory = Join-Path $testRoot 'backups'
$customProviderDirectory = Join-Path $testRoot 'custom_providers'
$customProviderPath = Join-Path $customProviderDirectory 'custom_lm_studio_3090_remote.json'

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Expected
    )

    if (-not $Text.Contains($Expected)) {
        throw "Expected fixture value was not found: $Expected"
    }
}

function Remove-TestArtifacts {
    if (-not (Test-Path -LiteralPath $testRoot)) {
        return
    }

    $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
    if (-not $resolvedTestRoot.StartsWith(
        $temporaryRoot,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to clean an unexpected test path: $resolvedTestRoot"
    }

    if (Test-Path -LiteralPath $backupDirectory -PathType Container) {
        Get-ChildItem -LiteralPath $backupDirectory -File | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
        }
        Remove-Item -LiteralPath $backupDirectory -Force
    }
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        Remove-Item -LiteralPath $configPath -Force
    }
    if (Test-Path -LiteralPath $customProviderDirectory -PathType Container) {
        Get-ChildItem -LiteralPath $customProviderDirectory -File | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
        }
        Remove-Item -LiteralPath $customProviderDirectory -Force
    }
    Remove-Item -LiteralPath $resolvedTestRoot -Force
}

try {
    foreach ($requiredPath in @($selector, $dailyOrchestrator, $dailySelector, $dailyEntry)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Missing Goose Daily Profile path: $requiredPath"
        }
    }

    foreach ($batchPath in @($dailySelector, $dailyEntry)) {
        & cmd.exe /d /c "call `"$batchPath`" 0"
        if ($LASTEXITCODE -ne 0) {
            throw "Goose Daily Profile Cancel regression failed: $batchPath"
        }
    }

    & cmd.exe /d /c "call `"$dailyEntry`" 11" *> $null
    if ($LASTEXITCODE -ne 2) {
        throw "Goose Daily invalid-selection regression expected exit 2, observed $LASTEXITCODE."
    }

    $dailyText = Get-Content -LiteralPath $dailySelector -Raw
    $expectedMenuMappings = [ordered]@{
        '1' = 'MAIN-Stable16K'
        '2' = 'MAIN-Stable32K'
        '3' = 'MAIN-Turbo16K'
        '9' = 'MAIN-Turbo32K'
        '4' = 'MAIN-Quality32K'
        '5' = 'BLUE-Stable16K'
        '6' = 'BLUE-Stable32K'
        '7' = 'BLUE-Turbo16K'
        '10' = 'BLUE-Turbo32K'
        '8' = 'BLUE-Quality32K'
    }
    foreach ($entry in $expectedMenuMappings.GetEnumerator()) {
        Assert-Contains -Text $dailyText -Expected "if `"%PROFILE_CHOICE%`"==`"$($entry.Key)`" set `"PROFILE_NAME=$($entry.Value)`""
    }
    foreach ($expected in @('Start-GooseDailyProfile.ps1', '[3] Turbo', '[9] Turbo', '[7] Turbo', '[10] Turbo', '[8] Quality Reference')) {
        Assert-Contains -Text $dailyText -Expected $expected
    }
    if ($dailyText -match '(?im)^\s*(lms|node|ssh|nvidia-smi)\b') {
        throw 'Goose Daily BAT contains direct runtime logic instead of thin orchestration.'
    }

    foreach ($powerShellPath in @($selector, $dailyOrchestrator)) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($powerShellPath, [ref]$tokens, [ref]$errors)
        if ($errors.Count -gt 0) { throw "PowerShell syntax error: $powerShellPath :: $($errors[0].Message)" }
    }
    $orchestratorText = Get-Content -LiteralPath $dailyOrchestrator -Raw
    foreach ($expected in @(
        "Get-Process -Name 'Goose'",
        'Invoke-CanonicalBatch',
        'Start-Goose-ManagedTurbo.ps1',
        '-MaxOutputTokens',
        'MAIN-Turbo32K',
        'BLUE-Turbo32K',
        'Test-ManagedTurbo.ps1',
        'Set-GooseProfile.ps1',
        '/api/v1/models',
        'Runtime/provider/model/context/output/endpoint cross-check passed',
        'configHashBefore',
        'Get-FileSha256',
        'BLUE-Q6K-Vision64K',
        '<nul'
    )) {
        Assert-Contains -Text $orchestratorText -Expected $expected
    }
    if ($orchestratorText.IndexOf("Get-Process -Name 'Goose'", [StringComparison]::OrdinalIgnoreCase) -gt
        $orchestratorText.IndexOf('Invoke-CanonicalBatch -Path $definition.Loader', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Goose already-running guard does not precede runtime switching.'
    }
    if ($orchestratorText -match '(?i)Stop-Process\s+-Name|taskkill|New-NetFirewallRule|Set-NetFirewallRule') {
        throw 'Goose Daily orchestrator contains a forbidden broad stop or Firewall operation.'
    }
    $turboCommon = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\standalone-turbo\Turbo.Common.psm1') -Raw
    Assert-Contains -Text $turboCommon -Expected 'function Get-TurboFileSha256'
    foreach ($turboScript in @(
        (Join-Path $repoRoot 'scripts\standalone-turbo\Start-ManagedTurbo.ps1'),
        (Join-Path $repoRoot 'scripts\standalone-turbo\Test-ManagedTurbo.ps1')
    )) {
        Assert-Contains -Text (Get-Content -LiteralPath $turboScript -Raw) -Expected 'Get-TurboFileSha256'
    }

    $null = New-Item -ItemType Directory -Path $testRoot
    $null = New-Item -ItemType Directory -Path $customProviderDirectory
    $fixture = @(
        'GOOSE_CONTEXT_LIMIT: 64512'
        'GOOSE_MAX_TOKENS: 32768'
        'GOOSE_AUTO_COMPACT_THRESHOLD: 0.3'
        'SAFE_SENTINEL: keep-me'
        'providers:'
        '  lmstudio:'
        '    name: LM Studio'
        '    host: http://127.0.0.1:1234/v1'
        '    model: qwen3.8-27b-uncensored-vision-q6k'
        '  lmstudio-remote:'
        '    name: BLUE'
        '    model: qwen3.8-27b-uncensored-vision-blue'
        '  custom_lm_studio_3090_remote:'
        '    name: LM Studio 3090 Remote'
        '    model: qwen3.8-27b-uncensored-vision-blue'
        'active_provider: custom_lm_studio_rx9070xt_remote'
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText(
        $configPath,
        $fixture,
        [System.Text.UTF8Encoding]::new($false)
    )
    $blueProviderFixture = [ordered]@{
        name = 'custom_lm_studio_3090_remote'
        engine = 'openai'
        display_name = 'LM Studio 3090 Remote'
        description = 'DESKTOP-L9HAM1G (192.168.0.104) LM Studio over the private LAN'
        api_key_env = ''
        base_url = 'http://192.168.0.104:1234/v1/chat/completions'
        requires_auth = $false
        models = @(
            [ordered]@{
                name = 'qwen3.8-27b-uncensored-vision-blue'
                context_limit = 64512
            }
        )
    }
    [System.IO.File]::WriteAllText(
        $customProviderPath,
        (($blueProviderFixture | ConvertTo-Json -Depth 5) + "`r`n"),
        [System.Text.UTF8Encoding]::new($false)
    )

    & $selector `
        -Profile Q5KM-Vision96K `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -CustomProviderDirectory $customProviderDirectory
    $q5Text = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 90112',
        'GOOSE_MAX_TOKENS: 16384',
        'GOOSE_AUTO_COMPACT_THRESHOLD: 0.3',
        'active_provider: lmstudio',
        '    model: qwen3.8-27b-uncensored-vision-q5km',
        '    model: qwen3.8-27b-uncensored-vision-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $q5Text -Expected $expected
    }

    & $selector `
        -Profile Q5KM-Vision96K-Output32K `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -CustomProviderDirectory $customProviderDirectory
    $q5LongText = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 90112',
        'GOOSE_MAX_TOKENS: 32768',
        'active_provider: lmstudio',
        '    model: qwen3.8-27b-uncensored-vision-q5km',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $q5LongText -Expected $expected
    }

    & $selector `
        -Profile Q6K-Vision64K `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -CustomProviderDirectory $customProviderDirectory
    $q6Text = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 64512',
        'GOOSE_MAX_TOKENS: 32768',
        'GOOSE_AUTO_COMPACT_THRESHOLD: 0.3',
        'active_provider: lmstudio',
        '    model: qwen3.8-27b-uncensored-vision',
        '    model: qwen3.8-27b-uncensored-vision-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $q6Text -Expected $expected
    }

    & $selector `
        -Profile BLUE-Q5KM-Vision96K-Output16K `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -CustomProviderDirectory $customProviderDirectory
    $blueStandardText = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 90112',
        'GOOSE_MAX_TOKENS: 16384',
        'active_provider: custom_lm_studio_3090_remote',
        '    model: qwen3.8-27b-uncensored-vision',
        '    model: qwen3.8-27b-uncensored-vision-q5km-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $blueStandardText -Expected $expected
    }

    $blueProvider = Get-Content -LiteralPath $customProviderPath -Raw | ConvertFrom-Json
    foreach ($expectedModel in @(
        @{ Name = 'qwen3.8-27b-uncensored-vision-q5km-blue'; Context = 90112 },
        @{ Name = 'qwen3.8-27b-uncensored-vision-blue'; Context = 64512 }
    )) {
        $matches = @($blueProvider.models | Where-Object {
            $_.name -eq $expectedModel.Name -and [int]$_.context_limit -eq $expectedModel.Context
        })
        if ($matches.Count -ne 1) {
            throw "Expected one BLUE custom-provider model entry: $($expectedModel.Name)"
        }
    }

    & $selector `
        -Profile BLUE-Q5KM-Vision96K-Output32K `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -CustomProviderDirectory $customProviderDirectory
    $blueLongText = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 90112',
        'GOOSE_MAX_TOKENS: 32768',
        'active_provider: custom_lm_studio_3090_remote',
        '    model: qwen3.8-27b-uncensored-vision-q5km-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $blueLongText -Expected $expected
    }

    & $selector `
        -Profile BLUE-Q6K-Vision64K `
        -ConfigPath $configPath `
        -BackupDirectory $backupDirectory `
        -CustomProviderDirectory $customProviderDirectory
    $blueQualityText = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 64512',
        'GOOSE_MAX_TOKENS: 32768',
        'active_provider: custom_lm_studio_3090_remote',
        '    model: qwen3.8-27b-uncensored-vision-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $blueQualityText -Expected $expected
    }

    $configBackups = @(Get-ChildItem -LiteralPath $backupDirectory -File -Filter '*.yaml')
    if ($configBackups.Count -ne 6) {
        throw "Expected six config backups, found $($configBackups.Count)."
    }
    $providerBackups = @(Get-ChildItem -LiteralPath $backupDirectory -File -Filter '*.json')
    if ($providerBackups.Count -ne 1) {
        throw "Expected one custom-provider backup, found $($providerBackups.Count)."
    }

    $beforeFailClosedText = [System.IO.File]::ReadAllText($configPath)
    $invalidProvider = Get-Content -LiteralPath $customProviderPath -Raw | ConvertFrom-Json
    $invalidProvider.base_url = 'http://192.168.0.250:1234/v1/chat/completions'
    [System.IO.File]::WriteAllText(
        $customProviderPath,
        (($invalidProvider | ConvertTo-Json -Depth 10) + "`r`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    $failedClosed = $false
    try {
        & $selector `
            -Profile BLUE-Q5KM-Vision96K-Output16K `
            -ConfigPath $configPath `
            -BackupDirectory $backupDirectory `
            -CustomProviderDirectory $customProviderDirectory
    } catch {
        $failedClosed = $true
    }
    if (-not $failedClosed) {
        throw 'Expected invalid BLUE custom-provider identity to fail closed.'
    }
    if ([System.IO.File]::ReadAllText($configPath) -ne $beforeFailClosedText) {
        throw 'Goose config changed during the invalid BLUE provider fail-closed test.'
    }

    Write-Host 'Goose Daily integration test passed: 10-option menu, Cancel/invalid, orchestration guards, MAIN/BLUE Stable/Turbo16K/Turbo32K/Quality mappings, backups and endpoint fail-closed behavior verified.' -ForegroundColor Green
} finally {
    Remove-TestArtifacts
}
