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
    param([Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick', 'BLUE-IQ4XS256K', 'RTX5090-IQ4XS256K')][string]$Profile)

    $path = Join-Path $PSScriptRoot "runtime-manifests\$Profile.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Turbo runtime manifest is missing: $path"
    }
    $manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$manifest.schema_version -ne 1) { throw "Unsupported Turbo manifest schema: $($manifest.schema_version)" }
    if ($manifest.server.host -ne '127.0.0.1' -or [int]$manifest.server.port -ne 18080) {
        throw 'Turbo manifest must bind only to 127.0.0.1:18080.'
    }
    $expectedUbatch = if ($Profile -in @('BLUE-IQ4XS256K', 'RTX5090-IQ4XS256K')) { 256 } else { 512 }
    if ($manifest.configuration.kv_cache_k -ne 'q8_0' -or
        $manifest.configuration.kv_cache_v -ne 'q8_0' -or
        [int]$manifest.configuration.eval_batch_size -ne 1024 -or
        [int]$manifest.configuration.ubatch_size -ne $expectedUbatch -or
        [int]$manifest.configuration.parallel -ne 1 -or
        $manifest.configuration.flash_attention -ne $true -or
        $manifest.configuration.dflash2 -ne $false) {
        throw 'Managed standalone manifest does not match its fixed Q8/batch1024/ubatch/parallel1 baseline.'
    }
    if ($Profile -in @('BLUE-IQ4XS256K', 'RTX5090-IQ4XS256K') -and $manifest.profile_class -ne 'extended-context') {
        throw 'IQ4_XS 256K must remain an extended-context Candidate.'
    }
    if ($manifest.profile_class -eq 'turbo') {
        if ([int]$manifest.configuration.context_tokens -ne 98304 -or
            $manifest.configuration.mtp_enabled -ne $true -or
            [int]$manifest.configuration.mtp_draft_max_tokens -ne 3 -or
            $manifest.configuration.vision -ne $true) {
            throw 'Turbo manifest does not describe the qualified 96K/MTP3/Vision configuration.'
        }
    }
    elseif ($manifest.profile_class -eq 'quick-response') {
        if ([int]$manifest.configuration.context_tokens -ne 65536 -or
            $manifest.configuration.mtp_enabled -ne $true -or
            [int]$manifest.configuration.mtp_draft_max_tokens -ne 1 -or
            $manifest.configuration.vision -ne $true -or
            [string]::IsNullOrWhiteSpace([string]$manifest.model.projector_path) -or
            [string]::IsNullOrWhiteSpace([string]$manifest.model.projector_sha256) -or
            $manifest.configuration.reasoning_mode -ne 'on' -or
            $manifest.configuration.reasoning_effort -ne 'low' -or
            [int]$manifest.configuration.reasoning_budget_tokens -ne 2048 -or
            [int]$manifest.goose.client_context_tokens -ne 57344 -or
            [int]$manifest.goose.max_output_tokens -ne 8192 -or
            [string]$manifest.server.api_model_alias -notmatch '^qwen3\.8-27b-uncensored-vision-q5km(?:-blue)?-quick-gpt-4o$' -or
            $null -eq $manifest.server.PSObject.Properties['legacy_api_model_aliases'] -or
            @($manifest.server.legacy_api_model_aliases).Count -ne 2 -or
            'gpt-4o' -notin @($manifest.server.legacy_api_model_aliases) -or
            [string]::IsNullOrWhiteSpace([string]$manifest.server.api_alias_purpose)) {
            throw 'Quick Response manifest does not describe the 64K/8K/MTP1/Reasoning-Low Vision Candidate.'
        }
    }
    elseif ($manifest.profile_class -eq 'extended-context' -and $Profile -eq 'RTX5090-IQ4XS256K') {
        if ($manifest.status -ne 'Candidate' -or
            $manifest.profile_id -ne 'rtx5090-iq4xs-vision-256k-mtp3-candidate' -or
            $manifest.target_host.computer_name -ne 'DESKTOP-5NPLIIV' -or $manifest.target_host.ipv4 -ne '192.168.0.100' -or
            $manifest.server.api_model_alias -ne 'qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o' -or
            [int]$manifest.configuration.context_tokens -ne 262144 -or $manifest.configuration.vision -ne $true -or
            $manifest.configuration.mtp_enabled -ne $true -or [int]$manifest.configuration.mtp_draft_max_tokens -ne 3 -or
            $manifest.configuration.load_mode -ne 'mmap+mlock' -or $null -ne $manifest.configuration.tensor_split -or
            $null -ne $manifest.configuration.split_mode -or
            $manifest.configuration.mtp_draft_kv_k -ne 'f16' -or $manifest.configuration.mtp_draft_kv_v -ne 'f16' -or
            $manifest.configuration.reasoning_mode -ne 'off' -or $manifest.configuration.reasoning_effort -ne 'default' -or
            [int]$manifest.configuration.reasoning_budget_tokens -ne 0 -or $manifest.configuration.reasoning_preserve -ne $false -or
            $manifest.configuration.jinja -ne $true -or $manifest.configuration.prompt_cache -ne $true -or
            [int]$manifest.configuration.cache_reuse_min_tokens -ne 0 -or
            $manifest.runtime.source_commit -ne 'f280b26983ad0fdb705a0d9ebf0503e76f2899b0' -or
            $manifest.runtime.executable_expected_sha256 -ne '103eb1ee3cbc55f08ee4df180b09305c17b2a844364436417f8f022326ef35f5' -or
            $manifest.model.sha256 -ne '53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5' -or
            $manifest.model.projector_sha256 -ne '5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c' -or
            [int]$manifest.goose.client_context_tokens -ne 237568 -or [int]$manifest.goose.max_output_tokens -ne 16384 -or
            [double]$manifest.goose.auto_compact_threshold -ne 0.6 -or [double]$manifest.goose.temperature -ne 0 -or
            [int]$manifest.goose.input_growth_reserve_tokens -ne 8192 -or
            $manifest.memory_gate.probe -ne 'Read-MainExtendedMemory.py' -or
            [int]$manifest.memory_gate.combined_shared_gib_strictly_below -ne 4 -or
            [int]$manifest.memory_gate.each_gpu_shared_gib_max -ne 2 -or [int]$manifest.memory_gate.each_gpu_free_mib_min -ne 1024 -or
            @($manifest.gpus).Count -ne 1 -or $manifest.gpus[0].name -ne 'NVIDIA GeForce RTX 5090' -or
            $manifest.gpus[0].pci_bus_id -ne '00000000:01:00.0' -or [int]$manifest.gpus[0].power_limit_w -ne 402) {
            throw 'MAIN extended context differs from the pinned RTX5090 IQ4_XS Vision256K Candidate.'
        }
    }
    elseif ($manifest.profile_class -eq 'extended-context') {
        if ($Profile -ne 'BLUE-IQ4XS256K' -or $manifest.status -ne 'Candidate' -or
            $manifest.profile_id -ne 'blue-iq4xs-vision-256k-mtp3-candidate' -or
            $manifest.target_host.computer_name -ne 'DESKTOP-L9HAM1G' -or
            $manifest.target_host.ipv4 -ne '192.168.0.104' -or $manifest.target_host.ssh_alias -ne 'pc5700x' -or
            [int]$manifest.server.main_tunnel_port -ne 18081 -or
            $manifest.server.api_model_alias -ne 'qwen3.8-27b-uncensored-vision-iq4xs-blue-256k-gpt-4o' -or
            [int]$manifest.configuration.context_tokens -ne 262144 -or
            $manifest.configuration.mtp_enabled -ne $true -or [int]$manifest.configuration.mtp_draft_max_tokens -ne 3 -or
            $manifest.configuration.vision -ne $true -or $manifest.configuration.load_mode -ne 'no-mmap' -or
            $manifest.configuration.split_mode -ne 'layer' -or $manifest.configuration.tensor_split -ne '0.75,0.25' -or
            $manifest.configuration.reasoning_mode -ne 'off' -or
            $manifest.configuration.reasoning_effort -ne 'default' -or [int]$manifest.configuration.reasoning_budget_tokens -ne 0 -or
            $manifest.configuration.jinja -ne $true -or $manifest.configuration.prompt_cache -ne $true -or
            [int]$manifest.configuration.cache_reuse_min_tokens -ne 0 -or
            $manifest.configuration.reasoning_preserve -ne $false -or
            $manifest.configuration.mtp_draft_kv_k -ne 'f16' -or $manifest.configuration.mtp_draft_kv_v -ne 'f16' -or
            $manifest.runtime.source_commit -ne 'f280b26983ad0fdb705a0d9ebf0503e76f2899b0' -or
            $manifest.runtime.executable_expected_sha256 -ne '970fa271bf4b8b2354cd399a702c8f882da3a14710d4730833cb687f64154ca4' -or
            $manifest.model.sha256 -ne '53adc4bbed67044d662273356bbf3a50fdec667ac21bbf18d13e5815fbccc7f5' -or
            $manifest.model.projector_sha256 -ne '5ac423f8a29059dc24e51bc6a43e9380dcd57a9347f28b62591e0b3f60b7081c' -or
            [int]$manifest.goose.client_context_tokens -ne 237568 -or [int]$manifest.goose.max_output_tokens -ne 16384 -or
            [double]$manifest.goose.auto_compact_threshold -ne 0.6 -or [double]$manifest.goose.temperature -ne 0 -or
            [int]$manifest.goose.input_growth_reserve_tokens -ne 8192 -or
            [int]$manifest.memory_gate.combined_shared_gib_strictly_below -ne 4 -or
            [int]$manifest.memory_gate.each_gpu_shared_gib_max -ne 2 -or [int]$manifest.memory_gate.each_gpu_free_mib_min -ne 1024 -or
            $manifest.memory_gate.probe -ne 'Read-BlueExtendedMemory.py') {
            throw 'Extended Context manifest differs from the BLUE IQ4_XS Vision256K/Q8/MTP3/ubatch256/75:25 Candidate.'
        }
    }
    else {
        throw "Unknown managed standalone profile class: $($manifest.profile_class)"
    }
    return $manifest
}

