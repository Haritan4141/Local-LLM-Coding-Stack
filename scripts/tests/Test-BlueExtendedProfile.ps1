[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Offline contract tests for the BLUE IQ4_XS Vision 256K Candidate.  This test
# intentionally imports a temporary copy of the manifest module so mutation
# cases cannot touch the repository's manifest or any host/runtime state.
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryRoot ('blue-extended-profile-' + [guid]::NewGuid().ToString('N'))
$manifestRoot = Join-Path $testRoot 'runtime-manifests'
$modulePath = Join-Path $testRoot 'Turbo.Common.psm1'
$candidatePath = Join-Path $manifestRoot 'BLUE-IQ4XS256K.json'
$moduleName = [System.IO.Path]::GetFileNameWithoutExtension($modulePath)
$passed = 0
$failed = 0

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Label
    )

    Assert-True -Condition $Text.Contains($Expected) -Message "${Label}: expected '$Expected'."
}

function Invoke-Pass {
    param([Parameter(Mandatory)][string]$Name)
    $script:passed++
    Write-Host "[PASS] $Name"
}

function Invoke-Fail {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Message
    )
    $script:failed++
    throw "$Name :: $Message"
}

function Get-ManifestCommand {
    $command = Get-Command -Name Get-TurboProfileManifest -ErrorAction Stop |
        Where-Object { $_.Source -eq $moduleName } |
        Select-Object -First 1
    if ($null -eq $command) {
        throw "Temporary Turbo.Common module did not export Get-TurboProfileManifest."
    }
    return $command
}

function Get-ExtendedMemoryCommand {
    $command = Get-Command -Name Assert-TurboExtendedMemory -ErrorAction Stop |
        Where-Object { $_.Source -eq $moduleName } |
        Select-Object -First 1
    if ($null -eq $command) {
        throw "Temporary Turbo.Common module did not export Assert-TurboExtendedMemory."
    }
    return $command
}

function Write-JsonUtf8 {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )

    $json = $Value | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-MutatedManifestRejection {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Mutator,
        [Parameter(Mandatory)]$ManifestCommand
    )

    $originalText = [System.IO.File]::ReadAllText($candidatePath)
    try {
        $mutated = $originalText | ConvertFrom-Json
        & $Mutator $mutated
        Write-JsonUtf8 -Value $mutated -Path $candidatePath
        $rejected = $false
        try {
            & $ManifestCommand -Profile 'BLUE-IQ4XS256K' | Out-Null
        }
        catch {
            $rejected = $true
        }
        Assert-True -Condition $rejected -Message "${Name}: mutated manifest was accepted."
        Invoke-Pass -Name $Name
    }
    finally {
        [System.IO.File]::WriteAllText($candidatePath, $originalText, [System.Text.UTF8Encoding]::new($false))
    }
}

function Remove-TestArtifacts {
    if (-not (Test-Path -LiteralPath $testRoot)) {
        return
    }
    $resolvedRoot = (Resolve-Path -LiteralPath $testRoot).Path
    if (-not $resolvedRoot.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean unexpected test path: $resolvedRoot"
    }
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}

