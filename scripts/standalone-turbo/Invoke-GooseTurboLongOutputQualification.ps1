[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile,
    [Parameter(Mandatory)][string]$BaseUrl,
    [ValidateRange(16385, 32768)][int]$MinimumOutputTokens = 17000,
    [ValidateSet(32768)][int]$MaxOutputTokens = 32768,
    [ValidateRange(2500, 5000)][int]$FinalSequenceNumber = 3500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

function Get-QualificationSlots {
    param([Parameter(Mandatory)][string]$Endpoint)

    $response = Invoke-RestMethod -Uri ($Endpoint.TrimEnd('/') + '/slots') -TimeoutSec 10
    return @($response | ForEach-Object { $_ })
}

$manifest = Get-TurboProfileManifest -Profile $Profile
$mode = if ($Profile -eq 'BLUE') { 'Tunnel' } else { 'Local' }
& (Join-Path $PSScriptRoot 'Test-ManagedTurbo.ps1') -Profile $Profile -Mode $mode -BaseUrl $BaseUrl | Out-Null
if (@(Get-Process -Name 'Goose' -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'Goose is already running. Close it before the isolated Output32K qualification.'
}
$startingSlots = @(Get-QualificationSlots -Endpoint $BaseUrl)
if ($startingSlots.Count -ne 1 -or @($startingSlots | Where-Object { $_.is_processing -eq $true }).Count -gt 0) {
    throw 'Turbo did not expose exactly one idle slot before qualification.'
}
$persistentConfig = Join-Path $env:APPDATA 'Block\goose\config\config.yaml'
$configHashBefore = if (Test-Path -LiteralPath $persistentConfig -PathType Leaf) { Get-TurboFileSha256 -Path $persistentConfig } else { $null }

$gooseOnPath = Get-Command goose.exe -ErrorAction SilentlyContinue
$gooseCandidates = @(
    (Join-Path $env:USERPROFILE 'Applications\goose\v1.47.0\dist-windows\resources\bin\goose.exe')
    if ($null -ne $gooseOnPath) { $gooseOnPath.Source }
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -Unique
$goose = $gooseCandidates | Select-Object -First 1
if (-not $goose) { throw 'Goose CLI could not be resolved.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runRoot = Join-Path $env:LOCALAPPDATA "Local-LLM-Coding-Stack\turbo\qualification\$($Profile.ToLowerInvariant())-goose-output32k-$stamp"
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$instructionPath = Join-Path $runRoot 'instruction.txt'
$stdoutPath = Join-Path $runRoot 'goose.stdout.json'
$stderrPath = Join-Path $runRoot 'goose.stderr.log'
$resultPath = Join-Path $runRoot 'result.json'

$instruction = @"
/no_think
Do not use tools. Return only a newline-separated sequence of five-digit decimal numbers.
Start at 00001, increase by exactly one on every line, and continue through $($FinalSequenceNumber.ToString('00000')).
Do not add a title, explanation, code fence, blank line, ellipsis, or commentary. Do not stop early.
"@
[IO.File]::WriteAllText($instructionPath, $instruction, [Text.UTF8Encoding]::new($false))

$saved = @{}
$overrides = [ordered]@{
    OPENAI_HOST = $BaseUrl.TrimEnd('/')
    OPENAI_BASE_PATH = '/v1/chat/completions'
    OPENAI_API_KEY = 'managed-turbo-local-only'
    GOOSE_CONTEXT_LIMIT = '90112'
    GOOSE_MAX_TOKENS = [string]$MaxOutputTokens
    GOOSE_AUTO_COMPACT_THRESHOLD = '0.3'
    GOOSE_TEMPERATURE = '0'
}
foreach ($name in $overrides.Keys) {
    $item = Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    $saved[$name] = if ($null -eq $item) { [pscustomobject]@{ exists = $false; value = $null } } else { [pscustomobject]@{ exists = $true; value = $item.Value } }
    Set-Item -LiteralPath "Env:$name" -Value $overrides[$name]
}

$arguments = @(
    'run', '--no-session', '--no-profile', '--provider', 'openai', '--model', [string]$manifest.server.api_model_alias,
    '--max-turns', '1', '--max-tool-repetitions', '0', '--stats', '--debug', '--output-format', 'json', '--instructions', $instructionPath
)
$observedPredict = $null
$observedContext = $null
$exitCode = $null
$processExited = $false
$startedAt = Get-Date
try {
    $process = Start-Process -FilePath $goose -ArgumentList $arguments -WorkingDirectory $runRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    while (-not $process.HasExited) {
        try {
            $slots = @(Get-QualificationSlots -Endpoint $BaseUrl)
            $active = @($slots | Where-Object { $_.is_processing -eq $true }) | Select-Object -First 1
            if ($null -ne $active) {
                if ($null -ne $active.params.PSObject.Properties['n_predict']) { $observedPredict = [int]$active.params.n_predict }
                if ($null -ne $active.PSObject.Properties['n_ctx']) { $observedContext = [int]$active.n_ctx }
            }
        }
        catch {
            # The managed process and final API health check remain authoritative.
        }
        if (((Get-Date) - $startedAt).TotalMinutes -gt 20) {
            throw 'Goose 32K qualification exceeded the 20-minute safety timeout.'
        }
        Start-Sleep -Seconds 2
        $process.Refresh()
    }
    $process.WaitForExit()
    $process.Refresh()
    $processExited = $process.HasExited
    try { $exitCode = [int]$process.ExitCode } catch { $exitCode = $null }
}
finally {
    foreach ($name in $overrides.Keys) {
        if ($saved[$name].exists) { Set-Item -LiteralPath "Env:$name" -Value $saved[$name].value }
        else { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
    }
}

$raw = if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) { [IO.File]::ReadAllText($stdoutPath, [Text.Encoding]::UTF8) } else { '' }
$jsonStart = $raw.IndexOf('{')
if ($jsonStart -lt 0) { throw "Goose JSON output was not found. Evidence: $runRoot" }
$payload = $raw.Substring($jsonStart) | ConvertFrom-Json
$outputTokens = [int]$payload.metadata.output_tokens
$status = [string]$payload.metadata.status
$assistantText = [string]((@($payload.messages | Where-Object role -eq 'assistant') | Select-Object -Last 1).content | Where-Object type -eq 'text' | Select-Object -Last 1).text
$expectedTail = $FinalSequenceNumber.ToString('00000')
$reachedTail = $assistantText.TrimEnd().EndsWith($expectedTail, [StringComparison]::Ordinal)
$lines = @($assistantText.TrimEnd() -split "`r?`n")
$sequenceValid = $lines.Count -eq $FinalSequenceNumber
if ($sequenceValid) {
    for ($index = 1; $index -le $FinalSequenceNumber; $index++) {
        if ($lines[$index - 1] -cne $index.ToString('00000')) {
            $sequenceValid = $false
            break
        }
    }
}

& (Join-Path $PSScriptRoot 'Test-ManagedTurbo.ps1') -Profile $Profile -Mode $mode -BaseUrl $BaseUrl | Out-Null
$finalSlots = @(Get-QualificationSlots -Endpoint $BaseUrl)
if ($null -eq $observedContext -and $finalSlots.Count -eq 1 -and $null -ne $finalSlots[0].PSObject.Properties['n_ctx']) {
    $observedContext = [int]$finalSlots[0].n_ctx
}
if ($null -eq $observedPredict -and $finalSlots.Count -eq 1 -and $null -ne $finalSlots[0].params.PSObject.Properties['n_predict']) {
    $observedPredict = [int]$finalSlots[0].params.n_predict
}
$props = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/props') -TimeoutSec 10
if ($null -eq $observedContext -and $null -ne $props.default_generation_settings.PSObject.Properties['n_ctx']) {
    $observedContext = [int]$props.default_generation_settings.n_ctx
}
$finalIdle = $finalSlots.Count -eq 1 -and @($finalSlots | Where-Object { $_.is_processing -eq $true }).Count -eq 0
$configHashAfter = if (Test-Path -LiteralPath $persistentConfig -PathType Leaf) { Get-TurboFileSha256 -Path $persistentConfig } else { $null }
$configUnchanged = $configHashAfter -eq $configHashBefore
$record = [ordered]@{
    schema_version = 1
    recorded_at = (Get-Date).ToString('o')
    profile = $Profile
    endpoint = $BaseUrl
    model_alias = $manifest.server.api_model_alias
    goose_context_limit = 90112
    goose_max_output_tokens = $MaxOutputTokens
    minimum_output_tokens = $MinimumOutputTokens
    observed_slot_n_predict = $observedPredict
    observed_slot_context = $observedContext
    goose_exit = $exitCode
    goose_process_exited = $processExited
    goose_status = $status
    output_tokens = $outputTokens
    requested_sequence_tail = $expectedTail
    reached_sequence_tail = $reachedTail
    full_sequence_valid = $sequenceValid
    final_slot_idle = $finalIdle
    persistent_config_sha256_before = $configHashBefore
    persistent_config_sha256_after = $configHashAfter
    persistent_config_unchanged = $configUnchanged
    stdout_path = $stdoutPath
    stderr_path = $stderrPath
    pass = $processExited -and $status -eq 'completed' -and $outputTokens -ge $MinimumOutputTokens -and $outputTokens -le $MaxOutputTokens -and $observedPredict -eq $MaxOutputTokens -and $observedContext -eq 98304 -and $sequenceValid -and $finalIdle -and $configUnchanged
}
Write-TurboJson -InputObject $record -Path $resultPath -Depth 10
if (-not $record.pass) { throw "Goose Turbo Output32K qualification failed. Evidence: $resultPath" }
Write-Host "[OK] $Profile Goose Turbo Output32K PASS: $outputTokens output tokens; n_predict $observedPredict; n_ctx $observedContext." -ForegroundColor Green
Write-Host "[OK] Evidence: $resultPath" -ForegroundColor Green
$record
