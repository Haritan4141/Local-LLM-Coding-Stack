[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$failures = [System.Collections.Generic.List[string]]::new()

function Get-RepoPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    Join-Path $repoRoot ($RelativePath -replace '/', '\')
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Description
    )
    if ($Text -notmatch $Pattern) { $failures.Add("Missing $Description") }
}

$mainRoot = 'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q6K-Vision'
$mainQ5Root = 'scripts/lmstudio/model-loaders/RTX5090/Qwen3.8-JonathanColetti-Q5KM-Vision'
$blueRoot = 'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q6K-Vision'
$blueQ5Root = 'scripts/lmstudio/model-loaders/RTX3090/Qwen3.8-JonathanColetti-Q5KM-Vision'
$requiredPaths = @(
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat",
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat",
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat",
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat",
    "$mainQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat",
    "$mainQ5Root/Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.ps1",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.ps1",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.ps1",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.ps1",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat",
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat",
    "$blueQ5Root/README.md",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.ps1",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.bat",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.ps1"
)
foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Get-RepoPath $relativePath) -PathType Leaf)) {
        $failures.Add("Missing profile loader path: $relativePath")
    }
}

$mainBalanced = Get-Content -LiteralPath (Get-RepoPath "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat") -Raw
$mainCodingFast = Get-Content -LiteralPath (Get-RepoPath "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat") -Raw
$mainQ5Recommended = Get-Content -LiteralPath (Get-RepoPath "$mainQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat") -Raw
foreach ($check in @(
    @{ Text = $mainQ5Recommended; Pattern = '--context 98304 --mtp on --mtp-draft 3'; Description = 'RTX5090 Q5 Recommended 96K/MTP3' },
    @{ Text = $mainQ5Recommended; Pattern = '--kv-k q8_0 --kv-v q8_0'; Description = 'RTX5090 Q5 Recommended Q8/Q8' },
    @{ Text = $mainQ5Recommended; Pattern = '--eval-batch 1024'; Description = 'RTX5090 Q5 Recommended batch1024' },
    @{ Text = $mainQ5Recommended; Pattern = '--mmap on --keep-model-in-memory on'; Description = 'RTX5090 Q5 Recommended mmap/mlock behavior' },
    @{ Text = $mainQ5Recommended; Pattern = 'Test-ManagedModel\.mjs.*--vision-required on'; Description = 'RTX5090 Q5 Recommended post-load Vision preflight' },
    @{ Text = $mainBalanced; Pattern = '--mtp-draft 4'; Description = 'RTX5090 Balanced MTP4' },
    @{ Text = $mainBalanced; Pattern = '--kv-k q8_0 --kv-v q8_0'; Description = 'RTX5090 Balanced Q8/Q8' },
    @{ Text = $mainBalanced; Pattern = '--eval-batch 2048'; Description = 'RTX5090 Balanced batch2048' },
    @{ Text = $mainCodingFast; Pattern = '--mtp-draft 4'; Description = 'RTX5090 Coding-Fast MTP4' },
    @{ Text = $mainCodingFast; Pattern = '--kv-k q4_0 --kv-v q4_0'; Description = 'RTX5090 Coding-Fast Q4/Q4' },
    @{ Text = $mainCodingFast; Pattern = '--eval-batch 2048'; Description = 'RTX5090 Coding-Fast batch2048' }
)) {
    Assert-Contains @check
}