function Get-TurboRuntimeInfo {
    param([Parameter(Mandatory)]$Manifest)

    $root = Resolve-TurboExpandedPath $Manifest.runtime.external_path
    $executable = Join-Path $root $Manifest.runtime.executable
    $bundleManifest = Join-Path $root $Manifest.runtime.bundle_manifest
    $projector = $null
    if ($Manifest.configuration.vision -eq $true) {
        $projector = Resolve-TurboExpandedPath $Manifest.model.projector_path
    }
    return [pscustomobject]@{
        root = $root
        executable = $executable
        bundle_manifest = $bundleManifest
        model = Resolve-TurboExpandedPath $Manifest.model.path
        projector = $projector
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

function Enter-TurboOperationLock {
    param(
        [Parameter(Mandatory)]$Manifest,
        [ValidateRange(1, 900)][int]$TimeoutSeconds = 600
    )

    $profileFamily = if ([string]$Manifest.profile_id -like 'blue-*') { 'BLUE' } else { 'RTX5090' }
    $name = "Local\LocalLLMCS-ManagedRuntime-$profileFamily-$([int]$Manifest.server.port)"
    $mutex = [Threading.Mutex]::new($false, $name)
    $acquired = $false
    try {
        try {
            $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))
        }
        catch [Threading.AbandonedMutexException] {
            # The previous owner terminated without releasing the lock. This
            # thread owns it now and still performs all normal safety checks.
            $acquired = $true
        }
        if (-not $acquired) {
            throw "Managed $profileFamily runtime operation is already in progress. No runtime state was changed."
        }
        return [pscustomobject]@{ name = $name; mutex = $mutex; acquired = $true }
    }
    catch {
        if (-not $acquired) { $mutex.Dispose() }
        throw
    }
}

