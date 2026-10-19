[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Offline contract tests for the MAIN RTX 5090 IQ4_XS Vision 256K Candidate.
# The manifest module and all manifests are copied to a temporary directory so
# mutation cases cannot edit repository files.  This test intentionally does
# not call lms, nvidia-smi, a loader, Goose, DeepSeek Harness, or any network
# endpoint.
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $tempRoot ('main-extended-profile-' + [guid]::NewGuid().ToString('N'))
$manifestRoot = Join-Path $testRoot 'runtime-manifests'
$modulePath = Join-Path $testRoot 'Turbo.Common.psm1'
$candidatePath = Join-Path $manifestRoot 'RTX5090-IQ4XS256K.json'
$moduleName = [IO.Path]::GetFileNameWithoutExtension($modulePath)
$passed = 0

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) { throw $Message }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Label
    )

    Assert-True -Condition ($Text.IndexOf($Expected, [StringComparison]::OrdinalIgnoreCase) -ge 0) `
        -Message "${Label}: expected '$Expected'."
}

function Invoke-Pass {
    param([Parameter(Mandatory)][string]$Name)
    $script:passed++
    Write-Host "[PASS] $Name"
}

function Write-JsonUtf8 {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )

    $json = $Value | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Invoke-MutatedManifestRejection {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Mutator,
        [Parameter(Mandatory)]$ManifestCommand
    )

    $originalText = [IO.File]::ReadAllText($candidatePath)
    try {
        $mutated = $originalText | ConvertFrom-Json
        & $Mutator $mutated
        Write-JsonUtf8 -Value $mutated -Path $candidatePath
        $rejected = $false
        try {
            & $ManifestCommand -Profile 'RTX5090-IQ4XS256K' | Out-Null
        }
        catch {
            $rejected = $true
        }
        Assert-True -Condition $rejected -Message "${Name}: mutated manifest was accepted."
        Invoke-Pass -Name $Name
    }
    finally {
        [IO.File]::WriteAllText($candidatePath, $originalText, [Text.UTF8Encoding]::new($false))
    }
}

function Remove-TestArtifacts {
    if (-not (Test-Path -LiteralPath $testRoot)) { return }
    $resolvedRoot = (Resolve-Path -LiteralPath $testRoot).Path
    if (-not $resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean unexpected test path: $resolvedRoot"
    }
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}

try {
    $null = New-Item -ItemType Directory -Path $manifestRoot -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\standalone-turbo\Turbo.Common.psm1') -Destination $modulePath
    foreach ($manifestName in @(
        'RTX5090.json',
        'BLUE.json',
        'RTX5090-Quick.json',
        'BLUE-Quick.json',
        'BLUE-IQ4XS256K.json',
        'RTX5090-IQ4XS256K.json'
    )) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\standalone-turbo\runtime-manifests\$manifestName") `
            -Destination (Join-Path $manifestRoot $manifestName)
    }

    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force -DisableNameChecking
    $manifestCommand = Get-Command -Name Get-TurboProfileManifest -ErrorAction Stop |
        Where-Object { $_.Source -eq $moduleName } |
        Select-Object -First 1
    Assert-True -Condition ($null -ne $manifestCommand) -Message 'Temporary Turbo.Common module did not export Get-TurboProfileManifest.'

    $main = & $manifestCommand -Profile 'RTX5090-IQ4XS256K'
    Assert-True -Condition ($main.profile_class -eq 'extended-context' -and $main.status -eq 'Candidate') `
        -Message 'MAIN IQ4_XS profile must remain an extended-context Candidate.'
    Assert-True -Condition ($main.profile_id -eq 'rtx5090-iq4xs-vision-256k-mtp3-candidate') `
        -Message 'MAIN IQ4_XS profile id is not pinned.'
    Assert-True -Condition ($main.target_host.computer_name -eq 'DESKTOP-5NPLIIV' -and $main.target_host.ipv4 -eq '192.168.0.100') `
        -Message 'MAIN target identity is not pinned.'
    Assert-True -Condition ($main.server.host -eq '127.0.0.1' -and [int]$main.server.port -eq 18080) `
        -Message 'MAIN candidate must use the isolated loopback port 18080.'
    Assert-True -Condition ($main.server.api_model_alias -eq 'qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o') `
        -Message 'MAIN candidate API model alias changed.'
    Assert-True -Condition ([int]$main.configuration.context_tokens -eq 262144 -and [int]$main.goose.client_context_tokens -eq 237568) `
        -Message 'MAIN candidate runtime/client context is not 256K/237568.'
    Assert-True -Condition ([int]$main.goose.max_output_tokens -eq 16384 -and [double]$main.goose.auto_compact_threshold -eq 0.6) `
        -Message 'MAIN candidate Goose output/compaction contract changed.'
    Assert-True -Condition ($main.configuration.vision -eq $true -and $main.configuration.mtp_enabled -eq $true -and
        [int]$main.configuration.mtp_draft_max_tokens -eq 3 -and $main.configuration.mtp_draft_kv_k -eq 'f16' -and
        $main.configuration.mtp_draft_kv_v -eq 'f16') `
        -Message 'MAIN candidate Vision/MTP3/F16 draft contract changed.'
    Assert-True -Condition ($main.configuration.kv_cache_k -eq 'q8_0' -and $main.configuration.kv_cache_v -eq 'q8_0' -and
        [int]$main.configuration.eval_batch_size -eq 1024 -and [int]$main.configuration.ubatch_size -eq 256 -and
        [int]$main.configuration.parallel -eq 1 -and $main.configuration.flash_attention -eq $true -and
        $main.configuration.dflash2 -eq $false) `
        -Message 'MAIN candidate Q8/batch1024/ubatch256/parallel1 contract changed.'
    Assert-True -Condition ($main.configuration.load_mode -eq 'mmap+mlock' -and $null -eq $main.configuration.split_mode -and
        $null -eq $main.configuration.tensor_split -and $main.configuration.jinja -eq $true -and
        $main.configuration.prompt_cache -eq $true -and [int]$main.configuration.cache_reuse_min_tokens -eq 0) `
        -Message 'MAIN candidate single-GPU/cache contract changed.'
    Assert-True -Condition ($main.configuration.reasoning_mode -eq 'off' -and $main.configuration.reasoning_effort -eq 'default' -and
        [int]$main.configuration.reasoning_budget_tokens -eq 0 -and $main.configuration.reasoning_preserve -eq $false) `
        -Message 'MAIN candidate reasoning-off contract changed.'
    Assert-True -Condition ($main.runtime.source_commit -eq 'f280b26983ad0fdb705a0d9ebf0503e76f2899b0' -and
        $main.runtime.executable_expected_sha256 -eq '103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5' -and
        $main.model.sha256 -eq '53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5' -and
        $main.model.projector_sha256 -eq '5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c') `
        -Message 'MAIN candidate runtime/model/projector provenance changed.'
    Assert-True -Condition ($main.memory_gate.probe -eq 'Read-MainExtendedMemory.py' -and
        [int]$main.memory_gate.combined_shared_gib_strictly_below -eq 4 -and
        [int]$main.memory_gate.each_gpu_shared_gib_max -eq 2 -and
        [int]$main.memory_gate.each_gpu_free_mib_min -eq 1024 -and
        @($main.gpus).Count -eq 1 -and $main.gpus[0].name -eq 'NVIDIA GeForce RTX 5090' -and
        $main.gpus[0].pci_bus_id -eq '00000000:01:00.0' -and [int]$main.gpus[0].power_limit_w -eq 402) `
        -Message 'MAIN candidate memory gate/GPU identity contract changed.'
    Invoke-Pass -Name 'MAIN IQ4_XS Vision 256K manifest accepted with pinned identity, runtime, Vision, MTP, Goose, and memory gate'

    # Preserve the contracts of all five profiles that existed before the MAIN
    # extended Candidate was added.  These assertions are intentionally
    # read-only and do not run any profile loader.
    $oldProfiles = @(
        [pscustomobject]@{ Name = 'RTX5090'; Class = 'turbo'; Context = 98304; Ubatch = 512; Host = 'DESKTOP-5NPLIIV'; Vision = $true; Draft = 3 },
        [pscustomobject]@{ Name = 'BLUE'; Class = 'turbo'; Context = 98304; Ubatch = 512; Host = 'DESKTOP-L9HAM1G'; Vision = $true; Draft = 3 },
        [pscustomobject]@{ Name = 'RTX5090-Quick'; Class = 'quick-response'; Context = 65536; Ubatch = 512; Host = 'DESKTOP-5NPLIIV'; Vision = $true; Draft = 1 },
        [pscustomobject]@{ Name = 'BLUE-Quick'; Class = 'quick-response'; Context = 65536; Ubatch = 512; Host = 'DESKTOP-L9HAM1G'; Vision = $true; Draft = 1 },
        [pscustomobject]@{ Name = 'BLUE-IQ4XS256K'; Class = 'extended-context'; Context = 262144; Ubatch = 256; Host = 'DESKTOP-L9HAM1G'; Vision = $true; Draft = 3 }
    )
    foreach ($expected in $oldProfiles) {
        $profile = & $manifestCommand -Profile $expected.Name
        Assert-True -Condition ($profile.profile_class -eq $expected.Class -and
            [int]$profile.configuration.context_tokens -eq $expected.Context -and
            [int]$profile.configuration.ubatch_size -eq $expected.Ubatch -and
            $profile.target_host.computer_name -eq $expected.Host -and
            $profile.configuration.vision -eq $expected.Vision -and
            $profile.configuration.mtp_enabled -eq $true -and
            [int]$profile.configuration.mtp_draft_max_tokens -eq $expected.Draft -and
            $profile.configuration.kv_cache_k -eq 'q8_0' -and $profile.configuration.kv_cache_v -eq 'q8_0' -and
            [int]$profile.configuration.eval_batch_size -eq 1024 -and [int]$profile.configuration.parallel -eq 1 -and
            $profile.configuration.flash_attention -eq $true -and $profile.configuration.dflash2 -eq $false) `
            -Message "$($expected.Name) changed its pre-existing profile contract."
    }
    Invoke-Pass -Name 'Existing RTX5090/BLUE/Quick/IQ4_XS profiles preserve their pre-existing contracts'

    Invoke-MutatedManifestRejection -Name 'Reject mutated MAIN host identity' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.target_host.computer_name = 'DESKTOP-L9HAM1G' }
    Invoke-MutatedManifestRejection -Name 'Reject mutated MAIN context' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.configuration.context_tokens = 131072 }
    Invoke-MutatedManifestRejection -Name 'Reject Vision disabled' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.configuration.vision = $false }
    Invoke-MutatedManifestRejection -Name 'Reject changed model SHA' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.model.sha256 = (('0' * 64) -join '') }
    Invoke-MutatedManifestRejection -Name 'Reject changed projector SHA' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.model.projector_sha256 = (('0' * 64) -join '') }
    Invoke-MutatedManifestRejection -Name 'Reject MAIN ubatch 512' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.configuration.ubatch_size = 512 }
    Invoke-MutatedManifestRejection -Name 'Reject changed KV cache' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.configuration.kv_cache_k = 'q4_0'; $m.configuration.kv_cache_v = 'q4_0' }
    Invoke-MutatedManifestRejection -Name 'Reject stale 30 percent compaction threshold' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.goose.auto_compact_threshold = 0.3 }
    Invoke-MutatedManifestRejection -Name 'Reject mutated MAIN memory gate' -ManifestCommand $manifestCommand `
        -Mutator { param($m) $m.memory_gate.combined_shared_gib_strictly_below = 5 }
    Invoke-Pass -Name 'MAIN identity/context/Vision/SHA/ubatch/KV/threshold/memory mutations fail closed'

    $selectorPath = Join-Path $repoRoot 'scripts\goose\Goose-Daily-Profile-Selector.bat'
    $selectorText = [IO.File]::ReadAllText($selectorPath)
    Assert-Contains -Text $selectorText -Expected 'MAIN-Extended256K16K' -Label 'Goose Daily MAIN extended profile name'
    Assert-Contains -Text $selectorText -Expected '"%PROFILE_CHOICE%"=="14"' -Label 'Goose Daily selector 14 mapping'
    Invoke-Pass -Name 'Goose Daily selector 14 maps to MAIN-Extended256K16K'

    $gooseOrchestratorPath = Join-Path $repoRoot 'scripts\goose\Start-GooseDailyProfile.ps1'
    $gooseOrchestratorText = [IO.File]::ReadAllText($gooseOrchestratorPath)
    foreach ($expectedText in @('MAIN-Extended256K16K', 'RTX5090-IQ4XS256K', 'Extended-Context.bat', '237568', '16384')) {
        Assert-Contains -Text $gooseOrchestratorText -Expected $expectedText -Label 'Goose MAIN extended orchestrator'
    }
    Invoke-Pass -Name 'Goose MAIN extended profile is wired to the managed RTX5090 candidate'

    $mainDailyRoot = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\RTX5090\00-Daily-Profiles'
    $mainExtendedWrapper = Join-Path $mainDailyRoot 'Extended-Context.bat'
    Assert-True -Condition (Test-Path -LiteralPath $mainExtendedWrapper -PathType Leaf) -Message "Missing MAIN extended wrapper: $mainExtendedWrapper"
    $wrapperText = [IO.File]::ReadAllText($mainExtendedWrapper)
    Assert-Contains -Text $wrapperText -Expected 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.bat' -Label 'MAIN extended model wrapper'
    $modelLoaderPath = Join-Path $mainDailyRoot '..\Qwen3.8-JonathanColetti-IQ4XS-Vision\Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.ps1'
    Assert-True -Condition (Test-Path -LiteralPath $modelLoaderPath -PathType Leaf) -Message "Missing MAIN extended model loader: $modelLoaderPath"
    $modelLoaderText = [IO.File]::ReadAllText($modelLoaderPath)
    Assert-Contains -Text $modelLoaderText -Expected 'Start-ManagedTurbo.ps1' -Label 'MAIN extended managed launcher'
    Assert-Contains -Text $modelLoaderText -Expected '-Profile ''RTX5090-IQ4XS256K''' -Label 'MAIN extended managed profile'
    Invoke-Pass -Name 'MAIN Daily Extended-Context wrapper references the IQ4_XS Vision 256K loader and managed profile'

    # Exercise the real root entry, selector, and Extended-Context wrapper in
    # an isolated copy. Every leaf BAT is a nonce/exit-code stub; neither the
    # real model BAT nor any PowerShell runtime loader is copied or executed.
    $cloneRoot = Join-Path $testRoot 'loader navigation with spaces'
    $cloneDaily = Join-Path $cloneRoot 'RTX5090\00-Daily-Profiles'
    $cloneModel = Join-Path $cloneRoot 'RTX5090\Qwen3.8-JonathanColetti-IQ4XS-Vision'
    $null = New-Item -ItemType Directory -Path $cloneDaily -Force
    $null = New-Item -ItemType Directory -Path $cloneModel -Force
    $cloneEntry = Join-Path $cloneRoot '00-RTX5090-Daily-Profiles.bat'
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\lmstudio\model-loaders\00-RTX5090-Daily-Profiles.bat') -Destination $cloneEntry
    Copy-Item -LiteralPath (Join-Path $mainDailyRoot 'Profile-Selector.bat') -Destination (Join-Path $cloneDaily 'Profile-Selector.bat')
    Copy-Item -LiteralPath $mainExtendedWrapper -Destination (Join-Path $cloneDaily 'Extended-Context.bat')
    $stubLeaves = @('1-Stable.bat', '2-Turbo.bat', 'Quick-Response.bat', '3-Quality-Reference.bat', '4-Release.bat')
    for ($index = 0; $index -lt $stubLeaves.Count; $index++) {
        $choice = $index + 1
        $stub = "@echo off`r`necho MOCK_DAILY_$choice`r`nexit /b $(40 + $choice)`r`n"
        [IO.File]::WriteAllText((Join-Path $cloneDaily $stubLeaves[$index]), $stub, [Text.UTF8Encoding]::new($false))
    }
    [IO.File]::WriteAllText((Join-Path $cloneModel 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.bat'),
        "@echo off`r`necho MOCK_MAIN_IQ4XS256K`r`nexit /b 46`r`n", [Text.UTF8Encoding]::new($false))

    $runtimeSelectorText = [IO.File]::ReadAllText((Join-Path $mainDailyRoot 'Profile-Selector.bat'))
    Assert-Contains -Text $runtimeSelectorText -Expected '[6] Extended Context - IQ4XS Vision 256K' -Label 'MAIN runtime menu entry'
    Assert-Contains -Text $runtimeSelectorText -Expected '"%PROFILE_CHOICE%"=="6" goto :extended' -Label 'MAIN runtime choice 6 dispatch'
    Invoke-Pass -Name 'MAIN runtime menu advertises IQ4_XS Vision 256K at choice 6'

    $navigationCases = @(
        [pscustomobject]@{ Argument = '0'; Input = $null; Code = 0; Marker = $null; Name = 'Cancel leaves every mock leaf untouched' },
        [pscustomobject]@{ Argument = '1'; Input = $null; Code = 41; Marker = 'MOCK_DAILY_1'; Name = 'Stable mapping and exit code preserved' },
        [pscustomobject]@{ Argument = '2'; Input = $null; Code = 42; Marker = 'MOCK_DAILY_2'; Name = 'Turbo mapping and exit code preserved' },
        [pscustomobject]@{ Argument = '3'; Input = $null; Code = 43; Marker = 'MOCK_DAILY_3'; Name = 'Quick mapping and exit code preserved' },
        [pscustomobject]@{ Argument = '4'; Input = $null; Code = 44; Marker = 'MOCK_DAILY_4'; Name = 'Quality mapping and exit code preserved' },
        [pscustomobject]@{ Argument = '5'; Input = $null; Code = 45; Marker = 'MOCK_DAILY_5'; Name = 'Release mapping and exit code preserved' },
        [pscustomobject]@{ Argument = '6'; Input = $null; Code = 46; Marker = 'MOCK_MAIN_IQ4XS256K'; Name = 'Root choice 6 reaches canonical MAIN model BAT through Extended wrapper' },
        [pscustomobject]@{ Argument = 'invalid'; Input = $null; Code = 2; Marker = $null; Name = 'Invalid selection fails without touching a leaf' },
        [pscustomobject]@{ Argument = ''; Input = '6'; Code = 46; Marker = 'MOCK_MAIN_IQ4XS256K'; Name = 'Interactive choice 6 reaches canonical MAIN model BAT' }
    )
    foreach ($case in $navigationCases) {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $env:ComSpec
        $startInfo.Arguments = '/d /q /c call "' + $cloneEntry + '" ' + $case.Argument
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.RedirectStandardInput = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            $null = $process.Start()
            if ($null -ne $case.Input) { $process.StandardInput.WriteLine($case.Input) }
            $process.StandardInput.Close()
            Assert-True -Condition ($process.WaitForExit(10000)) -Message "Navigation mock timed out: $($case.Name)"
            $output = $process.StandardOutput.ReadToEnd()
            $errorText = $process.StandardError.ReadToEnd()
            Assert-True -Condition ($process.ExitCode -eq $case.Code -and [string]::IsNullOrWhiteSpace($errorText)) -Message "Navigation mock failed: $($case.Name)"
            # SET /P leaves its prompt on the nonce line for redirected input.
            $markers = @([regex]::Matches($output, '(?m)^(?:Select profile: )?(MOCK_[A-Z0-9_]+)\r?$') | ForEach-Object { $_.Groups[1].Value })
            if ($null -eq $case.Marker) {
                Assert-True -Condition ($markers.Count -eq 0) -Message "Unexpected leaf executed: $($case.Name)"
            }
            else {
                Assert-True -Condition ($markers.Count -eq 1 -and $markers[0] -eq $case.Marker) -Message "Wrong or repeated leaf executed: $($case.Name)"
            }
            Invoke-Pass -Name $case.Name
        }
        finally {
            # Only the test-owned mock CMD may be stopped on a failed timeout.
            if ($process.Id -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $process.Dispose()
        }
    }

    Write-Host "MAIN extended profile offline tests: $passed passed" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
finally {
    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    Remove-TestArtifacts
}
