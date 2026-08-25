[CmdletBinding()]
param([switch]$AllowNotRunning)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile BLUE
$sshAlias = [string]$manifest.target_host.ssh_alias
$expectedHostname = [string]$manifest.target_host.computer_name
$localPort = [int]$manifest.server.main_tunnel_port
$forward = "127.0.0.1:${localPort}:127.0.0.1:$($manifest.server.port)"
$remoteStop = 'C:\Users\Atsuki\Codex-RTX3090-Setup\standalone-turbo\Stop-ManagedTurbo.ps1'
$root = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\turbo'
$statePath = Join-Path $root 'blue-tunnel.json'
$history = Join-Path $root 'history'
$sshExe = (Get-Command ssh.exe -ErrorAction Stop).Source

if ([Environment]::MachineName -ne 'DESKTOP-5NPLIIV') { throw 'BLUE Remote stop requires DESKTOP-5NPLIIV.' }
$hostname = (@(& ssh -o BatchMode=yes $sshAlias hostname) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $hostname -ne $expectedHostname) { throw "SSH identity mismatch for $sshAlias." }

$listeners = @(Get-TurboPortListeners -Port $localPort)
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $process = Get-TurboProcessRecord -ProcessId ([int]$state.pid)
    if ($null -ne $process) {
        $expectedExe = [IO.Path]::GetFullPath($sshExe)
        $stateExe = [IO.Path]::GetFullPath([string]$state.executable_path)
        $actualExe = [IO.Path]::GetFullPath([string]$process.executable_path)
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
            throw "PID $($state.pid) is not the managed BLUE Turbo tunnel. It was not stopped."
        }
        Stop-Process -Id ([int]$state.pid)
        $deadline = (Get-Date).AddSeconds(30)
        do {
            if ($null -eq (Get-TurboProcessRecord -ProcessId ([int]$state.pid))) { break }
            Start-Sleep -Milliseconds 500
        } while ((Get-Date) -lt $deadline)
        if ($null -ne (Get-TurboProcessRecord -ProcessId ([int]$state.pid))) { throw 'Managed BLUE tunnel did not stop before the timeout.' }
    }
    elseif ($listeners.Count -gt 0) { throw 'Tunnel state PID is absent but MAIN port 18081 is owned. No process was stopped.' }
    Move-TurboStateToHistory -StatePath $statePath -HistoryRoot $history -Reason 'managed-blue-tunnel-stop' | Out-Null
}
elseif ($listeners.Count -gt 0) {
    $owners = ($listeners | ForEach-Object OwningProcess | Sort-Object -Unique) -join ', '
    throw "MAIN port $localPort is owned by unknown PID(s) $owners. No process was stopped."
}
elseif (-not $AllowNotRunning) {
    Write-Host '[INFO] Managed BLUE tunnel state is absent; continuing with verified remote Turbo stop.'
}

& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -ExecutionPolicy Bypass -File $remoteStop -Profile BLUE -AllowNotRunning
if ($LASTEXITCODE -ne 0) { throw "Remote BLUE Turbo stop failed with exit code $LASTEXITCODE." }

$portCommand = "if (@(Get-NetTCPConnection -State Listen -LocalPort 18080 -ErrorAction SilentlyContinue).Count -eq 0) { 'FREE' } else { exit 11 }"
$remotePort = (@(& ssh -o BatchMode=yes $sshAlias powershell.exe -NoProfile -Command $portCommand) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $remotePort -ne 'FREE') { throw 'BLUE localhost port 18080 is not free after managed stop.' }
if (@(Get-TurboPortListeners -Port $localPort).Count -ne 0) { throw 'MAIN tunnel port 18081 is not free after managed stop.' }

Write-Host '[OK] BLUE managed Turbo and SSH tunnel stopped; MAIN 18081 and BLUE 18080 are free.' -ForegroundColor Green