function Exit-TurboOperationLock {
    param([Parameter(Mandatory)]$Lock)

    if ($Lock.acquired -eq $true) {
        $Lock.mutex.ReleaseMutex()
        $Lock.acquired = $false
    }
    $Lock.mutex.Dispose()
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
        [Parameter(Mandatory)][string]$Reason,
        [int]$ExpectedProcessId = 0
    )
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    if (-not (Test-Path -LiteralPath $HistoryRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $HistoryRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $destination = Join-Path $HistoryRoot ("{0}-{1}.json" -f ([IO.Path]::GetFileNameWithoutExtension($StatePath)), $stamp)
    $state = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($ExpectedProcessId -gt 0 -and
        ($null -eq $state.PSObject.Properties['pid'] -or [int]$state.pid -ne $ExpectedProcessId)) {
        # A different launcher now owns the shared profile state. Never archive
        # or remove its record while handling another process's failure.
        return $null
    }
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

function Assert-TurboExtendedMemory {
    param([Parameter(Mandatory)]$Manifest)
    if ($Manifest.profile_class -ne 'extended-context') { return $null }
    # This probe imports only the previously tested read-only telemetry functions.
    # Run before changing LM Studio state and after load/reuse; fail closed if unavailable.
    $probe = Join-Path $PSScriptRoot ([string]$Manifest.memory_gate.probe)
    if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) { throw 'Extended Context memory probe is missing.' }
    $python = (Get-Command python.exe -ErrorAction Stop).Source
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $python -B $probe 2>&1 | ForEach-Object { $_.ToString() })
        $probeExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    if ($probeExit -ne 0) { throw ("[EXTENDED_MEMORY] Capacity/identity preflight failed.`n" + ($output -join "`n")) }
    $row = ($output -join "`n") | ConvertFrom-Json
    if (@($row.gpus).Count -ne @($Manifest.gpus).Count) { throw 'Extended memory probe returned incomplete telemetry.' }
    return $row
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
        creation_time = if ($null -ne $record.CreationDate) { ([datetime]$record.CreationDate).ToString('o') } else { $null }
    }
}

