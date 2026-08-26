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
$mainDailyRoot = 'scripts/lmstudio/model-loaders/RTX5090/00-Daily-Profiles'
$blueDailyRoot = 'scripts/lmstudio/model-loaders/RTX3090/00-Daily-Profiles'
$turboRoot = 'scripts/standalone-turbo'
$requiredPaths = @(
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat",
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat",
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat",
    "$mainRoot/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat",
    "$mainQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K.bat",
    "$mainQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat",
    "$mainQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat",
    "$mainQ5Root/Start-Goose-Jonathan-Q5KM-Vision96K-Turbo.ps1",
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
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_REMOTE.ps1",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable.bat",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.ps1",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable_REMOTE.bat",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.bat",
    "$blueQ5Root/Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.ps1",
    "$blueQ5Root/Start-Goose-Jonathan-Q5KM-Vision96K-BLUE-Turbo_REMOTE.ps1",
    "$turboRoot/Turbo.Common.psm1",
    "$turboRoot/Install-ManagedTurboRuntime.ps1",
    "$turboRoot/Start-ManagedTurbo.ps1",
    "$turboRoot/Stop-ManagedTurbo.ps1",
    "$turboRoot/Release-ManagedRuntime.ps1",
    "$turboRoot/Test-ManagedTurbo.ps1",
    "$turboRoot/Start-BlueManagedTurboRemote.ps1",
    "$turboRoot/Stop-BlueManagedTurboRemote.ps1",
    "$turboRoot/Release-BlueManagedRuntimeRemote.ps1",
    "$turboRoot/Start-Goose-ManagedTurbo.ps1",
    "$turboRoot/Invoke-GooseTurboLongOutputQualification.ps1",
    "$turboRoot/Invoke-ManagedTurboSmoke.ps1",
    "$turboRoot/README.md",
    "$turboRoot/runtime-manifests/RTX5090.json",
    "$turboRoot/runtime-manifests/BLUE.json",
    'scripts/tests/Test-StandaloneTurboFailClosed.ps1',
    'benchmarks/results/2026-08-25-standalone-mtp3-turbo-integration.md',
    'benchmarks/results/2026-08-26-goose-turbo-output32k-qualification.md',
    'scripts/lmstudio/model-loaders/README.md',
    'scripts/lmstudio/model-loaders/00-RTX5090-Daily-Profiles.bat',
    'scripts/lmstudio/model-loaders/00-BLUE-Daily-Profiles-LOCAL.bat',
    'scripts/lmstudio/model-loaders/00-BLUE-Daily-Profiles-REMOTE.bat',
    "$mainDailyRoot/README.md",
    "$mainDailyRoot/1-Stable.bat",
    "$mainDailyRoot/2-Turbo.bat",
    "$mainDailyRoot/3-Quality-Reference.bat",
    "$mainDailyRoot/4-Release.bat",
    "$mainDailyRoot/Profile-Selector.bat",
    "$blueDailyRoot/README.md",
    "$blueDailyRoot/1-Stable.bat",
    "$blueDailyRoot/2-Turbo.bat",
    "$blueDailyRoot/3-Quality-Reference.bat",
    "$blueDailyRoot/4-Release.bat",
    "$blueDailyRoot/Profile-Selector_LOCAL.bat",
    "$blueDailyRoot/1-Stable_REMOTE.bat",
    "$blueDailyRoot/2-Turbo_REMOTE.bat",
    "$blueDailyRoot/3-Quality-Reference_REMOTE.bat",
    "$blueDailyRoot/4-Release_REMOTE.bat",
    "$blueDailyRoot/Profile-Selector_REMOTE.bat",
    'profiles/Qwen3.8-Daily-Profiles.md'
)
foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Get-RepoPath $relativePath) -PathType Leaf)) {
        $failures.Add("Missing profile loader path: $relativePath")
    }
}

