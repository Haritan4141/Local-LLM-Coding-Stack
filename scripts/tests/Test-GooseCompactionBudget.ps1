[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$measure = Join-Path $PSScriptRoot '..\goose\Measure-GooseCompactionBudget.ps1'
$qualification = Join-Path $PSScriptRoot '..\goose\Invoke-GooseCompactionQualification.ps1'
foreach ($scriptPath in @($measure, $qualification)) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) { throw "Compaction script syntax failed: $scriptPath" }
}
$qualificationText = Get-Content -LiteralPath $qualification -Raw
foreach ($required in @('GOOSE_PATH_ROOT', '--no-profile', 'configHashBefore', 'configHashAfter', 'No synthetic usage is inserted',
    "GOOSE_STATE_MACHINE = 'false'", 'GOOSE_SYSTEM_PROMPT_FILE_PATH = $null', 'GOOSE_ADDITIONAL_CONFIG_FILES = $null',
    'System-wide Goose config exists', 'Qualification requires the audited Goose CLI version 1.52.0.',
    'First-turn provider usage is not measured.', 'already crossed threshold')) {
    if (-not $qualificationText.Contains($required)) { throw "Missing isolation guard: $required" }
}
$rows = @(& $measure)
if ($rows.Count -ne 14) { throw 'Expected all 14 Daily profiles.' }
foreach ($row in $rows) {
    $extended = $row.profile -cin @('BLUE-Extended256K16K', 'MAIN-Extended256K16K')
    $expectedCurrent = if ($extended) { 0.6 } else { 0.3 }
    $expectedCutoff = if ($extended) { 21 } else { 10 }
    if (-not $row.candidate_budget_fits -or $row.current_threshold -ne $expectedCurrent) {
        throw "Unexpected current/candidate budget: $($row.profile)"
    }
    if ($row.current_derived_tool_call_cutoff -ne $expectedCutoff -or $row.candidate_derived_tool_call_cutoff -ne $expectedCutoff) {
        throw 'Unexpected derived tool cutoff: existing profiles10; approved extended profile21.'
    }
    $expected = switch -Regex ($row.profile) {
        '^(BLUE|MAIN)-Extended256K16K$' { @(262144, 237568, 16384, 0.6, 142541, 95027); break }
        '-Quick8K$' { @(65536, 57344, 8192, 0.6, 34407, 14745); break }
        '-(Stable|Turbo)16K$' { @(98304, 90112, 16384, 0.65, 58573, 15155); break }
        '-(Stable|Turbo)32K$' { @(98304, 90112, 32768, 0.5, 45057, 12287); break }
        '-Quality32K$' { @(65536, 64512, 32768, 0.3, 19354, 5222); break }
        default { throw "Unexpected profile: $($row.profile)" }
    }
    $actual = @($row.runtime_context_tokens, $row.goose_client_context_tokens, $row.max_output_tokens,
        $row.candidate_threshold, $row.first_eligible_usage_tokens, $row.margin_after_growth_reserve_tokens)
    for ($i = 0; $i -lt $expected.Count; $i++) {
        if ($actual[$i] -ne $expected[$i]) { throw "Budget mismatch: $($row.profile), field $i" }
    }
    if ($row.max_output_tokens -eq 32768 -and $row.default_80_percent_margin_tokens -ge 0) {
        throw 'Output32K must reject an unqualified blanket 80% threshold.'
    }
    if ($extended -and
        ($row.candidate_threshold -ne $row.current_threshold -or
        $row.candidate_status -cne 'user-approved-60-percent-trial; live compaction not qualified')) {
        throw 'Extended-context trial must retain approved60% and unqualified live compaction status.'
    }
}
$largerReserve = @(& $measure -GrowthReserveTokens 16384)
if (@($largerReserve | Where-Object { -not $_.candidate_budget_fits }).Count -ne 2 -or
    @($largerReserve | Where-Object { -not $_.candidate_budget_fits -and $_.profile -notmatch '-Quality32K$' }).Count -gt 0) {
    throw 'Quality 64K/32K must expose the long-loop 16K-growth limitation.'
}
Write-Host 'Goose compaction static budget tests passed: 14 profiles, exact boundaries, approved extended60% only, output reserves, 80% rejection and 16K-growth limitation.'