function Test-TurboLegacyApiAlias {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$Alias
    )
    if ($Manifest.profile_class -ne 'quick-response' -or
        $null -eq $Manifest.server.PSObject.Properties['legacy_api_model_aliases']) {
        return $false
    }
    return $Alias -in @($Manifest.server.legacy_api_model_aliases | ForEach-Object { [string]$_ })
}

function Get-TurboAcceptedApiAliases {
    param(
        [Parameter(Mandatory)]$Manifest,
        [switch]$AllowLegacyApiAlias
    )
    $aliases = @([string]$Manifest.server.api_model_alias)
    if ($AllowLegacyApiAlias -and $Manifest.profile_class -eq 'quick-response' -and
        $null -ne $Manifest.server.PSObject.Properties['legacy_api_model_aliases']) {
        $aliases += @($Manifest.server.legacy_api_model_aliases | ForEach-Object { [string]$_ })
    }
    return @($aliases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Assert-ManagedTurboProcess {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)]$Manifest,
        [switch]$RequireListener,
        [switch]$AllowLegacyApiAlias
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
    $acceptedAliases = @(Get-TurboAcceptedApiAliases -Manifest $Manifest -AllowLegacyApiAlias:$AllowLegacyApiAlias)
    if ([string]$State.api_model_alias -notin $acceptedAliases) {
        throw "Managed state API alias '$($State.api_model_alias)' is not accepted by the pinned profile. PID $($State.pid) was not stopped."
    }
    if ($State.profile_id -ne $Manifest.profile_id -or
        $State.source_commit -ne $Manifest.runtime.source_commit -or
        $State.server_host -ne $Manifest.server.host -or
        [int]$State.server_port -ne [int]$Manifest.server.port -or
        $State.executable_sha256 -ne $Manifest.runtime.executable_expected_sha256 -or
        $State.model_sha256 -ne $Manifest.model.sha256) {
        throw "Managed state metadata does not match the pinned profile. PID $($State.pid) was not stopped."
    }
    foreach ($fragment in @(
        "--alias $($State.api_model_alias)",
        "--port $($Manifest.server.port)"
    )) {
        if ($process.command_line.IndexOf($fragment, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "PID $($State.pid) command line does not contain managed fragment '$fragment'. It was not stopped."
        }
    }
    if ($process.command_line.IndexOf($expectedModel, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "PID $($State.pid) command line model path mismatch. It was not stopped."
    }
    if ($Manifest.profile_class -eq 'extended-context') {
        $hostFragments = if ($Manifest.target_host.computer_name -eq 'DESKTOP-L9HAM1G') {
            @('--tensor-split 0.75,0.25', '--device CUDA0,CUDA1', '--no-mmap', '--fit off')
        } else { @('--device CUDA0', '--load-mode mmap+mlock', '--mmproj-offload', '--spec-draft-device CUDA0') }
        foreach ($fragment in (@('--ctx-size 262144', '--ubatch-size 256', '--batch-size 1024',
            '--cache-type-k q8_0', '--cache-type-v q8_0', '--spec-draft-type-k f16', '--spec-draft-type-v f16',
            '--spec-draft-n-max 3', '--parallel 1', '--reasoning off', '--jinja') + $hostFragments)) {
            if ($process.command_line -notmatch ('(?i)(?:^|\s)' + [regex]::Escape($fragment) + '(?=\s|$)')) {
                throw "Extended Context process is missing pinned argument '$fragment'. PID $($State.pid) was not stopped."
            }
        }
        $expectedProjector = [IO.Path]::GetFullPath([string]$runtime.projector)
        if ($null -eq $State.PSObject.Properties['projector_sha256'] -or
            $State.projector_sha256 -ne $Manifest.model.projector_sha256 -or
            $null -eq $State.PSObject.Properties['projector_path'] -or
            -not ([IO.Path]::GetFullPath([string]$State.projector_path)).Equals($expectedProjector, [StringComparison]::OrdinalIgnoreCase) -or
            $process.command_line.IndexOf($expectedProjector, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
            $process.command_line -match '(?i)(?:^|\s)--no-mmproj(?:\s|$)') {
            throw 'Extended Context Vision projector provenance/arguments do not match; no runtime was stopped.'
        }
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

function Restore-TurboStateFromHistory {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)]$Storage
    )

    if (Test-Path -LiteralPath $Storage.active_state -PathType Leaf) { return $null }
    if (-not (Test-Path -LiteralPath $Storage.history -PathType Container)) { return $null }

    $listeners = @(Get-TurboPortListeners -Port ([int]$Manifest.server.port))
    if ($listeners.Count -ne 1 -or $listeners[0].LocalAddress -ne '127.0.0.1') { return $null }
    $ownerId = [int]$listeners[0].OwningProcess
    $process = Get-TurboProcessRecord -ProcessId $ownerId
    if ($null -eq $process -or [string]::IsNullOrWhiteSpace([string]$process.creation_time)) { return $null }

    $pattern = "$($Manifest.profile_id)-*.json"
    $historyFiles = @(Get-ChildItem -LiteralPath $Storage.history -File -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
    foreach ($historyFile in $historyFiles) {
        try {
            $state = Get-Content -LiteralPath $historyFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -eq $state.PSObject.Properties['pid'] -or [int]$state.pid -ne $ownerId -or
                $null -eq $state.PSObject.Properties['ready'] -or $state.ready -ne $true -or
                $null -eq $state.PSObject.Properties['host'] -or $state.host -ne $Manifest.target_host.computer_name -or
                $null -eq $state.PSObject.Properties['start_time']) {
                continue
            }

            $stateStart = [DateTimeOffset]::Parse([string]$state.start_time, [Globalization.CultureInfo]::InvariantCulture)
            $processStart = [DateTimeOffset]::Parse([string]$process.creation_time, [Globalization.CultureInfo]::InvariantCulture)
            if ([Math]::Abs(($stateStart - $processStart).TotalSeconds) -gt 30) { continue }

            $allowLegacyQuickApiAlias = Test-TurboLegacyApiAlias -Manifest $Manifest -Alias ([string]$state.api_model_alias)
            Assert-ManagedTurboProcess -State $state -Manifest $Manifest -RequireListener -AllowLegacyApiAlias:$allowLegacyQuickApiAlias | Out-Null
            $allowLegacyQuickTextOnly = $Manifest.profile_class -eq 'quick-response' -and
                $Manifest.configuration.vision -eq $true -and
                $process.command_line.IndexOf('--no-mmproj', [StringComparison]::OrdinalIgnoreCase) -ge 0
            Test-TurboApiState -Manifest $Manifest -AllowLegacyQuickTextOnly:$allowLegacyQuickTextOnly -AllowLegacyApiAlias:$allowLegacyQuickApiAlias | Out-Null
            $runtime = Get-TurboRuntimeInfo -Manifest $Manifest
            if ((Get-TurboFileSha256 -Path $runtime.executable) -ne $Manifest.runtime.executable_expected_sha256 -or
                (Get-TurboFileSha256 -Path $runtime.model) -ne $Manifest.model.sha256) {
                continue
            }
            if ($Manifest.configuration.vision -eq $true -and
                (Get-TurboFileSha256 -Path $runtime.projector) -ne $Manifest.model.projector_sha256) {
                continue
            }

            # Preserve the archived evidence and write a fresh active record only
            # after every ownership, time, hash, command-line and API check passes.
            $recovered = [ordered]@{}
            foreach ($property in $state.PSObject.Properties) {
                if ($property.Name -notin @('archived_at', 'archive_reason')) {
                    $recovered[$property.Name] = $property.Value
                }
            }
            $recovered['recovered_at'] = (Get-Date).ToString('o')
            $recovered['recovered_from_history'] = $historyFile.FullName
            Write-TurboJson -InputObject $recovered -Path $Storage.active_state -Depth 15
            Write-Host "[RECOVERED] Restored managed state for verified PID $ownerId from history." -ForegroundColor Yellow
            return [pscustomobject]$recovered
        }
        catch {
            Write-Verbose "History recovery candidate rejected: $($historyFile.FullName) :: $($_.Exception.Message)"
        }
    }
    return $null
}

function Test-TurboApiState {
    param(
        [Parameter(Mandatory)]$Manifest,
        [string]$BaseUrl,
        [switch]$AllowLegacyQuickTextOnly,
        [switch]$AllowLegacyApiAlias
    )
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = "http://$($Manifest.server.host):$($Manifest.server.port)"
    }
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
    if ($health.status -ne 'ok') { throw "Turbo health is not OK at $BaseUrl." }
    $props = Invoke-RestMethod -Uri "$BaseUrl/props" -TimeoutSec 15
    $visionProperty = $props.modalities.PSObject.Properties['vision']
    $observedVision = $null -ne $visionProperty -and [bool]$visionProperty.Value
    $visionMatches = $observedVision -eq [bool]$Manifest.configuration.vision
    $legacyQuickTextOnly = $AllowLegacyQuickTextOnly -and
        $Manifest.profile_class -eq 'quick-response' -and
        $Manifest.configuration.vision -eq $true -and
        $observedVision -eq $false
    $acceptedAliases = @(Get-TurboAcceptedApiAliases -Manifest $Manifest -AllowLegacyApiAlias:$AllowLegacyApiAlias)
    $observedAlias = [string]$props.model_alias
    if ($observedAlias -notin $acceptedAliases -or
        [int]$props.default_generation_settings.n_ctx -ne [int]$Manifest.configuration.context_tokens -or
        [int]$props.total_slots -ne [int]$Manifest.configuration.parallel -or
        (-not $visionMatches -and -not $legacyQuickTextOnly)) {
        throw 'Turbo /props does not match alias/context/parallel/Vision expectations.'
    }
    $models = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -TimeoutSec 15
    $matches = @($models.data | Where-Object { $_.id -eq $observedAlias })
    if ($matches.Count -ne 1 -or [int]$matches[0].meta.n_ctx -ne [int]$Manifest.configuration.context_tokens) {
        throw 'Turbo /v1/models does not expose the expected alias and context.'
    }
    return [pscustomobject]@{ base_url = $BaseUrl; health = $health; props = $props; model = $matches[0] }
}

Export-ModuleMember -Function *