$turboGooseLauncher = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Start-Goose-ManagedTurbo.ps1") -Raw
$turboGooseQualification = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Invoke-GooseTurboLongOutputQualification.ps1") -Raw
foreach ($check in @(
    @{ Text = $turboGooseLauncher; Pattern = '\[ValidateSet\(16384, 32768\)\]\[int\]\$MaxOutputTokens = 16384'; Description = 'Turbo Goose 16K default with explicit 32K allowance' },
    @{ Text = $turboGooseLauncher; Pattern = "GOOSE_MAX_TOKENS = \[string\]\`$MaxOutputTokens"; Description = 'Turbo Goose process-local dynamic output limit' },
    @{ Text = $turboGooseQualification; Pattern = 'MinimumOutputTokens = 17000'; Description = 'Turbo Goose 17K qualification gate' },
    @{ Text = $turboGooseQualification; Pattern = 'full_sequence_valid'; Description = 'Turbo Goose full sequence evidence' },
    @{ Text = $turboGooseQualification; Pattern = 'persistent_config_unchanged'; Description = 'Turbo Goose persistent config preservation evidence' }
)) {
    Assert-Contains -Text $check.Text -Pattern $check.Pattern -Description $check.Description
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
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Stable.bat',
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_Turbo.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_Coding-Fast.bat'
    )
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_Profile-Selector.bat" = @(
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable.bat',
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance.bat'
    )
    "$blueRoot/Qwen3.8-JonathanColetti-Q6K-Vision_REMOTE-Profile-Selector.bat" = @(
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Stable_REMOTE.bat',
        '..\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W_Turbo_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Coding-Fast_REMOTE.bat',
        'Qwen3.8-JonathanColetti-Q6K-Vision_64K_370W-Performance_REMOTE.bat'
    )
    "$mainDailyRoot/Profile-Selector.bat" = @(
        '1-Stable.bat',
        '2-Turbo.bat',
        '3-Quality-Reference.bat',
        '4-Release.bat'
    )
    "$blueDailyRoot/Profile-Selector_LOCAL.bat" = @(
        '1-Stable.bat',
        '2-Turbo.bat',
        '3-Quality-Reference.bat',
        '4-Release.bat'
    )
    "$blueDailyRoot/Profile-Selector_REMOTE.bat" = @(
        '1-Stable_REMOTE.bat',
        '2-Turbo_REMOTE.bat',
        '3-Quality-Reference_REMOTE.bat',
        '4-Release_REMOTE.bat'
    )
}
foreach ($entry in $selectorExpectations.GetEnumerator()) {
    $selectorPath = Get-RepoPath $entry.Key
    $selectorText = Get-Content -LiteralPath $selectorPath -Raw
    $calls = @([regex]::Matches($selectorText, '(?im)^call "%~dp0([^"\r\n]+\.bat)"\r?$') | ForEach-Object { $_.Groups[1].Value })
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

$dailyQualityChecks = @(
    @{ Path = "$mainDailyRoot/3-Quality-Reference.bat"; Patterns = @('Stop-ManagedTurbo.ps1', '-Profile RTX5090 -AllowNotRunning', 'Qwen3.8-JonathanColetti-Q6K-Vision_64K_Balanced.bat') },
    @{ Path = "$blueDailyRoot/3-Quality-Reference.bat"; Patterns = @('Stop-ManagedTurbo.ps1', '-Profile BLUE -AllowNotRunning', 'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced.bat') },
    @{ Path = "$blueDailyRoot/3-Quality-Reference_REMOTE.bat"; Patterns = @('Stop-BlueManagedTurboRemote.ps1', '-AllowNotRunning', 'Qwen3.8-JonathanColetti-Q6K-Vision_64K_259W-Balanced_REMOTE.bat') }
)
foreach ($check in $dailyQualityChecks) {
    $text = Get-Content -LiteralPath (Get-RepoPath $check.Path) -Raw
    foreach ($pattern in $check.Patterns) {
        if ($text.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $failures.Add("Daily Quality wrapper is missing '$pattern': $($check.Path)")
        }
    }
    if ($text -notmatch '(?im)^set "RC=%ERRORLEVEL%"\r?$' -or $text -notmatch '(?im)^\s*exit /b %RC%\r?$') {
        $failures.Add("Daily Quality wrapper does not preserve stop failure: $($check.Path)")
    }
}

$powerShellFiles = @(
    Get-Item -LiteralPath (Get-RepoPath "$mainQ5Root/Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.ps1")
    Get-Item -LiteralPath (Get-RepoPath "$mainQ5Root/Start-Goose-Jonathan-Q5KM-Vision96K-Turbo.ps1")
    Get-ChildItem -LiteralPath (Get-RepoPath $blueRoot) -File -Filter '*.ps1'
    Get-ChildItem -LiteralPath (Get-RepoPath $blueQ5Root) -File -Filter '*.ps1'
    Get-ChildItem -LiteralPath (Get-RepoPath $turboRoot) -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') }
)
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failures.Add("PowerShell syntax error: $($file.Name) :: $($errors[0].Message)")
    }
}