try {
    $null = New-Item -ItemType Directory -Path $manifestRoot -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\standalone-turbo\Turbo.Common.psm1') -Destination $modulePath
    foreach ($manifestName in @('RTX5090.json', 'BLUE.json', 'RTX5090-Quick.json', 'BLUE-Quick.json', 'BLUE-IQ4XS256K.json')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\standalone-turbo\runtime-manifests\$manifestName") -Destination (Join-Path $manifestRoot $manifestName)
    }

    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    Import-Module -Name $modulePath -Force -DisableNameChecking
    $manifestCommand = Get-ManifestCommand
    $memoryCommand = Get-ExtendedMemoryCommand

    $candidate = & $manifestCommand -Profile 'BLUE-IQ4XS256K'
    Assert-True -Condition ($candidate.profile_class -eq 'extended-context') -Message 'Candidate profile class is not extended-context.'
    Assert-True -Condition ($candidate.status -eq 'Candidate') -Message 'Candidate status changed unexpectedly.'
    Assert-True -Condition ([int]$candidate.configuration.context_tokens -eq 262144) -Message 'Candidate context is not 262144.'
    Assert-True -Condition ([int]$candidate.configuration.ubatch_size -eq 256) -Message 'Candidate ubatch is not 256.'
    Assert-True -Condition ($candidate.configuration.kv_cache_k -eq 'q8_0' -and $candidate.configuration.kv_cache_v -eq 'q8_0') -Message 'Candidate KV cache is not Q8/Q8.'
    Assert-True -Condition ($candidate.configuration.mtp_enabled -eq $true -and [int]$candidate.configuration.mtp_draft_max_tokens -eq 3) -Message 'Candidate MTP3 settings are not pinned.'
    Assert-True -Condition ($candidate.configuration.mtp_draft_kv_k -eq 'f16' -and $candidate.configuration.mtp_draft_kv_v -eq 'f16') -Message 'Candidate MTP draft KV is not F16/F16.'
    Assert-True -Condition ($candidate.configuration.vision -eq $true) -Message 'Candidate Vision capability is not enabled.'
    Assert-True -Condition ($candidate.configuration.split_mode -eq 'layer' -and $candidate.configuration.tensor_split -eq '0.75,0.25') -Message 'Candidate tensor split is not 75:25 layer split.'
    Assert-True -Condition ($candidate.configuration.reasoning_mode -eq 'off' -and $candidate.configuration.reasoning_effort -eq 'default' -and [int]$candidate.configuration.reasoning_budget_tokens -eq 0) -Message 'Candidate reasoning policy is not off/default/zero budget.'
    Assert-True -Condition ($candidate.model.sha256 -eq '53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5') -Message 'Candidate model SHA is not pinned.'
    Assert-True -Condition ($candidate.model.projector_sha256 -eq '5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c') -Message 'Candidate projector SHA is not pinned.'
    Assert-True -Condition ($candidate.target_host.computer_name -eq 'DESKTOP-L9HAM1G' -and $candidate.target_host.ipv4 -eq '192.168.0.104' -and $candidate.target_host.ssh_alias -eq 'pc5700x') -Message 'Candidate BLUE host identity changed.'
    Assert-True -Condition ([int]$candidate.server.port -eq 18080 -and [int]$candidate.server.main_tunnel_port -eq 18081) -Message 'Candidate server/tunnel ports changed.'
    Assert-True -Condition ([int]$candidate.goose.client_context_tokens -eq 237568 -and [int]$candidate.goose.max_output_tokens -eq 16384) -Message 'Candidate Goose context/output contract changed.'
    Assert-True -Condition ([double]$candidate.goose.auto_compact_threshold -eq 0.6) -Message 'Candidate must use the user-approved60% compaction trial.'
    Assert-True -Condition ([int]$candidate.memory_gate.combined_shared_gib_strictly_below -eq 4 -and [int]$candidate.memory_gate.each_gpu_shared_gib_max -eq 2 -and [int]$candidate.memory_gate.each_gpu_free_mib_min -eq 1024) -Message 'Candidate memory gate is not strict 4GiB/2GiB/1GiB.'
    Invoke-Pass -Name 'BLUE-IQ4XS256K manifest accepted with pinned context, caches, MTP, Vision, split, provenance, and Goose limits'

    $oldProfiles = [ordered]@{
        'RTX5090' = 98304
        'BLUE' = 98304
        'RTX5090-Quick' = 65536
        'BLUE-Quick' = 65536
    }
    foreach ($oldProfile in $oldProfiles.GetEnumerator()) {
        $old = & $manifestCommand -Profile $oldProfile.Key
        Assert-True -Condition ([int]$old.configuration.ubatch_size -eq 512) -Message "$($oldProfile.Key) ubatch changed from the 512 baseline."
        Assert-True -Condition ([int]$old.configuration.context_tokens -eq $oldProfile.Value) -Message "$($oldProfile.Key) context changed unexpectedly."
        Assert-True -Condition ($old.configuration.kv_cache_k -eq 'q8_0' -and $old.configuration.kv_cache_v -eq 'q8_0') -Message "$($oldProfile.Key) KV cache changed from Q8/Q8."
        Assert-True -Condition ([int]$old.configuration.eval_batch_size -eq 1024 -and [int]$old.configuration.parallel -eq 1 -and $old.configuration.flash_attention -eq $true -and $old.configuration.dflash2 -eq $false) -Message "$($oldProfile.Key) common batch/parallel/flash settings changed."
        Assert-True -Condition ($old.configuration.vision -eq $true) -Message "$($oldProfile.Key) Vision setting changed unexpectedly."
    }
    Invoke-Pass -Name 'Existing four profiles preserve 512 ubatch and fixed baseline settings'

    Invoke-MutatedManifestRejection -Name 'Reject mutated/new wrong context' -ManifestCommand $manifestCommand -Mutator { param($m) $m.configuration.context_tokens = 131072 }
    Invoke-MutatedManifestRejection -Name 'Reject candidate ubatch 512' -ManifestCommand $manifestCommand -Mutator { param($m) $m.configuration.ubatch_size = 512 }
    Invoke-MutatedManifestRejection -Name 'Reject wrong tensor split' -ManifestCommand $manifestCommand -Mutator { param($m) $m.configuration.tensor_split = '0.50,0.50' }
    Invoke-MutatedManifestRejection -Name 'Reject Vision disabled' -ManifestCommand $manifestCommand -Mutator { param($m) $m.configuration.vision = $false }
    Invoke-MutatedManifestRejection -Name 'Reject changed model SHA' -ManifestCommand $manifestCommand -Mutator { param($m) $m.model.sha256 = (('0' * 64) -join '') }
    Invoke-MutatedManifestRejection -Name 'Reject wrong BLUE host' -ManifestCommand $manifestCommand -Mutator { param($m) $m.target_host.computer_name = 'DESKTOP-5NPLIIV' }
    Invoke-MutatedManifestRejection -Name 'Reject changed KV caches' -ManifestCommand $manifestCommand -Mutator { param($m) $m.configuration.kv_cache_k = 'q4_0'; $m.configuration.kv_cache_v = 'q4_0' }
    Invoke-MutatedManifestRejection -Name 'Reject changed Goose client output limit' -ManifestCommand $manifestCommand -Mutator { param($m) $m.goose.max_output_tokens = 8192 }
    Invoke-MutatedManifestRejection -Name 'Reject stale30% extended threshold' -ManifestCommand $manifestCommand -Mutator { param($m) $m.goose.auto_compact_threshold = 0.3 }
    Invoke-MutatedManifestRejection -Name 'Reject unapproved65% extended threshold' -ManifestCommand $manifestCommand -Mutator { param($m) $m.goose.auto_compact_threshold = 0.65 }

    # Execute only the actual launcher's isolated override-resolution block,
    # never its runtime preflight, environment mutations, or Start-Process.
    $launcherPath = Join-Path $repoRoot 'scripts\standalone-turbo\Start-Goose-ManagedTurbo.ps1'
    $parseTokens = $null
    $parseErrors = $null
    $launcherAst = [Management.Automation.Language.Parser]::ParseFile($launcherPath, [ref]$parseTokens, [ref]$parseErrors)
    Assert-True -Condition ($parseErrors.Count -eq 0) -Message 'Goose launcher syntax failed.'
    $blocks = @($launcherAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.IfStatementAst] -and
        $node.Extent.Text.Contains('$overrides[''GOOSE_AUTO_COMPACT_THRESHOLD''] =')
    }, $false))
    Assert-True -Condition ($blocks.Count -eq 1) -Message 'Expected one canonical compaction override block.'
    $overrideBlock = [scriptblock]::Create($blocks[0].Extent.Text)
    $savedCulture = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
        foreach ($cultureName in @('en-US', 'ja-JP', 'fr-FR')) {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($cultureName)
            foreach ($profileName in @('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick', 'BLUE-IQ4XS256K')) {
                $manifest = & $manifestCommand -Profile $profileName
                $overrides = [ordered]@{ GOOSE_AUTO_COMPACT_THRESHOLD = '0.3' }
                . $overrideBlock
                $expectedRate = if ($profileName -ceq 'BLUE-IQ4XS256K') { '0.6' } else { '0.3' }
                Assert-True -Condition ($overrides['GOOSE_AUTO_COMPACT_THRESHOLD'] -ceq $expectedRate) -Message "$profileName/$cultureName resolved wrong process-local threshold."
            }
        }
    }
    finally {
        [Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture
    }
    Invoke-Pass -Name 'Actual launcher block resolves60% for extended only; four old profiles30%; invariant decimal in three cultures'

    foreach ($oldProfile in $oldProfiles.Keys) {
        $old = & $manifestCommand -Profile $oldProfile
        $memoryResult = & $memoryCommand -Manifest $old
        Assert-True -Condition ($null -eq $memoryResult) -Message "$oldProfile would invoke the BLUE extended memory helper."
    }
    $commonText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts\standalone-turbo\Turbo.Common.psm1'))
    Assert-Contains -Text $commonText -Expected "if (`$Manifest.profile_class -ne 'extended-context') { return `$null }" -Label 'Extended memory guard'
    foreach ($oldProfile in @('RTX5090.json', 'BLUE.json', 'RTX5090-Quick.json', 'BLUE-Quick.json')) {
        $oldManifest = Get-Content -LiteralPath (Join-Path $repoRoot "scripts\standalone-turbo\runtime-manifests\$oldProfile") -Raw | ConvertFrom-Json
        Assert-True -Condition ($null -eq $oldManifest.PSObject.Properties['memory_gate']) -Message "$oldProfile unexpectedly declares extended memory gate."
    }
    Invoke-Pass -Name 'Existing profiles return before the extended BLUE memory helper'

    $loaderRoot = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\RTX3090\00-Daily-Profiles'
    $iq4Root = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\RTX3090\Qwen3.8-JonathanColetti-IQ4XS-Vision'
    foreach ($path in @(
        (Join-Path $loaderRoot 'Extended-Context.bat'),
        (Join-Path $loaderRoot 'Extended-Context_REMOTE.bat'),
        (Join-Path $iq4Root 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.bat'),
        (Join-Path $iq4Root 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K_REMOTE.bat'),
        (Join-Path $iq4Root 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.ps1'),
        (Join-Path $iq4Root 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K_REMOTE.ps1')
    )) {
        Assert-True -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message "Missing BLUE extended loader path: $path"
    }
    Assert-Contains -Text ([System.IO.File]::ReadAllText((Join-Path $loaderRoot 'Extended-Context.bat'))) -Expected 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K.bat' -Label 'Local extended wrapper'
    Assert-Contains -Text ([System.IO.File]::ReadAllText((Join-Path $loaderRoot 'Extended-Context_REMOTE.bat'))) -Expected 'Qwen3.8-JonathanColetti-IQ4XS-Vision_256K_REMOTE.bat' -Label 'Remote extended wrapper'
    foreach ($selectorName in @('Profile-Selector_LOCAL.bat', 'Profile-Selector_REMOTE.bat')) {
        $selectorText = [System.IO.File]::ReadAllText((Join-Path $loaderRoot $selectorName))
        Assert-Contains -Text $selectorText -Expected '"%PROFILE_CHOICE%"=="6" goto :extended' -Label "$selectorName choice 6"
        Assert-Contains -Text $selectorText -Expected 'Extended-Context' -Label "$selectorName extended wrapper"
    }
    Invoke-Pass -Name 'BLUE local/remote selector 6 and wrapper paths are present'

    $gooseSelectorText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts\goose\Goose-Daily-Profile-Selector.bat'))
    Assert-Contains -Text $gooseSelectorText -Expected 'BLUE-Extended256K16K' -Label 'Goose Daily selector 13'
    Assert-Contains -Text $gooseSelectorText -Expected '"%PROFILE_CHOICE%"=="13"' -Label 'Goose Daily selector 13 mapping'
    $gooseOrchestratorText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts\goose\Start-GooseDailyProfile.ps1'))
    foreach ($expected in @('BLUE-IQ4XS256K', 'BLUE-Extended256K16K', 'Extended-Context_REMOTE.bat', '237568', '16384', '18081')) {
        Assert-Contains -Text $gooseOrchestratorText -Expected $expected -Label 'Goose extended orchestrator'
    }
    $releaseText = [System.IO.File]::ReadAllText((Join-Path $repoRoot 'scripts\standalone-turbo\Release-ManagedRuntime.ps1'))
    Assert-Contains -Text $releaseText -Expected "'BLUE-IQ4XS256K'" -Label 'Release knownProfiles'
    Assert-Contains -Text $releaseText -Expected '-AllowNotRunning' -Label 'Release explicit stopped cleanup'
    Invoke-Pass -Name 'Goose selector 13, orchestrator values, and Release candidate knownProfiles are wired'

    if ($failed -gt 0) { throw "Offline BLUE extended profile tests failed: $failed" }
    Write-Host "BLUE extended profile offline tests: $passed passed"
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
