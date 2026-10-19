[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$turboRoot = Join-Path $repoRoot 'scripts\standalone-turbo'

function Read-TestAst {
    param([string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Parse failed: $Path" }
    return $ast
}
function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Get-TestFailure {
    param([scriptblock]$Action)
    try { & $Action | Out-Null }
    catch { return $_.Exception.Message }
    throw 'Expected failure was not raised.'
}

# Extract only pure diagnostics functions; never import or execute a launcher.
$commonAst = Read-TestAst (Join-Path $turboRoot 'Turbo.Common.psm1')
foreach ($functionName in @('Assert-TurboVramLoaded', 'Invoke-TurboSshText')) {
    $definitions = @($commonAst.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
    }, $true))
    Assert-Test ($definitions.Count -eq 1) "Expected one $functionName definition."
    . ([scriptblock]::Create($definitions[0].Extent.Text))
}
$manifest = Get-Content -LiteralPath (Join-Path $turboRoot 'runtime-manifests\BLUE.json') -Raw | ConvertFrom-Json
function New-GpuFixture {
    param([string]$Main = '12000', [string]$Secondary = '6000')
    @(
        [pscustomobject]@{ name = 'NVIDIA GeForce RTX 3090'; pci_bus_id = '00000000:0B:00.0'; memory_used_mib = $Main }
        [pscustomobject]@{ name = 'NVIDIA GeForce RTX 3060'; pci_bus_id = '00000000:01:00.0'; memory_used_mib = $Secondary }
    )
}
function Get-TurboGpuState {
    if ($script:queryFails) { throw 'QUERY_FAILURE_SENTINEL' }
    return $script:gpuRows
}
$script:queryFails = $false
$script:gpuRows = @(New-GpuFixture)
Assert-Test (@(Assert-TurboVramLoaded -Manifest $manifest).Count -eq 2) 'Minimum boundary must pass.'
foreach ($values in @(@('11999','6000'), @('12000','5999'))) {
    $script:gpuRows = @(New-GpuFixture $values[0] $values[1])
    $message = Get-TestFailure { Assert-TurboVramLoaded -Manifest $manifest }
    foreach ($fragment in @('RTX 3090','RTX 3060','0B:00.0','01:00.0',"current $($values[0]) MiB", "current $($values[1]) MiB",'minimum 12000 MiB','minimum 6000 MiB','BELOW MINIMUM')) {
        Assert-Test ($message.Contains($fragment)) "Missing GPU diagnostic: $fragment"
    }
}
foreach ($invalid in @('N/A','NaN','Infinity','-1')) {
    $script:gpuRows = @(New-GpuFixture $invalid)
    $message = Get-TestFailure { Assert-TurboVramLoaded -Manifest $manifest }
    Assert-Test ($message.Contains('memory usage unavailable')) "Invalid telemetry accepted: $invalid"
}
$script:gpuRows = @((New-GpuFixture)[1])
$message = Get-TestFailure { Assert-TurboVramLoaded -Manifest $manifest }
Assert-Test ($message.Contains('found 0')) 'Missing GPU must be identified.'
$script:gpuRows = @(New-GpuFixture) + @((New-GpuFixture)[0])
$message = Get-TestFailure { Assert-TurboVramLoaded -Manifest $manifest }
Assert-Test ($message.Contains('found 2')) 'Duplicate GPU must be identified.'
$script:queryFails = $true
$message = Get-TestFailure { Assert-TurboVramLoaded -Manifest $manifest }
Assert-Test ($message -eq 'QUERY_FAILURE_SENTINEL') 'GPU query error was obscured.'

# ssh.exe is shadowed with a local function. The only native executable it may run
# is PowerShell with a fixed synthetic stdout/stderr payload, never a connection.
$nativePowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$nativePayload = "[Console]::Out.WriteLine('STDOUT_SENTINEL'); [Console]::Error.WriteLine('STDERR_BEGIN' + ('x' * 8192) + 'STDERR_END'); exit 7"
$nativeEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($nativePayload))
function ssh.exe {
    & $nativePowerShell -NoProfile -NonInteractive -EncodedCommand $nativeEncoded
    $global:LASTEXITCODE = $LASTEXITCODE
}
$savedNativeExit = Get-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
$savedNativeExitValue = if ($null -ne $savedNativeExit) { $savedNativeExit.Value } else { $null }
try {
    $response = Invoke-TurboSshText -SshAlias 'OFFLINE_FIXTURE_ONLY' -Code 'This code is never executed.'
    Assert-Test ($response.exit_code -eq 7) 'Native exit code was lost.'
    $combined = $response.output -join "`n"
    Assert-Test ($combined.Contains('STDOUT_SENTINEL')) 'Native stdout was lost.'
    Assert-Test ($combined.Contains('STDERR_BEGIN' + ('x' * 8192) + 'STDERR_END')) 'Native stderr was truncated.'
    Assert-Test ($ErrorActionPreference -eq 'Stop') 'ErrorActionPreference was not restored.'
}
finally {
    Remove-Item Function:\ssh.exe
    if ($null -ne $savedNativeExit) { $global:LASTEXITCODE = $savedNativeExitValue }
    else { Remove-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue }
}

