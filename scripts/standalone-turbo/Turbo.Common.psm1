Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-TurboExpandedPath {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($Path))
}

function Get-TurboFileSha256 {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-TurboProfileManifest {
    param([Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE')][string]$Profile)

    $path = Join-Path $PSScriptRoot "runtime-manifests\$Profile.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Turbo runtime manifest is missing: $path"
    }
    $manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$manifest.schema_version -ne 1) { throw "Unsupported Turbo manifest schema: $($manifest.schema_version)" }
    if ($manifest.server.host -ne '127.0.0.1' -or [int]$manifest.server.port -ne 18080) {
        throw 'Turbo manifest must bind only to 127.0.0.1:18080.'
    }
    if ([int]$manifest.configuration.context_tokens -ne 98304 -or
        $manifest.configuration.kv_cache_k -ne 'q8_0' -or
        $manifest.configuration.kv_cache_v -ne 'q8_0' -or
        $manifest.configuration.mtp_enabled -ne $true -or
        [int]$manifest.configuration.mtp_draft_max_tokens -ne 3 -or
        [int]$manifest.configuration.eval_batch_size -ne 1024 -or
        [int]$manifest.configuration.ubatch_size -ne 512 -or
        [int]$manifest.configuration.parallel -ne 1 -or
        $manifest.configuration.flash_attention -ne $true -or
        $manifest.configuration.vision -ne $true -or
        $manifest.configuration.dflash2 -ne $false) {
        throw 'Turbo manifest does not describe the qualified 96K/Q8/MTP3/batch1024/ubatch512/Vision configuration.'
    }
    return $manifest
}

function Get-TurboRuntimeInfo {
    param([Parameter(Mandatory)]$Manifest)

    $root = Resolve-TurboExpandedPath $Manifest.runtime.external_path
    $executable = Join-Path $root $Manifest.runtime.executable
    $bundleManifest = Join-Path $root $Manifest.runtime.bundle_manifest
    return [pscustomobject]@{
        root = $root
        executable = $executable
        bundle_manifest = $bundleManifest
        model = Resolve-TurboExpandedPath $Manifest.model.path
        projector = Resolve-TurboExpandedPath $Manifest.model.projector_path
    }
}

function Get-TurboStorage {
    param([Parameter(Mandatory)]$Manifest)

    $root = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\turbo'
    return [pscustomobject]@{
        root = $root
        active_state = Join-Path $root "$($Manifest.profile_id).json"
        history = Join-Path $root 'history'
        logs = Join-Path $root 'logs'
    }
}

function Write-TurboJson {
    param(
        [Parameter(Mandatory)]$InputObject,
        [Parameter(Mandatory)][string]$Path,
        [ValidateRange(2, 20)][int]$Depth = 12
    )
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $InputObject | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Move-TurboStateToHistory {
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][string]$HistoryRoot,
        [Parameter(Mandatory)][string]$Reason
    )
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    if (-not (Test-Path -LiteralPath $HistoryRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $HistoryRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $destination = Join-Path $HistoryRoot ("{0}-{1}.json" -f ([IO.Path]::GetFileNameWithoutExtension($StatePath)), $stamp)
    $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $state | Add-Member -NotePropertyName archived_at -NotePropertyValue (Get-Date).ToString('o') -Force
    $state | Add-Member -NotePropertyName archive_reason -NotePropertyValue $Reason -Force
    Write-TurboJson -InputObject $state -Path $destination
    Remove-Item -LiteralPath $StatePath -Force
    return $destination
}

function Get-TurboGpuState {
    $rows = @(& nvidia-smi '--query-gpu=uuid,name,pci.bus_id,power.limit,memory.used,memory.total' '--format=csv,noheader,nounits')
    if ($LASTEXITCODE -ne 0) { throw 'nvidia-smi GPU identity/power/memory query failed.' }
    return @($rows | ConvertFrom-Csv -Header @('uuid', 'name', 'pci_bus_id', 'power_limit_w', 'memory_used_mib', 'memory_total_mib'))
}

function Assert-TurboHostAndGpu {
    param([Parameter(Mandatory)]$Manifest)

    if ([Environment]::MachineName -ne $Manifest.target_host.computer_name) {
        throw "Turbo profile requires $($Manifest.target_host.computer_name); observed $([Environment]::MachineName)."
    }
    $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object IPAddress)
    if ($Manifest.target_host.ipv4 -notin $addresses) {
        throw "Expected IPv4 $($Manifest.target_host.ipv4) was not found. No runtime state was changed."
    }

    $rows = @(Get-TurboGpuState)
    $resolved = @()
    foreach ($expected in @($Manifest.gpus)) {
        $matches = @($rows | Where-Object {
            $_.name.Trim() -eq $expected.name -and
            $_.pci_bus_id.Trim().ToUpperInvariant() -eq $expected.pci_bus_id
        })
        if ($matches.Count -ne 1) {
            throw "Expected one $($expected.name) at PCI Bus $($expected.pci_bus_id), found $($matches.Count)."
        }
        $actualPower = [double]::Parse($matches[0].power_limit_w.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        if ([Math]::Abs($actualPower - [double]$expected.power_limit_w) -gt 0.5) {
            throw "$($expected.name) at $($expected.pci_bus_id) has Power Limit ${actualPower}W; expected $($expected.power_limit_w)W. Power Limit was not changed."
        }
        $resolved += $matches[0]
    }
    return $resolved
}

function Get-TurboLmsModels {
    $lines = @(& lms ps --json)
    if ($LASTEXITCODE -ne 0) { throw 'lms ps --json failed.' }
    $text = $lines -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $parsed = $text | ConvertFrom-Json
    return @($parsed | ForEach-Object { $_ } | Where-Object { $null -ne $_ })
}

function Assert-TurboLmsIdle {
    $models = @(Get-TurboLmsModels)
    $unsafe = @($models | Where-Object {
        $null -eq $_.PSObject.Properties['status'] -or
        $null -eq $_.PSObject.Properties['queued'] -or
        $_.status -notin @('idle', 'loaded') -or
        [int]$_.queued -gt 0
    })
    if ($unsafe.Count -gt 0) {
        $ids = ($unsafe | ForEach-Object {
            if ($null -ne $_.PSObject.Properties['identifier']) { $_.identifier } else { '<unknown>' }
        }) -join ', '
        throw "LM Studio has an active or queued prediction ($ids). Turbo switching was refused without unloading it."
    }
    return $models
}

function Wait-TurboLmsEmpty {
    param([ValidateRange(5, 300)][int]$TimeoutSeconds = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (@(Get-TurboLmsModels).Count -eq 0) { return }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw 'LM Studio did not release all loaded models before the timeout.'
}

function Wait-TurboVramReleased {
    param(
        [Parameter(Mandatory)]$Manifest,
        [ValidateRange(5, 300)][int]$TimeoutSeconds = 120
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $rows = @(Get-TurboGpuState)
        $allReleased = $true
        foreach ($expected in @($Manifest.gpus)) {
            $row = @($rows | Where-Object {
                $_.name.Trim() -eq $expected.name -and
                $_.pci_bus_id.Trim().ToUpperInvariant() -eq $expected.pci_bus_id
            })
            if ($row.Count -ne 1 -or [double]$row[0].memory_used_mib -gt [double]$expected.vram_release_max_mib) {
                $allReleased = $false
            }
        }
        if ($allReleased) { return $rows }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    throw 'Qualified GPU VRAM did not return to the managed release baseline before the timeout.'
}

function Assert-TurboVramLoaded {
    param([Parameter(Mandatory)]$Manifest)
    $rows = @(Get-TurboGpuState)
    $report = [Collections.Generic.List[string]]::new()
    $failed = $false
    foreach ($expected in @($Manifest.gpus)) {
        $row = @($rows | Where-Object {
            $_.name.Trim() -eq $expected.name -and
            $_.pci_bus_id.Trim().ToUpperInvariant() -eq $expected.pci_bus_id
        })
        $identity = "$($expected.name) / PCI $($expected.pci_bus_id)"
        if ($row.Count -ne 1) {
            $report.Add("$identity : identity mismatch (expected 1 GPU, found $($row.Count)); memory usage unknown.")
            $failed = $true
            continue
        }
        $used = 0.0
        $valid = [double]::TryParse(([string]$row[0].memory_used_mib).Trim(), [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$used)
        if (-not $valid -or [double]::IsNaN($used) -or [double]::IsInfinity($used) -or $used -lt 0) {
            $report.Add("$identity : memory usage unavailable ('$($row[0].memory_used_mib)').")
            $failed = $true
            continue
        }
        $minimum = [double]$expected.vram_loaded_min_mib
        $status = if ($used -ge $minimum) { 'PASS' } else { 'BELOW MINIMUM'; $failed = $true }
        $report.Add(('{0} : current {1} MiB / required minimum {2} MiB [{3}]' -f $identity,
            $used.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture),
            $minimum.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture), $status))
    }
    if ($failed) {
        throw ("[TURBO_VRAM_RESIDENCY] Turbo GPU memory verification failed.`n" + ($report -join "`n") +
            "`nValues are total GPU memory.used from nvidia-smi, not free VRAM or process-specific residency." +
            "`nThis does not by itself prove out-of-memory, model corruption, or Windows paging.")
    }
    return $rows
}

function Invoke-TurboSshText {
    param([Parameter(Mandatory)][string]$SshAlias, [Parameter(Mandatory)][string]$Code)

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
    # PS 5.1 otherwise turns native stderr into a terminating, width-formatted ErrorRecord.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& ssh.exe -o BatchMode=yes -o ConnectTimeout=10 $SshAlias powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded 2>&1 |
            ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    return [pscustomobject]@{ exit_code = $exitCode; output = $output }
}

function Get-TurboPortListeners {
    param([Parameter(Mandatory)][int]$Port)
    return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
}

function Get-TurboProcessRecord {
    param([Parameter(Mandatory)][int]$ProcessId)
    $record = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
    if ($null -eq $record) { return $null }
    return [pscustomobject]@{
        pid = [int]$record.ProcessId
        executable_path = [string]$record.ExecutablePath
        command_line = [string]$record.CommandLine
    }
}

function Assert-ManagedTurboProcess {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)]$Manifest,
        [switch]$RequireListener
    )
    $process = Get-TurboProcessRecord -ProcessId ([int]$State.pid)
    if ($null -eq $process) { throw "Managed Turbo PID $($State.pid) is not running." }
    $runtime = Get-TurboRuntimeInfo -Manifest $Manifest
    $expectedExe = [IO.Path]::GetFullPath([string]$runtime.executable)
    $stateExe = [IO.Path]::GetFullPath([string]$State.executable_path)
    $actualExe = [IO.Path]::GetFullPath([string]$process.executable_path)
    if (-not $stateExe.Equals($expectedExe, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Managed state executable path does not match the pinned runtime. PID $($State.pid) was not stopped."
    }
    if (-not $actualExe.Equals($expectedExe, [StringComparison]::OrdinalIgnoreCase)) {
        throw "PID $($State.pid) executable mismatch. Expected '$expectedExe'; observed '$actualExe'. It was not stopped."
    }
    $expectedModel = [IO.Path]::GetFullPath([string]$runtime.model)
    $stateModel = [IO.Path]::GetFullPath([string]$State.model_path)
    if (-not $stateModel.Equals($expectedModel, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Managed state model path does not match the pinned target. PID $($State.pid) was not stopped."
    }
    foreach ($property in @('profile_id', 'source_commit', 'server_host', 'server_port', 'api_model_alias', 'executable_sha256', 'model_sha256')) {
        if ($null -eq $State.PSObject.Properties[$property]) {
            throw "Managed state is missing '$property'. PID $($State.pid) was not stopped."
        }
    }
    if ($State.profile_id -ne $Manifest.profile_id -or
        $State.source_commit -ne $Manifest.runtime.source_commit -or
        $State.server_host -ne $Manifest.server.host -or
        [int]$State.server_port -ne [int]$Manifest.server.port -or
        $State.api_model_alias -ne $Manifest.server.api_model_alias -or
        $State.executable_sha256 -ne $Manifest.runtime.executable_expected_sha256 -or
        $State.model_sha256 -ne $Manifest.model.sha256) {
        throw "Managed state metadata does not match the pinned profile. PID $($State.pid) was not stopped."
    }
    foreach ($fragment in @(
        "--alias $($Manifest.server.api_model_alias)",
        "--port $($Manifest.server.port)"
    )) {
        if ($process.command_line.IndexOf($fragment, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "PID $($State.pid) command line does not contain managed fragment '$fragment'. It was not stopped."
        }
    }
    if ($process.command_line.IndexOf($expectedModel, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "PID $($State.pid) command line model path mismatch. It was not stopped."
    }
    if ($RequireListener) {
        $listeners = @(Get-TurboPortListeners -Port ([int]$Manifest.server.port))
        $owned = @($listeners | Where-Object { [int]$_.OwningProcess -eq [int]$State.pid -and $_.LocalAddress -eq '127.0.0.1' })
        if ($owned.Count -ne 1 -or $listeners.Count -ne 1) {
            throw "Managed Turbo PID $($State.pid) does not exclusively own 127.0.0.1:$($Manifest.server.port)."
        }
    }
    return $process
}

function Test-TurboApiState {
    param(
        [Parameter(Mandatory)]$Manifest,
        [string]$BaseUrl
    )
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = "http://$($Manifest.server.host):$($Manifest.server.port)"
    }
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
    if ($health.status -ne 'ok') { throw "Turbo health is not OK at $BaseUrl." }
    $props = Invoke-RestMethod -Uri "$BaseUrl/props" -TimeoutSec 15
    if ($props.model_alias -ne $Manifest.server.api_model_alias -or
        [int]$props.default_generation_settings.n_ctx -ne [int]$Manifest.configuration.context_tokens -or
        [int]$props.total_slots -ne [int]$Manifest.configuration.parallel -or
        $props.modalities.vision -ne $true) {
        throw 'Turbo /props does not match alias/context/parallel/Vision expectations.'
    }
    $models = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -TimeoutSec 15
    $matches = @($models.data | Where-Object { $_.id -eq $Manifest.server.api_model_alias })
    if ($matches.Count -ne 1 -or [int]$matches[0].meta.n_ctx -ne [int]$Manifest.configuration.context_tokens) {
        throw 'Turbo /v1/models does not expose the expected alias and context.'
    }
    return [pscustomobject]@{ base_url = $BaseUrl; health = $health; props = $props; model = $matches[0] }
}

Export-ModuleMember -Function *
