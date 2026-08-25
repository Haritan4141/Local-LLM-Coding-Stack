[CmdletBinding()]
param(
    [ValidateSet('96K', '64K')]
    [string]$Profile = '96K'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedMainHostname = 'DESKTOP-5NPLIIV'
$SshAlias = 'pc7600x'
$ExpectedHostname = 'DESKTOP-LMB720F'
$ExpectedIp = '192.168.0.103'
$ExpectedGpuName = 'AMD Radeon RX 9070 XT'
$ExpectedArchitecture = 'gfx1201'
$ExpectedRuntimeName = 'llama.cpp-win-x86_64-amd-rocm-avx2'
$ExpectedRuntimeVersion = '2.29.1'
$ExpectedModelKey = 'qwen3.8-27b-uncensored'
$ExpectedQuantization = 'IQ4_XS'
$ExpectedSizeBytes = [int64]15309039008
$Identifier = 'qwen3.8-27b-uncensored-iq4xs-red'
$FirewallRule = 'Local-LLM-LMStudio-RX9070XT-In-TCP-1234-Private-LocalSubnet'
$LanBaseUrl = 'http://192.168.0.103:1234'
$SdkBaseUrl = 'ws://192.168.0.103:1234'
$SharedLimitBytes = [int64]4GB
$MinimumDedicatedHeadroomBytes = [int64]768MB
$ContextLength = if ($Profile -eq '96K') { 98304 } else { 65536 }

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$managedLoader = Join-Path $repoRoot 'scripts\lmstudio\Load-ManagedModel.mjs'
$managedTest = Join-Path $repoRoot 'scripts\lmstudio\Test-ManagedModel.mjs'

function Invoke-RemoteText {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lines = @(& ssh -o BatchMode=yes -o ConnectTimeout=10 $SshAlias @Arguments 2>$null)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        throw "Remote command failed: $($Arguments -join ' ')"
    }
    return ($lines -join [Environment]::NewLine).Trim()
}

function Invoke-RemotePowerShell {
    param([Parameter(Mandatory)][string]$Command)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    return Invoke-RemoteText -Arguments @('powershell', '-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
}

if ([Environment]::MachineName -ne $ExpectedMainHostname) {
    throw "This REMOTE loader must run on $ExpectedMainHostname; observed $([Environment]::MachineName)."
}
foreach ($command in @('ssh', 'node')) {
    if ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required MAIN command is unavailable: $command"
    }
}
foreach ($path in @($managedLoader, $managedTest)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required managed helper was not found: $path"
    }
}

$hostnameResult = Invoke-RemoteText -Arguments @('hostname')
if (-not $hostnameResult.Equals($ExpectedHostname, [StringComparison]::OrdinalIgnoreCase)) {
    throw "SSH alias $SshAlias returned '$hostnameResult'; expected '$ExpectedHostname'."
}
$ipResult = Invoke-RemotePowerShell -Command "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '$ExpectedIp') { '$ExpectedIp' } else { exit 9 }"
if ($ipResult -ne $ExpectedIp) { throw "Remote IPv4 verification failed; expected $ExpectedIp." }

$firewallCommand = @'
$rule = Get-NetFirewallRule -Name 'Local-LLM-LMStudio-RX9070XT-In-TCP-1234-Private-LocalSubnet' -ErrorAction Stop
$port = $rule | Get-NetFirewallPortFilter
$address = $rule | Get-NetFirewallAddressFilter
$app = $rule | Get-NetFirewallApplicationFilter
[pscustomobject]@{
  enabled = [int]$rule.Enabled
  profile = [int]$rule.Profile
  edge = [int]$rule.EdgeTraversalPolicy
  protocol = [string]$port.Protocol
  local_port = [string]$port.LocalPort
  remote_address = @($address.RemoteAddress)
  program = [string]$app.Program
} | ConvertTo-Json -Compress
'@
$firewall = Invoke-RemotePowerShell -Command $firewallCommand | ConvertFrom-Json
if ($firewall.enabled -ne 1 -or $firewall.profile -ne 2 -or $firewall.edge -ne 0 -or
    $firewall.protocol -ne 'TCP' -or $firewall.local_port -ne '1234' -or
    'LocalSubnet' -notin @($firewall.remote_address) -or
    $firewall.program -ne 'C:\Users\Atsuki\AppData\Local\Programs\LM Studio\LM Studio.exe') {
    throw "Firewall rule '$FirewallRule' does not match the managed Private/LocalSubnet boundary."
}