$mainTurboManifest = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/runtime-manifests/RTX5090.json") -Raw | ConvertFrom-Json
$blueTurboManifest = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/runtime-manifests/BLUE.json") -Raw | ConvertFrom-Json
foreach ($entry in @(
    [pscustomobject]@{ profile = $mainTurboManifest; host = 'DESKTOP-5NPLIIV'; sha = '103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5'; alias = 'qwen3.8-27b-uncensored-vision-q5km-turbo' },
    [pscustomobject]@{ profile = $blueTurboManifest; host = 'DESKTOP-L9HAM1G'; sha = '970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4'; alias = 'qwen3.8-27b-uncensored-vision-q5km-blue-turbo' }
)) {
    $profile = $entry.profile
    if ($profile.runtime.source_commit -ne 'f280b26983ad0fdb705a0d9ebf0503e76f2899b0' -or
        $profile.runtime.executable_expected_sha256 -ne $entry.sha -or
        $profile.target_host.computer_name -ne $entry.host -or
        $profile.server.host -ne '127.0.0.1' -or [int]$profile.server.port -ne 18080 -or
        $profile.server.api_model_alias -ne $entry.alias -or
        [int]$profile.configuration.context_tokens -ne 98304 -or
        $profile.configuration.kv_cache_k -ne 'q8_0' -or $profile.configuration.kv_cache_v -ne 'q8_0' -or
        [int]$profile.configuration.mtp_draft_max_tokens -ne 3 -or
        [int]$profile.configuration.eval_batch_size -ne 1024 -or
        [int]$profile.configuration.ubatch_size -ne 512 -or
        [int]$profile.configuration.parallel -ne 1 -or
        $profile.configuration.vision -ne $true -or $profile.configuration.dflash2 -ne $false) {
        $failures.Add("Standalone Turbo runtime manifest is not pinned to the qualified profile: $($entry.host)")
    }
}
if ([int]$blueTurboManifest.server.main_tunnel_port -ne 18081 -or
    $blueTurboManifest.configuration.split_mode -ne 'layer' -or
    $blueTurboManifest.configuration.tensor_split -ne '0.7108,0.2892' -or
    $blueTurboManifest.configuration.load_mode -ne 'no-mmap') {
    $failures.Add('BLUE Turbo manifest does not preserve tunnel18081/layer split/0.7108,0.2892/no-mmap.')
}

