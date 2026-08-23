[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ModelIdentifier,

    [Parameter(Mandatory)]
    [string]$PromptPath,

    [ValidateRange(1, 10)]
    [int]$Iterations = 3,

    [ValidateRange(16, 32768)]
    [int]$MaxTokens = 512,

    [ValidateRange(0.0, 2.0)]
    [double]$Temperature = 1.0,

    [ValidateRange(0.0, 1.0)]
    [double]$TopP = 0.95,

    [ValidatePattern('^https?://[^/]+(?::[0-9]+)?$')]
    [string]$BaseUrl = 'http://127.0.0.1:1234',

    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$GpuSshAlias,

    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$ExpectedGpuHostname,

    [switch]$SkipWarmup,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$promptFullPath = if ([System.IO.Path]::IsPathRooted($PromptPath)) {
    [System.IO.Path]::GetFullPath($PromptPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $PromptPath))
}

if (-not (Test-Path -LiteralPath $promptFullPath -PathType Leaf)) {
    throw "Prompt fixture not found: $promptFullPath"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $safeModelId = $ModelIdentifier -replace '[^A-Za-z0-9._-]', '_'
    $outputFullPath = Join-Path $repoRoot "benchmarks\raw\$stamp-$safeModelId-api-benchmark.json"
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
}

if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite existing benchmark output: $outputFullPath"
}

$prompt = Get-Content -LiteralPath $promptFullPath -Raw
$endpoint = $BaseUrl.TrimEnd('/') + '/api/v0/chat/completions'
$sshExecutable = if ([string]::IsNullOrWhiteSpace($GpuSshAlias)) {
    $null
} else {
    (Get-Command ssh -ErrorAction Stop).Source
}

if ($sshExecutable -and -not [string]::IsNullOrWhiteSpace($ExpectedGpuHostname)) {
    $observedHostname = @(& $sshExecutable -o BatchMode=yes -o ConnectTimeout=10 $GpuSshAlias hostname 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify GPU host through SSH alias: $GpuSshAlias"
    }
    $observedHostname = ($observedHostname -join '').Trim()
    if ($observedHostname -ne $ExpectedGpuHostname) {
        throw "GPU host mismatch: expected $ExpectedGpuHostname, observed $observedHostname"
    }
}

function Get-GpuMemoryUsedMiB {
    $raw = if ($sshExecutable) {
        & $sshExecutable -o BatchMode=yes -o ConnectTimeout=10 $GpuSshAlias nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
    } else {
        & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
    }
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        return $null
    }
    return [int](($raw | Select-Object -First 1).Trim())
}

