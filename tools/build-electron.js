'use strict'

const { spawnSync } = require('child_process')
const path = require('path')

// electron-builder asks npm to inspect production dependencies through cmd.exe
// on Windows. Ensure that standard Windows executables remain discoverable when
// the build is launched from a portable Node runtime or CI shell with a trimmed
// PATH; otherwise electron-builder silently packages no runtime node_modules.
if(process.platform === 'win32') {
    const systemDirectory = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32')
    const existingPath = process.env.Path || process.env.PATH || ''
    const containsSystemDirectory = existingPath
        .split(path.delimiter)
        .some(entry => entry.toLowerCase() === systemDirectory.toLowerCase())

    if(!containsSystemDirectory) {
        process.env.Path = `${systemDirectory}${path.delimiter}${existingPath}`
        process.env.PATH = process.env.Path
    }
}

const executable = process.execPath
const builderCli = path.resolve(__dirname, '..', 'node_modules', 'electron-builder', 'out', 'cli', 'cli.js')
const builderArguments = ['build', ...process.argv.slice(2)]
const result = spawnSync(executable, [builderCli, ...builderArguments], {
    env: process.env,
    stdio: 'inherit'
})

if(result.error) {
    throw result.error
}

process.exitCode = result.status === null ? 1 : result.status
