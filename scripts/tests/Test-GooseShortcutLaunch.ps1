[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../standalone-turbo/Start-Goose-ManagedTurbo.ps1')
$match = [regex]::Match($source, '(?s)try\s*\{\s*(\$launch = @\{.*?Start-Process @launch)\s*\}\s*finally')
if (-not $match.Success) { throw 'Isolated launch block not found.' }
$block = [scriptblock]::Create($match.Groups[1].Value)
$script:guardCapturedLaunch = $null
function Start-Process {
    param([string]$FilePath, [string]$WorkingDirectory, [string]$ArgumentList, [string]$WindowStyle)
    $script:guardCapturedLaunch = @{ FilePath=$FilePath; WorkingDirectory=$WorkingDirectory; ArgumentList=$ArgumentList; WindowStyle=$WindowStyle }
}
foreach ($case in @(
    @{ path='C:\fixture\Goose.exe'; args=''; hidden=$false },
    @{ path='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'; args='-NoProfile -File "C:\fixture with spaces\guard.ps1"'; hidden=$true }
)) {
    $gooseDesktop = [pscustomobject]@{path=$case.path;working_directory='C:\fixture';arguments=$case.args}
    & $block
    if ($script:guardCapturedLaunch.FilePath -cne $case.path -or
        $script:guardCapturedLaunch.WorkingDirectory -cne 'C:\fixture' -or
        $script:guardCapturedLaunch.ArgumentList -cne $case.args) { throw 'Shortcut arguments or target were not preserved.' }
    if ($case.hidden -and $script:guardCapturedLaunch.WindowStyle -cne 'Hidden') { throw 'Helper window must stay hidden.' }
    if (-not $case.hidden -and $script:guardCapturedLaunch.WindowStyle) { throw 'Direct interactive Goose must remain visible.' }
}
$pathMatch = [regex]::Match($source, '(?s)# Shell guard PATH compatibility:.*?\r?\n(.*?)# End shell guard PATH compatibility\.')
if (-not $pathMatch.Success) { throw 'Scoped shell-guard PATH block missing.' }
$pathBlock = [scriptblock]::Create($pathMatch.Groups[1].Value)
function Test-Path {
    param([string]$LiteralPath, [string]$PathType)
    if ($LiteralPath -like '*goose-shell-repetition-guard\hooks\hooks.json') { return $script:guardPluginPresent }
    if ($LiteralPath -eq 'C:\Program Files\Git\usr\bin\sh.exe') { return $script:guardShellPresent }
    throw 'Unexpected filesystem query in isolated PATH test.'
}
$parentPathBefore=$env:PATH
foreach($pluginPresent in @($false,$true)) {
    $script:guardPluginPresent=$pluginPresent
    $script:guardShellPresent=$true
    $overrides=[ordered]@{GOOSE_MODEL='unchanged-model';GOOSE_CONTEXT_LIMIT='237568';GOOSE_AUTO_COMPACT_THRESHOLD='0.6'}
    & $pathBlock
    if($pluginPresent -and $overrides['PATH'] -cne "C:\Program Files\Git\usr\bin;$parentPathBefore") { throw 'Direct launch would omit Git sh PATH.' }
    if(-not $pluginPresent -and $overrides.Contains('PATH')) { throw 'PATH changed without a guard plugin.' }
    if($overrides['GOOSE_MODEL'] -cne 'unchanged-model' -or $overrides['GOOSE_CONTEXT_LIMIT'] -cne '237568' -or $overrides['GOOSE_AUTO_COMPACT_THRESHOLD'] -cne '0.6') { throw 'Profile overrides changed.' }
}
$script:guardPluginPresent=$true
$script:guardShellPresent=$false
try { & $pathBlock; throw 'Expected missing-shell refusal' } catch { if($_.Exception.Message -notlike 'Shell guard requires existing Git sh.exe*') { throw } }
if($env:PATH -cne $parentPathBefore) { throw 'PATH preflight modified the parent process.' }
Write-Output 'PASS: 2 shortcut cases + 3 scoped PATH cases; no model or process launched.'
