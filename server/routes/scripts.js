'use strict'

const express = require('express')
const router = express.Router()
const { runScript, getScriptMetadata } = require('../lib/scriptRunner')
const { createSSE } = require('../lib/sse')

// GET /api/scripts — list all available scripts
router.get('/', (req, res) => {
  const scripts = getScriptMetadata()
  res.json({ scripts })
})

// POST /api/scripts/:id/run — execute a script, stream output via SSE
// Body: { args: string[] }
router.post('/:id/run', (req, res) => {
  const { id } = req.params
  const body = req.body || {}
  const args = Array.isArray(body.args) ? body.args.filter(a => typeof a === 'string') : []

  const sse = createSSE(res)
  const child = runScript(id, args, sse)

  req.on('close', () => {
    try { if (child && !child.killed) child.kill('SIGTERM') } catch {}
  })
})

// GET /api/scripts/:id/run?arg=...&arg=... — SSE-compatible (EventSource is GET-only)
router.get('/:id/run', (req, res) => {
  const { id } = req.params
  // Collect repeated ?arg= query params as the argument list
  let args = req.query.arg || []
  if (!Array.isArray(args)) args = [args]

  const sse = createSSE(res)
  const child = runScript(id, args, sse)

  req.on('close', () => {
    try { if (child && !child.killed) child.kill('SIGTERM') } catch {}
  })
})

module.exports = router
