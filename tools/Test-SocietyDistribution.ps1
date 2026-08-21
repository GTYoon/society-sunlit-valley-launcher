[CmdletBinding()]
param(
    [string]$DistributionPath = 'D:\society-sunlit-valley-client-release-v3\distribution.json'
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
if ($server.minecraftVersion -ne '1.20.1' -or $server.javaOptions.suggestedMajor -ne 17) {
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
    if ([long]$module.artifact.size -lt 0 -or [string]$module.artifact.MD5 -notmatch '^[0-9a-f]{32}$' -or [string]$module.artifact.url -notmatch '^https://') {
        $failures.Add("Invalid artifact metadata: $($module.id)")
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
