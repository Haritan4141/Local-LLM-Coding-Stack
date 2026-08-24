[CmdletBinding()]
param(
    [switch]$NoLaunch,
    [switch]$InstallDesktopShortcut,
    [switch]$ForceReload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modelKey = 'qwen3.8-27b-uncensored-vision-q6k'
$identifier = 'qwen3.8-27b-uncensored-vision'
$contextLength = 65536
$scriptDirectory = $PSScriptRoot
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDirectory '..\..\..\..\..')).Path
$managedLoader = Join-Path $repoRoot 'scripts\lmstudio\Load-ManagedModel.mjs'
$managedPreflight = Join-Path $repoRoot 'scripts\lmstudio\Test-ManagedModel.mjs'
$launcherBat = Join-Path $scriptDirectory 'Start-Goose-Jonathan-Vision64K.bat'
$gooseConfig = Join-Path $env:APPDATA 'Block\goose\config\config.yaml'
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

function Ensure-GooseDefaultModel {
    if (-not (Test-Path -LiteralPath $gooseConfig -PathType Leaf)) {
        throw "Goose config was not found: $gooseConfig"
    }

    $configText = [System.IO.File]::ReadAllText($gooseConfig)
    $providerMatches = [regex]::Matches(
        $configText,
        '(?ms)^  lmstudio:\r?\n(?<body>(?:    [^\r\n]*(?:\r?\n|$))*)'
    )
    if ($providerMatches.Count -ne 1) {
        throw "Expected exactly one Goose lmstudio provider block, found $($providerMatches.Count)."
    }

    $providerBody = $providerMatches[0].Groups['body']
    $modelMatches = [regex]::Matches(
        $providerBody.Value,
        '(?m)^(    model:[ \t]*)([^\r\n]+?)[ \t]*(\r?)$'
    )
    if ($modelMatches.Count -ne 1) {
        throw "Expected exactly one model setting in the Goose lmstudio provider block, found $($modelMatches.Count)."
    }

    $currentModel = $modelMatches[0].Groups[2].Value.Trim()
    $lineEnding = $modelMatches[0].Groups[3].Value
    if ($currentModel -eq $identifier) {
        Write-Host "[OK] Goose default model: $identifier" -ForegroundColor Green
        return
    }

    if (Get-Process -Name 'Goose' -ErrorAction SilentlyContinue) {
        throw "Goose Desktop is running with default model '$currentModel'. Close Goose and run this launcher again to switch safely."
    }

    $backupRoot = Join-Path $env:LOCALAPPDATA 'Local-LLM-Coding-Stack\goose-config-backups'
    $null = New-Item -ItemType Directory -Path $backupRoot -Force
    $backupPath = Join-Path $backupRoot ("config-{0}.yaml" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Copy-Item -LiteralPath $gooseConfig -Destination $backupPath

    $updatedLine = "    model: $identifier$lineEnding"
    $modelIndex = $providerBody.Index + $modelMatches[0].Index
    $updatedText = $configText.Remove($modelIndex, $modelMatches[0].Length).Insert($modelIndex, $updatedLine)

    $bytes = [System.IO.File]::ReadAllBytes($gooseConfig)
    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $encoding = [System.Text.UTF8Encoding]::new($hasUtf8Bom)
    [System.IO.File]::WriteAllText($gooseConfig, $updatedText, $encoding)
    Write-Host "[OK] Goose default model changed: $currentModel -> $identifier" -ForegroundColor Green
    Write-Host '[INFO] The previous Goose config was backed up outside the repository.'
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

    # Windows PowerShell 5.1 returns an empty Object[] for JSON `[]`. Wrapping
    # that value in @() produces one nested array item, which then has no model
    # properties. Return the parsed value directly so PowerShell enumerates an
    # empty array as zero pipeline objects and a model array as its items.
    $parsed = $json | ConvertFrom-Json
    if ($null -ne $parsed) {
        return $parsed
    }
}

function Test-VisionRuntime {
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
        [int]$apiConfig.speculative_draft_max_tokens -eq 2
    if (-not $apiMatches) {
        return $false
    }

    & node $managedPreflight --identifier $identifier --context $contextLength --mtp on
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

function Load-VisionRuntime {
    Assert-NoActiveConflictingPrediction

    & lms unload --all
    if ($LASTEXITCODE -ne 0) {
        throw "lms unload --all failed with exit code $LASTEXITCODE."
    }

    & node $managedLoader --model-key $modelKey --identifier $identifier --context $contextLength --mtp on
    if ($LASTEXITCODE -ne 0) {
        throw "Managed Vision load failed with exit code $LASTEXITCODE."
    }

    if (-not (Test-VisionRuntime)) {
        throw 'Vision model loaded, but the managed 64K/Q8/MTP/parallel preflight did not pass.'
    }

    Write-Host '[OK] Jonathan Q6_K Vision 64K runtime loaded and verified.' -ForegroundColor Green
}

function Install-DesktopShortcut {
    $gooseDesktop = Resolve-GooseDesktop
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath 'Goose Vision 64K.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $launcherBat
    $shortcut.WorkingDirectory = $scriptDirectory
    $shortcut.Description = 'Load Jonathan Q6_K Vision at 64K with managed settings, then start Goose Desktop.'
    $shortcut.IconLocation = "$($gooseDesktop.TargetPath),0"
    $shortcut.Save()
    Write-Host "[OK] Desktop shortcut installed: $shortcutPath" -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $managedLoader -PathType Leaf)) {
    throw "Managed loader is missing: $managedLoader"
}
if (-not (Test-Path -LiteralPath $managedPreflight -PathType Leaf)) {
    throw "Managed preflight is missing: $managedPreflight"
}

Ensure-GooseDefaultModel

if ($ForceReload -or -not (Test-VisionRuntime)) {
    Load-VisionRuntime
} else {
    Write-Host '[OK] Jonathan Q6_K Vision 64K runtime is already loaded with managed settings.' -ForegroundColor Green
}

if ($InstallDesktopShortcut) {
    Install-DesktopShortcut
}

if ($NoLaunch) {
    Write-Host '[OK] Preflight completed; Goose Desktop launch was skipped.' -ForegroundColor Green
    exit 0
}

$gooseDesktop = Resolve-GooseDesktop
$runningGoose = Get-Process -Name 'Goose' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($runningGoose) {
    $shell = New-Object -ComObject WScript.Shell
    $null = $shell.AppActivate($runningGoose.Id)
    Write-Host '[OK] Goose Desktop is already running and was brought to the foreground.' -ForegroundColor Green
    exit 0
}

Start-Process -FilePath $gooseDesktop.TargetPath -WorkingDirectory $gooseDesktop.WorkingDirectory
Start-Sleep -Seconds 2
if (-not (Get-Process -Name 'Goose' -ErrorAction SilentlyContinue)) {
    throw 'Goose Desktop did not remain running after launch.'
}

Write-Host '[OK] Goose Desktop started with the Vision 64K runtime ready.' -ForegroundColor Green