$mainProfile = Get-Content -LiteralPath (Get-RepoPath 'configs/candidates/jonathan-q6k-vision.json') -Raw | ConvertFrom-Json
$mainQ5Profile = Get-Content -LiteralPath (Get-RepoPath 'configs/candidates/jonathan-q5km-vision.json') -Raw | ConvertFrom-Json
$blueProfile = Get-Content -LiteralPath (Get-RepoPath 'configs/candidates/rtx3090-dual-jonathan-q6k-vision.json') -Raw | ConvertFrom-Json
$blueQ5Profile = Get-Content -LiteralPath (Get-RepoPath 'configs/candidates/rtx3090-dual-jonathan-q5km-vision-96k.json') -Raw | ConvertFrom-Json
$nodeProfile = Get-Content -LiteralPath (Get-RepoPath 'profiles/RTX3090-Remote/node.json') -Raw | ConvertFrom-Json
if ($mainProfile.status -ne 'Candidate' -or $mainProfile.operational_profiles.recommended -ne 'Balanced' -or
    $mainProfile.operational_profiles.safe.mtp_max_draft_tokens -ne 2 -or
    $mainProfile.operational_profiles.balanced.mtp_max_draft_tokens -ne 4 -or
    $mainProfile.operational_profiles.coding_fast.kv_cache -ne 'Q4_0/Q4_0') {
    $failures.Add('RTX5090 management profile does not preserve Candidate lifecycle and Safe/Balanced/Coding-Fast metadata.')
}
if ($mainQ5Profile.status -ne 'Candidate' -or
    $mainQ5Profile.operational_role -ne 'Recommended Production' -or
    $mainQ5Profile.effective_settings.context_tokens -ne 98304 -or
    $mainQ5Profile.effective_settings.kv_cache.k -ne 'Q8_0' -or
    $mainQ5Profile.effective_settings.kv_cache.v -ne 'Q8_0' -or
    $mainQ5Profile.effective_settings.mtp.enabled -ne $true -or
    $mainQ5Profile.effective_settings.mtp.max_draft_tokens -ne 3 -or
    $mainQ5Profile.effective_settings.eval_batch_size -ne 1024 -or
    $mainQ5Profile.effective_settings.effective_ubatch_size -ne 512 -or
    $mainQ5Profile.effective_settings.mmap -ne $true -or
    $mainQ5Profile.effective_settings.mlock -ne $true -or
    $mainQ5Profile.effective_settings.power_limit_w -ne 402 -or
    $mainQ5Profile.final_quality_gate.result -ne 'PASS') {
    $failures.Add('RTX5090 Q5_K_M management profile does not preserve Candidate lifecycle and the qualified 96K Production settings.')
}
if ($blueProfile.status -ne 'Candidate' -or $blueProfile.operational_profiles.recommended -ne 'Balanced' -or
    $blueProfile.operational_profiles.safe.eval_batch_size -ne 512 -or
    $blueProfile.operational_profiles.balanced.eval_batch_size -ne 1024 -or
    $blueProfile.operational_profiles.coding_fast.kv_cache -ne 'Q4_0/Q4_0') {
    $failures.Add('BLUE management profile does not preserve Candidate lifecycle and Safe/Balanced/Coding-Fast metadata.')
}
if ($blueQ5Profile.status -ne 'Candidate' -or $blueQ5Profile.effective_settings.context_tokens -ne 98304 -or
    $blueQ5Profile.effective_settings.kv_cache.k -ne 'Q8_0' -or
    $blueQ5Profile.effective_settings.kv_cache.v -ne 'Q8_0' -or
    $blueQ5Profile.effective_settings.mtp.max_draft_tokens -ne 3 -or
    $blueQ5Profile.effective_settings.eval_batch_size -ne 1024 -or
    $blueQ5Profile.capacity_gate.result -ne 'PASS') {
    $failures.Add('BLUE Q5_K_M management profile does not preserve Candidate lifecycle and the qualified 96K Recommended settings.')
}
if ($nodeProfile.operational_default.profile_id -ne 'candidate-rtx3090-dual-jonathan-q5km-vision-96k' -or
    $nodeProfile.operational_default.operational_profile -ne 'Recommended Production' -or
    $nodeProfile.operational_default.mtp -ne 'on / draft 3' -or
    $nodeProfile.operational_default.eval_batch_size -ne 1024) {
    $failures.Add('BLUE node profile does not select Q5_K_M 96K as Recommended Production.')
}

$blueCore = Get-Content -LiteralPath (Get-RepoPath "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K.ps1") -Raw
foreach ($check in @(
    @{ Text = $blueCore; Pattern = "(?s)'Safe'.*?DraftTokens = 2; KCache = 'q8_0'; VCache = 'q8_0'; EvalBatch = 512"; Description = 'BLUE Safe settings' },
    @{ Text = $blueCore; Pattern = "(?s)'Balanced'.*?DraftTokens = 3; KCache = 'q8_0'; VCache = 'q8_0'; EvalBatch = 1024"; Description = 'BLUE Balanced settings' },
    @{ Text = $blueCore; Pattern = "(?s)'Coding-Fast'.*?DraftTokens = 3; KCache = 'q4_0'; VCache = 'q4_0'; EvalBatch = 512"; Description = 'BLUE Coding-Fast settings' },
    @{ Text = $blueCore; Pattern = [regex]::Escape("Rtx3090PowerLimit -ne 259 -and `$OperationalProfile -ne 'Safe'"); Description = 'BLUE 370W profile-combination guard' },
    @{ Text = $blueCore; Pattern = [regex]::Escape("'--mmap', 'off'"); Description = 'BLUE mmap OFF' },
    @{ Text = $blueCore; Pattern = [regex]::Escape("'--priority', `$priorityArg"); Description = 'BLUE priorityOrder argument' }
)) {
    Assert-Contains @check
}