$listener = Invoke-RemotePowerShell -Command "if (Get-NetTCPConnection -State Listen -LocalPort 1234 -ErrorAction SilentlyContinue | Where-Object LocalAddress -eq '0.0.0.0') { 'LISTEN' }"
if ($listener -ne 'LISTEN') {
    Write-Host '[INFO] Starting the RED LM Studio LAN server...'
    Invoke-RemoteText -Arguments @('lms', 'server', 'start', '--port', '1234', '--bind', '0.0.0.0') | Write-Host
    Start-Sleep -Seconds 2
    $listener = Invoke-RemotePowerShell -Command "if (Get-NetTCPConnection -State Listen -LocalPort 1234 -ErrorAction SilentlyContinue | Where-Object LocalAddress -eq '0.0.0.0') { 'LISTEN' }"
    if ($listener -ne 'LISTEN') { throw 'RED LM Studio did not bind to 0.0.0.0:1234.' }
}
if (-not (Test-NetConnection -ComputerName $ExpectedIp -Port 1234 -InformationLevel Quiet)) {
    throw "MAIN cannot reach ${ExpectedIp}:1234."
}

$survey = Invoke-RemoteText -Arguments @('lms', 'runtime', 'survey', '--json') | ConvertFrom-Json
$engineMatches = @($survey.engines | Where-Object {
    $_.name -eq $ExpectedRuntimeName -and $_.version -eq $ExpectedRuntimeVersion -and $_.compatibility.status -eq 'compatible'
})
if ($engineMatches.Count -ne 1) {
    throw "Expected selected ROCm runtime $ExpectedRuntimeName@$ExpectedRuntimeVersion."
}
$engine = $engineMatches[0]
$runtimeGpus = @($engine.hardwareSurvey.gpuSurveyResult.gpuInfo)
$gpuMatches = @($runtimeGpus | Where-Object { $_.name -eq $ExpectedGpuName -and $_.otherInfo.gcnArchName -eq $ExpectedArchitecture })
if ($gpuMatches.Count -ne 1) { throw "Expected one $ExpectedGpuName / $ExpectedArchitecture, found $($gpuMatches.Count)." }
$priority = @([int]$gpuMatches[0].deviceId)
$disabled = @($runtimeGpus | Where-Object { [int]$_.deviceId -notin $priority } | ForEach-Object { [int]$_.deviceId })
$priorityArg = $priority -join ','
$disabledArg = if ($disabled.Count -eq 0) { 'none' } else { $disabled -join ',' }

$catalog = Invoke-RestMethod -Uri "$LanBaseUrl/api/v1/models" -Method Get -TimeoutSec 15
$modelMatches = @($catalog.models | Where-Object {
    $_.key -eq $ExpectedModelKey -and $_.quantization.name -eq $ExpectedQuantization -and [int64]$_.size_bytes -eq $ExpectedSizeBytes
})
if ($modelMatches.Count -ne 1) { throw 'The expected Jonathan IQ4_XS artifact is not uniquely installed on RED.' }
if ($modelMatches[0].capabilities.vision -ne $false -or $modelMatches[0].capabilities.trained_for_tool_use -ne $true) {
    throw 'RED model capability metadata does not match text/tool IQ4_XS.'
}

$loadedText = Invoke-RemoteText -Arguments @('lms', 'ps', '--json')
$loaded = if ([string]::IsNullOrWhiteSpace($loadedText)) { @() } else { @($loadedText | ConvertFrom-Json) }
$active = @($loaded | Where-Object {
    ($null -eq $_.PSObject.Properties['queued']) -or
    ($null -eq $_.PSObject.Properties['status']) -or
    [int]$_.queued -gt 0 -or
    $_.status -notin @('idle', 'loaded')
})
if ($active.Count -gt 0) { throw 'An LM Studio prediction is active or queued on RED. Runtime state was not changed.' }

