[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$ServerPackZip,

    [string]$Destination
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path (Split-Path -Parent $projectRoot) 'society-sunlit-valley-server'
}

$ServerPackZip = [IO.Path]::GetFullPath($ServerPackZip)
$Destination = [IO.Path]::GetFullPath($Destination)

if ([IO.Path]::GetExtension($ServerPackZip) -ne '.zip') {
    throw "Server pack must be a ZIP file: $ServerPackZip"
}
if ((Split-Path -Leaf $ServerPackZip) -notmatch '(?i)society.*sunlit.*4\.1\.3') {
    throw "Expected the official Society: Sunlit Valley 4.1.3 server pack: $ServerPackZip"
}
if (Test-Path -LiteralPath $Destination) {
    $existingItems = @(Get-ChildItem -LiteralPath $Destination -Force)
    if ($existingItems.Count -gt 0) {
        throw "Destination is not empty; refusing to overwrite a server: $Destination"
    }
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
Expand-Archive -LiteralPath $ServerPackZip -DestinationPath $Destination -Force

[pscustomobject]@{
    serverPack = $ServerPackZip
    destination = $Destination
    files = @(Get-ChildItem -LiteralPath $Destination -File -Recurse).Count
    nextStep = 'Review the extracted pack, then accept eula.txt manually before its first start.'
}
