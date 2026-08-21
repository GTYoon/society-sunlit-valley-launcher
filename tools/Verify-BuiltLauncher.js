'use strict'

const path = require('path')
const asar = require('@electron/asar')

const archivePath = path.resolve(process.argv[2] || 'dist/win-unpacked/resources/app.asar')
const archiveEntries = asar.listPackage(archivePath).map(entry => entry.replace(/\\/g, '/').replace(/^\/+/, ''))
const resolveArchiveFile = file => archiveEntries
    .filter(entry => entry.endsWith(file))
    .sort((left, right) => left.length - right.length)[0]
    .replace(/\//g, path.sep)
const readArchiveFile = file => asar.extractFile(archivePath, resolveArchiveFile(file)).toString('utf8')

const packageJson = JSON.parse(readArchiveFile('package.json'))
const sourcePackageJson = require(path.resolve(__dirname, '..', 'package.json'))
const settingsScript = readArchiveFile('app/assets/js/scripts/settings.js')
const uiCoreScript = readArchiveFile('app/assets/js/scripts/uicore.js')
const koreanLanguage = readArchiveFile('app/assets/lang/ko_KR.toml')

const result = {
    archive: archivePath,
    version: packageJson.version,
    sourceVersion: sourcePackageJson.version,
    remoteMain: archiveEntries.includes('node_modules/@electron/remote/main/index.js'),
    remoteRenderer: archiveEntries.includes('node_modules/@electron/remote/renderer/index.js'),
    heliosCore: archiveEntries.includes('node_modules/helios-core/dist/index.js'),
    updater: archiveEntries.includes('node_modules/electron-updater/out/main.js'),
    gameUpdater: settingsScript.includes('checkGameFilesAndLauncher'),
    fullRepair: settingsScript.includes('SettingsFullRepair'),
    updateNavigation: uiCoreScript.includes('showGameFilesUpdateUI'),
    koreanHeader: koreanLanguage.includes('게임 및 런처 업데이트'),
    koreanProgress: koreanLanguage.includes('게임 파일 검사 중')
}

console.log(JSON.stringify(result, null, 2))

if(
    result.version !== result.sourceVersion ||
    !result.remoteMain ||
    !result.remoteRenderer ||
    !result.heliosCore ||
    !result.updater ||
    !result.gameUpdater ||
    !result.fullRepair ||
    !result.updateNavigation ||
    !result.koreanHeader ||
    !result.koreanProgress
){
    process.exitCode = 1
}