Write-Host "[INFO] Verified $SshAlias -> $ExpectedHostname / $ExpectedIp / $ExpectedGpuName / ROCm $ExpectedRuntimeVersion."
Write-Host '[INFO] Unloading idle RED models before the managed load...'
Invoke-RemoteText -Arguments @('lms', 'unload', '--all') | Write-Host

$loadArgs = @(
    $managedLoader,
    '--base-url', $SdkBaseUrl,
    '--model-key', $ExpectedModelKey,
    '--identifier', $Identifier,
    '--context', [string]$ContextLength,
    '--mtp', 'on',
    '--mtp-draft', '2',
    '--kv-k', 'q4_0',
    '--kv-v', 'q4_0',
    '--mmap', 'on',
    '--keep-model-in-memory', 'on',
    '--strict-vram-cap', 'on',
    '--eval-batch', '512',
    '--priority', $priorityArg,
    '--disabled', $disabledArg
)

try {
    & node @loadArgs
    if ($LASTEXITCODE -ne 0) { throw "Managed model load failed with exit code $LASTEXITCODE." }

    $testArgs = @(
        $managedTest,
        '--base-url', $SdkBaseUrl,
        '--identifier', $Identifier,
        '--context', [string]$ContextLength,
        '--mtp', 'on',
        '--mtp-draft', '2',
        '--kv-k', 'q4_0',
        '--kv-v', 'q4_0',
        '--mmap', 'on',
        '--keep-model-in-memory', 'on',
        '--strict-vram-cap', 'on',
        '--eval-batch', '512',
        '--priority', $priorityArg,
        '--disabled', $disabledArg,
        '--vision-required', 'off'
    )
    & node @testArgs
    if ($LASTEXITCODE -ne 0) { throw "Managed model audit failed with exit code $LASTEXITCODE." }

    $memoryCommand = @'
$row = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory |
  Sort-Object DedicatedUsage -Descending | Select-Object -First 1
[pscustomobject]@{
  name = [string]$row.Name
  dedicated_bytes = [int64]$row.DedicatedUsage
  shared_bytes = [int64]$row.SharedUsage
  committed_bytes = [int64]$row.TotalCommitted
} | ConvertTo-Json -Compress
'@
    $memory = Invoke-RemotePowerShell -Command $memoryCommand | ConvertFrom-Json
    $vramTotal = [int64]$gpuMatches[0].dedicatedMemoryCapacityBytes
    $headroom = $vramTotal - [int64]$memory.dedicated_bytes
    if ([int64]$memory.dedicated_bytes -lt 10GB -or [int64]$memory.shared_bytes -gt $SharedLimitBytes -or
        $headroom -lt $MinimumDedicatedHeadroomBytes) {
        throw ("RED capacity gate failed: Dedicated {0:N3} GiB, Shared {1:N3} GiB, headroom {2:N3} GiB." -f @(
            ([int64]$memory.dedicated_bytes / 1GB),
            ([int64]$memory.shared_bytes / 1GB),
            ($headroom / 1GB)
        ))
    }

    $loadedAfter = @(Invoke-RemoteText -Arguments @('lms', 'ps', '--json') | ConvertFrom-Json)
    $target = @($loadedAfter | Where-Object { $_.identifier -eq $Identifier })
    if ($target.Count -ne 1 -or [int]$target[0].contextLength -ne $ContextLength -or
        [int]$target[0].parallel -ne 1 -or [int]$target[0].queued -ne 0 -or $target[0].status -ne 'idle') {
        throw 'RED lms ps did not report exactly one intended IDLE instance.'
    }

    Write-Host ("[OK] RED Jonathan IQ4_XS {0} is ready: Dedicated {1:N3} GiB / Shared {2:N3} GiB / headroom {3:N3} GiB." -f @(
        $Profile,
        ([int64]$memory.dedicated_bytes / 1GB),
        ([int64]$memory.shared_bytes / 1GB),
        ($headroom / 1GB)
    )) -ForegroundColor Green
    Write-Host "[OK] Base URL: $LanBaseUrl/v1" -ForegroundColor Green
    Write-Host "[OK] Model ID: $Identifier" -ForegroundColor Green
} catch {
    Write-Warning "RED managed load failed; unloading '$Identifier'."
    try { Invoke-RemoteText -Arguments @('lms', 'unload', $Identifier) | Write-Warning } catch { Write-Warning $_ }
    throw
}
