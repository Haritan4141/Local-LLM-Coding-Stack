[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet(
        'MAIN-Stable16K',
        'MAIN-Stable32K',
        'MAIN-Turbo16K',
        'MAIN-Turbo32K',
        'MAIN-Quick8K',
        'MAIN-Quality32K',
        'BLUE-Stable16K',
        'BLUE-Stable32K',
        'BLUE-Turbo16K',
        'BLUE-Turbo32K',
        'BLUE-Quick8K',
        'BLUE-Quality32K',
        'BLUE-Extended256K16K',
        'MAIN-Extended256K16K'
    )][string]$Profile,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$configPath = Join-Path $env:APPDATA 'Block\goose\config\config.yaml'
$providerDirectory = Join-Path $env:APPDATA 'Block\goose\config\custom_providers'
$profileSync = Join-Path $PSScriptRoot 'Set-GooseProfile.ps1'
$turboRoot = Join-Path $repoRoot 'scripts\standalone-turbo'
$mainDailyRoot = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\RTX5090\00-Daily-Profiles'
$blueDailyRoot = Join-Path $repoRoot 'scripts\lmstudio\model-loaders\RTX3090\00-Daily-Profiles'

$profiles = @{
    'MAIN-Extended256K16K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Extended Context Candidate'; Runtime = 'official llama.cpp'; ModelDisplay = 'IQ4_XS Vision'
        RuntimeContext = 262144; ClientContext = 237568; Output = 16384
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-iq4xs-main-256k-gpt-4o'; Endpoint = 'http://127.0.0.1:18080'
        RuntimeKind = 'Turbo'; Loader = Join-Path $mainDailyRoot 'Extended-Context.bat'; TurboProfile = 'RTX5090-IQ4XS256K'
    }
    'MAIN-Stable16K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Stable'; Runtime = 'LM Studio'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 16384
        Provider = 'lmstudio'; Model = 'qwen3.8-27b-uncensored-vision-q5km'; Endpoint = 'http://127.0.0.1:1234'
        RuntimeKind = 'LMStudio'; Loader = Join-Path $mainDailyRoot '1-Stable.bat'; GooseProfile = 'Q5KM-Vision96K-Output16K'
    }
    'MAIN-Stable32K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Stable'; Runtime = 'LM Studio'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 32768
        Provider = 'lmstudio'; Model = 'qwen3.8-27b-uncensored-vision-q5km'; Endpoint = 'http://127.0.0.1:1234'
        RuntimeKind = 'LMStudio'; Loader = Join-Path $mainDailyRoot '1-Stable.bat'; GooseProfile = 'Q5KM-Vision96K-Output32K'
    }
    'MAIN-Turbo16K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Turbo'; Runtime = 'official llama.cpp'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 16384
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-q5km-turbo'; Endpoint = 'http://127.0.0.1:18080'
        RuntimeKind = 'Turbo'; Loader = Join-Path $mainDailyRoot '2-Turbo.bat'; TurboProfile = 'RTX5090'
    }
    'MAIN-Turbo32K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Turbo'; Runtime = 'official llama.cpp'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 32768
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-q5km-turbo'; Endpoint = 'http://127.0.0.1:18080'
        RuntimeKind = 'Turbo'; Loader = Join-Path $mainDailyRoot '2-Turbo.bat'; TurboProfile = 'RTX5090'
    }
    'MAIN-Quick8K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Quick Response Candidate'; Runtime = 'official llama.cpp'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 65536; ClientContext = 57344; Output = 8192
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-q5km-quick-gpt-4o'; Endpoint = 'http://127.0.0.1:18080'
        RuntimeKind = 'Turbo'; Loader = Join-Path $mainDailyRoot 'Quick-Response.bat'; TurboProfile = 'RTX5090-Quick'
    }
    'MAIN-Quality32K' = [ordered]@{
        Target = 'MAIN RTX5090'; Role = 'Quality Reference'; Runtime = 'LM Studio'; ModelDisplay = 'Q6_K Vision'
        RuntimeContext = 65536; ClientContext = 64512; Output = 32768
        Provider = 'lmstudio'; Model = 'qwen3.8-27b-uncensored-vision'; Endpoint = 'http://127.0.0.1:1234'
        RuntimeKind = 'LMStudio'; Loader = Join-Path $mainDailyRoot '3-Quality-Reference.bat'; GooseProfile = 'Q6K-Vision64K'
    }
    'BLUE-Stable16K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Stable'; Runtime = 'LM Studio'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 16384
        Provider = 'custom_lm_studio_3090_remote'; Model = 'qwen3.8-27b-uncensored-vision-q5km-blue'; Endpoint = 'http://192.168.0.104:1234'
        RuntimeKind = 'LMStudioRemote'; Loader = Join-Path $blueDailyRoot '1-Stable_REMOTE.bat'; GooseProfile = 'BLUE-Q5KM-Vision96K-Output16K'
    }
    'BLUE-Stable32K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Stable'; Runtime = 'LM Studio'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 32768
        Provider = 'custom_lm_studio_3090_remote'; Model = 'qwen3.8-27b-uncensored-vision-q5km-blue'; Endpoint = 'http://192.168.0.104:1234'
        RuntimeKind = 'LMStudioRemote'; Loader = Join-Path $blueDailyRoot '1-Stable_REMOTE.bat'; GooseProfile = 'BLUE-Q5KM-Vision96K-Output32K'
    }
    'BLUE-Turbo16K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Turbo'; Runtime = 'official llama.cpp'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 16384
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-q5km-blue-turbo'; Endpoint = 'http://127.0.0.1:18081'
        RuntimeKind = 'Turbo'; Loader = Join-Path $blueDailyRoot '2-Turbo_REMOTE.bat'; TurboProfile = 'BLUE'
    }
    'BLUE-Turbo32K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Turbo'; Runtime = 'official llama.cpp'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 98304; ClientContext = 90112; Output = 32768
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-q5km-blue-turbo'; Endpoint = 'http://127.0.0.1:18081'
        RuntimeKind = 'Turbo'; Loader = Join-Path $blueDailyRoot '2-Turbo_REMOTE.bat'; TurboProfile = 'BLUE'
    }
    'BLUE-Quick8K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Quick Response Candidate'; Runtime = 'official llama.cpp'; ModelDisplay = 'Q5_K_M Vision'
        RuntimeContext = 65536; ClientContext = 57344; Output = 8192
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-q5km-blue-quick-gpt-4o'; Endpoint = 'http://127.0.0.1:18081'
        RuntimeKind = 'Turbo'; Loader = Join-Path $blueDailyRoot 'Quick-Response_REMOTE.bat'; TurboProfile = 'BLUE-Quick'
    }
    'BLUE-Quality32K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Quality Reference'; Runtime = 'LM Studio'; ModelDisplay = 'Q6_K Vision'
        RuntimeContext = 65536; ClientContext = 64512; Output = 32768
        Provider = 'custom_lm_studio_3090_remote'; Model = 'qwen3.8-27b-uncensored-vision-blue'; Endpoint = 'http://192.168.0.104:1234'
        RuntimeKind = 'LMStudioRemote'; Loader = Join-Path $blueDailyRoot '3-Quality-Reference_REMOTE.bat'; GooseProfile = 'BLUE-Q6K-Vision64K'
    }
    'BLUE-Extended256K16K' = [ordered]@{
        Target = 'BLUE RTX3090+RTX3060'; Role = 'Extended Context Candidate'; Runtime = 'official llama.cpp'; ModelDisplay = 'IQ4_XS Vision'
        RuntimeContext = 262144; ClientContext = 237568; Output = 16384
        Provider = 'openai'; Model = 'qwen3.8-27b-uncensored-vision-iq4xs-blue-256k-gpt-4o'; Endpoint = 'http://127.0.0.1:18081'
        RuntimeKind = 'Turbo'; Loader = Join-Path $blueDailyRoot 'Extended-Context_REMOTE.bat'; TurboProfile = 'BLUE-IQ4XS256K'
    }
}

