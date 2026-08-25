[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile BLUE
$sshAlias = [string]$manifest.target_host.ssh_alias
$expectedHostname = [string]$manifest.target_host.computer_name
$expectedIp = [string]$manifest.target_host.ipv4
$remoteRoot = 'C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo'
$remoteStart = Join-Path $remoteRoot 'Start-ManagedTurbo.ps1'
$remoteTest = Join-Path $remoteRoot 'Test-ManagedTurbo.ps1'
$localPort = [int]$manifest.server.main_tunnel_port
$forward = "127.0.0.1:${localPort}:127.0.0.1:$($manifest.server.port)"
$tunnelRoot = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\turbo'
$tunnelStatePath = Join-Path $tunnelRoot 'blue-tunnel.json'
$tunnelHistory = Join-Path $tunnelRoot 'history'
$listeners = @(Get-TurboPortListeners -Port $localPort)
$sshExe = (Get-Command ssh.exe -ErrorAction Stop).Source

function Assert-MainHost {
    if ([Environment]::MachineName -ne 'DESKTOP-5NPLIIV') { throw "BLUE Remote launcher requires DESKTOP-5NPLIIV; observed $([Environment]::MachineName)." }
    $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object IPAddress)
    if ('192.168.0.100' -notin $addresses) { throw 'MAIN IPv4 192.168.0.100 was not found.' }
}

function Assert-BlueIdentity {
    $hostname = (@(& ssh -o BatchMode=yes $sshAlias hostname) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $hostname -ne $expectedHostname) {
        throw "SSH alias $sshAlias returned '$hostname'; expected '$expectedHostname'."
    }
    $ipCommand = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '$expectedIp') { '$expectedIp' } else { exit 9 }"
    $ip = (@(& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -Command $ipCommand) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $ip -ne $expectedIp) { throw "Remote IPv4 verification failed; expected $expectedIp." }
}

function Assert-TunnelProcess {
    param([Parameter(Mandatory)]$State, [switch]$RequireListener)
    $process = Get-TurboProcessRecord -ProcessId ([int]$State.pid)
    if ($null -eq $process) { throw "Managed SSH tunnel PID $($State.pid) is not running." }
    $expectedExe = [IO.Path]::GetFullPath($sshExe)
    $stateExe = [IO.Path]::GetFullPath([string]$State.executable_path)
    $actualExe = [IO.Path]::GetFullPath([string]$process.executable_path)
    if (-not $stateExe.Equals($expectedExe, [StringComparison]::OrdinalIgnoreCase) -or
        -not $actualExe.Equals($expectedExe, [StringComparison]::OrdinalIgnoreCase) -or
        $State.ssh_alias -ne $sshAlias -or
        [int]$State.local_port -ne $localPort -or
        [int]$State.remote_port -ne [int]$manifest.server.port -or
        $State.forward -ne $forward -or
        $process.command_line.IndexOf($forward, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
        $process.command_line.IndexOf($sshAlias, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "PID $($State.pid) is not the managed BLUE Turbo SSH tunnel. It was not stopped."
    }
    if ($RequireListener) {
        $all = @(Get-TurboPortListeners -Port $localPort)
        $owned = @($all | Where-Object { [int]$_.OwningProcess -eq [int]$State.pid -and $_.LocalAddress -eq '127.0.0.1' })
        if ($all.Count -ne 1 -or $owned.Count -ne 1) { throw "Managed SSH tunnel does not exclusively own 127.0.0.1:$localPort." }
    }
    return $process
}

Assert-MainHost
Assert-BlueIdentity

if (Test-Path -LiteralPath $tunnelStatePath -PathType Leaf) {
    $existing = Get-Content -LiteralPath $tunnelStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $existingProcess = Get-TurboProcessRecord -ProcessId ([int]$existing.pid)
    if ($listeners.Count -gt 0) {
        Assert-TunnelProcess -State $existing -RequireListener | Out-Null
        Test-TurboApiState -Manifest $manifest -BaseUrl "http://127.0.0.1:$localPort" | Out-Null
        Write-Host "[OK] Managed BLUE Turbo tunnel is already ready on 127.0.0.1:$localPort." -ForegroundColor Green
        exit 0
    }
    if ($null -ne $existingProcess) { throw 'Managed BLUE tunnel PID exists without the expected listener. Refusing a second tunnel.' }
    Move-TurboStateToHistory -StatePath $tunnelStatePath -HistoryRoot $tunnelHistory -Reason 'stale-blue-tunnel-before-start' | Out-Null
}
elseif ($listeners.Count -gt 0) {
    $owners = ($listeners | ForEach-Object OwningProcess | Sort-Object -Unique) -join ', '
    throw "MAIN port $localPort is owned by unknown PID(s) $owners. No process was stopped."
}

Write-Host "[INFO] Starting BLUE localhost Turbo through verified SSH alias $sshAlias..."
$remoteStatePath = "C:\Users\Atsuki\AppData\Local\Local-LLM-Coding-Stack\turbo\$($manifest.profile_id).json"
$remoteLaunchLog = "C:\Users\Atsuki\AppData\Local\Local-LLM-Coding-Stack\turbo\logs\blue-detached-launch-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$launchPayload = @"
`$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path '$([IO.Path]::GetDirectoryName($remoteLaunchLog))' -Force | Out-Null
try {
    & '$remoteStart' -Profile BLUE | Out-File -LiteralPath '$remoteLaunchLog' -Append -Encoding UTF8
    exit 0
}
catch {
    (`$_ | Out-String) | Out-File -LiteralPath '$remoteLaunchLog' -Append -Encoding UTF8
    exit 1
}
"@
$launchPayloadEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchPayload))
$detachedCommandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $launchPayloadEncoded"
$createCode = @"
`$created = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = '$detachedCommandLine' }
if ([int]`$created.ReturnValue -ne 0) { throw "Win32_Process.Create failed with return value `$(`$created.ReturnValue)." }
Write-Output "DETACHED_PID=`$(`$created.ProcessId)"
"@
$createEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($createCode))
$createOutput = @(& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $createEncoded 2>&1 | ForEach-Object { $_.ToString() })
$createExit = $LASTEXITCODE
$pidLine = @($createOutput | Where-Object { $_ -match '^DETACHED_PID=\d+$' } | Select-Object -Last 1)
if ($createExit -ne 0 -or $pidLine.Count -ne 1) {
    throw "Detached BLUE Turbo launcher creation failed. Output: $($createOutput -join ' | ')"
}
$remoteLauncherPid = [int]($pidLine[0] -replace '^DETACHED_PID=', '')

