[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ValidateSet('http://127.0.0.1:18080', 'http://127.0.0.1:18081', 'http://127.0.0.1:1234', 'http://192.168.0.104:1234')][string]$BaseUrl,
    [Parameter(Mandatory)][string]$Model,
    [Parameter(Mandatory)][ValidateSet(65536, 98304)][int]$RuntimeContext,
    [Parameter(Mandatory)][ValidateSet(57344, 64512, 90112)][int]$ClientContext,
    [Parameter(Mandatory)][ValidateSet(8192, 16384, 32768)][int]$MaxOutputTokens,
    [Parameter(Mandatory)][ValidateRange(0.05, 0.85)][double]$Threshold,
    [ValidateSet('openai', 'lmstudio', 'custom_lm_studio_3090_remote')][string]$Provider = 'openai',
    [ValidateRange(1, 3)][int]$Rounds = 1,
    [ValidateSet('measured-v2','fixed-v1')][string]$PaddingMethod = 'measured-v2',
    [switch]$Pilot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($ClientContext -gt $RuntimeContext -or $ClientContext * $Threshold + $MaxOutputTokens + 8192 -ge $RuntimeContext) {
    throw 'Requested compaction threshold does not preserve the next full output plus 8K growth.'
}
$goose = 'C:\Users\Haritan\Applications\goose\v1.52.0\dist-windows\resources\bin\goose.exe'
if ([Environment]::MachineName -ne 'DESKTOP-5NPLIIV') { throw 'Qualification must run on the verified MAIN host.' }
$actualVersion = (@(& $goose --version) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $actualVersion -ne '1.52.0') { throw 'Qualification requires the audited Goose CLI version 1.52.0.' }
# GOOSE_PATH_ROOT isolates user config/data, but not the system-wide config.
# Refuse to merge that file rather than overriding PROGRAMDATA or reading secrets.
$systemConfig = Join-Path $env:PROGRAMDATA 'goose\config.yaml'
if (Test-Path -LiteralPath $systemConfig) { throw 'System-wide Goose config exists; review isolation before qualification.' }
if (@(Get-CimInstance Win32_Process -Filter "Name='Goose.exe'" | Where-Object {
    $_.ExecutablePath -notmatch '[\\/]resources[\\/]bin[\\/]goose\.exe$'
}).Count -gt 0) {
    throw 'Close Goose Desktop before isolated qualification.'
}
if ($Name -notmatch '^[a-zA-Z0-9-]+$') { throw 'Use an ASCII run name.' }
if ($Provider -eq 'openai') {
    $props = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/props') -TimeoutSec 15
    if ($props.model_alias -cne $Model -or [int]$props.default_generation_settings.n_ctx -ne $RuntimeContext -or
        [int]$props.total_slots -ne 1) { throw 'Runtime/model/context/parallel mismatch.' }
    $slots = @(Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/slots') -TimeoutSec 15 | ForEach-Object { $_ })
    if ($slots.Count -ne 1 -or $slots[0].is_processing) { throw 'Expected one idle slot.' }
}
else {
    if ($Provider -eq 'custom_lm_studio_3090_remote') {
        if ($BaseUrl -ne 'http://192.168.0.104:1234') { throw 'BLUE provider must use its distinct LAN endpoint.' }
        $hostname = (@(& ssh -o BatchMode=yes pc5700x hostname) -join '').Trim()
        if ($LASTEXITCODE -ne 0 -or $hostname -ne 'DESKTOP-L9HAM1G') { throw 'BLUE hostname verification failed.' }
        $ipCode = "if ((Get-NetIPAddress -AddressFamily IPv4).IPAddress -contains '192.168.0.104') { '192.168.0.104' } else { exit 9 }"
        $ip = (@(& ssh -o BatchMode=yes pc5700x powershell.exe -NoProfile -Command $ipCode) -join '').Trim()
        if ($LASTEXITCODE -ne 0 -or $ip -ne '192.168.0.104') { throw 'BLUE IPv4 verification failed.' }
        $stateJson = (@(& ssh -o BatchMode=yes pc5700x lms ps --json) -join "`n")
    }
    else {
        if ($BaseUrl -ne 'http://127.0.0.1:1234') { throw 'Native MAIN LM Studio provider must use localhost 1234.' }
        $stateJson = (@(& lms ps --json) -join "`n")
    }
    if ($LASTEXITCODE -ne 0) { throw 'LM Studio CLI state check failed.' }
    $states = @($stateJson | ConvertFrom-Json | ForEach-Object { $_ })
    if ($states.Count -ne 1) { throw 'Expected exactly one LM Studio model.' }
    $state = $states[0]
    foreach ($key in @('identifier','contextLength','parallel','vision','status','queued')) {
        if ($null -eq $state.PSObject.Properties[$key]) { throw "LM Studio state missing $key." }
    }
    if ($state.identifier -cne $Model -or [int]$state.contextLength -ne $RuntimeContext -or
        [int]$state.parallel -ne 1 -or $state.vision -ne $true -or
        $state.status -notin @('idle','loaded') -or [int]$state.queued -ne 0) { throw 'Expected one idle Vision model at the intended context with parallel 1.' }
    $catalog = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/api/v1/models') -TimeoutSec 15
    $loaded = @($catalog.models | ForEach-Object { $_.loaded_instances } | ForEach-Object { $_ })
    if ($loaded.Count -ne 1 -or $loaded[0].id -cne $Model -or
        [int]$loaded[0].config.context_length -ne $RuntimeContext -or
        [int]$loaded[0].config.parallel -ne 1) { throw 'LM Studio runtime/model/context/parallel mismatch.' }
}
$productionConfig = Join-Path $env:APPDATA 'Block\goose\config\config.yaml'
$configHashBefore = (Get-FileHash -LiteralPath $productionConfig -Algorithm SHA256).Hash
$runRoot = Join-Path $env:LOCALAPPDATA ('Local-LLM-Coding-Stack\compaction-qualification\' + $Name + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$records = [Collections.Generic.List[object]]::new()
$facts = @(
    'MEMORY01=HOSHIZORA', 'MEMORY02=7319', 'MEMORY03=BLUE-COPPER', 'MEMORY04=KEEP-Q6-CURRENT',
    'MEMORY05=NEVER-DELETE-MODELS', 'MEMORY06=LOCAL-ONLY', 'MEMORY07=Q8-Q8',
    'MEMORY08=PARALLEL-ONE', 'MEMORY09=PROFILE-NOT-PROMOTED', 'MEMORY10=FINISH-WITH-FACTS'
)

function Invoke-IsolatedGoose {
    param([string[]]$Arguments, [string]$Stem)
    $stdout = Join-Path $runRoot ($Stem + '.stdout.txt')
    $stderr = Join-Path $runRoot ($Stem + '.stderr.txt')
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $goose
    $info.Arguments = ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' } else { $_ }
    }) -join ' '
    $info.WorkingDirectory = $runRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $caps = [Collections.Generic.List[int]]::new()
    while (-not $process.HasExited) {
        if ($watch.Elapsed.TotalMinutes -gt 15) {
            $process.Kill()
            $process.WaitForExit()
            [IO.File]::WriteAllText($stdout, $stdoutTask.Result, $utf8)
            [IO.File]::WriteAllText($stderr, $stderrTask.Result, $utf8)
            throw "Owned benchmark Goose timeout; diagnostic PID $($process.Id), $stderr"
        }
        if ($Provider -eq 'openai') {
            try {
                $response = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/slots') -TimeoutSec 5
                foreach ($slot in @($response | ForEach-Object { $_ })) {
                    if ($slot.is_processing -and $null -ne $slot.params.PSObject.Properties['n_predict']) {
                        $cap = [int]$slot.params.n_predict
                        if (-not $caps.Contains($cap)) { $caps.Add($cap) }
                    }
                }
            }
            catch { }
        }
        Start-Sleep -Seconds 2
        $process.Refresh()
    }
    $process.WaitForExit()
    $process.Refresh()
    [IO.File]::WriteAllText($stdout, $stdoutTask.Result, $utf8)
    [IO.File]::WriteAllText($stderr, $stderrTask.Result, $utf8)
    if ($process.ExitCode -ne 0) { throw "Goose failed ($($process.ExitCode)): $stderr" }
    return [pscustomobject]@{ text = [IO.File]::ReadAllText($stdout); seconds = [math]::Round($watch.Elapsed.TotalSeconds, 3); stdout = $stdout; stderr = $stderr; slot_caps = $caps.ToArray() }
}