function Get-TextSha256([string]$Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Invoke-Prediction([int]$OutputLimit) {
    $body = [ordered]@{
        model = $ModelIdentifier
        messages = @(
            [ordered]@{
                role = 'system'
                content = 'Follow the user instructions exactly. Do not call tools for this benchmark.'
            },
            [ordered]@{
                role = 'user'
                content = $prompt
            }
        )
        temperature = $Temperature
        top_p = $TopP
        max_tokens = $OutputLimit
        stream = $false
    }

    $json = $body | ConvertTo-Json -Depth 8 -Compress
    return Invoke-RestMethod -Method Post -Uri $endpoint -ContentType 'application/json; charset=utf-8' -Body $json
}

if (-not $SkipWarmup) {
    Write-Host 'Running warm-up prediction (not included in measured results)...'
    $null = Invoke-Prediction -OutputLimit ([Math]::Min(32, $MaxTokens))
}

$runs = [System.Collections.Generic.List[object]]::new()
for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
    $vramBefore = Get-GpuMemoryUsedMiB
    $remoteMonitorScript = @'
for ($sample = 0; $sample -lt 3600; $sample++) {
    $value = & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
    if ($LASTEXITCODE -eq 0 -and $value) {
        Write-Output ([int](($value | Select-Object -First 1).Trim()))
    }
    Start-Sleep -Milliseconds 250
}
'@
    $remoteMonitorEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($remoteMonitorScript))
    $monitor = Start-Job -ArgumentList $sshExecutable,$GpuSshAlias,$remoteMonitorEncoded -ScriptBlock {
        param($SshExecutable, $SshAlias, $RemoteEncoded)
        if ($SshExecutable) {
            & $SshExecutable -o BatchMode=yes -o ConnectTimeout=10 $SshAlias powershell.exe -NoProfile -NonInteractive -EncodedCommand $RemoteEncoded 2>$null
            return
        }
        for ($sample = 0; $sample -lt 3600; $sample++) {
            $value = & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
            if ($LASTEXITCODE -eq 0 -and $value) {
                Write-Output ([int](($value | Select-Object -First 1).Trim()))
            }
            Start-Sleep -Milliseconds 250
        }
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-Prediction -OutputLimit $MaxTokens
    } finally {
        $stopwatch.Stop()
        Stop-Job -Job $monitor -ErrorAction SilentlyContinue
    }

    $samples = @(Receive-Job -Job $monitor -ErrorAction SilentlyContinue | ForEach-Object {
        $sampleText = [string]$_
        if ($sampleText -match '^\s*([0-9]+)\s*$') {
            [int]$Matches[1]
        }
    })
    Remove-Job -Job $monitor -Force -ErrorAction SilentlyContinue
    $vramAfter = Get-GpuMemoryUsedMiB
    $vramPeak = if ($samples.Count -gt 0) {
        ($samples | Measure-Object -Maximum).Maximum
    } else {
        $vramAfter
    }

    $message = $response.choices[0].message
    $assistantText = [string]$message.content
    $assistantReasoning = if ($message.PSObject.Properties.Name -contains 'reasoning_content') {
        [string]$message.reasoning_content
    } elseif ($message.PSObject.Properties.Name -contains 'reasoning') {
        [string]$message.reasoning
    } else {
        ''
    }
    $responsePayload = "content:`n$assistantText`nreasoning:`n$assistantReasoning"
    $responsePayloadEmpty = [string]::IsNullOrWhiteSpace($assistantText) -and [string]::IsNullOrWhiteSpace($assistantReasoning)
    if ($responsePayloadEmpty -and [int]$response.usage.completion_tokens -gt 0) {
        Write-Warning "Run $iteration returned completion tokens but neither content nor reasoning text was exposed by the API."
    }

    $run = [ordered]@{
        iteration = $iteration
        wall_time_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 4)
        prompt_tokens = $response.usage.prompt_tokens
        completion_tokens = $response.usage.completion_tokens
        total_tokens = $response.usage.total_tokens
        generation_tok_s = $response.stats.tokens_per_second
        time_to_first_token_seconds = $response.stats.time_to_first_token
        generation_time_seconds = $response.stats.generation_time
        stop_reason = $response.stats.stop_reason
        response_stats = $response.stats
        vram_before_request_mib = $vramBefore
        vram_peak_request_mib = $vramPeak
        vram_after_request_mib = $vramAfter
        response_sha256 = Get-TextSha256 $responsePayload
        response_payload_empty = $responsePayloadEmpty
        response_text = $assistantText
        response_reasoning = $assistantReasoning
    }
    $runs.Add([pscustomobject]$run)
    Write-Host ("Run {0}: {1} tok/s, TTFT {2}s, peak VRAM {3} MiB" -f $iteration, $run.generation_tok_s, $run.time_to_first_token_seconds, $run.vram_peak_request_mib)
}

$tokValues = @($runs | ForEach-Object { [double]$_.generation_tok_s } | Sort-Object)
$ttftValues = @($runs | ForEach-Object { [double]$_.time_to_first_token_seconds } | Sort-Object)
$middle = [Math]::Floor($tokValues.Count / 2)
$medianTok = if ($tokValues.Count % 2 -eq 1) { $tokValues[$middle] } else { ($tokValues[$middle - 1] + $tokValues[$middle]) / 2 }
$medianTtft = if ($ttftValues.Count % 2 -eq 1) { $ttftValues[$middle] } else { ($ttftValues[$middle - 1] + $ttftValues[$middle]) / 2 }

$record = [ordered]@{
    schema_version = 1
    recorded_at = (Get-Date).ToString('o')
    endpoint = $endpoint
    gpu_telemetry = if ($sshExecutable) { "ssh:$GpuSshAlias" } else { 'local' }
    model_identifier = $ModelIdentifier
    prompt_path = $PromptPath.Replace('\', '/')
    settings = [ordered]@{
        iterations = $Iterations
        max_tokens = $MaxTokens
        temperature = $Temperature
        top_p = $TopP
        warmup = -not $SkipWarmup
    }
    summary = [ordered]@{
        median_generation_tok_s = [Math]::Round($medianTok, 4)
        median_time_to_first_token_seconds = [Math]::Round($medianTtft, 4)
        peak_vram_mib = ($runs | Measure-Object vram_peak_request_mib -Maximum).Maximum
    }
    runs = $runs
}

$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outputFullPath -Encoding utf8
Write-Output $outputFullPath
