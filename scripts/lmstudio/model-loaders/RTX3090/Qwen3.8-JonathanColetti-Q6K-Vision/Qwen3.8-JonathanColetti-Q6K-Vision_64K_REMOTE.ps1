[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SshAlias = 'pc5700x'
$ExpectedHostname = 'DESKTOP-L9HAM1G'
$ExpectedIp = '192.168.0.104'
$RemoteLoader = 'C:\Users\Atsuki\Codex-RTX3090-Setup\model-loaders\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K.ps1'
$Identifier = 'qwen3.8-27b-uncensored-vision-blue'

$hostnameResult = (@(& ssh -o BatchMode=yes $SshAlias hostname) -join '').Trim()
if ($LASTEXITCODE -ne 0) { throw "SSH connection to $SshAlias failed." }
if ($hostnameResult -ne $ExpectedHostname) {
    throw "SSH alias $SshAlias returned '$hostnameResult'; expected '$ExpectedHostname'."
}

$ipCommand = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '$ExpectedIp') { '$ExpectedIp' } else { exit 9 }"
$ipResult = (@(& ssh -o BatchMode=yes $SshAlias powershell -NoProfile -Command $ipCommand) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $ipResult -ne $ExpectedIp) {
    throw "Remote IPv4 verification failed; expected $ExpectedIp."
}

Write-Host "[INFO] Verified $SshAlias -> $ExpectedHostname / $ExpectedIp."
& ssh -o BatchMode=yes $SshAlias powershell -NoProfile -ExecutionPolicy Bypass -File $RemoteLoader
if ($LASTEXITCODE -ne 0) { throw "Remote BLUE loader failed with exit code $LASTEXITCODE." }

$catalog = Invoke-RestMethod -Uri 'http://192.168.0.104:1234/api/v1/models' -Method Get -TimeoutSec 15
$loadedMatches = @($catalog.models | ForEach-Object { @($_.loaded_instances) } | Where-Object { $_.id -eq $Identifier })
if ($loadedMatches.Count -ne 1) {
    throw "Expected one remotely loaded instance '$Identifier', found $($loadedMatches.Count)."
}

Write-Host '[OK] BLUE Operational Default is reachable from MAIN.'
Write-Host '[OK] Base URL: http://192.168.0.104:1234/v1'
Write-Host "[OK] Model ID: $Identifier"