$turboStart = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Start-ManagedTurbo.ps1") -Raw
$turboStop = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Stop-ManagedTurbo.ps1") -Raw
$runtimeRelease = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Release-ManagedRuntime.ps1") -Raw
$blueRemoteStart = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Start-BlueManagedTurboRemote.ps1") -Raw
$blueRemoteStop = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Stop-BlueManagedTurboRemote.ps1") -Raw
$blueRemoteRelease = Get-Content -LiteralPath (Get-RepoPath "$turboRoot/Release-BlueManagedRuntimeRemote.ps1") -Raw
foreach ($check in @(
    @{ Text = $turboStart; Pattern = [regex]::Escape("'--ctx-size', [string]`$manifest.configuration.context_tokens"); Description = 'Turbo context argument' },
    @{ Text = $turboStart; Pattern = [regex]::Escape("'--batch-size', [string]`$manifest.configuration.eval_batch_size"); Description = 'Turbo batch argument' },
    @{ Text = $turboStart; Pattern = [regex]::Escape("'--ubatch-size', [string]`$manifest.configuration.ubatch_size"); Description = 'Turbo ubatch argument' },
    @{ Text = $turboStart; Pattern = [regex]::Escape("'--spec-type', 'draft-mtp'"); Description = 'Turbo target-contained MTP' },
    @{ Text = $turboStart; Pattern = [regex]::Escape("'--tensor-split', [string]`$manifest.configuration.tensor_split"); Description = 'BLUE qualified tensor split' },
    @{ Text = $turboStart; Pattern = 'Assert-TurboLmsIdle'; Description = 'LM Studio active/queued protection' },
    @{ Text = $turboStart; Pattern = 'executable_expected_sha256'; Description = 'runtime SHA startup validation' },
    @{ Text = $turboStart; Pattern = 'model\.sha256'; Description = 'model SHA startup validation' },
    @{ Text = $turboStart; Pattern = 'projector_sha256'; Description = 'projector SHA startup validation' },
    @{ Text = $turboStop; Pattern = 'Assert-ManagedTurboProcess'; Description = 'PID/path/command/port stop validation' },
    @{ Text = $runtimeRelease; Pattern = 'Assert-TurboLmsIdle'; Description = 'Release active/queued LM Studio protection' },
    @{ Text = $runtimeRelease; Pattern = 'Assert-ManagedTurboProcess'; Description = 'Release managed Turbo ownership validation' },
    @{ Text = $runtimeRelease; Pattern = '/slots'; Description = 'Release active Turbo prediction protection' },
    @{ Text = $runtimeRelease; Pattern = [regex]::Escape('$slotResponse | ForEach-Object { $_ }'); Description = 'Windows PowerShell 5.1 slot-array flattening' },
    @{ Text = $runtimeRelease; Pattern = [regex]::Escape('lms unload --all'); Description = 'Release LM Studio unload operation' },
    @{ Text = $blueRemoteStart; Pattern = [regex]::Escape('127.0.0.1:${localPort}:127.0.0.1:'); Description = 'BLUE localhost SSH forward' },
    @{ Text = $blueRemoteStart; Pattern = 'ExitOnForwardFailure=yes'; Description = 'SSH forward fail-closed option' },
    @{ Text = $blueRemoteStop; Pattern = 'is not the managed BLUE Turbo tunnel'; Description = 'unknown SSH PID protection' },
    @{ Text = $blueRemoteRelease; Pattern = [regex]::Escape("`$sshAlias = [string]`$manifest.target_host.ssh_alias"); Description = 'BLUE release manifest SSH alias' },
    @{ Text = $blueRemoteRelease; Pattern = [regex]::Escape("`$expectedIp = [string]`$manifest.target_host.ipv4"); Description = 'BLUE release expected IPv4' },
    @{ Text = $blueRemoteRelease; Pattern = 'is not the managed BLUE Turbo tunnel'; Description = 'BLUE release unknown tunnel protection' },
    @{ Text = $blueRemoteRelease; Pattern = 'Release-ManagedRuntime\.ps1'; Description = 'BLUE remote managed release helper' },
    @{ Text = $blueRemoteRelease; Pattern = [regex]::Escape('$remoteModelResponse | ForEach-Object { $_ }'); Description = 'Windows PowerShell 5.1 remote lms array flattening' }
)) {
    Assert-Contains @check
}
foreach ($text in @($turboStart, $turboStop, $runtimeRelease, $blueRemoteStart, $blueRemoteStop, $blueRemoteRelease)) {
    if ($text -match '(?i)New-NetFirewallRule|Set-NetFirewallRule|netsh\s+advfirewall|New-Service|Set-Service|schtasks|dflash2') {
        $failures.Add('Standalone Turbo helper contains a forbidden Firewall/service/autostart/DFlash2 operation.')
    }
    if ($text -match '(?i)Stop-Process\s+-Name|taskkill') {
        $failures.Add('Standalone Turbo helper contains a broad process-kill operation.')
    }
}

$dailyReleaseChecks = @(
    @{ Path = "$mainDailyRoot/4-Release.bat"; Patterns = @('Release-ManagedRuntime.ps1', '-Profile RTX5090') },
    @{ Path = "$blueDailyRoot/4-Release.bat"; Patterns = @('Release-ManagedRuntime.ps1', '-Profile BLUE') },
    @{ Path = "$blueDailyRoot/4-Release_REMOTE.bat"; Patterns = @('Release-BlueManagedRuntimeRemote.ps1') }
)
foreach ($check in $dailyReleaseChecks) {
    $text = Get-Content -LiteralPath (Get-RepoPath $check.Path) -Raw
    foreach ($pattern in $check.Patterns) {
        if ($text.IndexOf($pattern, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $failures.Add("Daily Release wrapper is missing '$pattern': $($check.Path)")
        }
    }
    if ($text -notmatch '(?im)^set "RC=%ERRORLEVEL%"\r?$' -or $text -notmatch '(?im)^\s*exit /b %RC%\r?$') {
        $failures.Add("Daily Release wrapper does not preserve failure: $($check.Path)")
    }
    foreach ($safetyPattern in @('release-logs', 'type "%LOG_FILE%"', 'pause')) {
        if ($text.IndexOf($safetyPattern, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $failures.Add("Daily Release wrapper is missing error visibility '$safetyPattern': $($check.Path)")
        }
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