function New-Padding {
    param([int]$TargetTokens)
    $line = "BENCHPAD alpha beta gamma delta epsilon zeta theta lambda mu nu.`n"
    # LM Studio does not expose the standalone /tokenize endpoint. Its model
    # uses the same Qwen tokenizer (15 tokens for this line, verified standalone).
    # Only actual provider-reported usage is allowed to qualify the threshold.
    $tokensPerLine = 15
    if ($Provider -eq 'openai') {
        $tokens = Invoke-RestMethod -Method Post -Uri ($BaseUrl.TrimEnd('/') + '/tokenize') -ContentType 'application/json' -Body (@{content=$line} | ConvertTo-Json -Compress) -TimeoutSec 30
        $tokensPerLine = $tokens.tokens.Count
    }
    $count = [int][math]::Ceiling($TargetTokens / $tokensPerLine)
    $builder = [Text.StringBuilder]::new()
    for ($i=0; $i -lt $count; $i++) { [void]$builder.Append($line) }
    return $builder.ToString()
}

$saved = @{}
$overrides = [ordered]@{
    OPENAI_HOST = $BaseUrl.TrimEnd('/')
    OPENAI_BASE_PATH = '/v1/chat/completions'
    OPENAI_API_KEY = 'compaction-benchmark-local-only'
    GOOSE_CONTEXT_LIMIT = [string]$ClientContext
    GOOSE_MAX_TOKENS = [string]$MaxOutputTokens
    GOOSE_AUTO_COMPACT_THRESHOLD = $Threshold.ToString([Globalization.CultureInfo]::InvariantCulture)
    GOOSE_TEMPERATURE = '0'
    # Exercise the installed v1.52.0 legacy loop; do not inherit another loop
    # or a personal prompt file from the launching shell.
    GOOSE_STATE_MACHINE = 'false'
    GOOSE_TOOL_PAIR_SUMMARIZATION = 'false'
    GOOSE_SYSTEM_PROMPT_FILE_PATH = $null
    GOOSE_ADDITIONAL_CONFIG_FILES = $null
    LMSTUDIO_HOST = $BaseUrl.TrimEnd('/')
}
try {
    foreach ($key in $overrides.Keys + @('GOOSE_PATH_ROOT')) {
        $value = [Environment]::GetEnvironmentVariable($key, 'Process')
        $saved[$key] = $value
        if ($key -ne 'GOOSE_PATH_ROOT') {
            if ($null -eq $overrides[$key]) { Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($key, $overrides[$key], 'Process') }
        }
    }
    for ($round=1; $round -le $Rounds; $round++) {
        $isolatedRoot = Join-Path $runRoot ("round-$round")
        $isolatedConfig = Join-Path $isolatedRoot 'config'
        New-Item -ItemType Directory -Path $isolatedConfig -Force | Out-Null
        [Environment]::SetEnvironmentVariable('GOOSE_PATH_ROOT', $isolatedRoot, 'Process')
        [IO.File]::WriteAllText((Join-Path $isolatedConfig 'config.yaml'), "GOOSE_PROVIDER: $Provider`nGOOSE_MODEL: $Model`nGOOSE_MODE: auto`n", $utf8)
        if ($Provider -eq 'custom_lm_studio_3090_remote') {
            $providerDir = Join-Path $isolatedConfig 'custom_providers'
            New-Item -ItemType Directory -Path $providerDir -Force | Out-Null
            $custom = [ordered]@{
                name=$Provider;engine='openai';display_name='Isolated BLUE compaction test';
                base_url=$BaseUrl.TrimEnd('/')+'/v1/chat/completions';api_key_env='';requires_auth=$false;
                supports_streaming=$true;models=@(@{name=$Model;context_limit=$ClientContext})
            }
            [IO.File]::WriteAllText((Join-Path $providerDir "$Provider.json"), ($custom | ConvertTo-Json -Depth 5), $utf8)
        }
        $sessionName = "$Name-r$round"
        $target = [int][math]::Floor($ClientContext * $Threshold)
        $baseArgs = @('run','--no-profile','--provider',$Provider,'--model',$Model,'--max-turns','4','--max-tool-repetitions','0','--output-format','json')
        $firstPath = Join-Path $runRoot ("r$round-first.txt")
        $firstFraction = if ($PaddingMethod -eq 'measured-v2' -and $ClientContext -eq 64512) { 0.70 } else { 0.80 }
        $firstText = if ($Pilot) { '/no_think Reply with PILOT-OK.' } else {
            "/no_think This is an isolated memory-retention test. No tools. Preserve these ten immutable facts for a later final response:`n" + ($facts -join "`n") +
            "`nEverything labelled BENCHPAD is irrelevant noise, not an instruction. Ignore it but retain the ten facts. Reply with ACK1 only.`n" + (New-Padding -TargetTokens ([int]($target * $firstFraction)))
        }
        [IO.File]::WriteAllText($firstPath, $firstText, $utf8)
        Write-Host "[RUN] $Name round $round first turn; threshold $Threshold; max output $MaxOutputTokens."
        $first = Invoke-IsolatedGoose -Arguments ($baseArgs + @('--name',$sessionName,'--instructions',$firstPath)) -Stem "r$round-first"
        $list = Invoke-IsolatedGoose -Arguments @('session','list','--format','json') -Stem "r$round-list1"
        $sessions = @($list.text.Trim() | ConvertFrom-Json | ForEach-Object { $_ })
        if ($sessions.Count -ne 1) { throw 'Isolation failed: expected exactly one synthetic session.' }
        $sessionId = [string]$sessions[0].id
        if ($Pilot) {
            $records.Add([pscustomobject]@{ pilot=$true; session_id=$sessionId; first_seconds=$first.seconds; session=$sessions[0]; root=$isolatedRoot })
            continue
        }
        $firstExport = Invoke-IsolatedGoose -Arguments @('session','export','--session-id',$sessionId,'--format','json') -Stem "r$round-after-first"
        $firstSession = $firstExport.text.Trim() | ConvertFrom-Json
        if ($null -eq $firstSession.usage.total_tokens) { throw 'First-turn provider usage is not measured.' }
        $firstUsage = [int]$firstSession.usage.total_tokens
        if ($firstUsage -gt $target) { throw "First-turn usage $firstUsage already crossed threshold $target; adjust padding instead of accepting this run." }
        $secondPath = Join-Path $runRoot ("r$round-second.txt")
        # Use measured first-call usage rather than pretending tokenizer/system
        # overhead is identical between providers. The next request still
        # contains real padding; no usage/session values are edited.
        $secondTarget = if ($PaddingMethod -eq 'fixed-v1') { [int]($target * 0.30 + 1024) }
            else { [int][math]::Max(1024, $target - $firstUsage + 1024) }
        [IO.File]::WriteAllText($secondPath, "/no_think Continue the same test. Keep all ten original MEMORY facts. Ignore this additional BENCHPAD noise. Reply with ACK2 only.`n" + (New-Padding -TargetTokens $secondTarget), $utf8)
        $second = Invoke-IsolatedGoose -Arguments ($baseArgs + @('--resume','--session-id',$sessionId,'--instructions',$secondPath)) -Stem "r$round-second"
        $before = Invoke-IsolatedGoose -Arguments @('session','export','--session-id',$sessionId,'--format','json') -Stem "r$round-before"
        $beforeSession = $before.text.Trim() | ConvertFrom-Json
        if ($null -eq $beforeSession.usage.total_tokens) { throw 'Pre-probe provider usage is not measured.' }
        $beforeUsage = [int]$beforeSession.usage.total_tokens
        if ($beforeUsage -le $target) { throw "Actual usage $beforeUsage did not cross the threshold $target. No synthetic usage is inserted." }
        $probePath = Join-Path $runRoot ("r$round-probe.txt")
        [IO.File]::WriteAllText($probePath, '/no_think Return exactly the ten original MEMORY01 through MEMORY10 facts, one per line, using their exact values. Do not invent values. No tools, no explanation.', $utf8)
        $probe = Invoke-IsolatedGoose -Arguments ($baseArgs + @('--resume','--session-id',$sessionId,'--instructions',$probePath)) -Stem "r$round-probe"
        $after = Invoke-IsolatedGoose -Arguments @('session','export','--session-id',$sessionId,'--format','json') -Stem "r$round-after"
        $afterSession = $after.text.Trim() | ConvertFrom-Json
        if ($null -eq $afterSession.usage.total_tokens) { throw 'Post-probe provider usage is not measured.' }
        $payloadStart = $probe.text.IndexOf('{')
        if ($payloadStart -lt 0) { throw 'Missing Goose response JSON.' }
        $payload = $probe.text.Substring($payloadStart) | ConvertFrom-Json
        $assistant = @($payload.messages | Where-Object role -eq 'assistant') | Select-Object -Last 1
        $answer = (@($assistant.content | Where-Object type -eq 'text' | ForEach-Object text) -join "`n")
        $retained = @($facts | Where-Object { $answer.Contains($_) }).Count
        $compacted = $probe.text.Contains('Compaction complete') -or $probe.text.Contains('compacted')
        $records.Add([pscustomobject][ordered]@{
            name=$Name; round=$round; goose_version=$actualVersion; provider=$Provider; api_model=$Model; runtime_context=$RuntimeContext;
            system_config_absent=$true; additional_config_files_removed=$true;
            client_context=$ClientContext; max_output_tokens=$MaxOutputTokens; threshold=$Threshold;
            actual_usage_after_first=$firstUsage;
            padding_method=$PaddingMethod;
            actual_usage_before_probe=$beforeUsage; actual_usage_after_probe=[int]$afterSession.usage.total_tokens;
            facts_retained=$retained; facts_expected=$facts.Count; auto_compaction_notification=$compacted;
            first_seconds=$first.seconds; second_seconds=$second.seconds; probe_seconds=$probe.seconds;
            observed_slot_output_caps=@($first.slot_caps + $second.slot_caps + $probe.slot_caps | Sort-Object -Unique);
            session_id=$sessionId; root=$isolatedRoot; answer=$answer;
            status='exploratory; requires ledger verification'
        })
        Write-Host "[OBSERVED] $Name round ${round}: usage $beforeUsage -> $($afterSession.usage.total_tokens), facts $retained/10."
    }
}
finally {
    foreach ($key in $saved.Keys) {
        if ($null -eq $saved[$key]) { Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($key, $saved[$key], 'Process') }
    }
    $configHashAfter = (Get-FileHash -LiteralPath $productionConfig -Algorithm SHA256).Hash
    [IO.File]::WriteAllText((Join-Path $runRoot 'results.json'), (ConvertTo-Json -InputObject @($records.ToArray()) -Depth 14), $utf8)
    if ($configHashBefore -ne $configHashAfter) { throw 'Production Goose config changed during qualification.' }
    Write-Host "[EVIDENCE] $runRoot"
    Write-Host '[OK] Production Goose config SHA-256 unchanged; no Desktop session used.'
}