$blueQ5Core = Get-Content -LiteralPath (Get-RepoPath "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.ps1") -Raw
foreach ($check in @(
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("`$ModelKey = 'qwen3.8-27b-uncensored-vision-q5km'"); Description = 'BLUE Q5_K_M model key' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("`$Identifier = 'qwen3.8-27b-uncensored-vision-q5km-blue'"); Description = 'BLUE Q5_K_M API identifier' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape('$ContextLength = 98304'); Description = 'BLUE Q5_K_M 96K context' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape('$DraftTokens = 3'); Description = 'BLUE Q5_K_M MTP3' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape('$EvalBatch = 1024'); Description = 'BLUE Q5_K_M batch1024' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("'--kv-k', 'q8_0'"); Description = 'BLUE Q5_K_M Q8 K cache' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("'--kv-v', 'q8_0'"); Description = 'BLUE Q5_K_M Q8 V cache' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("'--mmap', 'off'"); Description = 'BLUE Q5_K_M mmap OFF' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape('$CombinedSharedLimitBytes = [int64]4GB'); Description = 'BLUE Q5_K_M combined Shared gate' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape('$PerGpuSharedLimitBytes = [int64]2GB'); Description = 'BLUE Q5_K_M per-GPU Shared gate' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("& lms unload `$Identifier"); Description = 'BLUE Q5_K_M fail-closed unload' },
    @{ Text = $blueQ5Core; Pattern = [regex]::Escape("'--priority', `$priorityArg"); Description = 'BLUE Q5_K_M priorityOrder argument' }
)) {
    Assert-Contains @check
}

$selectorExpectations = @{
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat" = @(
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat'
    )
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat" = @(
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat'
    )
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat" = @(
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.bat'
    )
}
foreach ($entry in $selectorExpectations.GetEnumerator()) {
    $selectorPath = Get-RepoPath $entry.Key
    $selectorText = Get-Content -LiteralPath $selectorPath -Raw
    $calls = @([regex]::Matches($selectorText, '(?im)^call "%~dp0([^"\r\n]+\.bat)"$') | ForEach-Object { $_.Groups[1].Value })
    if (($calls -join '|') -ne (@($entry.Value) -join '|')) {
        $failures.Add("Selector call mapping mismatch: $($entry.Key)")
    }
    if ($selectorText -match '(?im)^\s*(lms|node|powershell|nvidia-smi)\b') {
        $failures.Add("Selector contains direct runtime-setting logic: $($entry.Key)")
    }
    & cmd.exe /d /c "call `"$selectorPath`" 0" *> $null
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Selector Cancel smoke failed: $($entry.Key) :: exit $LASTEXITCODE")
    }
}

$powerShellFiles = @(
    Get-Item -LiteralPath (Get-RepoPath "$mainQ5Root/Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1")
    Get-ChildItem -LiteralPath (Get-RepoPath $blueRoot) -File -Filter '*.ps1'
    Get-ChildItem -LiteralPath (Get-RepoPath $blueQ5Root) -File -Filter '*.ps1'
)
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failures.Add("PowerShell syntax error: $($file.Name) :: $($errors[0].Message)")
    }
}

foreach ($relativePath in @('scripts/lmstudio/Load-ManagedModel.mjs', 'scripts/lmstudio/Test-ManagedModel.mjs')) {
    & node --check (Get-RepoPath $relativePath) 2>$null
    if ($LASTEXITCODE -ne 0) { $failures.Add("JavaScript syntax error: $relativePath") }
}

$invalidCases = @(
    @{ Script = 'scripts/lmstudio/Load-ManagedModel.mjs'; Args = @('--model-key', 'x', '--identifier', 'x', '--context', '65536', '--mtp-draft', '5') },
    @{ Script = 'scripts/lmstudio/Load-ManagedModel.mjs'; Args = @('--model-key', 'x', '--identifier', 'x', '--context', '65536', '--kv-k', 'q5') },
    @{ Script = 'scripts/lmstudio/Test-ManagedModel.mjs'; Args = @('--identifier', 'x', '--context', '65536', '--unknown-setting', 'x') }
)
foreach ($case in $invalidCases) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & node (Get-RepoPath $case.Script) @($case.Args) 2>&1 | Out-Null
    $caseExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($caseExitCode -eq 0) {
        $failures.Add("Managed helper accepted an invalid argument set: $($case.Script)")
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Qwen Vision profile loader tests failed with $($failures.Count) issue(s):" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host 'Qwen Vision profile loader tests passed: explicit profiles, selector mapping/Cancel, JS and PowerShell syntax, fail-closed arguments.' -ForegroundColor Green
exit 0
