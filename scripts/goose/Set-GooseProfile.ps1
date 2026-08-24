[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Q5KM-Vision96K', 'Q6K-Vision64K')]
    [string]$Profile,

    [string]$ConfigPath = (Join-Path $env:APPDATA 'Block\goose\config\config.yaml'),

    [string]$BackupDirectory = (Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\goose-config-backups')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$profileDefinitions = @{
    'Q5KM-Vision96K' = [ordered]@{
        DisplayName = 'Jonathan Q5_K_M Vision 96K Candidate'
        Model = 'qwen3.8-27b-uncensored-vision-q5km'
        ContextLimit = '90112'
        MaxTokens = '16384'
        CompactThreshold = '0.3'
        BackupSlug = 'q5km-vision96k'
    }
    'Q6K-Vision64K' = [ordered]@{
        DisplayName = 'Jonathan Q6_K Vision 64K Operational Default'
        Model = 'qwen3.8-27b-uncensored-vision'
        ContextLimit = '64512'
        MaxTokens = '32768'
        CompactThreshold = '0.3'
        BackupSlug = 'q6k-vision64k'
    }
}

function Get-PreferredLineEnding {
    param([string]$Text)

    if ($Text.Contains("`r`n")) {
        return "`r`n"
    }
    return "`n"
}

function Set-TopLevelScalar {
    param(
        [string]$Text,
        [string]$Name,
        [string]$Value
    )

    $escapedName = [regex]::Escape($Name)
    $matches = [regex]::Matches($Text, "(?m)^${escapedName}:[^\r\n]*(?:\r)?$")
    if ($matches.Count -gt 1) {
        throw "Expected at most one top-level '$Name' setting, found $($matches.Count)."
    }

    if ($matches.Count -eq 0) {
        $lineEnding = Get-PreferredLineEnding -Text $Text
        return "${Name}: $Value$lineEnding$Text"
    }

    $match = $matches[0]
    $carriageReturn = if ($match.Value.EndsWith("`r")) { "`r" } else { '' }
    $replacement = "${Name}: $Value$carriageReturn"
    return $Text.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
}

function Get-TopLevelScalar {
    param(
        [string]$Text,
        [string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    $matches = [regex]::Matches(
        $Text,
        "(?m)^${escapedName}:[ \t]*(?<value>[^#\r\n]*?)[ \t]*(?:#[^\r\n]*)?(?:\r)?$"
    )
    if ($matches.Count -ne 1) {
        throw "Expected exactly one top-level '$Name' setting after update, found $($matches.Count)."
    }
    return $matches[0].Groups['value'].Value.Trim()
}

function Set-LmStudioModel {
    param(
        [string]$Text,
        [string]$Model
    )

    $providerMatches = [regex]::Matches(
        $Text,
        '(?ms)^  lmstudio:\r?\n(?<body>(?:    [^\r\n]*(?:\r?\n|$))*)'
    )
    if ($providerMatches.Count -ne 1) {
        throw "Expected exactly one Goose lmstudio provider block, found $($providerMatches.Count)."
    }

    $providerBody = $providerMatches[0].Groups['body']
    $modelMatches = [regex]::Matches(
        $providerBody.Value,
        '(?m)^(    model:[ \t]*)([^\r\n]+?)[ \t]*(\r?)$'
    )
    if ($modelMatches.Count -ne 1) {
        throw "Expected exactly one model setting in the Goose lmstudio provider block, found $($modelMatches.Count)."
    }

    $carriageReturn = $modelMatches[0].Groups[3].Value
    $replacement = "    model: $Model$carriageReturn"
    $modelIndex = $providerBody.Index + $modelMatches[0].Index
    return $Text.Remove($modelIndex, $modelMatches[0].Length).Insert($modelIndex, $replacement)
}

function Get-LmStudioModel {
    param([string]$Text)

    $providerMatches = [regex]::Matches(
        $Text,
        '(?ms)^  lmstudio:\r?\n(?<body>(?:    [^\r\n]*(?:\r?\n|$))*)'
    )
    if ($providerMatches.Count -ne 1) {
        throw "Expected exactly one Goose lmstudio provider block, found $($providerMatches.Count)."
    }

    $modelMatches = [regex]::Matches(
        $providerMatches[0].Groups['body'].Value,
        '(?m)^    model:[ \t]*(?<model>[^\r\n]+?)[ \t]*(?:\r)?$'
    )
    if ($modelMatches.Count -ne 1) {
        throw "Expected exactly one model setting in the Goose lmstudio provider block, found $($modelMatches.Count)."
    }
    return $modelMatches[0].Groups['model'].Value.Trim()
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Goose config was not found: $ConfigPath"
}

$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$defaultConfigPath = [System.IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Block\goose\config\config.yaml'))
$isLiveConfig = $resolvedConfigPath.Equals($defaultConfigPath, [System.StringComparison]::OrdinalIgnoreCase)

if ($isLiveConfig) {
    $runningGoose = @(Get-Process -Name 'Goose' -ErrorAction SilentlyContinue)
    if ($runningGoose.Count -gt 0) {
        throw 'Goose Desktop is running. Close it completely before changing the persistent Goose profile.'
    }
}

$definition = $profileDefinitions[$Profile]
$originalBytes = [System.IO.File]::ReadAllBytes($resolvedConfigPath)
$hasUtf8Bom =
    $originalBytes.Length -ge 3 -and
    $originalBytes[0] -eq 0xEF -and
    $originalBytes[1] -eq 0xBB -and
    $originalBytes[2] -eq 0xBF
$encoding = [System.Text.UTF8Encoding]::new($hasUtf8Bom)
$originalText = [System.IO.File]::ReadAllText($resolvedConfigPath)

$updatedText = Set-TopLevelScalar -Text $originalText -Name 'GOOSE_CONTEXT_LIMIT' -Value $definition.ContextLimit
$updatedText = Set-TopLevelScalar -Text $updatedText -Name 'GOOSE_MAX_TOKENS' -Value $definition.MaxTokens
$updatedText = Set-TopLevelScalar -Text $updatedText -Name 'GOOSE_AUTO_COMPACT_THRESHOLD' -Value $definition.CompactThreshold
$updatedText = Set-LmStudioModel -Text $updatedText -Model $definition.Model

if ($updatedText -eq $originalText) {
    Write-Host "[OK] Goose profile is already selected: $($definition.DisplayName)" -ForegroundColor Green
    Write-Host "[OK] Model: $($definition.Model)" -ForegroundColor Green
    Write-Host "[OK] Client context: $($definition.ContextLimit); max output: $($definition.MaxTokens); compact threshold: $($definition.CompactThreshold)" -ForegroundColor Green
    exit 0
}

$null = New-Item -ItemType Directory -Path $BackupDirectory -Force
$backupPath = Join-Path $BackupDirectory (
    'config-{0}-before-{1}.yaml' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), $definition.BackupSlug
)
Copy-Item -LiteralPath $resolvedConfigPath -Destination $backupPath

try {
    [System.IO.File]::WriteAllText($resolvedConfigPath, $updatedText, $encoding)

    $verifiedText = [System.IO.File]::ReadAllText($resolvedConfigPath)
    $verifiedModel = Get-LmStudioModel -Text $verifiedText
    $verifiedContext = Get-TopLevelScalar -Text $verifiedText -Name 'GOOSE_CONTEXT_LIMIT'
    $verifiedMaxTokens = Get-TopLevelScalar -Text $verifiedText -Name 'GOOSE_MAX_TOKENS'
    $verifiedThreshold = Get-TopLevelScalar -Text $verifiedText -Name 'GOOSE_AUTO_COMPACT_THRESHOLD'

    $verified =
        $verifiedModel -eq $definition.Model -and
        $verifiedContext -eq $definition.ContextLimit -and
        $verifiedMaxTokens -eq $definition.MaxTokens -and
        $verifiedThreshold -eq $definition.CompactThreshold
    if (-not $verified) {
        throw 'The Goose profile verification did not match the requested values.'
    }
} catch {
    Copy-Item -LiteralPath $backupPath -Destination $resolvedConfigPath -Force
    throw "Goose profile update failed and the previous config was restored. $($_.Exception.Message)"
}

Write-Host "[OK] Goose profile selected: $($definition.DisplayName)" -ForegroundColor Green
Write-Host "[OK] Model: $($definition.Model)" -ForegroundColor Green
Write-Host "[OK] Client context: $($definition.ContextLimit); max output: $($definition.MaxTokens); compact threshold: $($definition.CompactThreshold)" -ForegroundColor Green
Write-Host "[OK] Backup: $backupPath" -ForegroundColor Green
Write-Host '[NEXT] Load the matching LM Studio preset, then start Goose normally and open a new chat.' -ForegroundColor Cyan