$readyCode = @"
`$ErrorActionPreference = 'Stop'
`$deadline = (Get-Date).AddMinutes(8)
`$lastError = ''
do {
    if (Test-Path -LiteralPath '$remoteStatePath' -PathType Leaf) {
        try {
            `$managedState = Get-Content -LiteralPath '$remoteStatePath' -Raw -Encoding UTF8 | ConvertFrom-Json
            if (`$managedState.ready -eq `$true) {
                & '$remoteTest' -Profile BLUE -Mode Local -BaseUrl 'http://127.0.0.1:18080' | Out-Null
                Write-Output 'REMOTE_READY'
                exit 0
            }
        }
        catch { `$lastError = `$_.Exception.Message }
    }
    `$launcher = Get-Process -Id $remoteLauncherPid -ErrorAction SilentlyContinue
    if (`$null -eq `$launcher) {
        `$tail = if (Test-Path -LiteralPath '$remoteLaunchLog') { (Get-Content -LiteralPath '$remoteLaunchLog' -Tail 30 -ErrorAction SilentlyContinue) -join ' | ' } else { '<no launch log>' }
        throw "Detached BLUE launcher exited before readiness. Last error: `$lastError. Log: `$tail"
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt `$deadline)
throw "Detached BLUE Turbo did not become ready before the timeout. Last error: `$lastError"
"@
$readyEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($readyCode))
$readyOutput = @(& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $readyEncoded 2>&1 | ForEach-Object { $_.ToString() })
$readyExit = $LASTEXITCODE
if ($readyExit -ne 0 -or 'REMOTE_READY' -notin $readyOutput) {
    throw "Detached BLUE Turbo start failed. Output: $($readyOutput -join ' | ')"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRoot = Join-Path $tunnelRoot "logs\blue-tunnel-$stamp"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$stdout = Join-Path $logRoot 'stdout.log'
$stderr = Join-Path $logRoot 'stderr.log'
$arguments = @('-N', '-L', $forward, '-o', 'ExitOnForwardFailure=yes', '-o', 'BatchMode=yes', $sshAlias)
$process = Start-Process -FilePath $sshExe -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$state = [ordered]@{
    schema_version = 1
    profile_id = 'blue-turbo-ssh-tunnel'
    pid = [int]$process.Id
    executable_path = $sshExe
    start_time = (Get-Date).ToString('o')
    ssh_alias = $sshAlias
    expected_hostname = $expectedHostname
    expected_ip = $expectedIp
    local_address = '127.0.0.1'
    local_port = $localPort
    remote_address = '127.0.0.1'
    remote_port = [int]$manifest.server.port
    forward = $forward
    command_line_sanitized = @($sshExe) + $arguments
    stdout_log = $stdout
    stderr_log = $stderr
    ready = $false
}
Write-TurboJson -InputObject $state -Path $tunnelStatePath -Depth 10

try {
    $deadline = (Get-Date).AddSeconds(60)
    do {
        $process.Refresh()
        if ($process.HasExited) { throw "SSH tunnel exited with code $($process.ExitCode). See $stderr" }
        $current = @(Get-TurboPortListeners -Port $localPort)
        if (@($current | Where-Object { [int]$_.OwningProcess -eq $process.Id -and $_.LocalAddress -eq '127.0.0.1' }).Count -eq 1) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    Assert-TunnelProcess -State ([pscustomobject]$state) -RequireListener | Out-Null
    $api = $null
    $apiDeadline = (Get-Date).AddSeconds(30)
    do {
        try {
            $api = Test-TurboApiState -Manifest $manifest -BaseUrl "http://127.0.0.1:$localPort"
            break
        }
        catch { Start-Sleep -Milliseconds 500 }
    } while ((Get-Date) -lt $apiDeadline)
    if ($null -eq $api) { throw 'BLUE Turbo API did not become reachable through the managed SSH tunnel.' }
    $state['ready'] = $true
    $state['ready_at'] = (Get-Date).ToString('o')
    $state['effective_api'] = $api
    $state['observed_command_line'] = (Get-TurboProcessRecord -ProcessId $process.Id).command_line
    Write-TurboJson -InputObject $state -Path $tunnelStatePath -Depth 12
}
catch {
    $record = Get-TurboProcessRecord -ProcessId $process.Id
    if ($null -ne $record -and
        [IO.Path]::GetFullPath($record.executable_path).Equals([IO.Path]::GetFullPath($sshExe), [StringComparison]::OrdinalIgnoreCase) -and
        $record.command_line.IndexOf($forward, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $record.command_line.IndexOf($sshAlias, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
    Move-TurboStateToHistory -StatePath $tunnelStatePath -HistoryRoot $tunnelHistory -Reason 'blue-tunnel-start-failed' | Out-Null
    throw
}

Write-Host "[OK] BLUE Turbo is available on MAIN at http://127.0.0.1:$localPort/v1" -ForegroundColor Green
[pscustomobject]$state
