'use strict'

const express = require('express')
const router = express.Router()
const path = require('path')
const os = require('os')
const { createSSE } = require('../lib/sse')
const {
  searchModels,
  listModelFiles,
  groupGgufFiles,
  downloadFile,
  cancelDownload,
  listLocalModels,
} = require('../lib/huggingface')

// Default directory where downloaded models are stored
// Match the launch script's default: ~/.local/llama-cpp/models
const HOME = os.homedir()
const MODELS_DIR = process.env.MODELS_DIR || path.join(HOME, '.local', 'llama-cpp', 'models')

// Track active downloads: key = `modelId::filename`, value = ChildProcess
const activeDownloads = new Map()

// ---------------------------------------------------------------------------
// GET /api/models
// List locally downloaded .gguf model files
// ---------------------------------------------------------------------------
router.get('/', (req, res) => {
  try {
    const models = listLocalModels(MODELS_DIR)
    res.json({ models, modelsDir: MODELS_DIR })
  } catch (err) {
    res.status(500).json({ error: err.message })
  }
})

// ---------------------------------------------------------------------------
// GET /api/models/search?q=<query>&limit=<n>
// Search HuggingFace for GGUF models
// ---------------------------------------------------------------------------
router.get('/search', async (req, res) => {
  const query = (req.query.q || '').trim()
  const limit = Math.min(parseInt(req.query.limit || '20', 10), 100)
  const token = req.headers['x-hf-token'] || process.env.HF_TOKEN || undefined

  if (!query) {
    return res.status(400).json({ error: 'Query parameter "q" is required' })
  }

  try {
    const results = await searchModels(query, limit, token)
    res.json({ results, query, count: results.length })
  } catch (err) {
    res.status(502).json({ error: `HuggingFace API error: ${err.message}` })
  }
})

// ---------------------------------------------------------------------------
// GET /api/models/:owner/:repo/files
// List files available in a HuggingFace model repo
// ---------------------------------------------------------------------------
router.get('/:owner/:repo/files', async (req, res) => {
  const modelId = `${req.params.owner}/${req.params.repo}`
  const token = req.headers['x-hf-token'] || process.env.HF_TOKEN || undefined

  try {
    const files    = await listModelFiles(modelId, token)
    const variants = groupGgufFiles(files)
    res.json({ modelId, files, variants })
  } catch (err) {
    res.status(502).json({ error: `HuggingFace API error: ${err.message}` })
  }
})

// ---------------------------------------------------------------------------
// GET /api/models/:owner/:repo/download
// Download one or more files (variant) with real-time SSE progress.
// Query params:
//   file=<filename>  — repeat for each shard, or pass a single filename
//   label=<string>   — human-readable variant label (for SSE start event)
// ---------------------------------------------------------------------------
router.get('/:owner/:repo/download', (req, res) => {
  const modelId = `${req.params.owner}/${req.params.repo}`
  const token   = req.headers['x-hf-token'] || process.env.HF_TOKEN || undefined

  // Accept ?file=a.gguf&file=b.gguf  or  ?file=a.gguf
  let files = req.query.file
  if (!files) {
    res.status(400).json({ error: 'At least one ?file= param is required' })
    return
  }
  if (!Array.isArray(files)) files = [files]

  const label = req.query.label || files[0]
  const downloadKey = `${modelId}::${label}`

  if (activeDownloads.has(downloadKey)) {
    const sse = createSSE(res)
    sse.send('error', { message: `Download already in progress for ${label}` })
    sse.close()
    return
  }

  const sse = createSSE(res)
  sse.send('start', { modelId, label, files, total: files.length, modelsDir: MODELS_DIR })

  let cancelled = false
  let currentChild = null

  activeDownloads.set(downloadKey, {
    kill: () => { cancelled = true; if (currentChild) cancelDownload(currentChild) },
  })

  // Download files sequentially
  let idx = 0

  function downloadNext() {
    if (cancelled) return
    if (idx >= files.length) {
      activeDownloads.delete(downloadKey)
      sse.send('done', { label, files, modelsDir: MODELS_DIR })
      sse.close()
      return
    }

    const filename = files[idx]
    sse.send('file-start', { filename, fileIndex: idx, total: files.length })

    const { emitter, cancel } = downloadFile(modelId, filename, MODELS_DIR, token)
    currentChild = { cancel }

    emitter.on('progress', (data) => {
      sse.send('progress', { ...data, filename, fileIndex: idx, total: files.length })
    })

    emitter.on('done', () => {
      idx++
      downloadNext()
    })

    emitter.on('error', (data) => {
      activeDownloads.delete(downloadKey)
      sse.send('error', { ...data, filename })
      sse.close()
    })
  }

  downloadNext()

  // Client disconnect — cancel current child
  req.on('close', () => {
    cancelled = true
    const entry = activeDownloads.get(downloadKey)
    activeDownloads.delete(downloadKey)
    if (entry) entry.kill()
  })
})

// ---------------------------------------------------------------------------
// DELETE /api/models/:owner/:repo/download?label=<label>
// Cancel an in-progress variant download
// ---------------------------------------------------------------------------
router.delete('/:owner/:repo/download', (req, res) => {
  const modelId = `${req.params.owner}/${req.params.repo}`
  const label   = req.query.label
  if (!label) {
    return res.status(400).json({ error: 'label query param required' })
  }
  const downloadKey = `${modelId}::${label}`

  const entry = activeDownloads.get(downloadKey)
  activeDownloads.delete(downloadKey)
  if (entry && typeof entry.kill === 'function') {
    entry.kill()
    return res.json({ cancelled: true, label })
  }
  res.json({ cancelled: false, label })
})

// ---------------------------------------------------------------------------
// GET /api/models/downloads
// List currently active downloads
// ---------------------------------------------------------------------------
router.get('/downloads', (req, res) => {
  const downloads = Array.from(activeDownloads.keys()).map((key) => {
    const [modelId, filename] = key.split('::')
    return { modelId, filename }
  })
  res.json({ downloads })
})

module.exports = router
