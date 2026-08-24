[CmdletBinding()]
param(
    [switch]$NoLaunch,
    [switch]$InstallDesktopShortcut,
    [switch]$ForceReload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modelKey = 'qwen3.8-27b-uncensored-vision-q5km'
$identifier = 'qwen3.8-27b-uncensored-vision-q5km'
$contextLength = 98304
$gooseContextLimit = 90112
$gooseMaxTokens = 16384
$gooseCompactThreshold = '0.3'
$scriptDirectory = $PSScriptRoot
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDirectory '..\..\..\..\..')).Path
$managedLoader = Join-Path $repoRoot 'scripts\lmstudio\Load-ManagedModel.mjs'
$managedPreflight = Join-Path $repoRoot 'scripts\lmstudio\Test-ManagedModel.mjs'
$launcherBat = Join-Path $scriptDirectory 'Start-Goose-Jonathan-Q5KM-Vision96K-Candidate.bat'
$gooseShortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Goose.lnk'

function Resolve-GooseDesktop {
    if (Test-Path -LiteralPath $gooseShortcut) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($gooseShortcut)
        if ($shortcut.TargetPath -and (Test-Path -LiteralPath $shortcut.TargetPath)) {
            return [pscustomobject]@{
                TargetPath = $shortcut.TargetPath
                WorkingDirectory = $shortcut.WorkingDirectory
            }
        }
    }

    $fallback = Join-Path $env:USERPROFILE 'Applications\goose\v1.47.0\dist-windows\Goose.exe'
    if (Test-Path -LiteralPath $fallback) {
        return [pscustomobject]@{
            TargetPath = $fallback
            WorkingDirectory = Split-Path -Parent $fallback
        }
    }

    throw 'Goose Desktop could not be resolved from the Start Menu shortcut or the managed fallback path.'
}

function Get-GooseDesktopWindow {
    return Get-Process -Name 'Goose' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1
}

function Get-GooseProcesses {
    return Get-Process -Name 'Goose' -ErrorAction SilentlyContinue
}

function Get-LoadedModels {
    $jsonLines = @(& lms ps --json)
    if ($LASTEXITCODE -ne 0) {
        throw "lms ps failed with exit code $LASTEXITCODE. Start LM Studio and its local server first."
    }
    $json = $jsonLines -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($json)) {
        return
    }

    $parsed = $json | ConvertFrom-Json
    if ($null -ne $parsed) {
        return $parsed
    }
}

function Test-CandidateRuntime {
    $loadedModels = @(Get-LoadedModels)
    if ($loadedModels.Count -ne 1) {
        return $false
    }

    $model = $loadedModels[0]
    $requiredModelProperties = @('type', 'modelKey', 'identifier', 'vision', 'contextLength', 'parallel')
    $missingModelProperties = @($requiredModelProperties | Where-Object {
        $null -eq $model.PSObject.Properties[$_]
    })
    if ($missingModelProperties.Count -gt 0) {
        return $false
    }

    $coreMatches =
        $model.type -eq 'llm' -and
        $model.modelKey -eq $modelKey -and
        $model.identifier -eq $identifier -and
        $model.vision -eq $true -and
        [int]$model.contextLength -eq $contextLength -and
        [int]$model.parallel -eq 1

    if (-not $coreMatches) {
        return $false
    }

    try {
        $catalog = Invoke-RestMethod -Uri 'http://127.0.0.1:1234/api/v1/models' -Method Get -TimeoutSec 5
    } catch {
        return $false
    }

    $apiModels = @($catalog.models | Where-Object { $_.key -eq $modelKey })
    if ($apiModels.Count -ne 1 -or $apiModels[0].capabilities.vision -ne $true) {
        return $false
    }

    $apiInstances = @($apiModels[0].loaded_instances | Where-Object { $_.id -eq $identifier })
    if ($apiInstances.Count -ne 1) {
        return $false
    }

    $apiConfig = $apiInstances[0].config
    $apiMatches =
        [int]$apiConfig.context_length -eq $contextLength -and
        [int]$apiConfig.parallel -eq 1 -and
        $apiConfig.flash_attention -eq $true -and
        $apiConfig.offload_kv_cache_to_gpu -eq $true -and
        $apiConfig.speculative_draft_mtp -eq $true -and
        [int]$apiConfig.speculative_draft_max_tokens -eq 3 -and
        [int]$apiConfig.eval_batch_size -eq 1024
    if (-not $apiMatches) {
        return $false
    }

    & node $managedPreflight --identifier $identifier --context $contextLength --mtp on --mtp-draft 3 --kv-k q8_0 --kv-v q8_0 --eval-batch 1024 --mmap on --keep-model-in-memory on --vision-required on
    return $LASTEXITCODE -eq 0
}