# Evaluate just the existing-listener branch, replacing its terminal exit with
# natural scriptblock return by omitting the AST ExitStatement. No filesystem
# fixture or real Test-ManagedTurbo invocation is needed.
$startAst = Read-TestAst (Join-Path $turboRoot 'Start-ManagedTurbo.ps1')
$branches = @($startAst.FindAll({ param($node)
    $node -is [Management.Automation.Language.IfStatementAst] -and
    $node.Clauses[0].Item1.Extent.Text -eq '$listeners.Count -gt 0' -and
    $node.Extent.Text.Contains('failed reuse verification')
}, $true))
Assert-Test ($branches.Count -eq 1) 'Existing reuse branch was not found.'
$reuseStatements = @($branches[0].Clauses[0].Item2.Statements | Where-Object { $_ -isnot [Management.Automation.Language.ExitStatementAst] })
$reuseBlock = [scriptblock]::Create(($reuseStatements | ForEach-Object { $_.Extent.Text }) -join "`n")
& {
    function Join-Path { param($Path,$ChildPath) if ($ChildPath -ne 'Test-ManagedTurbo.ps1') { throw 'Unexpected dependency.' }; 'Invoke-TestPreflight' }
    function Invoke-TestPreflight { param($Profile,$Mode) $script:preflightCalls++; if ($script:preflightFails) { throw 'VRAM_FAILURE_SENTINEL' }; 'REUSED_OK' }
    function Stop-Process { throw 'FORBIDDEN_STOP' }
    function Start-Process { throw 'FORBIDDEN_START' }
    function lms { throw 'FORBIDDEN_LMS' }
    function Move-TurboStateToHistory { throw 'FORBIDDEN_STATE_MUTATION' }
    $existingState = [pscustomobject]@{ pid = 424242 }
    $Profile = 'BLUE'
    $script:preflightCalls = 0
    $script:preflightFails = $false
    $result = @(& $reuseBlock)
    Assert-Test ($result -contains 'REUSED_OK') 'Existing runtime success not returned.'
    $script:preflightFails = $true
    $message = Get-TestFailure $reuseBlock
    Assert-Test ($message.Contains('VRAM_FAILURE_SENTINEL') -and $message.Contains('not stopped or reloaded')) 'Reuse failure lost preservation/diagnostic details.'
    Assert-Test ($script:preflightCalls -eq 2) 'Reuse did not call the preflight exactly once per attempt.'
}

