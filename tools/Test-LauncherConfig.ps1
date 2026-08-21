[CmdletBinding()]
param(
    [switch]$RequireProductionSettings
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()

foreach ($relativePath in @(
    'package.json',
    'electron-builder.yml',
    'app\assets\js\configmanager.js',
    'app\assets\js\distromanager.js',
    'app\assets\js\ipcconstants.js',
    'app\assets\images\backgrounds\0.jpg',
    'build\icon.png'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relativePath) -PathType Leaf)) {
        $failures.Add("Required file is missing: $relativePath")
    }
}

$package = Get-Content -LiteralPath (Join-Path $projectRoot 'package.json') -Raw | ConvertFrom-Json
if ($package.name -ne 'society-sunlit-valley-launcher') {
    $failures.Add('package.json name is not Society-specific.')
}
if ($package.productName -ne 'Society: Sunlit Valley 4.1.3') {
    $failures.Add('package.json productName is not the requested pack version.')
}

$targetFiles = @(
    'package.json', 'package-lock.json', 'electron-builder.yml', 'dev-app-update.yml',
    'app'
) | ForEach-Object { Join-Path $projectRoot $_ }
$sourceFiles = Get-ChildItem -LiteralPath $targetFiles -File -Recurse | Where-Object {
    $_.Extension -in @('.js', '.json', '.md', '.ps1', '.toml', '.yml', '.yaml', '.ejs')
}
foreach ($file in $sourceFiles) {
    $content = [IO.File]::ReadAllText($file.FullName)
    if ($content -match '(?i)modakbul|cobblemon') {
        $failures.Add("Inherited server identifier remains: $($file.FullName.Substring($projectRoot.Length + 1))")
    }
}

$dataConfig = [IO.File]::ReadAllText((Join-Path $projectRoot 'app\assets\js\configmanager.js'))
if ($dataConfig -notmatch '\.society-sunlit-valley-4-1-3') {
    $failures.Add('Launcher data directory is not isolated from Modakbul Season 1.')
}

$placeholders = @($sourceFiles | Where-Object {
    [IO.File]::ReadAllText($_.FullName) -match '__(GITHUB_OWNER|AZURE_CLIENT_ID|DISTRIBUTION_URL)__'
})
if ($RequireProductionSettings -and $placeholders.Count -gt 0) {
    $failures.Add("Production placeholders remain in $($placeholders.Count) file(s).")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

[pscustomobject]@{
    project = $projectRoot
    productionSettingsRequired = [bool]$RequireProductionSettings
    productionPlaceholders = $placeholders.Count
    status = 'passed'
}
