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
    'benchmarks/results/2026-08-24-qwen38-vision-operational-profiles.md',
    'benchmarks/templates/result.template.json',
    'configs',
    'configs/current/qwen38-27b-uncensored-q6k.json',
    'configs/candidates/jonathan-q6k-vision.json',
    'configs/candidates/hauhaucs-qwen38-27b-aggressive-mtp.json',
    'configs/candidates/rtx3090-jonathan-q4km.json',
    'configs/candidates/rtx3090-hauhaucs-aggressive-q4kp.json',
    'configs/candidates/rtx3090-dual-jonathan-q6k-vision.json',
    'configs/candidates/rtx3090-dual-jonathan-q5km-vision-96k.json',
    'profiles/README.md',
    'profiles/RTX3090-Remote/README.md',
    'profiles/RTX3090-Remote/node.json',
    'benchmarks/results/2026-08-20-rtx3090-remote-node.md',
    'benchmarks/results/2026-08-23-rtx5090-jonathan-q6k-vision.md',
    'benchmarks/results/2026-08-24-blue-q6k-vision-64k-operational-default.md',
    'benchmarks/results/2026-08-25-blue-q5km-vision-96k-qualification.md',
    'research/jonathan-q6k-vision-2026-08-23.md',
    'research/2026-08-24-blue-shared-gpu-memory-investigation.md',
    'package.json',
    'package-lock.json',
    'research',
    'logs',
    'scripts',
    'scripts/goose/Set-GooseProfile.ps1',
    'scripts/tests/Test-GooseProfileSelector.ps1',
    'scripts/tests/Test-QwenVisionProfileLoaders.ps1',
    'scripts/lmstudio/Load-ManagedModel.mjs',
    'scripts/lmstudio/Test-ManagedModel.mjs',
    'scripts/lmstudio/model-loaders/RTX3090/README.md',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q4KM/README.md',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q4KM/Qwen3.8-JonathanColetti-Q4KM_32K.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q4KM/Qwen3.8-JonathanColetti-Q4KM_64K.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/README.md',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.ps1',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.ps1',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/README.md',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K.ps1',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_REMOTE.ps1',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_REMOTE.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-HauhauCS-Aggressive-Q4KP/README.md',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-HauhauCS-Aggressive-Q4KP/Qwen3.8-HauhauCS-Q4KP_32K.bat',
    'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-HauhauCS-Aggressive-Q4KP/Qwen3.8-HauhauCS-Q4KP_64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/Qwen3.8-JonathanColetti-Q6K_96K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/Qwen3.8-JonathanColetti-Q6K_64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K/Qwen3.8-JonathanColetti-Q6K_32K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_96K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Qwen3.8-JonathanColetti-Q6K-Vision_32K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Start-Goose-Jonathan-Vision64K.ps1',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Start-Goose-Jonathan-Vision64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision/Set-Goose-Profile-Q6K-Vision64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q5KM-Vision/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q5KM-Vision/Set-Goose-Profile-Q5KM-Vision96K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q6KP/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q6KP/Qwen3.8-HauhauCS-Q6KP_96K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q6KP/Qwen3.8-HauhauCS-Q6KP_64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q6KP/Qwen3.8-HauhauCS-Q6KP_32K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q5KP/README.md',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q5KP/Qwen3.8-HauhauCS-Q5KP_96K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q5KP/Qwen3.8-HauhauCS-Q5KP_64K.bat',
    'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-HauhauCS-Aggressive-Q5KP/Qwen3.8-HauhauCS-Q5KP_32K.bat'
)

foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $failures.Add("Missing required path: $relativePath")
    }
}

$excludedJsonRoots = @(
    (Join-Path $repoRoot 'benchmarks\raw'),
    (Join-Path $repoRoot 'logs'),
    (Join-Path $repoRoot 'node_modules')
)
$jsonFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter '*.json' | Where-Object {
    $candidatePath = $_.FullName
    $_.Name -ne 'package-lock.json' -and -not ($excludedJsonRoots | Where-Object {
        $candidatePath.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    })
}
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

$visionProfile = @($profiles | Where-Object { $_.Id -eq 'candidate-jonathan-q6k-vision' })
if ($visionProfile.Count -ne 1 -or $visionProfile[0].Status -ne 'Candidate') {
    $failures.Add('Jonathan Q6_K Vision must exist exactly once with Candidate status.')
}

$blueVisionProfile = @($profiles | Where-Object { $_.Id -eq 'candidate-rtx3090-dual-jonathan-q6k-vision' })
if ($blueVisionProfile.Count -ne 1 -or $blueVisionProfile[0].Status -ne 'Candidate') {
    $failures.Add('BLUE Jonathan Q6_K Vision must exist exactly once with Candidate lifecycle status.')
}

$blueQ5VisionProfile = @($profiles | Where-Object { $_.Id -eq 'candidate-rtx3090-dual-jonathan-q5km-vision-96k' })
if ($blueQ5VisionProfile.Count -ne 1 -or $blueQ5VisionProfile[0].Status -ne 'Candidate') {
    $failures.Add('BLUE Jonathan Q5_K_M Vision 96K must exist exactly once with Candidate lifecycle status.')
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

$gooseSelectorTest = Join-Path $repoRoot 'scripts\tests\Test-GooseProfileSelector.ps1'
if (Test-Path -LiteralPath $gooseSelectorTest -PathType Leaf) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $gooseSelectorTest
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Goose profile selector regression test failed with exit code $LASTEXITCODE.")
    }
}

$visionProfileLoaderTest = Join-Path $repoRoot 'scripts\tests\Test-QwenVisionProfileLoaders.ps1'
if (Test-Path -LiteralPath $visionProfileLoaderTest -PathType Leaf) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $visionProfileLoaderTest
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Qwen Vision profile loader regression test failed with exit code $LASTEXITCODE.")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Repository validation failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Repository validation passed: $($jsonFiles.Count) managed JSON file(s), one Current profile, no model binaries." -ForegroundColor Green
exit 0
