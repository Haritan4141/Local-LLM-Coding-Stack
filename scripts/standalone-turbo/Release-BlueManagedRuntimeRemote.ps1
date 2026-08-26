[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile BLUE
$sshAlias = [string]$manifest.target_host.ssh_alias
$expectedHostname = [string]$manifest.target_host.computer_name
$expectedIp = [string]$manifest.target_host.ipv4
$localPort = [int]$manifest.server.main_tunnel_port
$remoteRelease = 'C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Release-ManagedRuntime.ps1'
$tunnelStatePath = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\turbo\blue-tunnel.json'
$sshExe = (Get-Command ssh.exe -ErrorAction Stop).Source

if ([Environment]::MachineName -ne 'DESKTOP-5NPLIIV') {
    throw "BLUE Remote release requires DESKTOP-5NPLIIV; observed $([Environment]::MachineName)."
}
$mainAddresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object IPAddress)
if ('192.168.0.100' -notin $mainAddresses) { throw 'MAIN IPv4 192.168.0.100 was not found.' }

$hostname = (@(& ssh -o BatchMode=yes $sshAlias hostname) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $hostname -ne $expectedHostname) {
    throw "SSH alias $sshAlias returned '$hostname'; expected '$expectedHostname'."
}
$ipCommand = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '$expectedIp') { '$expectedIp' } else { exit 9 }"
$ip = (@(& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -Command $ipCommand) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $ip -ne $expectedIp) { throw "Remote IPv4 verification failed; expected $expectedIp." }

# Validate a present MAIN tunnel before changing BLUE runtime state. Unknown listeners/PIDs are preserved.
$listeners = @(Get-TurboPortListeners -Port $localPort)
if (Test-Path -LiteralPath $tunnelStatePath -PathType Leaf) {
    $state = Get-Content -LiteralPath $tunnelStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $process = Get-TurboProcessRecord -ProcessId ([int]$state.pid)
    if ($null -eq $process) {
        if ($listeners.Count -gt 0) { throw 'Managed tunnel PID is absent but MAIN port 18081 is owned. No runtime was released.' }
    }
    else {
        $expectedExe = [IO.Path]::GetFullPath($sshExe)
        $stateExe = [IO.Path]::GetFullPath([string]$state.executable_path)
        $actualExe = [IO.Path]::GetFullPath([string]$process.executable_path)
        $forward = "127.0.0.1:${localPort}:127.0.0.1:$($manifest.server.port)"
        $owned = @($listeners | Where-Object { [int]$_.OwningProcess -eq [int]$state.pid -and $_.LocalAddress -eq '127.0.0.1' })
        if (-not $stateExe.Equals($expectedExe, [StringComparison]::OrdinalIgnoreCase) -or
            -not $actualExe.Equals($expectedExe, [StringComparison]::OrdinalIgnoreCase) -or
            $state.ssh_alias -ne $sshAlias -or
            [int]$state.local_port -ne $localPort -or
            [int]$state.remote_port -ne [int]$manifest.server.port -or
            $state.forward -ne $forward -or
            $process.command_line.IndexOf($forward, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
            $process.command_line.IndexOf($sshAlias, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
            $listeners.Count -ne 1 -or $owned.Count -ne 1) {
            throw "PID $($state.pid) is not the managed BLUE Turbo tunnel. No runtime was released."
        }
    }
}
elseif ($listeners.Count -gt 0) {
    $owners = ($listeners | ForEach-Object OwningProcess | Sort-Object -Unique) -join ', '
    throw "MAIN port $localPort is owned by unknown PID(s) $owners. No runtime was released."
}

Write-Host "[INFO] Releasing BLUE runtime through verified $sshAlias -> $expectedHostname / $expectedIp..."
& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -ExecutionPolicy Bypass -File $remoteRelease -Profile BLUE
if ($LASTEXITCODE -ne 0) { throw "Remote BLUE release failed with exit code $LASTEXITCODE." }

# The remote release stops the model first. This then removes only a validated managed tunnel/state.
& (Join-Path $PSScriptRoot 'Stop-BlueManagedTurboRemote.ps1') -AllowNotRunning

$remotePs = (@(& ssh -o BatchMode=yes $sshAlias lms ps --json) -join [Environment]::NewLine).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Remote lms ps verification failed after release.' }
$remoteModels = @()
if (-not [string]::IsNullOrWhiteSpace($remotePs)) {
    $remoteModelResponse = $remotePs | ConvertFrom-Json
    $remoteModels = @($remoteModelResponse | ForEach-Object { $_ })
}
if ($remoteModels.Count -ne 0) {
    throw 'BLUE LM Studio still reports a loaded model after release.'
}
if (@(Get-TurboPortListeners -Port $localPort).Count -ne 0) { throw 'MAIN Turbo tunnel is still listening after release.' }

Write-Host '[OK] BLUE model runtime released; LM Studio is empty and managed Turbo/tunnel ports are free.' -ForegroundColor Green
