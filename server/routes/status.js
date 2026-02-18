'use strict'

const express = require('express')
const router = express.Router()
const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')
const { ROOT } = require('../lib/scriptRunner')

const PID_DIR = path.join(ROOT, 'logs')

// Read all .pid files from the logs directory
function readPidFiles() {
  const pids = []
  if (!fs.existsSync(PID_DIR)) return pids

  const files = fs.readdirSync(PID_DIR).filter(f => f.endsWith('.pid'))
  for (const file of files) {
    const pidPath = path.join(PID_DIR, file)
    try {
      const pid = parseInt(fs.readFileSync(pidPath, 'utf8').trim(), 10)
      if (!isNaN(pid)) {
        pids.push({ pid, file })
      }
    } catch {
      // Skip unreadable files
    }
  }
  return pids
}

// Check if a PID is alive
function isProcessAlive(pid) {
  try {
    process.kill(pid, 0)
    return true
  } catch {
    return false
  }
}

// GET /api/status — check if llama-server is running
router.get('/', (req, res) => {
  const pidEntries = readPidFiles()
  const running = []

  for (const { pid, file } of pidEntries) {
    if (isProcessAlive(pid)) {
      // Try to get process command line
      let cmdline = ''
      try {
        cmdline = fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').replace(/\0/g, ' ').trim()
      } catch {
        cmdline = 'unknown'
      }
      running.push({ pid, file, cmdline, alive: true })
    }
  }

  // Also do a quick scan for any llama-server processes not tracked by PID files
  let untracked = []
  try {
    const output = execSync("pgrep -a llama-server 2>/dev/null || true", { encoding: 'utf8' })
    const trackedPids = new Set(running.map(r => r.pid))
    for (const line of output.split('\n').filter(Boolean)) {
      const parts = line.split(' ')
      const pid = parseInt(parts[0], 10)
      if (!isNaN(pid) && !trackedPids.has(pid)) {
        untracked.push({ pid, cmdline: parts.slice(1).join(' '), alive: true, untracked: true })
      }
    }
  } catch {
    // pgrep not available or no processes
  }

  const all = [...running, ...untracked]
  res.json({
    running: all.length > 0,
    processes: all,
    count: all.length,
  })
})

module.exports = router
