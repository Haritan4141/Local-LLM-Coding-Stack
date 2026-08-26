[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'Q5KM-Vision96K',
        'Q5KM-Vision96K-Output16K',
        'Q5KM-Vision96K-Output32K',
        'Q6K-Vision64K',
        'BLUE-Q5KM-Vision96K-Output16K',
        'BLUE-Q5KM-Vision96K-Output32K',
        'BLUE-Q6K-Vision64K'
    )]
    [string]$Profile,

    [string]$ConfigPath = (Join-Path $env:APPDATA 'Block\goose\config\config.yaml'),

    [string]$BackupDirectory = (Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\goose-config-backups'),

    [string]$CustomProviderDirectory = (Join-Path $env:APPDATA 'Block\goose\config\custom_providers'),

    [switch]$SuppressNextMessage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$profileDefinitions = @{
    'Q5KM-Vision96K' = [ordered]@{
        DisplayName = 'MAIN Jonathan Q5_K_M Vision 96K / Output 16K'
        Provider = 'lmstudio'
        Model = 'qwen3.8-27b-uncensored-vision-q5km'
        ContextLimit = '90112'
        MaxTokens = '16384'
        CompactThreshold = '0.3'
        BackupSlug = 'main-q5km-vision96k-output16k'
        CustomProviderFile = $null
    }
    'Q5KM-Vision96K-Output16K' = [ordered]@{
        DisplayName = 'MAIN Jonathan Q5_K_M Vision 96K / Output 16K'
        Provider = 'lmstudio'
        Model = 'qwen3.8-27b-uncensored-vision-q5km'
        ContextLimit = '90112'
        MaxTokens = '16384'
        CompactThreshold = '0.3'
        BackupSlug = 'main-q5km-vision96k-output16k'
        CustomProviderFile = $null
    }
    'Q5KM-Vision96K-Output32K' = [ordered]@{
        DisplayName = 'MAIN Jonathan Q5_K_M Vision 96K / Output 32K'
        Provider = 'lmstudio'
        Model = 'qwen3.8-27b-uncensored-vision-q5km'
        ContextLimit = '90112'
        MaxTokens = '32768'
        CompactThreshold = '0.3'
        BackupSlug = 'main-q5km-vision96k-output32k'
        CustomProviderFile = $null
    }
    'Q6K-Vision64K' = [ordered]@{
        DisplayName = 'MAIN Jonathan Q6_K Vision 64K / Output 32K'
        Provider = 'lmstudio'
        Model = 'qwen3.8-27b-uncensored-vision'
        ContextLimit = '64512'
        MaxTokens = '32768'
        CompactThreshold = '0.3'
        BackupSlug = 'main-q6k-vision64k-output32k'
        CustomProviderFile = $null
    }
    'BLUE-Q5KM-Vision96K-Output16K' = [ordered]@{
        DisplayName = 'BLUE Jonathan Q5_K_M Vision 96K / Output 16K'
        Provider = 'custom_lm_studio_3090_remote'
        Model = 'qwen3.8-27b-uncensored-vision-q5km-blue'
        ContextLimit = '90112'
        MaxTokens = '16384'
        CompactThreshold = '0.3'
        BackupSlug = 'blue-q5km-vision96k-output16k'
        CustomProviderFile = 'custom_lm_studio_3090_remote.json'
    }
    'BLUE-Q5KM-Vision96K-Output32K' = [ordered]@{
        DisplayName = 'BLUE Jonathan Q5_K_M Vision 96K / Output 32K'
        Provider = 'custom_lm_studio_3090_remote'
        Model = 'qwen3.8-27b-uncensored-vision-q5km-blue'
        ContextLimit = '90112'
        MaxTokens = '32768'
        CompactThreshold = '0.3'
        BackupSlug = 'blue-q5km-vision96k-output32k'
        CustomProviderFile = 'custom_lm_studio_3090_remote.json'
    }
    'BLUE-Q6K-Vision64K' = [ordered]@{
        DisplayName = 'BLUE Jonathan Q6_K Vision 64K / Output 32K'
        Provider = 'custom_lm_studio_3090_remote'
        Model = 'qwen3.8-27b-uncensored-vision-blue'
        ContextLimit = '64512'
        MaxTokens = '32768'
        CompactThreshold = '0.3'
        BackupSlug = 'blue-q6k-vision64k-output32k'
        CustomProviderFile = 'custom_lm_studio_3090_remote.json'
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

function Set-ProviderModel {
    param(
        [string]$Text,
        [string]$Provider,
        [string]$Model
    )

    $escapedProvider = [regex]::Escape($Provider)
    $providerMatches = [regex]::Matches(
        $Text,
        "(?ms)^  ${escapedProvider}:\r?\n(?<body>(?:    [^\r\n]*(?:\r?\n|$))*)"
    )
    if ($providerMatches.Count -ne 1) {
        throw "Expected exactly one Goose '$Provider' provider block, found $($providerMatches.Count)."
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

function Get-ProviderModel {
    param(
        [string]$Text,
        [string]$Provider
    )

    $escapedProvider = [regex]::Escape($Provider)
    $providerMatches = [regex]::Matches(
        $Text,
        "(?ms)^  ${escapedProvider}:\r?\n(?<body>(?:    [^\r\n]*(?:\r?\n|$))*)"
    )
    if ($providerMatches.Count -ne 1) {
        throw "Expected exactly one Goose '$Provider' provider block, found $($providerMatches.Count)."
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

function Get-UpdatedBlueProvider {
    param([string]$ProviderPath)

    if (-not (Test-Path -LiteralPath $ProviderPath -PathType Leaf)) {
        throw "Goose BLUE custom provider was not found: $ProviderPath"
    }

    $providerText = [System.IO.File]::ReadAllText($ProviderPath)
    try {
        $provider = $providerText | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Goose BLUE custom provider is invalid JSON: $ProviderPath :: $($_.Exception.Message)"
    }

    if (
        $provider.name -ne 'custom_lm_studio_3090_remote' -or
        $provider.engine -ne 'openai' -or
        $provider.base_url -ne 'http://192.168.0.104:1234/v1/chat/completions' -or
        $provider.requires_auth -ne $false
    ) {
        throw 'Goose BLUE custom provider identity or LAN endpoint did not match the managed definition.'
    }

    $requiredModels = [ordered]@{
        'qwen3.8-27b-uncensored-vision-q5km-blue' = 90112
        'qwen3.8-27b-uncensored-vision-blue' = 64512
    }
    $models = [System.Collections.Generic.List[object]]::new()
    foreach ($model in @($provider.models)) {
        $models.Add($model)
    }

    $changed = $false
    foreach ($entry in $requiredModels.GetEnumerator()) {
        $matches = @($models | Where-Object { $_.name -eq $entry.Key })
        if ($matches.Count -gt 1) {
            throw "Goose BLUE custom provider has duplicate model entries: $($entry.Key)"
        }
        if ($matches.Count -eq 0) {
            $models.Add([pscustomobject][ordered]@{
                name = $entry.Key
                context_limit = $entry.Value
            })
            $changed = $true
            continue
        }
        if ([int]$matches[0].context_limit -ne $entry.Value) {
            $matches[0].context_limit = $entry.Value
            $changed = $true
        }
    }

    if (-not $changed) {
        return [pscustomobject]@{
            Changed = $false
            Text = $providerText
        }
    }

    $provider.models = @($models)
    return [pscustomobject]@{
        Changed = $true
        Text = (($provider | ConvertTo-Json -Depth 10) + "`r`n")
    }
}

function Test-BlueProvider {
    param([string]$ProviderPath)

    $provider = Get-Content -LiteralPath $ProviderPath -Raw | ConvertFrom-Json -ErrorAction Stop
    if (
        $provider.name -ne 'custom_lm_studio_3090_remote' -or
        $provider.engine -ne 'openai' -or
        $provider.base_url -ne 'http://192.168.0.104:1234/v1/chat/completions' -or
        $provider.requires_auth -ne $false
    ) {
        return $false
    }

    $expected = [ordered]@{
        'qwen3.8-27b-uncensored-vision-q5km-blue' = 90112
        'qwen3.8-27b-uncensored-vision-blue' = 64512
    }
    foreach ($entry in $expected.GetEnumerator()) {
        $matches = @($provider.models | Where-Object {
            $_.name -eq $entry.Key -and [int]$_.context_limit -eq $entry.Value
        })
        if ($matches.Count -ne 1) {
            return $false
        }
    }
    return $true
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
$updatedText = Set-TopLevelScalar -Text $updatedText -Name 'active_provider' -Value $definition.Provider
$updatedText = Set-ProviderModel -Text $updatedText -Provider $definition.Provider -Model $definition.Model

$providerPath = $null
$providerUpdate = $null
$providerEncoding = $null
if ($null -ne $definition.CustomProviderFile) {
    $providerPath = Join-Path $CustomProviderDirectory $definition.CustomProviderFile
    $providerUpdate = Get-UpdatedBlueProvider -ProviderPath $providerPath
    $providerBytes = [System.IO.File]::ReadAllBytes($providerPath)
    $providerHasUtf8Bom =
        $providerBytes.Length -ge 3 -and
        $providerBytes[0] -eq 0xEF -and
        $providerBytes[1] -eq 0xBB -and
        $providerBytes[2] -eq 0xBF
    $providerEncoding = [System.Text.UTF8Encoding]::new($providerHasUtf8Bom)
}

$configChanged = $updatedText -ne $originalText
$providerChanged = $null -ne $providerUpdate -and $providerUpdate.Changed

if (-not $configChanged -and -not $providerChanged) {
    Write-Host "[OK] Goose profile is already selected: $($definition.DisplayName)" -ForegroundColor Green
    Write-Host "[OK] Provider: $($definition.Provider)" -ForegroundColor Green
    Write-Host "[OK] Model: $($definition.Model)" -ForegroundColor Green
    Write-Host "[OK] Client context: $($definition.ContextLimit); max output: $($definition.MaxTokens); compact threshold: $($definition.CompactThreshold)" -ForegroundColor Green
    exit 0
}

$null = New-Item -ItemType Directory -Path $BackupDirectory -Force
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$configBackupPath = $null
$providerBackupPath = $null
if ($configChanged) {
    $configBackupPath = Join-Path $BackupDirectory (
        'config-{0}-before-{1}.yaml' -f $timestamp, $definition.BackupSlug
    )
    Copy-Item -LiteralPath $resolvedConfigPath -Destination $configBackupPath
}
if ($providerChanged) {
    $providerBackupPath = Join-Path $BackupDirectory (
        'custom-provider-{0}-before-{1}.json' -f $timestamp, $definition.BackupSlug
    )
    Copy-Item -LiteralPath $providerPath -Destination $providerBackupPath
}

try {
    if ($providerChanged) {
        [System.IO.File]::WriteAllText($providerPath, $providerUpdate.Text, $providerEncoding)
    }
    if ($configChanged) {
        [System.IO.File]::WriteAllText($resolvedConfigPath, $updatedText, $encoding)
    }

    $verifiedText = [System.IO.File]::ReadAllText($resolvedConfigPath)
    $verifiedProvider = Get-TopLevelScalar -Text $verifiedText -Name 'active_provider'
    $verifiedModel = Get-ProviderModel -Text $verifiedText -Provider $definition.Provider
    $verifiedContext = Get-TopLevelScalar -Text $verifiedText -Name 'GOOSE_CONTEXT_LIMIT'
    $verifiedMaxTokens = Get-TopLevelScalar -Text $verifiedText -Name 'GOOSE_MAX_TOKENS'
    $verifiedThreshold = Get-TopLevelScalar -Text $verifiedText -Name 'GOOSE_AUTO_COMPACT_THRESHOLD'

    $verified =
        $verifiedProvider -eq $definition.Provider -and
        $verifiedModel -eq $definition.Model -and
        $verifiedContext -eq $definition.ContextLimit -and
        $verifiedMaxTokens -eq $definition.MaxTokens -and
        $verifiedThreshold -eq $definition.CompactThreshold
    if ($null -ne $providerPath) {
        $verified = $verified -and (Test-BlueProvider -ProviderPath $providerPath)
    }
    if (-not $verified) {
        throw 'The Goose profile verification did not match the requested values.'
    }
} catch {
    if ($null -ne $configBackupPath) {
        Copy-Item -LiteralPath $configBackupPath -Destination $resolvedConfigPath -Force
    }
    if ($null -ne $providerBackupPath) {
        Copy-Item -LiteralPath $providerBackupPath -Destination $providerPath -Force
    }
    throw "Goose profile update failed and the previous config was restored. $($_.Exception.Message)"
}

Write-Host "[OK] Goose profile selected: $($definition.DisplayName)" -ForegroundColor Green
Write-Host "[OK] Provider: $($definition.Provider)" -ForegroundColor Green
Write-Host "[OK] Model: $($definition.Model)" -ForegroundColor Green
Write-Host "[OK] Client context: $($definition.ContextLimit); max output: $($definition.MaxTokens); compact threshold: $($definition.CompactThreshold)" -ForegroundColor Green
if ($null -ne $configBackupPath) {
    Write-Host "[OK] Config backup: $configBackupPath" -ForegroundColor Green
}
if ($null -ne $providerBackupPath) {
    Write-Host "[OK] Provider backup: $providerBackupPath" -ForegroundColor Green
}
if (-not $SuppressNextMessage) {
    Write-Host '[NEXT] Load the matching LM Studio preset, then start Goose normally and open a new chat.' -ForegroundColor Cyan
}