function Assert-NoActiveConflictingPrediction {
    $loadedModels = @(Get-LoadedModels)
    $activeModels = @($loadedModels | Where-Object {
        $null -eq $_.PSObject.Properties['status'] -or
        $null -eq $_.PSObject.Properties['queued'] -or
        $_.status -notin @('idle', 'loaded') -or
        [int]$_.queued -gt 0
    })
    if ($activeModels.Count -gt 0) {
        $activeIdentifiers = ($activeModels | ForEach-Object {
            if ($null -ne $_.PSObject.Properties['identifier']) { $_.identifier } else { '<unknown>' }
        }) -join ', '
        throw "An LM Studio prediction is active or queued ($activeIdentifiers). It was not interrupted."
    }
}

function Load-CandidateRuntime {
    Assert-NoActiveConflictingPrediction

    & lms unload --all
    if ($LASTEXITCODE -ne 0) {
        throw "lms unload --all failed with exit code $LASTEXITCODE."
    }

    & node $managedLoader --model-key $modelKey --identifier $identifier --context $contextLength --mtp on --mtp-draft 3 --kv-k q8_0 --kv-v q8_0 --eval-batch 1024 --mmap on --keep-model-in-memory on
    if ($LASTEXITCODE -ne 0) {
        throw "Managed Candidate load failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-CandidateRuntime)) {
        throw 'Profile loaded, but the managed 96K/Q8/MTP3/batch1024/Vision/parallel preflight did not pass.'
    }

    Write-Host '[OK] Jonathan Q5_K_M Vision 96K Recommended Production runtime loaded and verified.' -ForegroundColor Green
}

function Install-DesktopShortcut {
    $gooseDesktop = Resolve-GooseDesktop
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath 'Goose Q5KM Vision 96K Candidate.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $launcherBat
    $shortcut.WorkingDirectory = $scriptDirectory
    $shortcut.Description = 'Load the Jonathan Q5_K_M Vision 96K Recommended Production profile, then start Goose with isolated client limits.'
    $shortcut.IconLocation = "$($gooseDesktop.TargetPath),0"
    $shortcut.Save()
    Write-Host "[OK] Desktop shortcut installed: $shortcutPath" -ForegroundColor Green
}

function Start-GooseWithCandidateEnvironment {
    $gooseDesktop = Resolve-GooseDesktop
    $overrides = [ordered]@{
        GOOSE_PROVIDER = 'lmstudio'
        GOOSE_MODEL = $identifier
        GOOSE_CONTEXT_LIMIT = [string]$gooseContextLimit
        GOOSE_MAX_TOKENS = [string]$gooseMaxTokens
        GOOSE_AUTO_COMPACT_THRESHOLD = $gooseCompactThreshold
    }
    $previous = @{}

    foreach ($name in $overrides.Keys) {
        $item = Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        $previous[$name] = if ($null -eq $item) {
            [pscustomobject]@{ Exists = $false; Value = $null }
        } else {
            [pscustomobject]@{ Exists = $true; Value = $item.Value }
        }
        Set-Item -LiteralPath "Env:$name" -Value $overrides[$name]
    }

    try {
        Start-Process -FilePath $gooseDesktop.TargetPath -WorkingDirectory $gooseDesktop.WorkingDirectory
    } finally {
        foreach ($name in $overrides.Keys) {
            if ($previous[$name].Exists) {
                Set-Item -LiteralPath "Env:$name" -Value $previous[$name].Value
            } else {
                Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
            }
        }
    }

    Start-Sleep -Seconds 2
    if (-not (Get-GooseDesktopWindow)) {
        throw 'Goose Desktop did not remain running after launch.'
    }

    Write-Host "[OK] Goose Desktop started with Recommended Production model $identifier." -ForegroundColor Green
    Write-Host "[OK] Process-only client limits: context $gooseContextLimit, max output $gooseMaxTokens, compact threshold $gooseCompactThreshold." -ForegroundColor Green
    Write-Host '[INFO] Persistent Goose config was not changed.'
}

if (-not (Test-Path -LiteralPath $managedLoader -PathType Leaf)) {
    throw "Managed loader is missing: $managedLoader"
}
if (-not (Test-Path -LiteralPath $managedPreflight -PathType Leaf)) {
    throw "Managed preflight is missing: $managedPreflight"
}

$runningGooseProcesses = @(Get-GooseProcesses)
if ($runningGooseProcesses.Count -gt 0 -and -not $NoLaunch) {
    throw 'Goose Desktop is already running. Close it completely, then run the Q5KM Vision 96K shortcut so the process-specific model and context settings can take effect.'
}

$runtimeMatches = Test-CandidateRuntime
if ($ForceReload -or -not $runtimeMatches) {
    if ($runningGooseProcesses.Count -gt 0) {
        throw 'Goose Desktop is running and the Production runtime requires a reload. Close Goose before changing LM Studio runtime state.'
    }
    Load-CandidateRuntime
} else {
    Write-Host '[OK] Jonathan Q5_K_M Vision 96K Recommended Production runtime is already loaded with managed settings.' -ForegroundColor Green
}

if ($InstallDesktopShortcut) {
    Install-DesktopShortcut
}

if ($NoLaunch) {
    Write-Host '[OK] Recommended Production preflight completed; Goose Desktop launch was skipped.' -ForegroundColor Green
    exit 0
}

Start-GooseWithCandidateEnvironment
