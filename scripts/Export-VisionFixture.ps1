[CmdletBinding()]
param(
    [string]$SourcePath = 'benchmarks/fixtures/vision-ui-v1/index.html',
    [string]$OutputPath = 'benchmarks/raw/vision-ui-v1.png',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

$sourceFullPath = Resolve-RepoPath $SourcePath
$outputFullPath = Resolve-RepoPath $OutputPath

if (-not (Test-Path -LiteralPath $sourceFullPath -PathType Leaf)) {
    throw "Vision fixture source not found: $sourceFullPath"
}
if ((Test-Path -LiteralPath $outputFullPath) -and -not $Force) {
    throw "Refusing to overwrite existing screenshot: $outputFullPath. Use -Force to regenerate it."
}

$chromeCandidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$chrome = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $chrome) {
    throw 'Google Chrome was not found in the standard installation paths.'
}

$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$sourceUri = [uri]$sourceFullPath
& $chrome `
    --headless=new `
    --disable-gpu `
    --hide-scrollbars `
    --window-size=960,540 `
    "--screenshot=$outputFullPath" `
    $sourceUri.AbsoluteUri

$chromeFailed = $null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0
if ($chromeFailed -or -not (Test-Path -LiteralPath $outputFullPath -PathType Leaf)) {
    throw "Chrome failed to render the Vision fixture: $outputFullPath"
}

Write-Output $outputFullPath
