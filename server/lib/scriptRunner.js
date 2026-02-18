'use strict'

const { spawn } = require('child_process')
const path = require('path')
const fs = require('fs')

const ROOT = path.join(__dirname, '..', '..')

// Track running child processes for cleanup on shutdown
const runningChildren = new Set()

// Map script IDs to their shell script paths
const SCRIPT_MAP = {
  'install': path.join(ROOT, 'scripts', 'install', 'install-lamacpp.sh'),
  'compile': path.join(ROOT, 'scripts', 'compile', 'compile-lamacpp.sh'),
  'launch': path.join(ROOT, 'scripts', 'launch', 'launch-lamacpp.sh'),
  'manage': path.join(ROOT, 'scripts', 'manage', 'manage-lamacpp.sh'),
  'terminate': path.join(ROOT, 'scripts', 'terminate', 'terminate-lamacpp.sh'),
  'upgrade': path.join(ROOT, 'scripts', 'upgrade', 'upgrade-lamacpp.sh'),
  'detect-hardware': path.join(ROOT, 'scripts', 'detect-hardware.sh'),
  'llama': path.join(ROOT, 'scripts', 'llama.sh'),
}

/**
 * Run a script and stream output via SSE helpers.
 * @param {string} scriptId - Key from SCRIPT_MAP
 * @param {string[]} args - CLI arguments to pass to the script
 * @param {object} sse - SSE helper from createSSE()
 * @param {object} options - spawn options override
 * @returns {ChildProcess}
 */
function runScript(scriptId, args, sse, options = {}) {
  const scriptPath = SCRIPT_MAP[scriptId]

  if (!scriptPath) {
    sse.send('error', { message: `Unknown script: ${scriptId}` })
    sse.close()
    return null
  }

  if (!fs.existsSync(scriptPath)) {
    sse.send('error', { message: `Script not found: ${scriptPath}` })
    sse.close()
    return null
  }

  sse.send('start', { script: scriptId, args, pid: null })

  const child = spawn('bash', [scriptPath, ...args], {
    cwd: ROOT,
    env: { ...process.env },
    stdio: ['ignore', 'pipe', 'pipe'],
    ...options,
  })

  runningChildren.add(child)

  // Send PID after spawn
  sse.send('pid', { pid: child.pid })

  child.stdout.on('data', (data) => {
    const lines = data.toString().split('\n').filter(Boolean)
    for (const line of lines) {
      sse.send('stdout', { line })
    }
  })

  child.stderr.on('data', (data) => {
    const lines = data.toString().split('\n').filter(Boolean)
    for (const line of lines) {
      sse.send('stderr', { line })
    }
  })

  child.on('close', (code) => {
    runningChildren.delete(child)
    sse.send('exit', { code })
    sse.close()
  })

  child.on('error', (err) => {
    runningChildren.delete(child)
    sse.send('error', { message: err.message })
    // Don't close here — 'close' event will still fire after 'error'
  })

  return child
}

/**
 * Get metadata about all available scripts.
 */
function getScriptMetadata() {
  return Object.entries(SCRIPT_MAP).map(([id, scriptPath]) => ({
    id,
    path: scriptPath,
    exists: fs.existsSync(scriptPath),
    name: path.basename(scriptPath),
  }))
}

/**
 * Kill all tracked child processes (for graceful shutdown).
 */
function shutdown() {
  for (const child of runningChildren) {
    try { child.kill('SIGTERM') } catch {}
  }
  runningChildren.clear()
}

module.exports = { runScript, getScriptMetadata, shutdown, SCRIPT_MAP, ROOT }
