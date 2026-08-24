[CmdletBinding()]
param(
    [ValidateSet(259, 370)]
    [int]$Rtx3090PowerLimit = 259
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SshAlias = 'pc5700x'
$ExpectedHostname = 'DESKTOP-L9HAM1G'
$ExpectedIp = '192.168.0.104'
$RemoteLoader = 'C:\Users\Atsuki\Codex-RTX3090-Setup\model-loaders\Qwen3.8-JonathanColetti-Q6K-Vision\Qwen3.8-JonathanColetti-Q6K-Vision_64K.ps1'
$Identifier = 'qwen3.8-27b-uncensored-vision-blue'
$Rtx3090Name = 'NVIDIA GeForce RTX 3090'
$Rtx3090Bus = '00000000:0B:00.0'
$Rtx3060Name = 'NVIDIA GeForce RTX 3060'
$Rtx3060Bus = '00000000:01:00.0'

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
& ssh -o BatchMode=yes $SshAlias powershell -NoProfile -ExecutionPolicy Bypass -File $RemoteLoader -Rtx3090PowerLimit $Rtx3090PowerLimit
if ($LASTEXITCODE -ne 0) { throw "Remote BLUE loader failed with exit code $LASTEXITCODE." }

$powerRows = @(& ssh -o BatchMode=yes $SshAlias nvidia-smi --query-gpu=name,pci.bus_id,power.limit --format=csv,noheader,nounits | ConvertFrom-Csv -Header @('name', 'pci_bus_id', 'power_limit_w'))
if ($LASTEXITCODE -ne 0) { throw 'Remote GPU Power Limit verification failed.' }
foreach ($expected in @(
    [pscustomobject]@{ name = $Rtx3090Name; bus = $Rtx3090Bus; watts = [double]$Rtx3090PowerLimit },
    [pscustomobject]@{ name = $Rtx3060Name; bus = $Rtx3060Bus; watts = 170.0 }
)) {
    $matches = @($powerRows | Where-Object {
        $_.name.Trim() -eq $expected.name -and
        $_.pci_bus_id.Trim().ToUpperInvariant() -eq $expected.bus
    })
    if ($matches.Count -ne 1) {
        throw "Expected one remote $($expected.name) at PCI Bus $($expected.bus), found $($matches.Count)."
    }
    $actual = [double]::Parse($matches[0].power_limit_w.Trim(), [Globalization.CultureInfo]::InvariantCulture)
    if ([Math]::Abs($actual - $expected.watts) -gt 0.5) {
        throw "Remote $($expected.name) Power Limit is ${actual}W; expected $($expected.watts)W."
    }
}

$catalog = Invoke-RestMethod -Uri 'http://192.168.0.104:1234/api/v1/models' -Method Get -TimeoutSec 15
$loadedMatches = @($catalog.models | ForEach-Object { @($_.loaded_instances) } | Where-Object { $_.id -eq $Identifier })
if ($loadedMatches.Count -ne 1) {
    throw "Expected one remotely loaded instance '$Identifier', found $($loadedMatches.Count)."
}

if ($Rtx3090PowerLimit -eq 259) {
    Write-Host '[OK] BLUE Primary Operational Default is reachable from MAIN.'
} else {
    Write-Host '[OK] BLUE 370W Performance override is reachable from MAIN.'
}
Write-Host '[OK] Base URL: http://192.168.0.104:1234/v1'
Write-Host "[OK] Model ID: $Identifier"
Write-Host "[OK] Power Limits: RTX3090 ${Rtx3090PowerLimit}W / RTX3060 170W"