# Parse generated remote scripts without running them, SSH, CIM or a launcher.
$remoteAst = Read-TestAst (Join-Path $turboRoot 'Start-BlueManagedTurboRemote.ps1')
$remoteLaunchLog = 'C:\offline-fixture\launch.log'
$remoteStart = 'C:\offline-fixture\Start-ManagedTurbo.ps1'
$remoteTest = 'C:\offline-fixture\Test-ManagedTurbo.ps1'
$remoteStatePath = 'C:\offline-fixture\state.json'
$remoteLauncherPid = 424242
foreach ($variableName in @('launchPayload','readyCode')) {
    $assignments = @($remoteAst.FindAll({ param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq ('$' + $variableName)
    }, $true))
    Assert-Test ($assignments.Count -eq 1) "Expected remote payload: $variableName"
    . ([scriptblock]::Create($assignments[0].Extent.Text))
    $payload = (Get-Variable -Name $variableName -ValueOnly)
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($payload, [ref]$tokens, [ref]$errors)
    Assert-Test ($errors.Count -eq 0) "Generated $variableName contains syntax errors."
}
Assert-Test ($launchPayload.Contains('$_.Exception.Message')) 'Launch log must preserve exception text.'
Assert-Test ($readyCode.Contains('[REMOTE_PREFLIGHT_FAILED]') -and $readyCode.Contains('[REMOTE_LAUNCH_FAILED]') -and $readyCode.Contains('[BLUE LOG]')) 'Readiness diagnostics must distinguish failure stages and identify the full log.'
Assert-Test (-not ($readyCode -match 'Stop-Process|lms unload|Start-ManagedTurbo')) 'Readiness payload must not recover or stop runtime automatically.'

# Exercise only the final error-display/log catch with an isolated LOCALAPPDATA.
# No launcher initialization, SSH, GPU, or runtime code is executed.
$outerTry = @($remoteAst.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.TryStatementAst] })
Assert-Test ($outerTry.Count -eq 1) 'Expected one outer diagnostic try/catch.'
$catchBlock = [scriptblock]::Create($outerTry[0].CatchClauses[0].Body.Extent.Text.Trim().Substring(1).TrimEnd().TrimEnd('}'))
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('turbo-diagnostic-test-' + [guid]::NewGuid().ToString('N'))
$savedLocalAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = $fixtureRoot
    $diagnosticSentinel = '[TURBO_VRAM_RESIDENCY] BEGIN_' + ('x' * 8192) + '_END'
    $display = @(& {
        try {
            try { throw $diagnosticSentinel }
            catch { & $catchBlock }
        }
        catch { Write-Output $_.Exception.Message }
    } 6>&1)
    $savedLogs = @(Get-ChildItem -LiteralPath (Join-Path $fixtureRoot 'Local-LLM-Coding-Stack\turbo\logs') -Filter '*.log')
    Assert-Test ($savedLogs.Count -eq 1) 'Expected one diagnostic log.'
    $logText = Get-Content -LiteralPath $savedLogs[0].FullName -Raw
    Assert-Test ($logText.Contains($diagnosticSentinel)) 'Saved diagnostic was truncated.'
    Assert-Test (($display -join "`n").Contains($diagnosticSentinel)) 'Displayed diagnostic was truncated.'
    foreach ($fragment in @('[5] Release', '[2] Turbo', 'queued work', 'Automatic Release/restart was NOT attempted')) {
        Assert-Test ($logText.Contains($fragment)) "Missing recovery instruction: $fragment"
    }
}
finally {
    $env:LOCALAPPDATA = $savedLocalAppData
    # Only remove the exact unique test directory after validating its resolved parent.
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolved = (Resolve-Path -LiteralPath $fixtureRoot).Path
        $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
        if ([IO.Path]::GetDirectoryName($resolved) -ne $expectedParent -or [IO.Path]::GetFileName($resolved) -notmatch '^turbo-diagnostic-test-[a-f0-9]{32}$') {
            throw 'Unsafe test cleanup path.'
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
Write-Host 'Turbo launcher diagnostics offline tests passed: GPU telemetry, native stderr, reuse preservation, remote payload syntax, full display/log and recovery hints.' -ForegroundColor Green
