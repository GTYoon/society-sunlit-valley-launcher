const remoteMain = require('@electron/remote/main')
remoteMain.initialize()

const { app, BrowserWindow, ipcMain, shell } = require('electron')
const autoUpdater = require('electron-updater').autoUpdater
const path = require('path')
const { pathToFileURL } = require('url')
const ejse = require('ejs-electron')
const isDev = require('./app/assets/js/isdev')
const semver = require('semver')
const LangLoader = require('./app/assets/js/langloader')
const {
    AZURE_CLIENT_ID,
    MSFT_OPCODE,
    MSFT_REPLY_TYPE,
    MSFT_ERROR,
    SHELL_OPCODE
} = require('./app/assets/js/ipcconstants')

app.setPath('userData', path.join(app.getPath('appData'), 'Society-Sunlit-Valley-4.1.3'))
LangLoader.setupLanguage()
app.disableHardwareAcceleration()

function initAutoUpdater(event, allowPrerelease) {
    autoUpdater.allowPrerelease = Boolean(allowPrerelease)
    if (isDev) {
        autoUpdater.autoInstallOnAppQuit = false
        autoUpdater.updateConfigPath = path.join(__dirname, 'dev-app-update.yml')
    }
    if (process.platform === 'darwin') {
        autoUpdater.autoDownload = false
    }
    autoUpdater.on('update-available', (info) => event.sender.send('autoUpdateNotification', 'update-available', info))
    autoUpdater.on('update-downloaded', (info) => event.sender.send('autoUpdateNotification', 'update-downloaded', info))
    autoUpdater.on('update-not-available', (info) => event.sender.send('autoUpdateNotification', 'update-not-available', info))
    autoUpdater.on('checking-for-update', () => event.sender.send('autoUpdateNotification', 'checking-for-update'))
    autoUpdater.on('error', (error) => event.sender.send('autoUpdateNotification', 'realerror', error))
}

const REDIRECT_URI_PREFIX = 'https://login.microsoftonline.com/common/oauth2/nativeclient?'
let msftAuthWindow
let msftAuthSuccess
let msftAuthViewSuccess
let msftAuthViewOnClose
let msftLogoutWindow
let msftLogoutSuccess
let msftLogoutSuccessSent

function getPlatformIcon(filename) {
    return path.join(__dirname, 'app', 'assets', 'images', `${filename}.png`)
}

function openMicrosoftLogin(ipcEvent, viewSuccess, viewOnClose) {
    if (msftAuthWindow) {
        ipcEvent.reply(MSFT_OPCODE.REPLY_LOGIN, MSFT_REPLY_TYPE.ERROR, MSFT_ERROR.ALREADY_OPEN, msftAuthViewOnClose)
        return
    }

    msftAuthSuccess = false
    msftAuthViewSuccess = viewSuccess
    msftAuthViewOnClose = viewOnClose
    msftAuthWindow = new BrowserWindow({
        title: LangLoader.queryJS('index.microsoftLoginTitle'),
        backgroundColor: '#222222',
        width: 520,
        height: 600,
        frame: true,
        icon: getPlatformIcon('SealCircle')
    })
    msftAuthWindow.on('closed', () => {
        msftAuthWindow = undefined
    })
    msftAuthWindow.on('close', () => {
        if (!msftAuthSuccess) {
            ipcEvent.reply(MSFT_OPCODE.REPLY_LOGIN, MSFT_REPLY_TYPE.ERROR, MSFT_ERROR.NOT_FINISHED, msftAuthViewOnClose)
        }
    })
    msftAuthWindow.webContents.on('did-navigate', (_, uri) => {
        if (!uri.startsWith(REDIRECT_URI_PREFIX)) {
            return
        }
        const queryMap = {}
        new URL(uri).searchParams.forEach((value, key) => {
            queryMap[key] = value
        })
        ipcEvent.reply(MSFT_OPCODE.REPLY_LOGIN, MSFT_REPLY_TYPE.SUCCESS, queryMap, msftAuthViewSuccess)
        msftAuthSuccess = true
        msftAuthWindow.close()
        msftAuthWindow = null
    })
    msftAuthWindow.removeMenu()
    msftAuthWindow.loadURL(`https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?prompt=select_account&client_id=${AZURE_CLIENT_ID}&response_type=code&scope=XboxLive.signin%20offline_access&redirect_uri=https://login.microsoftonline.com/common/oauth2/nativeclient`)
}

