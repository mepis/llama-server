'use strict'

const express = require('express')
const router = express.Router()
const fs = require('fs')
const path = require('path')
const { ROOT } = require('../lib/scriptRunner')

const LOG_DIR = path.join(ROOT, 'logs')

// GET /api/logs — list log files
router.get('/', (req, res) => {
  if (!fs.existsSync(LOG_DIR)) {
    return res.json({ logs: [] })
  }

  const files = fs.readdirSync(LOG_DIR)
    .filter(f => f.endsWith('.log') || f.endsWith('.md'))
    .map(f => {
      const stat = fs.statSync(path.join(LOG_DIR, f))
      return { name: f, size: stat.size, modified: stat.mtime }
    })
    .sort((a, b) => new Date(b.modified) - new Date(a.modified))

  res.json({ logs: files })
})

// GET /api/logs/:name — read a specific log file (last N lines)
router.get('/:name', (req, res) => {
  const { name } = req.params
  const lines = parseInt(req.query.lines, 10) || 200

  // Security: resolve and verify the path stays within LOG_DIR
  if (name.includes('..') || name.includes('/') || name.includes('\\')) {
    return res.status(400).json({ error: 'Invalid log name' })
  }

  const logPath = path.resolve(LOG_DIR, name)
  if (!logPath.startsWith(path.resolve(LOG_DIR) + path.sep)) {
    return res.status(400).json({ error: 'Invalid log name' })
  }

  if (!fs.existsSync(logPath)) {
    return res.status(404).json({ error: 'Log not found' })
  }

  try {
    // Use a streaming approach to read only the last N lines
    const { execSync } = require('child_process')
    const clampedLines = Math.min(Math.max(lines, 1), 10000)
    const output = execSync(`tail -n ${clampedLines} "${logPath}"`, {
      encoding: 'utf8',
      maxBuffer: 10 * 1024 * 1024,
    })
    const tail = output.split('\n')
    // Remove trailing empty line from tail output
    if (tail.length > 0 && tail[tail.length - 1] === '') tail.pop()
    res.json({ name, lines: tail, total: tail.length })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

module.exports = router
