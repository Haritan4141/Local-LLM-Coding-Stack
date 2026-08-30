[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

try {
# The outer catch prints full messages before PowerShell can width-format native errors.
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
    $identityResult = Invoke-TurboSshText -SshAlias $sshAlias -Code '[Environment]::MachineName'
    $hostname = ($identityResult.output -join "`n").Trim()
    if ($identityResult.exit_code -ne 0 -or $hostname -ne $expectedHostname) {
        throw "SSH alias $sshAlias could not verify hostname '$expectedHostname'.`n$hostname"
    }
    $ipCommand = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '$expectedIp') { '$expectedIp' } else { exit 9 }"
    $ipResult = Invoke-TurboSshText -SshAlias $sshAlias -Code $ipCommand
    $ip = ($ipResult.output -join "`n").Trim()
    if ($ipResult.exit_code -ne 0 -or $ip -ne $expectedIp) { throw "Remote IPv4 verification failed; expected $expectedIp.`n$ip" }
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
        $checkCode = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
try {
    & '$remoteTest' -Profile BLUE -Mode Local | Out-Null
    Write-Output 'REMOTE_READY'
}
catch { Write-Output `$_.Exception.Message; exit 1 }
"@
        $checked = Invoke-TurboSshText -SshAlias $sshAlias -Code $checkCode
        if ($checked.exit_code -ne 0 -or 'REMOTE_READY' -notin $checked.output) {
            throw ("Existing BLUE runtime/tunnel failed reuse verification. Neither was stopped.`n" + ($checked.output -join "`n"))
        }
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
$remoteLaunchLog = "C:\Users\Atsuki\AppData\Local\Local-LLM-Coding-Stack\turbo\logs\blue-detached-launch-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').log"
$launchPayload = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Path '$([IO.Path]::GetDirectoryName($remoteLaunchLog))' -Force | Out-Null
try {
    & '$remoteStart' -Profile BLUE *>&1 | Out-File -LiteralPath '$remoteLaunchLog' -Append -Encoding UTF8 -Width 4096
    exit 0
}
catch {
    `$_.Exception.Message | Out-File -LiteralPath '$remoteLaunchLog' -Append -Encoding UTF8
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
$createdResult = Invoke-TurboSshText -SshAlias $sshAlias -Code $createCode
$createOutput = $createdResult.output
$createExit = $createdResult.exit_code
$pidLine = @($createOutput | Where-Object { $_ -match '^DETACHED_PID=\d+$' } | Select-Object -Last 1)
if ($createExit -ne 0 -or $pidLine.Count -ne 1) {
    throw "Detached BLUE Turbo launcher creation failed. Output: $($createOutput -join ' | ')"
}
$remoteLauncherPid = [int]($pidLine[0] -replace '^DETACHED_PID=', '')

$readyCode = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
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
        if (`$lastError) {
            Write-Output "[REMOTE_PREFLIGHT_FAILED] BLUE runtime failed readiness verification.`n`$lastError"
        } else {
            Write-Output '[REMOTE_LAUNCH_FAILED] BLUE launcher finished without a verified ready runtime.'
        }
        if (Test-Path -LiteralPath '$remoteLaunchLog') {
            Get-Content -LiteralPath '$remoteLaunchLog' -Tail 40 -ErrorAction SilentlyContinue
        }
        Write-Output '[BLUE LOG] $remoteLaunchLog'
        exit 1
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt `$deadline)
Write-Output "[REMOTE_READY_TIMEOUT] BLUE Turbo readiness timed out.`n`$lastError"
Write-Output '[BLUE LOG] $remoteLaunchLog'
exit 1
"@
$readyResult = Invoke-TurboSshText -SshAlias $sshAlias -Code $readyCode
$readyOutput = $readyResult.output
$readyExit = $readyResult.exit_code
if ($readyExit -ne 0 -or 'REMOTE_READY' -notin $readyOutput) {
    throw ("BLUE Turbo startup was not accepted.`n" + ($readyOutput -join "`n"))
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
}
catch {
    $message = $_.Exception.Message
    $lines = @('[ERROR] BLUE Turbo is not ready.', $message)
    if ($message.Contains('[TURBO_VRAM_RESIDENCY]')) {
        $lines += @(
            '[NEXT] Finish/stop Goose generation and confirm there is no queued work.',
            '[NEXT] In 00-BLUE-Daily-Profiles-REMOTE.bat, select [4] Release, then [2] Turbo.',
            '[SAFE] If Release refuses active work or an unknown process, do not force-stop it.'
        )
    }
    $lines += '[SAFE] Automatic Release/restart was NOT attempted. Existing runtime reuse failures preserve the runtime and tunnel.'
    foreach ($line in $lines) { Write-Host $line -ForegroundColor Yellow }
    try {
        $diagnosticRoot = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\turbo\logs'
        New-Item -ItemType Directory -Path $diagnosticRoot -Force | Out-Null
        $diagnosticPath = Join-Path $diagnosticRoot "blue-remote-start-failed-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').log"
        $lines | Out-File -LiteralPath $diagnosticPath -Encoding UTF8
        Write-Host "[MAIN LOG] $diagnosticPath"
    }
    catch { Write-Host "[WARN] Could not save diagnostic log: $($_.Exception.Message)" -ForegroundColor Yellow }
    # Keep a terminating error for callers (including Goose); details were already printed unabridged.
    throw 'BLUE Turbo startup failed. See the full diagnostic and MAIN LOG above.'
}
