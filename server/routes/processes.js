'use strict'

const express = require('express')
const router = express.Router()
const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')
const { ROOT } = require('../lib/scriptRunner')

const LOG_DIR = path.join(ROOT, 'logs')

// GET /api/processes — list all running llama-server processes
router.get('/', (req, res) => {
  const processes = []

  try {
    const output = execSync("ps aux 2>/dev/null | grep llama-server | grep -v grep || true", {
      encoding: 'utf8',
    })

    for (const line of output.split('\n').filter(Boolean)) {
      const parts = line.trim().split(/\s+/)
      // ps aux columns: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND...
      if (parts.length < 11) continue
      const pid = parseInt(parts[1], 10)
      if (isNaN(pid)) continue

      processes.push({
        pid,
        user: parts[0],
        cpu: parts[2],
        mem: parts[3],
        vsz: parts[4],
        rss: parts[5],
        stat: parts[7],
        start: parts[8],
        time: parts[9],
        command: parts.slice(10).join(' '),
      })
    }
  } catch {
    // ps failed or no processes
  }

  res.json({ processes, count: processes.length })
})

// DELETE /api/processes/:pid — kill a specific process
router.delete('/:pid', (req, res) => {
  const pid = parseInt(req.params.pid, 10)
  if (isNaN(pid) || pid <= 0) {
    return res.status(400).json({ error: 'Invalid PID' })
  }

  // Safety: only allow killing processes that look like llama-server
  let cmdline = ''
  try {
    cmdline = fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').replace(/\0/g, ' ')
  } catch {
    return res.status(404).json({ error: `Process ${pid} not found` })
  }

  if (!cmdline.includes('llama-server')) {
    return res.status(403).json({
      error: 'Refusing to kill non-llama process',
      cmdline,
    })
  }

  try {
    process.kill(pid, 'SIGTERM')

    // Remove any PID files referencing this process
    if (fs.existsSync(LOG_DIR)) {
      const pidFiles = fs.readdirSync(LOG_DIR).filter(f => f.endsWith('.pid'))
      for (const file of pidFiles) {
        const pidPath = path.join(LOG_DIR, file)
        try {
          const filePid = parseInt(fs.readFileSync(pidPath, 'utf8').trim(), 10)
          if (filePid === pid) fs.unlinkSync(pidPath)
        } catch {
          // Ignore
        }
      }
    }

    res.json({ success: true, pid, signal: 'SIGTERM' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router
