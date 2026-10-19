[CmdletBinding()]
param(
    [ValidateRange(0, 65536)][int]$GrowthReserveTokens = 8192
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Parse literal management records only. Never dot-source a launcher or load a model.
function Read-AssignedTable {
    param([string]$Path, [string]$Variable)
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "Cannot parse $Path" }
    $matches = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ceq $Variable
    }, $false))
    if ($matches.Count -ne 1) { throw "Expected exactly one literal table: $Variable" }
    $table = $matches[0].Right.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if ($null -eq $table) { throw "Missing literal table: $Variable" }
    return $table
}

function Read-Literal {
    param($Table, [string]$Name)
    $pairs = @($Table.KeyValuePairs | Where-Object { $_.Item1.SafeGetValue() -ceq $Name })
    if ($pairs.Count -ne 1) { throw "Expected one literal field: $Name" }
    return $pairs[0].Item2.SafeGetValue()
}

$daily = Read-AssignedTable -Path (Join-Path $PSScriptRoot 'Start-GooseDailyProfile.ps1') -Variable 'profiles'
$persistent = Read-AssignedTable -Path (Join-Path $PSScriptRoot 'Set-GooseProfile.ps1') -Variable 'profileDefinitions'
$turbo = Read-AssignedTable -Path (Join-Path $PSScriptRoot '..\standalone-turbo\Start-Goose-ManagedTurbo.ps1') -Variable 'overrides'
$invariant = [Globalization.CultureInfo]::InvariantCulture

foreach ($pair in $daily.KeyValuePairs) {
    $id = [string]$pair.Item1.SafeGetValue()
    $entry = $pair.Item2.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
    $runtime = [int](Read-Literal -Table $entry -Name 'RuntimeContext')
    $client = [int](Read-Literal -Table $entry -Name 'ClientContext')
    $output = [int](Read-Literal -Table $entry -Name 'Output')
    $runtimeKind = [string](Read-Literal -Table $entry -Name 'RuntimeKind')
    if ($runtimeKind -eq 'Turbo') {
        $currentText = Read-Literal -Table $turbo -Name 'GOOSE_AUTO_COMPACT_THRESHOLD'
        $turboProfile = [string](Read-Literal -Table $entry -Name 'TurboProfile')
        $manifestPath = Join-Path $PSScriptRoot "..\standalone-turbo\runtime-manifests\$turboProfile.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ([int]$manifest.configuration.context_tokens -ne $runtime) { throw "Runtime context mismatch: $id" }
        if ($null -ne $manifest.PSObject.Properties['goose']) {
            if ([int]$manifest.goose.client_context_tokens -ne $client -or [int]$manifest.goose.max_output_tokens -ne $output) {
                throw "Goose context/output mismatch: $id"
            }
            $currentText = ([double]$manifest.goose.auto_compact_threshold).ToString($invariant)
        }
    }
    else {
        $persistentId = Read-Literal -Table $entry -Name 'GooseProfile'
        $persistentPair = @($persistent.KeyValuePairs | Where-Object { $_.Item1.SafeGetValue() -ceq $persistentId })
        if ($persistentPair.Count -ne 1) { throw "Missing profile definition: $persistentId" }
        $persistentEntry = $persistentPair[0].Item2.Find({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false)
        $currentText = Read-Literal -Table $persistentEntry -Name 'CompactThreshold'
    }
    $currentRate = [double]::Parse([string]$currentText, $invariant)
    # The extended-context profile uses the user-approved manifest rate, not
    # the legacy launcher default. Static fit is not live compaction acceptance.
    $extendedTrial = $id -cin @('BLUE-Extended256K16K', 'MAIN-Extended256K16K')
    $candidateRate = if ($extendedTrial) { $currentRate }
        elseif ($id -match '-Quick8K$') { 0.60 }
        elseif ($id -match '-Quality32K$') { 0.30 }
        elseif ($id -match '-(Stable|Turbo)16K$') { 0.65 }
        elseif ($id -match '-(Stable|Turbo)32K$') { 0.50 }
        else { throw "Profile has no evaluated candidate: $id" }
    if ($client -le 0 -or $client -gt $runtime -or $output -le 0 -or $output -ge $runtime) {
        throw "Invalid context/output record: $id"
    }
    # v1.52.0 compares usage/client > threshold, not >=. This is eligibility,
    # not a promise that compaction runs immediately during a tool loop.
    $firstEligible = [int][math]::Floor($client * $candidateRate) + 1
    $remaining = $runtime - $firstEligible - $output
    [pscustomobject][ordered]@{
        profile = $id
        runtime_context_tokens = $runtime
        goose_client_context_tokens = $client
        max_output_tokens = $output
        current_threshold = $currentRate
        candidate_threshold = $candidateRate
        # v1.52.0 compute_tool_call_cutoff: clamp(3 * floor(limit * rate) / 20000, 10, 500).
        current_derived_tool_call_cutoff = [int][math]::Min(500, [math]::Max(10, [math]::Floor(3 * [math]::Floor($client * $currentRate) / 20000)))
        candidate_derived_tool_call_cutoff = [int][math]::Min(500, [math]::Max(10, [math]::Floor(3 * [math]::Floor($client * $candidateRate) / 20000)))
        candidate_status = if ($extendedTrial) { 'user-approved-60-percent-trial; live compaction not qualified' }
            else { 'static-budget-only; live compaction qualification required' }
        first_eligible_usage_tokens = $firstEligible
        free_after_next_max_output_tokens = $remaining
        growth_reserve_tokens = $GrowthReserveTokens
        margin_after_growth_reserve_tokens = $remaining - $GrowthReserveTokens
        candidate_budget_fits = $remaining - $GrowthReserveTokens -gt 0
        default_80_percent_margin_tokens = $runtime - ([int][math]::Floor($client * 0.80) + 1) - $output - $GrowthReserveTokens
    }
}
