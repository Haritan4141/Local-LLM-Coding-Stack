[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$turboRoot = Join-Path $repoRoot 'scripts\standalone-turbo'
$commonPath = Join-Path $turboRoot 'Turbo.Common.psm1'
Import-Module $commonPath -Force

function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$startText = Get-Content -LiteralPath (Join-Path $turboRoot 'Start-ManagedTurbo.ps1') -Raw
$releaseText = Get-Content -LiteralPath (Join-Path $turboRoot 'Release-ManagedRuntime.ps1') -Raw
Assert-Test ($startText.Contains('Enter-TurboOperationLock') -and $startText.Contains('Exit-TurboOperationLock')) 'Start path is missing the operation lock lifecycle.'
Assert-Test ($startText.Contains('-ExpectedProcessId $process.Id')) 'Start failure cleanup is not bound to its own PID.'
Assert-Test ($releaseText.Contains('-Profile $resolvedProfile -AllowNotRunning') -and
    $releaseText.Contains("'-Profile', `$resolvedProfile")) 'Release does not pass the detected Turbo/Quick profile to Stop.'
Assert-Test ($releaseText.Contains('AllowLegacyQuickTextOnly') -and $releaseText.Contains("IndexOf('--no-mmproj'")) 'Release is missing the bounded legacy Quick-to-Vision transition.'
Assert-Test ($releaseText.Contains('Test-TurboLegacyApiAlias') -and $releaseText.Contains("'-AllowLegacyApiAlias'")) 'Release is missing the bounded legacy Quick alias transition.'

$quickManifest = Get-TurboProfileManifest -Profile 'RTX5090-Quick'
Assert-Test ($quickManifest.server.api_model_alias -eq 'qwen3.8-27b-uncensored-vision-q5km-quick-gpt-4o') 'Quick does not use the friendly local alias with the Goose v1.49 canonical Vision suffix.'
Assert-Test (Test-TurboLegacyApiAlias -Manifest $quickManifest -Alias 'gpt-4o') 'The prior canonical-only Quick alias was not recognized for migration.'
Assert-Test (Test-TurboLegacyApiAlias -Manifest $quickManifest -Alias 'qwen3.8-27b-uncensored-q5km-quick') 'Declared legacy Quick alias was not recognized.'
Assert-Test (-not (Test-TurboLegacyApiAlias -Manifest $quickManifest -Alias 'untrusted-alias')) 'Undeclared legacy alias was accepted.'
$normalAliases = @(Get-TurboAcceptedApiAliases -Manifest $quickManifest)
$migrationAliases = @(Get-TurboAcceptedApiAliases -Manifest $quickManifest -AllowLegacyApiAlias)
Assert-Test ($normalAliases.Count -eq 1 -and $normalAliases[0] -eq 'qwen3.8-27b-uncensored-vision-q5km-quick-gpt-4o') 'Normal Quick startup accepts a legacy alias.'
Assert-Test ($migrationAliases.Count -eq 3 -and 'qwen3.8-27b-uncensored-vision-q5km-quick-gpt-4o' -in $migrationAliases -and 'gpt-4o' -in $migrationAliases -and 'qwen3.8-27b-uncensored-q5km-quick' -in $migrationAliases) 'Quick migration aliases are incomplete.'

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('managed-runtime-lifecycle-test-' + [guid]::NewGuid().ToString('N'))
$historyRoot = Join-Path $fixtureRoot 'history'
$statePath = Join-Path $fixtureRoot 'active.json'
New-Item -ItemType Directory -Path $historyRoot -Force | Out-Null

try {
    # Failure cleanup must never archive a state owned by another process.
    Write-TurboJson -InputObject ([ordered]@{ pid = 111; profile_id = 'fixture' }) -Path $statePath
    $mismatch = Move-TurboStateToHistory -StatePath $statePath -HistoryRoot $historyRoot -Reason 'fixture-mismatch' -ExpectedProcessId 222
    Assert-Test ($null -eq $mismatch) 'PID-mismatched state was archived.'
    Assert-Test (Test-Path -LiteralPath $statePath -PathType Leaf) 'PID-mismatched active state was removed.'
    Assert-Test (@(Get-ChildItem -LiteralPath $historyRoot -File).Count -eq 0) 'PID-mismatched history file was created.'

    $matched = Move-TurboStateToHistory -StatePath $statePath -HistoryRoot $historyRoot -Reason 'fixture-match' -ExpectedProcessId 111
    Assert-Test (-not (Test-Path -LiteralPath $statePath)) 'PID-matched active state was not removed.'
    Assert-Test (Test-Path -LiteralPath $matched -PathType Leaf) 'PID-matched history file was not created.'

    # A family/port mutex must reject an overlapping process, then become
    # reusable once the original owner releases it.
    $lockManifest = [pscustomobject]@{
        profile_id = 'rtx5090-lifecycle-lock-fixture'
        server = [pscustomobject]@{ port = 61999 }
    }
    $lock = Enter-TurboOperationLock -Manifest $lockManifest -TimeoutSeconds 2
    try {
        $escapedModule = $commonPath.Replace("'", "''")
        $childCode = @"
`$ErrorActionPreference = 'Stop'
Import-Module '$escapedModule' -Force
`$manifest = [pscustomobject]@{ profile_id = 'rtx5090-lifecycle-lock-fixture'; server = [pscustomobject]@{ port = 61999 } }
try {
    `$childLock = Enter-TurboOperationLock -Manifest `$manifest -TimeoutSeconds 1
    Exit-TurboOperationLock -Lock `$childLock
    exit 4
}
catch {
    if (`$_.Exception.Message -like '*already in progress*') { exit 0 }
    exit 5
}
"@
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCode))
        & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded
        Assert-Test ($LASTEXITCODE -eq 0) "Overlapping operation lock was not rejected; child exit $LASTEXITCODE."
    }
    finally {
        Exit-TurboOperationLock -Lock $lock
    }
    $reacquired = Enter-TurboOperationLock -Manifest $lockManifest -TimeoutSeconds 2
    Exit-TurboOperationLock -Lock $reacquired

    # Exercise the history-recovery decision with offline fixtures and mocked
    # process/API/hash dependencies. This does not inspect or stop a real PID.
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($commonPath, [ref]$tokens, [ref]$errors)
    Assert-Test ($errors.Count -eq 0) 'Turbo.Common.psm1 did not parse.'
    $definitions = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Restore-TurboStateFromHistory'
    }, $true))
    Assert-Test ($definitions.Count -eq 1) 'Expected one Restore-TurboStateFromHistory definition.'
    . ([scriptblock]::Create($definitions[0].Extent.Text))

    $recoveryRoot = Join-Path $fixtureRoot 'recovery'
    $recoveryHistory = Join-Path $recoveryRoot 'history'
    $recoveryActive = Join-Path $recoveryRoot 'active.json'
    New-Item -ItemType Directory -Path $recoveryHistory -Force | Out-Null
    $startTime = '2026-09-07T15:38:24.2977711+09:00'
    $manifest = [pscustomobject]@{
        profile_id = 'rtx5090-recovery-fixture'
        profile_class = 'fixture'
        target_host = [pscustomobject]@{ computer_name = 'FIXTURE-HOST' }
        server = [pscustomobject]@{ host = '127.0.0.1'; port = 18080; api_model_alias = 'fixture-alias' }
        runtime = [pscustomobject]@{ source_commit = 'fixture-commit'; executable_expected_sha256 = 'exe-hash' }
        model = [pscustomobject]@{ sha256 = 'model-hash'; projector_sha256 = $null }
        configuration = [pscustomobject]@{ context_tokens = 65536; parallel = 1; vision = $false }
    }
    $storage = [pscustomobject]@{ active_state = $recoveryActive; history = $recoveryHistory }
    $historyState = [ordered]@{
        schema_version = 1
        profile_id = $manifest.profile_id
        host = 'FIXTURE-HOST'
        pid = 424242
        executable_path = 'C:\fixture\llama-server.exe'
        executable_sha256 = 'exe-hash'
        source_commit = 'fixture-commit'
        server_host = '127.0.0.1'
        server_port = 18080
        api_model_alias = 'fixture-alias'
        model_path = 'C:\fixture\model.gguf'
        model_sha256 = 'model-hash'
        start_time = $startTime
        ready = $true
        archived_at = '2026-09-07T15:39:00+09:00'
        archive_reason = 'start-failed'
    }
    $historyPath = Join-Path $recoveryHistory "$($manifest.profile_id)-20260907-153900-000.json"
    $historyState | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $historyPath -Encoding UTF8

    function Get-TurboPortListeners { @([pscustomobject]@{ LocalAddress = '127.0.0.1'; OwningProcess = 424242 }) }
    function Get-TurboProcessRecord {
        [pscustomobject]@{
            pid = 424242
            executable_path = 'C:\fixture\llama-server.exe'
            command_line = 'llama-server.exe --model C:\fixture\model.gguf --alias fixture-alias --port 18080'
            creation_time = $startTime
        }
    }
    function Assert-ManagedTurboProcess {
        param($State, $Manifest, [switch]$RequireListener, [switch]$AllowLegacyApiAlias)
        $script:processChecks++
        [pscustomobject]@{ pid = 424242 }
    }
    function Test-TurboApiState {
        param($Manifest, [string]$BaseUrl, [switch]$AllowLegacyQuickTextOnly, [switch]$AllowLegacyApiAlias)
        $script:apiChecks++
        [pscustomobject]@{ status = 'ok' }
    }
    function Get-TurboRuntimeInfo {
        [pscustomobject]@{ executable = 'C:\fixture\llama-server.exe'; model = 'C:\fixture\model.gguf'; projector = $null }
    }
    function Get-TurboFileSha256 {
        param([string]$Path)
        if ($Path -like '*llama-server.exe') { return 'exe-hash' }
        if ($Path -like '*model.gguf') { return 'model-hash' }
        return 'unexpected-hash'
    }
    function Write-TurboJson {
        param($InputObject, [string]$Path, [int]$Depth = 12)
        $InputObject | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
    }

    $script:processChecks = 0
    $script:apiChecks = 0
    $recovered = Restore-TurboStateFromHistory -Manifest $manifest -Storage $storage
    Assert-Test ($null -ne $recovered) 'Exact orphan history state was not recovered.'
    Assert-Test (Test-Path -LiteralPath $recoveryActive -PathType Leaf) 'Recovered active state was not written.'
    Assert-Test ($script:processChecks -eq 1 -and $script:apiChecks -eq 1) 'Recovery did not perform process and API checks.'
    $written = Get-Content -LiteralPath $recoveryActive -Raw | ConvertFrom-Json
    Assert-Test ([int]$written.pid -eq 424242 -and $written.recovered_from_history -eq $historyPath) 'Recovered state metadata is incorrect.'
    Assert-Test ($null -eq $written.PSObject.Properties['archive_reason']) 'Archived failure marker leaked into active state.'

    Remove-Item -LiteralPath $recoveryActive -Force
    $historyState.pid = 999999
    $historyState | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $historyPath -Encoding UTF8
    $script:processChecks = 0
    $script:apiChecks = 0
    $rejected = Restore-TurboStateFromHistory -Manifest $manifest -Storage $storage
    Assert-Test ($null -eq $rejected) 'Wrong-PID history state was recovered.'
    Assert-Test (-not (Test-Path -LiteralPath $recoveryActive)) 'Wrong-PID recovery wrote active state.'
    Assert-Test ($script:processChecks -eq 0 -and $script:apiChecks -eq 0) 'Wrong-PID state reached process/API checks.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolved = (Resolve-Path -LiteralPath $fixtureRoot).Path
        $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if ([IO.Path]::GetDirectoryName($resolved) -ne $expectedParent -or
            [IO.Path]::GetFileName($resolved) -notmatch '^managed-runtime-lifecycle-test-[a-f0-9]{32}$') {
            throw 'Unsafe lifecycle test cleanup path.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

Write-Host 'Managed runtime lifecycle tests passed: operation lock, PID-owned archive, exact history recovery and rejection.' -ForegroundColor Green
