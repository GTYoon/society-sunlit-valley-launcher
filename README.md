# Society: Sunlit Valley 4.1.3 launcher

This is a standalone launcher project for the unmodified Society: Sunlit Valley 4.1.3 pack.
It has its own app ID, install data directory, updater repository, and client distribution URL. It does not read, update, or share files with the active Modakbul Season 1 launcher.

## Confirmed pack baseline

- Pack: Society: Sunlit Valley 4.1.3
- Minecraft: 1.20.1
- Loader: Forge
- Server source: the matching CurseForge server pack only

The server pack is never edited by this project. `Prepare-ServerPack.ps1` only extracts the official ZIP into a new destination; it does not add, remove, or replace mods or configuration files.

## Server preparation

Download the official `SERVER-PACK-Society-Sunlit-Valley-4.1.3.zip`, then run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\tools\Prepare-ServerPack.ps1 `
  -ServerPackZip 'C:\path\to\SERVER-PACK-Society-Sunlit-Valley-4.1.3.zip'
```

The destination defaults to `..\society-sunlit-valley-server`. The script refuses to extract over a non-empty folder. Accepting Minecraft's EULA, choosing server properties, port forwarding, and the first server start are separate administrator actions.

## Client launcher release input

The server pack alone cannot create a client launcher because it does not include every client-only mod and asset. Install the matching 4.1.3 client pack through CurseForge once without changing it, then inventory that installed instance:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\tools\New-ClientPackInventory.ps1 `
  -ClientPackRoot 'C:\path\to\CurseForge\Instances\Society - Sunlit Valley'
```

This creates hashes only; it does not change the official client files. Use the resulting inventory to publish the exact client files and a Forge `distribution.json` before building the installer.

## Build the launcher distribution

The installed CurseForge instance is the source of truth. The following command copies client configuration, scripts, and assets into `D:\society-sunlit-valley-client-release-v3`; it keeps all 351 mods and files marked non-distributable on their original CurseForge download URLs. It never changes the source instance.

```powershell
.\tools\Build-SocietyDistribution.ps1
.\tools\Test-SocietyDistribution.ps1
```

The published client manifest is [distribution.json](https://raw.githubusercontent.com/GTYoon/society-sunlit-valley-client/main/distribution.json). It targets `116.126.112.66:25565` and is served from the public [client-files repository](https://github.com/GTYoon/society-sunlit-valley-client).

## Production configuration and build

Register a separate Microsoft Entra application for this launcher, then configure the copied project with its client ID:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\tools\Configure-Launcher.ps1 `
  -GitHubOwner 'GTYoon' `
  -AzureClientId '<new-client-id>' `
  -DistributionUrl 'https://raw.githubusercontent.com/GTYoon/society-sunlit-valley-client/main/distribution.json'

.\tools\Test-LauncherConfig.ps1 -RequireProductionSettings
npm ci
npm run lint
npm run dist:win
```

`dist` is intentionally not committed. Do not build or publish until the exact 4.1.3 client distribution and server address have been verified.
