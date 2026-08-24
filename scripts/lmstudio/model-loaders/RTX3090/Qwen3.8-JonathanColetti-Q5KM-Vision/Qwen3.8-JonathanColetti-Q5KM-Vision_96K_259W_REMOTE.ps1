[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SshAlias = 'pc5700x'
$ExpectedHostname = 'DESKTOP-L9HAM1G'
$ExpectedIp = '192.168.0.104'
$RemoteLoader = 'C:\Users\Atsuki\Codex-RTX3090-Setup\model-loaders\Qwen3.8-JonathanColetti-Q5KM-Vision\Qwen3.8-JonathanColetti-Q5KM-Vision_96K_259W.ps1'
$Identifier = 'qwen3.8-27b-uncensored-vision-q5km-blue'
$Rtx3090Name = 'NVIDIA GeForce RTX 3090'
$Rtx3090Bus = '00000000:0B:00.0'
$Rtx3060Name = 'NVIDIA GeForce RTX 3060'
$Rtx3060Bus = '00000000:01:00.0'

$hostnameResult = (@(& ssh -o BatchMode=yes $SshAlias hostname) -join '').Trim()
if ($LASTEXITCODE -ne 0) { throw "SSH connection to $SshAlias failed." }
if ($hostnameResult -ne $ExpectedHostname) { throw "SSH alias $SshAlias returned '$hostnameResult'; expected '$ExpectedHostname'." }

$ipCommand = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '$ExpectedIp') { '$ExpectedIp' } else { exit 9 }"
$ipResult = (@(& ssh -o BatchMode=yes $SshAlias powershell -NoProfile -Command $ipCommand) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $ipResult -ne $ExpectedIp) { throw "Remote IPv4 verification failed; expected $ExpectedIp." }

Write-Host "[INFO] Verified $SshAlias -> $ExpectedHostname / $ExpectedIp."
& ssh -o BatchMode=yes $SshAlias powershell -NoProfile -ExecutionPolicy Bypass -File $RemoteLoader
if ($LASTEXITCODE -ne 0) { throw "Remote BLUE Q5_K_M loader failed with exit code $LASTEXITCODE." }

$powerRows = @(& ssh -o BatchMode=yes $SshAlias nvidia-smi --query-gpu=name,pci.bus_id,power.limit --format=csv,noheader,nounits | ConvertFrom-Csv -Header @('name', 'pci_bus_id', 'power_limit_w'))
if ($LASTEXITCODE -ne 0) { throw 'Remote GPU Power Limit verification failed.' }
foreach ($expected in @(
    [pscustomobject]@{ name = $Rtx3090Name; bus = $Rtx3090Bus; watts = 259.0 },
    [pscustomobject]@{ name = $Rtx3060Name; bus = $Rtx3060Bus; watts = 170.0 }
)) {
    $matches = @($powerRows | Where-Object {
        $_.name.Trim() -eq $expected.name -and $_.pci_bus_id.Trim().ToUpperInvariant() -eq $expected.bus
    })
    if ($matches.Count -ne 1) { throw "Expected one remote $($expected.name) at PCI Bus $($expected.bus), found $($matches.Count)." }
    $actual = [double]::Parse($matches[0].power_limit_w.Trim(), [Globalization.CultureInfo]::InvariantCulture)
    if ([Math]::Abs($actual - $expected.watts) -gt 0.5) { throw "Remote $($expected.name) Power Limit is ${actual}W; expected $($expected.watts)W." }
}

$catalog = Invoke-RestMethod -Uri 'http://192.168.0.104:1234/api/v1/models' -Method Get -TimeoutSec 15
$loadedParents = @($catalog.models | Where-Object { @($_.loaded_instances | ForEach-Object id) -contains $Identifier })
if ($loadedParents.Count -ne 1) { throw "Expected one remotely loaded model for '$Identifier', found $($loadedParents.Count)." }
if ($loadedParents[0].capabilities.vision -ne $true) { throw 'Remote API does not report Vision true for Q5_K_M.' }
$loadedMatches = @($loadedParents[0].loaded_instances | Where-Object { $_.id -eq $Identifier })
if ($loadedMatches.Count -ne 1) { throw "Expected one remotely loaded instance '$Identifier', found $($loadedMatches.Count)." }
$instance = $loadedMatches[0]
if ([int]$instance.config.context_length -ne 98304 -or [int]$instance.config.parallel -ne 1) {
    throw 'Remote API effective state did not report 96K context and parallel 1.'
}
if ([int]$instance.config.eval_batch_size -ne 1024 -or [int]$instance.config.physical_batch_size -ne 512 -or
    $instance.config.flash_attention -ne $true -or $instance.config.offload_kv_cache_to_gpu -ne $true -or
    $instance.config.speculative_draft_mtp -ne $true -or [int]$instance.config.speculative_draft_max_tokens -ne 3) {
    throw 'Remote API effective state did not report the qualified MTP3/Q8-GPU/batch1024/ubatch512 profile.'
}

$psText = (@(& ssh -o BatchMode=yes $SshAlias lms ps --json) -join [Environment]::NewLine)
if ($LASTEXITCODE -ne 0) { throw 'Remote lms ps verification failed.' }
$psEntries = @($psText | ConvertFrom-Json)
$psTarget = @($psEntries | Where-Object { $_.identifier -eq $Identifier })
if ($psTarget.Count -ne 1 -or $psTarget[0].status -ne 'idle' -or [int]$psTarget[0].queued -ne 0) {
    throw 'Remote lms ps did not report exactly one Q5_K_M instance in IDLE state with queued 0.'
}

Write-Host '[OK] BLUE Q5_K_M Vision 96K Recommended is reachable from MAIN.'
Write-Host '[OK] Base URL: http://192.168.0.104:1234/v1'
Write-Host "[OK] Model ID: $Identifier"
Write-Host '[OK] Power Limits: RTX3090 259W / RTX3060 170W'
