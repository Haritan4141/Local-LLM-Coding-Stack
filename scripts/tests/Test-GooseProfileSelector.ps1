[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$selector = Join-Path $repoRoot 'scripts\goose\Set-GooseProfile.ps1'
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryRoot ('goose-profile-selector-' + [guid]::NewGuid().ToString('N'))
$configPath = Join-Path $testRoot 'config.yaml'
$backupDirectory = Join-Path $testRoot 'backups'

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
    Remove-Item -LiteralPath $resolvedTestRoot -Force
}

try {
    $null = New-Item -ItemType Directory -Path $testRoot
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
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText(
        $configPath,
        $fixture,
        [System.Text.UTF8Encoding]::new($false)
    )

    & $selector -Profile Q5KM-Vision96K -ConfigPath $configPath -BackupDirectory $backupDirectory
    $q5Text = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 90112',
        'GOOSE_MAX_TOKENS: 16384',
        'GOOSE_AUTO_COMPACT_THRESHOLD: 0.3',
        '    model: qwen3.8-27b-uncensored-vision-q5km',
        '    model: qwen3.8-27b-uncensored-vision-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $q5Text -Expected $expected
    }

    & $selector -Profile Q6K-Vision64K -ConfigPath $configPath -BackupDirectory $backupDirectory
    $q6Text = [System.IO.File]::ReadAllText($configPath)
    foreach ($expected in @(
        'GOOSE_CONTEXT_LIMIT: 64512',
        'GOOSE_MAX_TOKENS: 32768',
        'GOOSE_AUTO_COMPACT_THRESHOLD: 0.3',
        '    model: qwen3.8-27b-uncensored-vision',
        '    model: qwen3.8-27b-uncensored-vision-blue',
        'SAFE_SENTINEL: keep-me'
    )) {
        Assert-Contains -Text $q6Text -Expected $expected
    }

    $backups = @(Get-ChildItem -LiteralPath $backupDirectory -File -Filter '*.yaml')
    if ($backups.Count -ne 2) {
        throw "Expected two config backups, found $($backups.Count)."
    }

    Write-Host 'Goose profile selector test passed: Q5KM 96K and Q6K 64K, backup and provider isolation verified.' -ForegroundColor Green
} finally {
    Remove-TestArtifacts
}
