[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$ModelId,

    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$WorkloadId,

    [ValidateRange(0, 1048576)]
    [int]$ContextTokens = 0,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$configFullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
    [System.IO.Path]::GetFullPath($ConfigPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ConfigPath))
}

if (-not (Test-Path -LiteralPath $configFullPath -PathType Leaf)) {
    throw "Configuration record not found: $configFullPath"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runId = "$stamp-$ModelId-$WorkloadId"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputFullPath = Join-Path $repoRoot "benchmarks\results\$runId.json"
} elseif ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $outputFullPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
}

if (Test-Path -LiteralPath $outputFullPath) {
    throw "Refusing to overwrite existing benchmark record: $outputFullPath"
}

$contextValue = if ($ContextTokens -gt 0) { $ContextTokens } else { $null }
$record = [ordered]@{
    schema_version = 1
    record_type = 'controlled_run'
    run_id = $runId
    created_at = (Get-Date).ToString('o')
    measured_at = $null
    status = 'pending_measurement'
    model_id = $ModelId
    model_artifact = [ordered]@{
        repository = $null
        variant = $null
        file_name = $null
        checksum = $null
    }
    config_path = $ConfigPath.Replace('\', '/')
    workload = [ordered]@{
        id = $WorkloadId
        fixture_version = $null
        context_tokens = $contextValue
        prompt_tokens = $null
        output_tokens = $null
        warmup = $false
        iteration = 1
    }
    environment = [ordered]@{
        gpu = 'NVIDIA GeForce RTX 5090'
        vram_gib = 32
        lm_studio_version = $null
        zoo_code_version = $null
        nvidia_driver_version = $null
    }
    settings = [ordered]@{
        k_cache = $null
        v_cache = $null
        flash_attention = $null
        gpu_offload_layers = $null
        mtp_enabled = $null
        max_draft_tokens = $null
        reasoning_budget_tokens = $null
        max_concurrent_predictions = $null
        sampling = $null
    }
    metrics = [ordered]@{
        time_to_first_token_ms = $null
        generation_tok_s = $null
        mtp_acceptance_percent = $null
        vram_baseline_mib = $null
        vram_peak_mib = $null
        vram_delta_mib = $null
        wall_time_seconds = $null
    }
    outcome = [ordered]@{
        completed = $null
        correctness_score = $null
        tests_passed = $null
        tests_total = $null
        desktop_responsiveness = $null
        runtime_stability = $null
    }
    raw_artifacts = @()
    notes = @()
}

$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

if ($PSCmdlet.ShouldProcess($outputFullPath, 'Create benchmark record')) {
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outputFullPath -Encoding utf8
    Write-Output $outputFullPath
}
