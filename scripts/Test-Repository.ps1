[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

$requiredPaths = @(
    'AGENTS.md',
    'README.md',
    'CURRENT_STATE.md',
    'MODEL_REGISTRY.md',
    'CHANGELOG.md',
    'benchmarks',
    'benchmarks/results',
    'benchmarks/templates/result.template.json',
    'configs',
    'configs/current/qwen38-27b-uncensored-q6k.json',
    'configs/candidates/hauhaucs-qwen38-27b-aggressive-mtp.json',
    'research',
    'logs',
    'scripts',
    'scripts/lmstudio/model-loaders/RTX5090/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/Qwen3.8_96K_Normal.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/Qwen3.8_64K_VRChat.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti/Qwen3.8_32K_Light.bat'
)

foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing required path: $relativePath")
    }
}

$jsonFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter '*.json'
foreach ($jsonFile in $jsonFiles) {
    try {
        $null = Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $failures.Add("Invalid JSON: $($jsonFile.FullName) :: $($_.Exception.Message)")
    }
}

$profileFiles = @()
foreach ($profileDirectory in @('configs/current', 'configs/candidates')) {
    $directoryPath = Join-Path $repoRoot $profileDirectory
    if (Test-Path -LiteralPath $directoryPath -PathType Container) {
        $profileFiles += Get-ChildItem -LiteralPath $directoryPath -File -Filter '*.json'
    }
}

$profiles = @()
foreach ($profileFile in $profileFiles) {
    try {
        $profile = Get-Content -LiteralPath $profileFile.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
        $profiles += [pscustomobject]@{
            Path = $profileFile.FullName
            Id = $profile.profile_id
            Status = $profile.status
        }
    } catch {
        continue
    }
}

$currentProfiles = @($profiles | Where-Object { $_.Status -eq 'Current' })
if ($currentProfiles.Count -ne 1) {
    $failures.Add("Expected exactly one Current profile, found $($currentProfiles.Count).")
} elseif ($currentProfiles[0].Id -ne 'current-qwen38-27b-uncensored-q6k') {
    $failures.Add("Unexpected Current profile: $($currentProfiles[0].Id)")
}

$candidateProfile = @($profiles | Where-Object { $_.Id -eq 'candidate-hauhaucs-aggressive-mtp' })
if ($candidateProfile.Count -ne 1 -or $candidateProfile[0].Status -ne 'Candidate') {
    $failures.Add('HauhauCS Aggressive-MTP must exist exactly once with Candidate status.')
}

$blockedExtensions = @('.gguf', '.safetensors', '.bin', '.ckpt', '.pth', '.pt', '.onnx')
$blockedFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Where-Object {
    $blockedExtensions -contains $_.Extension.ToLowerInvariant()
}
foreach ($blockedFile in $blockedFiles) {
    $failures.Add("Model/runtime binary must not be stored in repository: $($blockedFile.FullName)")
}

foreach ($blockedDirectory in @('models', 'model-data', 'runtime-data', '.lmstudio')) {
    $blockedPath = Join-Path $repoRoot $blockedDirectory
    if (Test-Path -LiteralPath $blockedPath) {
        $failures.Add("Runtime/model data directory must not exist in repository: $blockedDirectory")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Repository validation failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Repository validation passed: $($jsonFiles.Count) JSON file(s), one Current profile, no model binaries." -ForegroundColor Green
exit 0
