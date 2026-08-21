[CmdletBinding()]
param(
    [string]$DistributionPath = 'D:\society-sunlit-valley-client-release-v4\distribution.json'
)

$ErrorActionPreference = 'Stop'
$DistributionPath = [IO.Path]::GetFullPath($DistributionPath)
if (-not (Test-Path -LiteralPath $DistributionPath -PathType Leaf)) {
    throw "Distribution file was not found: $DistributionPath"
}

$distribution = Get-Content -LiteralPath $DistributionPath -Raw | ConvertFrom-Json
$failures = [Collections.Generic.List[string]]::new()
if ($distribution.version -ne '4.1.3' -or $distribution.servers.Count -ne 1) {
    $failures.Add('Distribution must contain exactly one Society 4.1.3 server.')
}

$server = $distribution.servers[0]
if ($server.minecraftVersion -ne '1.20.1' -or $server.javaOptions.suggestedMajor -ne 17 -or $server.javaOptions.ram.recommended -ne 12288 -or $server.javaOptions.ram.minimum -ne 4096) {
    $failures.Add('Minecraft or Java version is not correct for Society 4.1.3.')
}

$modules = @($server.modules)
if (@($modules | Where-Object type -eq 'ForgeHosted').Count -ne 1) {
    $failures.Add('Exactly one ForgeHosted module is required.')
}
if (@($modules | Where-Object type -eq 'ForgeMod').Count -ne 351) {
    $failures.Add("Expected 351 Forge client mods; found $(@($modules | Where-Object type -eq 'ForgeMod').Count).")
}

$duplicateIds = @($modules.id | Group-Object | Where-Object Count -gt 1)
if ($duplicateIds.Count -gt 0) {
    $failures.Add("Duplicate module IDs: $($duplicateIds.Count)")
}

foreach ($module in $modules) {
    $toValidate = @($module)
    while ($toValidate.Count -gt 0) {
        $candidate = $toValidate[0]
        if ($toValidate.Count -eq 1) {
            $toValidate = @()
        }
        else {
            $toValidate = @($toValidate[1..($toValidate.Count - 1)])
        }
        if ($null -ne $candidate.subModules) {
            $toValidate += @($candidate.subModules)
        }
        if ([long]$candidate.artifact.size -lt 0 -or [string]$candidate.artifact.MD5 -notmatch '^[0-9a-f]{32}$' -or [string]$candidate.artifact.url -notmatch '^https://') {
            $failures.Add("Invalid artifact metadata: $($candidate.id)")
        }
    }
}

$forge = @($modules | Where-Object type -eq 'ForgeHosted')[0]
if ($null -ne $forge) {
    if ($forge.id -ne 'net.minecraftforge:lowcodelanguage:1.20.1-47.4.0') {
        $failures.Add("ForgeHosted bootstrap must be lowcodelanguage; found $($forge.id).")
    }
    $expectedForgeOutputs = @(
        'net.minecraftforge:fmlcore:1.20.1-47.4.0',
        'net.minecraftforge:javafmllanguage:1.20.1-47.4.0',
        'net.minecraftforge:mclanguage:1.20.1-47.4.0',
        'net.minecraftforge:forge:1.20.1-47.4.0:client',
        'net.minecraft:client:1.20.1-20230612.114412:srg',
        'net.minecraft:client:1.20.1-20230612.114412:slim',
        'net.minecraft:client:1.20.1-20230612.114412:extra'
    )
    foreach ($id in $expectedForgeOutputs) {
        if (@($forge.subModules | Where-Object id -eq $id).Count -ne 1) {
            $failures.Add("Forge installation output is missing: $id")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

[pscustomobject]@{
    distribution = $DistributionPath
    serverAddress = $server.address
    modules = $modules.Count
    forgeMods = @($modules | Where-Object type -eq 'ForgeMod').Count
    managedFiles = @($modules | Where-Object type -eq 'File').Count
    status = 'passed'
}