function Get-GooseProcesses {
    return @(Get-Process -Name 'Goose' -ErrorAction SilentlyContinue)
}

function Resolve-GooseDesktop {
    $shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Goose.lnk'
    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        if ($shortcut.TargetPath -and (Test-Path -LiteralPath $shortcut.TargetPath -PathType Leaf)) {
            return [pscustomobject]@{
                Path = $shortcut.TargetPath
                WorkingDirectory = $shortcut.WorkingDirectory
            }
        }
    }

    $fallback = Join-Path $env:USERPROFILE 'Applications\goose\v1.47.0\dist-windows\Goose.exe'
    if (-not (Test-Path -LiteralPath $fallback -PathType Leaf)) {
        throw 'Goose Desktop could not be resolved.'
    }
    return [pscustomobject]@{ Path = $fallback; WorkingDirectory = Split-Path -Parent $fallback }
}

function Invoke-CanonicalBatch {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Canonical Daily wrapper was not found: $Path" }
    # Canonical Daily BAT files intentionally pause for direct interactive use.
    # Close stdin only for this orchestration path so those pauses do not turn the
    # one-click Goose entry into an additional keypress, while preserving the BATs.
    & $env:ComSpec /d /c "call `"$Path`" <nul"
    if ($LASTEXITCODE -ne 0) { throw "Canonical Daily wrapper failed with exit code ${LASTEXITCODE}: $Path" }
}

function ConvertFrom-JsonItems {
    param([Parameter(Mandatory)][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $response = $Text | ConvertFrom-Json
    return @($response | ForEach-Object { $_ })
}

function Get-FileSha256 {
    param([Parameter(Mandatory)][string]$Path)

    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '')
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-BlueIdentity {
    $hostname = (@(& ssh -o BatchMode=yes pc5700x hostname) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $hostname -ne 'DESKTOP-L9HAM1G') {
        throw "SSH alias pc5700x returned '$hostname'; expected 'DESKTOP-L9HAM1G'."
    }
    $ipCommand = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '192.168.0.104') { '192.168.0.104' } else { exit 9 }"
    $ip = (@(& ssh -o BatchMode=yes pc5700x powershell.exe -NoProfile -Command $ipCommand) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $ip -ne '192.168.0.104') { throw 'BLUE IPv4 verification failed; expected 192.168.0.104.' }
}

function Assert-LmStudioRuntime {
    param([Parameter(Mandatory)]$Definition)

    if ($Definition.RuntimeKind -eq 'LMStudioRemote') {
        Assert-BlueIdentity
        $json = (@(& ssh -o BatchMode=yes pc5700x lms ps --json) -join [Environment]::NewLine)
        if ($LASTEXITCODE -ne 0) { throw 'BLUE lms ps verification failed.' }
    }
    else {
        $json = (@(& lms ps --json) -join [Environment]::NewLine)
        if ($LASTEXITCODE -ne 0) { throw 'MAIN lms ps verification failed.' }
    }

    $models = @(ConvertFrom-JsonItems -Text $json)
    $matches = @($models | Where-Object { $_.identifier -eq $Definition.Model })
    if ($models.Count -ne 1 -or $matches.Count -ne 1) {
        throw "LM Studio runtime/model cross-check failed; expected only '$($Definition.Model)'."
    }
    $model = $matches[0]
    foreach ($property in @('contextLength', 'parallel', 'vision', 'status', 'queued')) {
        if ($null -eq $model.PSObject.Properties[$property]) { throw "LM Studio model state is missing '$property'." }
    }
    if ([int]$model.contextLength -ne [int]$Definition.RuntimeContext -or [int]$model.parallel -ne 1 -or
        $model.vision -ne $true -or $model.status -notin @('idle', 'loaded') -or [int]$model.queued -ne 0) {
        throw 'LM Studio context/parallel/Vision/idle cross-check failed.'
    }

    $catalog = Invoke-RestMethod -Uri ($Definition.Endpoint.TrimEnd('/') + '/api/v1/models') -Method Get -TimeoutSec 20
    $parents = @($catalog.models | Where-Object { @($_.loaded_instances | ForEach-Object id) -contains $Definition.Model })
    if ($parents.Count -ne 1 -or $parents[0].capabilities.vision -ne $true) {
        throw 'LM Studio endpoint/model/Vision cross-check failed.'
    }
    $instances = @($parents[0].loaded_instances | Where-Object { $_.id -eq $Definition.Model })
    if ($instances.Count -ne 1 -or [int]$instances[0].config.context_length -ne [int]$Definition.RuntimeContext -or
        [int]$instances[0].config.parallel -ne 1) {
        throw 'LM Studio endpoint effective context/parallel cross-check failed.'
    }
}

function Get-ConfigScalar {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Name)
    $matches = [regex]::Matches($Text, "(?m)^$([regex]::Escape($Name)):[ \t]*(?<value>[^#\r\n]*?)[ \t]*(?:#[^\r\n]*)?(?:\r)?$")
    if ($matches.Count -ne 1) { throw "Expected one Goose '$Name' value, found $($matches.Count)." }
    return $matches[0].Groups['value'].Value.Trim()
}

function Get-ConfigProviderModel {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Provider)
    $providerMatches = [regex]::Matches($Text, "(?ms)^  $([regex]::Escape($Provider)):\r?\n(?<body>(?:    [^\r\n]*(?:\r?\n|$))*)")
    if ($providerMatches.Count -ne 1) { throw "Expected one Goose '$Provider' provider block, found $($providerMatches.Count)." }
    $modelMatches = [regex]::Matches($providerMatches[0].Groups['body'].Value, '(?m)^    model:[ \t]*(?<model>[^\r\n]+?)[ \t]*(?:\r)?$')
    if ($modelMatches.Count -ne 1) { throw "Expected one Goose model for provider '$Provider'." }
    return $modelMatches[0].Groups['model'].Value.Trim()
}

function Assert-PersistentGooseProfile {
    param([Parameter(Mandatory)]$Definition)

    $text = [IO.File]::ReadAllText($configPath)
    if ((Get-ConfigScalar -Text $text -Name 'active_provider') -ne $Definition.Provider -or
        (Get-ConfigProviderModel -Text $text -Provider $Definition.Provider) -ne $Definition.Model -or
        [int](Get-ConfigScalar -Text $text -Name 'GOOSE_CONTEXT_LIMIT') -ne [int]$Definition.ClientContext -or
        [int](Get-ConfigScalar -Text $text -Name 'GOOSE_MAX_TOKENS') -ne [int]$Definition.Output -or
        (Get-ConfigScalar -Text $text -Name 'GOOSE_AUTO_COMPACT_THRESHOLD') -ne '0.3') {
        throw 'Persistent Goose provider/model/context/output cross-check failed.'
    }

    if ($Definition.RuntimeKind -eq 'LMStudioRemote') {
        $providerPath = Join-Path $providerDirectory 'custom_lm_studio_3090_remote.json'
        $provider = Get-Content -LiteralPath $providerPath -Raw | ConvertFrom-Json
        if ($provider.name -ne 'custom_lm_studio_3090_remote' -or $provider.engine -ne 'openai' -or
            $provider.base_url -ne 'http://192.168.0.104:1234/v1/chat/completions' -or $provider.requires_auth -ne $false) {
            throw 'BLUE persistent Goose provider endpoint cross-check failed.'
        }
        $modelMatches = @($provider.models | Where-Object { $_.name -eq $Definition.Model -and [int]$_.context_limit -eq [int]$Definition.ClientContext })
        if ($modelMatches.Count -ne 1) { throw 'BLUE persistent Goose provider model/context cross-check failed.' }
    }
}

function Write-Selection {
    param([Parameter(Mandatory)]$Definition)
    Write-Host ''
    Write-Host '[SELECTED]' -ForegroundColor Cyan
    Write-Host ("Target   : {0}" -f $Definition.Target)
    Write-Host ("Profile  : {0}" -f $Definition.Role)
    Write-Host ("Runtime  : {0}" -f $Definition.Runtime)
    Write-Host ("Model    : {0}" -f $Definition.ModelDisplay)
    Write-Host ("Context  : {0:N0} runtime / {1:N0} Goose client" -f $Definition.RuntimeContext, $Definition.ClientContext)
    Write-Host ("Output   : {0:N0}" -f $Definition.Output)
    Write-Host ("Provider : {0}" -f $Definition.Provider)
    Write-Host ("Endpoint : {0}" -f $Definition.Endpoint)
    Write-Host ("Alias    : {0}" -f $Definition.Model)
    Write-Host ''
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Goose config was not found: $configPath" }
$runningGoose = @(Get-GooseProcesses)
if ($runningGoose.Count -gt 0) {
    throw 'Goose is already running. Close it completely before switching profile.'
}

$definition = $profiles[$Profile]
Write-Selection -Definition $definition

if ($definition.RuntimeKind -eq 'Turbo') {
    $configHashBefore = Get-FileSha256 -Path $configPath
    Invoke-CanonicalBatch -Path $definition.Loader
    $testScript = Join-Path $turboRoot 'Test-ManagedTurbo.ps1'
    $mode = if ($definition.TurboProfile.StartsWith('BLUE', [StringComparison]::OrdinalIgnoreCase)) { 'Tunnel' } else { 'Local' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testScript -Profile $definition.TurboProfile -Mode $mode -BaseUrl $definition.Endpoint | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Turbo runtime/provider endpoint cross-check failed with exit code $LASTEXITCODE." }

    $manifestPath = Join-Path $turboRoot "runtime-manifests\$($definition.TurboProfile).json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $expectedPort = [uri]$definition.Endpoint
    if ($manifest.server.api_model_alias -ne $definition.Model -or [int]$manifest.configuration.context_tokens -ne [int]$definition.RuntimeContext -or
        [int]$manifest.configuration.parallel -ne 1 -or
        [bool]$manifest.configuration.vision -ne [bool]($definition.ModelDisplay -like '*Vision*') -or
        $expectedPort.Port -notin @(18080, 18081)) {
        throw 'Turbo manifest/provider/model/endpoint cross-check failed.'
    }
    if ($null -ne $manifest.PSObject.Properties['goose'] -and
        ([int]$manifest.goose.client_context_tokens -ne [int]$definition.ClientContext -or
         [int]$manifest.goose.max_output_tokens -ne [int]$definition.Output)) {
        throw 'Candidate manifest/Goose client context/output cross-check failed.'
    }

    Write-Host 'Starting Goose...'
    $gooseTurbo = Join-Path $turboRoot 'Start-Goose-ManagedTurbo.ps1'
    $arguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $gooseTurbo,
        '-Profile', $definition.TurboProfile,
        '-MaxOutputTokens', [string]$definition.Output
    )
    if ($NoLaunch) { $arguments += '-NoLaunch' }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Goose Turbo launcher failed with exit code $LASTEXITCODE." }
    if ((Get-FileSha256 -Path $configPath) -ne $configHashBefore) {
        throw 'Turbo selection changed persistent Goose configuration.'
    }
}
else {
    Invoke-CanonicalBatch -Path $definition.Loader
    Assert-LmStudioRuntime -Definition $definition

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $profileSync -Profile $definition.GooseProfile -SuppressNextMessage
    if ($LASTEXITCODE -ne 0) { throw "Goose persistent profile sync failed with exit code $LASTEXITCODE." }
    Assert-PersistentGooseProfile -Definition $definition

    if ($NoLaunch) {
        Write-Host '[OK] Goose LM Studio preflight passed; launch skipped.' -ForegroundColor Green
    }
    else {
        Write-Host 'Starting Goose...'
        $gooseDesktop = Resolve-GooseDesktop
        Start-Process -FilePath $gooseDesktop.Path -WorkingDirectory $gooseDesktop.WorkingDirectory
        Start-Sleep -Seconds 3
        if (@(Get-GooseProcesses).Count -eq 0) { throw 'Goose Desktop did not remain running.' }
        Write-Host '[OK] Goose Desktop started with the verified persistent LM Studio profile.' -ForegroundColor Green
    }
}

Write-Host '[OK] Runtime/provider/model/context/output/endpoint cross-check passed.' -ForegroundColor Green
