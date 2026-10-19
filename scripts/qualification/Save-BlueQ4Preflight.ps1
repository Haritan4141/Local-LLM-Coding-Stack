[CmdletBinding()]
param([string]$Stage = 'before')
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$raw = Join-Path $repo 'benchmarks\raw\blue-q4-vision-20261006'
New-Item -ItemType Directory -Path $raw -Force | Out-Null
$path = Join-Path $raw "$Stage.json"
if (Test-Path -LiteralPath $path) { throw "Refusing existing evidence overwrite: $path" }
$globalPaths = @(
    "$env:APPDATA\Block\goose\config\config.yaml",
    "$env:USERPROFILE\.config\goose\.goosehints",
    "$env:USERPROFILE\.config\kilo\kilo.jsonc",
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Code\User\globalStorage\zoocodeorganization.zoo-code\settings\mcp_settings.json",
    "$env:APPDATA\Code\User\globalStorage\zoocodeorganization.zoo-code\settings\custom_modes.yaml",
    "$env:APPDATA\Code\User\globalStorage\kilocode.kilo-code\settings\mcp_settings.json",
    "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json",
    "$env:USERPROFILE\.lmstudio\settings.json",
    "$env:USERPROFILE\.lmstudio\mcp.json"
)
$global = @($globalPaths | ForEach-Object {
    if (Test-Path -LiteralPath $_ -PathType Leaf) {
        [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash;modified_utc=(Get-Item -LiteralPath $_).LastWriteTimeUtc.ToString('o')}
    } else { [ordered]@{path=$_;exists=$false} }
})
$repoHashes = @(& git -C $repo ls-files --cached --others --exclude-standard | Select-Object -Unique | ForEach-Object {
    $full = Join-Path $repo $_
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath $full).Hash}
    }
})
$record = [ordered]@{stage=$Stage;at_utc=[DateTime]::UtcNow.ToString('o');host=$env:COMPUTERNAME;global_hashes=$global;repo_hashes=$repoHashes;git_status=@(& git -C $repo status --short)}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
if ($Stage -eq 'before') {
    $backup = Join-Path $raw 'document-backup'
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($doc in @('CURRENT_STATE.md','CHANGELOG.md','MODEL_REGISTRY.md')) {
        Copy-Item -LiteralPath (Join-Path $repo $doc) -Destination (Join-Path $backup $doc)
    }
}
Write-Output "Saved secret-free SHA-only preflight: $path"
