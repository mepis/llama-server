'use strict'

const express = require('express')
const router = express.Router()
const fs = require('fs')
const path = require('path')
const os = require('os')

const INSTANCES_DIR = path.join(os.homedir(), '.local', 'llama-cpp', 'instances')

// GET /api/instances — list all server instances
router.get('/', (req, res) => {
  const instances = []

  try {
    if (!fs.existsSync(INSTANCES_DIR)) {
      return res.json({ instances: [], count: 0 })
    }

    const files = fs.readdirSync(INSTANCES_DIR)
    const jsonFiles = files.filter(f => f.endsWith('.json'))

    for (const file of jsonFiles) {
      try {
        const jsonPath = path.join(INSTANCES_DIR, file)
        const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'))

        // Check if process is still running
        let running = false
        try {
          process.kill(data.pid, 0) // Signal 0 just checks existence
          running = true
        } catch {
          running = false
        }

        instances.push({
          ...data,
          running,
          uptime: running ? getUptime(data.started_at) : null
        })

        // Clean up stale instances
        if (!running) {
          const pidFile = path.join(INSTANCES_DIR, `${data.name}.pid`)
          try {
            if (fs.existsSync(pidFile)) fs.unlinkSync(pidFile)
            fs.unlinkSync(jsonPath)
          } catch {
            // Ignore cleanup errors
          }
        }
      } catch {
        // Skip malformed JSON
      }
    }
  } catch (err) {
    return res.status(500).json({ error: err.message })
  }

  res.json({
    instances: instances.sort((a, b) => a.name.localeCompare(b.name)),
    count: instances.length
  })
})

// DELETE /api/instances/:name — stop a specific instance
router.delete('/:name', (req, res) => {
  const { name } = req.params

  try {
    const jsonPath = path.join(INSTANCES_DIR, `${name}.json`)
    const pidPath = path.join(INSTANCES_DIR, `${name}.pid`)

    if (!fs.existsSync(jsonPath)) {
      return res.status(404).json({ error: `Instance '${name}' not found` })
    }

    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'))
    const { pid } = data

    // Check if process exists and is llama-server
    let cmdline = ''
    try {
      cmdline = fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').replace(/\0/g, ' ')
    } catch {
      // Process doesn't exist, just clean up files
      if (fs.existsSync(pidPath)) fs.unlinkSync(pidPath)
      fs.unlinkSync(jsonPath)
      return res.json({ success: true, name, message: 'Process not running, cleaned up files' })
    }

    if (!cmdline.includes('llama-server')) {
      return res.status(403).json({
        error: 'Refusing to kill non-llama process',
        cmdline,
      })
    }

    // Kill the process
    try {
      process.kill(pid, 'SIGTERM')

      // Wait briefly for graceful shutdown
      setTimeout(() => {
        try {
          process.kill(pid, 0)
          // Still alive, force kill
          process.kill(pid, 'SIGKILL')
        } catch {
          // Already dead
        }
      }, 2000)
    } catch (err) {
      if (err.code !== 'ESRCH') {
        throw err
      }
    }

    // Clean up files
    if (fs.existsSync(pidPath)) fs.unlinkSync(pidPath)
    fs.unlinkSync(jsonPath)

    res.json({ success: true, name, pid, signal: 'SIGTERM' })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

function getUptime(startedAt) {
  try {
    const started = new Date(startedAt)
    const now = new Date()
    const uptimeMs = now - started

    const seconds = Math.floor(uptimeMs / 1000) % 60
    const minutes = Math.floor(uptimeMs / 60000) % 60
    const hours = Math.floor(uptimeMs / 3600000) % 24
    const days = Math.floor(uptimeMs / 86400000)

    if (days > 0) return `${days}d ${hours}h`
    if (hours > 0) return `${hours}h ${minutes}m`
    if (minutes > 0) return `${minutes}m ${seconds}s`
    return `${seconds}s`
  } catch {
    return null
  }
}

module.exports = router
