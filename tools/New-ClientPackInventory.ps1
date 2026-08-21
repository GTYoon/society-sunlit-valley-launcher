[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$ClientPackRoot,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $projectRoot 'client-pack-inventory.json'
}

$ClientPackRoot = [IO.Path]::GetFullPath($ClientPackRoot)
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$excludedRoots = @('logs', 'crash-reports', 'saves', 'screenshots', '.cache')

$files = Get-ChildItem -LiteralPath $ClientPackRoot -File -Recurse | Where-Object {
    $relative = $_.FullName.Substring($ClientPackRoot.Length).TrimStart('\', '/')
    $firstSegment = ($relative -split '[\\/]')[0]
    $firstSegment -notin $excludedRoots
} | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($ClientPackRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    [ordered]@{
        path = $relative
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$inventory = [ordered]@{
    pack = 'Society: Sunlit Valley'
    packVersion = '4.1.3'
    minecraftVersion = '1.20.1'
    loader = 'Forge'
    sourceRoot = $ClientPackRoot
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    files = @($files)
}

[IO.Directory]::CreateDirectory((Split-Path -Parent $OutputPath)) | Out-Null
[IO.File]::WriteAllText(
    $OutputPath,
    ($inventory | ConvertTo-Json -Depth 5),
    [Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    clientPack = $ClientPackRoot
    inventory = $OutputPath
    files = @($files).Count
    modifiedClientFiles = $false
}
