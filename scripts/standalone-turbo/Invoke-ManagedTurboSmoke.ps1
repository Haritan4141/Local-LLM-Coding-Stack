[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('RTX5090', 'BLUE', 'RTX5090-Quick', 'BLUE-Quick')][string]$Profile,
    [Parameter(Mandatory)][ValidateSet('Text', 'Vision', 'Tool', 'Goose')][string]$Kind,
    [Parameter(Mandatory)][string]$BaseUrl,
    [string]$Marker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Turbo.Common.psm1') -Force

$manifest = Get-TurboProfileManifest -Profile $Profile
Test-TurboApiState -Manifest $manifest -BaseUrl $BaseUrl | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runRoot = Join-Path $env:LOCALAPPDATA "Local-LLM-Coding-Stack\turbo\smoke\$($Profile.ToLowerInvariant())-$($Kind.ToLowerInvariant())-$stamp"
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

function Invoke-ChatRequest {
    param([Parameter(Mandatory)]$Body)
    $json = $Body | ConvertTo-Json -Depth 15 -Compress
    return Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/v1/chat/completions') -Method Post -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 900
}

$result = $null
if ($Kind -eq 'Text') {
    if ([string]::IsNullOrWhiteSpace($Marker)) { $Marker = "TURBO-$($Profile)-$stamp-PASS" }
    $response = Invoke-ChatRequest -Body ([ordered]@{
        model = $manifest.server.api_model_alias
        messages = @(
            @{ role = 'system'; content = "/no_think`nReply exactly as requested." },
            @{ role = 'user'; content = "Return exactly $Marker and nothing else." }
        )
        temperature = 0
        seed = 42
        max_tokens = 64
        stream = $false
        chat_template_kwargs = @{ enable_thinking = $false }
        reasoning_effort = 'none'
    })
    $text = [string]$response.choices[0].message.content
    $result = [ordered]@{ kind = 'Text'; marker = $Marker; response = $text; exact = $text.Trim() -eq $Marker; pass = $text.Trim() -eq $Marker }
}
elseif ($Kind -eq 'Tool') {
    $response = Invoke-ChatRequest -Body ([ordered]@{
        model = $manifest.server.api_model_alias
        messages = @(
            @{ role = 'system'; content = '/no_think`nUse exactly one required function call and no prose.' },
            @{ role = 'user'; content = "Call lookup_inventory for SKU $($manifest.tool_smoke.sku) in warehouse $($manifest.tool_smoke.warehouse)." }
        )
        tools = @(@{
            type = 'function'
            function = @{
                name = 'lookup_inventory'
                description = 'Look up inventory by SKU and warehouse.'
                parameters = @{
                    type = 'object'
                    properties = @{ sku = @{ type = 'string' }; warehouse = @{ type = 'string' } }
                    required = @('sku', 'warehouse')
                    additionalProperties = $false
                }
            }
        })
        tool_choice = 'required'
        temperature = 0
        seed = 42
        max_tokens = 128
        stream = $false
        chat_template_kwargs = @{ enable_thinking = $false }
        reasoning_effort = 'none'
    })
    $message = $response.choices[0].message
    $calls = @($message.tool_calls)
    $arguments = if ($calls.Count -eq 1) { $calls[0].function.arguments | ConvertFrom-Json } else { $null }
    $pass = $calls.Count -eq 1 -and
        $calls[0].function.name -eq 'lookup_inventory' -and
        $arguments.sku -eq $manifest.tool_smoke.sku -and
        $arguments.warehouse -eq $manifest.tool_smoke.warehouse -and
        [string]::IsNullOrWhiteSpace([string]$message.content)
    $result = [ordered]@{ kind = 'Tool'; function = if ($calls.Count) { $calls[0].function.name } else { $null }; arguments = $arguments; schema_valid = $pass; pass = $pass }
}
elseif ($Kind -eq 'Vision') {
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $source = Join-Path $repoRoot 'benchmarks\fixtures\vision-ui-v1\index.html'
    $promptPath = Join-Path $repoRoot 'benchmarks\fixtures\vision-ui-v1\prompt.txt'
    $imagePath = Join-Path $runRoot 'vision-ui-v1.png'
    & (Join-Path $repoRoot 'scripts\Export-VisionFixture.ps1') -SourcePath $source -OutputPath $imagePath
    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw 'Vision fixture export failed.' }
    $bytes = [IO.File]::ReadAllBytes($imagePath)
    $dataUrl = 'data:image/png;base64,' + [Convert]::ToBase64String($bytes)
    $response = Invoke-ChatRequest -Body ([ordered]@{
        model = $manifest.server.api_model_alias
        messages = @(
            @{ role = 'system'; content = "/no_think`nFollow the fixture instruction exactly. Reasoning must remain disabled." },
            @{ role = 'user'; content = @(
                @{ type = 'text'; text = (Get-Content -LiteralPath $promptPath -Raw -Encoding UTF8).Trim() },
                @{ type = 'image_url'; image_url = @{ url = $dataUrl } }
            ) }
        )
        temperature = 0
        seed = 42
        max_tokens = 512
        stream = $false
        cache_prompt = $false
        chat_template_kwargs = @{ enable_thinking = $false }
        reasoning_effort = 'none'
    })
    $text = [string]$response.choices[0].message.content
    $lower = (' ' + (($text.ToLowerInvariant() -split '\s+') -join ' ') + ' ')
    $compact = $lower -replace '[\s,]', ''
    $hasLeftLayout = $lower.Contains('left') -or $lower.Contains('navigation') -or $text -match '\u5de6|\u30ca\u30d3'
    $hasMainLayout = $lower.Contains('main') -or $text -match '\u30e1\u30a4\u30f3'
    $hasCardLayout = $lower.Contains('card') -or $text -match '\u30ab\u30fc\u30c9'
    $hasButtonLayout = $lower.Contains('button') -or $text -match '\u30dc\u30bf\u30f3'
    $checks = [ordered]@{
        title = $lower.Contains('vision check') -and $lower.Contains('rtx 5090')
        status = $lower.Contains('candidate')
        selected_menu = $lower.Contains('benchmarks')
        context = $compact.Contains('98304')
        kv_cache = ([regex]::Matches($lower, 'q8_0')).Count -ge 2
        error_code = $lower.Contains('vram-96k-042')
        button_and_layout = $lower.Contains('run vision test') -and
            $hasLeftLayout -and $hasMainLayout -and $hasCardLayout -and $hasButtonLayout
    }
    $score = @($checks.GetEnumerator() | Where-Object Value).Count
    $result = [ordered]@{ kind = 'Vision'; checks = $checks; score = "$score/7"; response = $text; pass = $score -eq 7 }
}
else {
    $gooseOnPath = Get-Command goose.exe -ErrorAction SilentlyContinue
    $gooseCandidates = @(
        (Join-Path $env:USERPROFILE 'Applications\goose\v1.47.0\dist-windows\resources\bin\goose.exe')
        if ($null -ne $gooseOnPath) { $gooseOnPath.Source }
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -Unique
    $goose = $gooseCandidates | Select-Object -First 1
    if (-not $goose) { throw 'Goose CLI could not be resolved.' }
    $toolMarker = "GOOSE-TOOL-$($Profile)-$stamp-PASS"
    $markerPath = Join-Path $runRoot 'tool-marker.txt'
    $instructionPath = Join-Path $runRoot 'instruction.txt'
    Set-Content -LiteralPath $markerPath -Value $toolMarker -Encoding ASCII
    Set-Content -LiteralPath $instructionPath -Value "Use the developer tool to read the file at $markerPath. Then reply with exactly the file contents and nothing else. Do not guess the contents." -Encoding UTF8
    $saved = @{}
    $overrides = [ordered]@{
        OPENAI_HOST = $BaseUrl.TrimEnd('/')
        OPENAI_BASE_PATH = '/v1/chat/completions'
        OPENAI_API_KEY = 'managed-turbo-local-only'
        GOOSE_CONTEXT_LIMIT = '90112'
        GOOSE_MAX_TOKENS = '16384'
        GOOSE_AUTO_COMPACT_THRESHOLD = '0.3'
        GOOSE_TEMPERATURE = '0'
    }
    foreach ($name in $overrides.Keys) {
        $item = Get-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        $saved[$name] = if ($null -eq $item) { [pscustomobject]@{ exists = $false; value = $null } } else { [pscustomobject]@{ exists = $true; value = $item.Value } }
        Set-Item -LiteralPath "Env:$name" -Value $overrides[$name]
    }
    $stdout = Join-Path $runRoot 'goose.stdout.json'
    $stderr = Join-Path $runRoot 'goose.stderr.log'
    try {
        $arguments = @(
            'run', '--no-session', '--no-profile', '--provider', 'openai', '--model', [string]$manifest.server.api_model_alias,
            '--with-builtin', 'developer', '--max-turns', '8', '--max-tool-repetitions', '3',
            '--stats', '--debug', '--output-format', 'json', '--instructions', $instructionPath
        )
        $process = Start-Process -FilePath $goose -ArgumentList $arguments -WorkingDirectory $runRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru
        $exitCode = $process.ExitCode
    }
    finally {
        foreach ($name in $overrides.Keys) {
            if ($saved[$name].exists) { Set-Item -LiteralPath "Env:$name" -Value $saved[$name].value }
            else { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
        }
    }
    $output = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw -Encoding UTF8 } else { '' }
    $pass = $exitCode -eq 0 -and $output.Contains($toolMarker)
    $result = [ordered]@{ kind = 'Goose'; marker = $toolMarker; goose_exit = $exitCode; marker_observed = $output.Contains($toolMarker); process_local_openai = $true; persistent_config_changed = $false; pass = $pass }
}

$record = [ordered]@{
    schema_version = 1
    recorded_at = (Get-Date).ToString('o')
    profile = $Profile
    endpoint = $BaseUrl
    model_alias = $manifest.server.api_model_alias
    result = $result
}
$recordPath = Join-Path $runRoot 'result.json'
Write-TurboJson -InputObject $record -Path $recordPath -Depth 15
if (-not $result.pass) { throw "$Kind smoke failed. Evidence: $recordPath" }
Write-Host "[OK] $Profile $Kind smoke PASS. Evidence: $recordPath" -ForegroundColor Green
$record