function openMicrosoftLogout(ipcEvent, uuid, isLastAccount) {
    if (msftLogoutWindow) {
        ipcEvent.reply(MSFT_OPCODE.REPLY_LOGOUT, MSFT_REPLY_TYPE.ERROR, MSFT_ERROR.ALREADY_OPEN)
        return
    }

    msftLogoutSuccess = false
    msftLogoutSuccessSent = false
    msftLogoutWindow = new BrowserWindow({
        title: LangLoader.queryJS('index.microsoftLogoutTitle'),
        backgroundColor: '#222222',
        width: 520,
        height: 600,
        frame: true,
        icon: getPlatformIcon('SealCircle')
    })
    msftLogoutWindow.on('closed', () => {
        msftLogoutWindow = undefined
    })
    msftLogoutWindow.on('close', () => {
        if (!msftLogoutSuccess) {
            ipcEvent.reply(MSFT_OPCODE.REPLY_LOGOUT, MSFT_REPLY_TYPE.ERROR, MSFT_ERROR.NOT_FINISHED)
        } else if (!msftLogoutSuccessSent) {
            msftLogoutSuccessSent = true
            ipcEvent.reply(MSFT_OPCODE.REPLY_LOGOUT, MSFT_REPLY_TYPE.SUCCESS, uuid, isLastAccount)
        }
    })
    msftLogoutWindow.webContents.on('did-navigate', (_, uri) => {
        if (!uri.startsWith('https://login.microsoftonline.com/common/oauth2/v2.0/logoutsession')) {
            return
        }
        msftLogoutSuccess = true
        setTimeout(() => {
            if (!msftLogoutSuccessSent) {
                msftLogoutSuccessSent = true
                ipcEvent.reply(MSFT_OPCODE.REPLY_LOGOUT, MSFT_REPLY_TYPE.SUCCESS, uuid, isLastAccount)
            }
            if (msftLogoutWindow) {
                msftLogoutWindow.close()
                msftLogoutWindow = null
            }
        }, 5000)
    })
    msftLogoutWindow.removeMenu()
    msftLogoutWindow.loadURL('https://login.microsoftonline.com/common/oauth2/v2.0/logout')
}

ipcMain.on('autoUpdateAction', (event, action, data) => {
    switch (action) {
        case 'initAutoUpdater':
            initAutoUpdater(event, data)
            event.sender.send('autoUpdateNotification', 'ready')
            break
        case 'checkForUpdate':
            autoUpdater.checkForUpdates().catch((error) => event.sender.send('autoUpdateNotification', 'realerror', error))
            break
        case 'allowPrereleaseChange': {
            const prerelease = semver.prerelease(app.getVersion())
            autoUpdater.allowPrerelease = Boolean(data) || (prerelease != null && prerelease.length > 0)
            break
        }
        case 'installUpdateNow':
            autoUpdater.quitAndInstall()
            break
        default:
            break
    }
})
ipcMain.on('distributionIndexDone', (event, result) => {
    event.sender.send('distributionIndexDone', result)
})
ipcMain.handle(SHELL_OPCODE.TRASH_ITEM, async (_, itemPath) => shell.trashItem(itemPath))
ipcMain.on(MSFT_OPCODE.OPEN_LOGIN, openMicrosoftLogin)
ipcMain.on(MSFT_OPCODE.OPEN_LOGOUT, openMicrosoftLogout)

function createWindow() {
    const window = new BrowserWindow({
        width: 980,
        height: 552,
        frame: false,
        backgroundColor: '#171614',
        icon: getPlatformIcon('SealCircle'),
        webPreferences: {
            preload: path.join(__dirname, 'app', 'assets', 'js', 'preloader.js'),
            nodeIntegration: true,
            contextIsolation: false
        }
    })
    remoteMain.enable(window.webContents)
    ejse.data('lang', (str, placeHolders) => LangLoader.queryEJS(str, placeHolders))
    window.loadURL(pathToFileURL(path.join(__dirname, 'app', 'app.ejs')).toString())
    window.removeMenu()
    window.resizable = true
}

app.on('ready', createWindow)
