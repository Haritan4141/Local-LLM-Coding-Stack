[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick')][string]$Profile,
    [Parameter(Mandatory)][string]$SourceDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
Assert-TurboHostAndGpu -Manifest $manifest | Out-Null
$runtime = Get-TurboRuntimeInfo -Manifest $manifest
$source = [IO.Path]::GetFullPath($SourceDirectory)
$sourceServer = Join-Path $source $manifest.runtime.executable
if (-not (Test-Path -LiteralPath $sourceServer -PathType Leaf)) {
    throw "Source llama-server.exe is missing: $sourceServer"
}
$sourceHash = (Get-FileHash -LiteralPath $sourceServer -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceHash -ne $manifest.runtime.executable_expected_sha256) {
    throw "Source llama-server.exe SHA mismatch: $sourceHash"
}
foreach ($required in @($manifest.runtime.required_files)) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $required) -PathType Leaf)) {
        throw "Source runtime bundle is incomplete; missing $required"
    }
}

$managedRoot = Resolve-TurboExpandedPath '%LOCALAPPDATA%\Local-LLM-Coding-Stack\runtimes'
$managedPrefix = $managedRoot.TrimEnd('\') + '\'
if (-not $runtime.root.StartsWith($managedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing runtime destination outside managed root: $($runtime.root)"
}

$destinationExists = Test-Path -LiteralPath $runtime.root -PathType Container
if ($destinationExists) {
    $existingFiles = @(Get-ChildItem -LiteralPath $runtime.root -Force -ErrorAction Stop)
    if ($existingFiles.Count -gt 0) {
        foreach ($required in @($manifest.runtime.required_files)) {
            if (-not (Test-Path -LiteralPath (Join-Path $runtime.root $required) -PathType Leaf)) {
                throw "Existing managed runtime is incomplete; refusing overwrite: $($runtime.root)"
            }
        }
        $existingHash = (Get-FileHash -LiteralPath $runtime.executable -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($existingHash -ne $manifest.runtime.executable_expected_sha256) {
            throw "Existing managed runtime SHA mismatch; refusing overwrite: $($runtime.root)"
        }
    }
}

if (-not $destinationExists -or @(Get-ChildItem -LiteralPath $runtime.root -Force -ErrorAction SilentlyContinue).Count -eq 0) {
    if (-not (Test-Path -LiteralPath $managedRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $managedRoot -Force | Out-Null
    }
    if (-not $destinationExists) {
        New-Item -ItemType Directory -Path $runtime.root | Out-Null
    }
    $bundleFiles = @(Get-ChildItem -LiteralPath $source -File | Where-Object {
        $_.Name -eq $manifest.runtime.executable -or $_.Extension -eq '.dll'
    })
    if ($bundleFiles.Count -lt @($manifest.runtime.required_files).Count) {
        throw 'Source runtime bundle did not expose the expected executable and DLL set.'
    }
    foreach ($file in $bundleFiles) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $runtime.root $file.Name)
    }
}

foreach ($required in @($manifest.runtime.required_files)) {
    if (-not (Test-Path -LiteralPath (Join-Path $runtime.root $required) -PathType Leaf)) {
        throw "Installed runtime bundle is incomplete; missing $required"
    }
}
$installedHash = (Get-FileHash -LiteralPath $runtime.executable -Algorithm SHA256).Hash.ToLowerInvariant()
if ($installedHash -ne $manifest.runtime.executable_expected_sha256) {
    throw "Installed llama-server.exe SHA mismatch: $installedHash"
}

$fileRecords = @(Get-ChildItem -LiteralPath $runtime.root -File | Where-Object {
    $_.Name -ne $manifest.runtime.bundle_manifest
} | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        name = $_.Name
        bytes = [int64]$_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$version = @(& $runtime.executable --version 2>&1 | ForEach-Object { $_.ToString() })
$versionExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($versionExitCode -ne 0 -or ($version -join "`n") -notmatch 'commit f280b2698') {
    throw 'Installed runtime --version did not report pinned commit f280b2698.'
}
$ErrorActionPreference = 'Continue'
$devices = @(& $runtime.executable --list-devices 2>&1 | ForEach-Object { $_.ToString() })
$devicesExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($devicesExitCode -ne 0) { throw 'Installed runtime --list-devices failed.' }
foreach ($gpu in @($manifest.gpus)) {
    $expected = "$($gpu.llama_device): $($gpu.name)"
    if (($devices -join "`n").IndexOf($expected, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Installed runtime device mapping mismatch; expected '$expected'."
    }
}

$bundleRecord = [ordered]@{
    schema_version = 1
    installed_at = (Get-Date).ToString('o')
    installed_by_host = [Environment]::MachineName
    profile_id = $manifest.profile_id
    source_repository = $manifest.runtime.source_repository
    source_commit = $manifest.runtime.source_commit
    source_directory = $source
    destination_directory = $runtime.root
    executable_expected_sha256 = $manifest.runtime.executable_expected_sha256
    files = $fileRecords
    version = $version
    devices = $devices
}
Write-TurboJson -InputObject $bundleRecord -Path $runtime.bundle_manifest -Depth 10

Write-Host "[OK] Managed Turbo runtime installed and verified: $($runtime.root)" -ForegroundColor Green
Write-Host "[OK] llama-server.exe SHA-256: $installedHash" -ForegroundColor Green
Write-Host '[OK] Required DLLs, --version, and --list-devices passed.' -ForegroundColor Green
$bundleRecord
