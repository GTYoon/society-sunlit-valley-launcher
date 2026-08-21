[CmdletBinding()]
param(
    [string]$ClientPackRoot = 'C:\Users\mandeuk\curseforge\minecraft\Instances\Society Sunlit Valley',
    [string]$ForgeLibrariesRoot = 'C:\Users\mandeuk\curseforge\minecraft\Install\libraries',
    [string]$OutputRoot = 'D:\society-sunlit-valley-client-release-v3',
    [string]$ServerAddress = '116.126.112.66:25565',
    [string]$FilesBaseUrl = '__CLIENT_FILES_BASE_URL__',
    [string]$ServerIconUrl = '__SERVER_ICON_URL__',
    [string]$ServerIconSource = 'D:\society-sunlit-valley-server\server-icon.png',
    [string]$NewsRssUrl = '__NEWS_RSS_URL__'
)

$ErrorActionPreference = 'Stop'

function Get-Md5 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLowerInvariant()
}

function Get-PathToken {
    param([Parameter(Mandatory)][string]$Value)
    $sha1 = [Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        (([BitConverter]::ToString($sha1.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()).Substring(0, 16)
    }
    finally {
        $sha1.Dispose()
    }
}

function Join-Url {
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $encodedPath = (($RelativePath -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    "$($BaseUrl.TrimEnd('/'))/$encodedPath"
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )
    $Path.Substring($Root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
}

function New-Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$ArtifactPath
    )
    [ordered]@{
        size = (Get-Item -LiteralPath $Path).Length
        MD5 = Get-Md5 -Path $Path
        url = $Url
        path = $ArtifactPath
    }
}

$ClientPackRoot = [IO.Path]::GetFullPath($ClientPackRoot)
$ForgeLibrariesRoot = [IO.Path]::GetFullPath($ForgeLibrariesRoot)
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)

foreach ($required in @($ClientPackRoot, $ForgeLibrariesRoot)) {
    if (-not (Test-Path -LiteralPath $required -PathType Container)) {
        throw "Required directory was not found: $required"
    }
}
if (Test-Path -LiteralPath $OutputRoot) {
    $existing = @(Get-ChildItem -LiteralPath $OutputRoot -Force)
    if ($existing.Count -gt 0) {
        throw "Output directory is not empty; refusing to overwrite a release: $OutputRoot"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $ClientPackRoot 'manifest.json') -Raw | ConvertFrom-Json
$instance = Get-Content -LiteralPath (Join-Path $ClientPackRoot 'minecraftinstance.json') -Raw | ConvertFrom-Json

if ($manifest.version -ne '4.1.3' -or $manifest.minecraft.version -ne '1.20.1') {
    throw "Expected Society: Sunlit Valley 4.1.3 for Minecraft 1.20.1; found $($manifest.version) / $($manifest.minecraft.version)"
}
if ($instance.baseModLoader.name -ne 'forge-47.4.0') {
    throw "Expected Forge 47.4.0; found $($instance.baseModLoader.name)"
}

$forgeProfile = $instance.baseModLoader.versionJson
if ($forgeProfile -is [string]) {
    $forgeProfile = $forgeProfile | ConvertFrom-Json
}
if ($null -eq $forgeProfile -or [string]::IsNullOrWhiteSpace([string]$forgeProfile.mainClass)) {
    throw 'The installed CurseForge instance does not contain its Forge version manifest.'
}

$directUrls = @{}
$addonsByFileName = @{}
foreach ($addon in @($instance.installedAddons)) {
    $name = [string]$addon.fileNameOnDisk
    $url = [string]$addon.installedFile.downloadUrl
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        $addonsByFileName[$name] = $addon
    }
    if (-not [string]::IsNullOrWhiteSpace($name) -and $url -match '^https://') {
        $directUrls[$name] = $url
    }
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$managedFolders = @('config', 'configureddefaults', 'defaultconfigs', 'kubejs', 'patchouli_books', 'resourcepacks', 'shaderpacks')
$modules = [Collections.ArrayList]::new()
$copiedFiles = 0
$externalFiles = 0

foreach ($folder in $managedFolders) {
    $sourceFolder = Join-Path $ClientPackRoot $folder
    if (-not (Test-Path -LiteralPath $sourceFolder -PathType Container)) {
        continue
    }

    foreach ($sourceFile in Get-ChildItem -LiteralPath $sourceFolder -File -Recurse | Sort-Object FullName) {
        $relativePath = Get-RelativePath -Root $ClientPackRoot -Path $sourceFile.FullName
        $url = Join-Url -BaseUrl $FilesBaseUrl -RelativePath "files/$relativePath"
        $addon = $addonsByFileName[$sourceFile.Name]
        $copyToRelease = $true
        if ($null -ne $addon -and -not [bool]$addon.allowModDistribution) {
            $url = $directUrls[$sourceFile.Name]
            if ([string]::IsNullOrWhiteSpace($url)) {
                throw "No official CurseForge download URL is recorded for restricted file: $($sourceFile.Name)"
            }
            $copyToRelease = $false
        }
        if ($copyToRelease) {
            $destination = Join-Path $OutputRoot ('files\' + $relativePath.Replace('/', '\'))
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            [IO.File]::Copy($sourceFile.FullName, $destination, $false)
            $copiedFiles++
        }
        else {
            $externalFiles++
        }

        $token = Get-PathToken -Value $relativePath
        $null = $modules.Add([ordered]@{
            id = "society.file:file-$token`:4.1.3"
            name = [IO.Path]::GetFileName($relativePath)
            type = 'File'
            artifact = New-Artifact -Path $sourceFile.FullName -Url $url -ArtifactPath $relativePath
        })
    }
}

foreach ($mod in Get-ChildItem -LiteralPath (Join-Path $ClientPackRoot 'mods') -File -Filter '*.jar' | Sort-Object Name) {
    $url = $directUrls[$mod.Name]
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "No official CurseForge download URL is recorded for client mod: $($mod.Name)"
    }

    $token = Get-PathToken -Value "mods/$($mod.Name)"
    $coordinate = "society.sunlit:mod-$token`:4.1.3"
    $artifactPath = "society/sunlit/mod-$token/4.1.3/mod-$token-4.1.3.jar"
    $null = $modules.Add([ordered]@{
        id = "$coordinate@jar"
        name = $mod.Name
        type = 'ForgeMod'
        artifact = New-Artifact -Path $mod.FullName -Url $url -ArtifactPath $artifactPath
    })
}

$forgeArtifactPath = 'net/minecraftforge/forge/1.20.1-47.4.0/forge-1.20.1-47.4.0-universal.jar'
$forgeArtifactUrl = 'https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.0/forge-1.20.1-47.4.0-universal.jar'
$forgeArtifactFile = Join-Path $ForgeLibrariesRoot ($forgeArtifactPath.Replace('/', '\'))
if (-not (Test-Path -LiteralPath $forgeArtifactFile -PathType Leaf)) {
    throw "Forge universal jar is not installed locally: $forgeArtifactFile"
}

$forgeProfile.id = '1.20.1-forge-47.4.0'
$forgeProfileRelativePath = 'forge/1.20.1-forge-47.4.0.json'
$forgeProfileOutputPath = Join-Path $OutputRoot $forgeProfileRelativePath.Replace('/', '\')
New-Item -ItemType Directory -Path (Split-Path -Parent $forgeProfileOutputPath) -Force | Out-Null
[IO.File]::WriteAllText($forgeProfileOutputPath, ($forgeProfile | ConvertTo-Json -Depth 50), [Text.UTF8Encoding]::new($false))

$forgeSubModules = [Collections.ArrayList]::new()
$null = $forgeSubModules.Add([ordered]@{
    id = '1.20.1-forge-47.4.0'
    name = 'Forge 1.20.1-47.4.0 version manifest'
    type = 'VersionManifest'
    artifact = New-Artifact -Path $forgeProfileOutputPath -Url (Join-Url -BaseUrl $FilesBaseUrl -RelativePath $forgeProfileRelativePath) -ArtifactPath $forgeProfileRelativePath
})

foreach ($library in @($forgeProfile.libraries | Sort-Object name)) {
    $artifactPath = [string]$library.downloads.artifact.path
    $artifactUrl = [string]$library.downloads.artifact.url
    $artifactFile = Join-Path $ForgeLibrariesRoot $artifactPath.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $artifactFile -PathType Leaf)) {
        throw "Required Forge library is not installed locally: $artifactPath"
    }
    if ($artifactUrl -notmatch '^https://') {
        throw "Forge library has no HTTPS download URL: $($library.name)"
    }
    $null = $forgeSubModules.Add([ordered]@{
        id = [string]$library.name
        name = [string]$library.name
        type = 'Library'
        artifact = New-Artifact -Path $artifactFile -Url $artifactUrl -ArtifactPath $artifactPath
    })
}

$null = $modules.Insert(0, [ordered]@{
    id = 'net.minecraftforge:forge:1.20.1-47.4.0'
    name = 'Minecraft Forge 1.20.1-47.4.0'
    type = 'ForgeHosted'
    artifact = New-Artifact -Path $forgeArtifactFile -Url $forgeArtifactUrl -ArtifactPath $forgeArtifactPath
    subModules = @($forgeSubModules)
})

$distribution = [ordered]@{
    version = '4.1.3'
    rss = $NewsRssUrl
    servers = @(
        [ordered]@{
            id = 'society-sunlit-valley-4.1.3'
            name = 'Society: Sunlit Valley 4.1.3'
            description = 'Society: Sunlit Valley 4.1.3 · Minecraft 1.20.1 · Forge 47.4.0'
            icon = $ServerIconUrl
            version = '4.1.3'
            address = $ServerAddress
            minecraftVersion = '1.20.1'
            javaOptions = [ordered]@{
                supported = '>=17 <18'
                suggestedMajor = 17
                distribution = 'TEMURIN'
            }
            mainServer = $true
            autoconnect = $true
            modules = @($modules)
        }
    )
}

$distributionPath = Join-Path $OutputRoot 'distribution.json'
[IO.File]::WriteAllText($distributionPath, ($distribution | ConvertTo-Json -Depth 50), [Text.UTF8Encoding]::new($false))

if (-not (Test-Path -LiteralPath $ServerIconSource -PathType Leaf)) {
    throw "Server icon source was not found: $ServerIconSource"
}
[IO.File]::Copy($ServerIconSource, (Join-Path $OutputRoot 'server-icon.png'), $false)

[pscustomobject]@{
    outputRoot = $OutputRoot
    distribution = $distributionPath
    copiedManagedFiles = $copiedFiles
    externallyHostedFiles = $externalFiles
    forgeMods = @($modules | Where-Object type -eq 'ForgeMod').Count
    forgeLibraries = $forgeSubModules.Count - 1
    serverAddress = $ServerAddress
    filesBaseUrl = $FilesBaseUrl
    sourceClientWasModified = $false
}
