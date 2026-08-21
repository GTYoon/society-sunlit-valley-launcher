[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$')]
    [string]$GitHubOwner,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AzureClientId,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$DistributionUrl
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

$replacements = [ordered]@{
    '__GITHUB_OWNER__'   = $GitHubOwner
    '__AZURE_CLIENT_ID__' = $AzureClientId.ToLowerInvariant()
    '__DISTRIBUTION_URL__' = $DistributionUrl
}

$textExtensions = @('.js', '.json', '.md', '.toml', '.yml', '.yaml')
$files = Get-ChildItem -LiteralPath $projectRoot -Recurse -File |
    Where-Object {
        $_.Extension -in $textExtensions -and
        $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]'
    }

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $updated = $content

    foreach ($entry in $replacements.GetEnumerator()) {
        $updated = $updated.Replace($entry.Key, $entry.Value)
    }

    if ($updated -ne $content) {
        [System.IO.File]::WriteAllText(
            $file.FullName,
            $updated,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}

& (Join-Path $PSScriptRoot 'Test-LauncherConfig.ps1')
