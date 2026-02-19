'use strict'

const express = require('express')
const router = express.Router()
const path = require('path')
const { createSSE } = require('../lib/sse')
const {
  searchModels,
  listModelFiles,
  downloadFile,
  cancelDownload,
  listLocalModels,
} = require('../lib/huggingface')
const { ROOT } = require('../lib/scriptRunner')

// Default directory where downloaded models are stored
const MODELS_DIR = process.env.MODELS_DIR || path.join(ROOT, 'models')

// Track active downloads: key = `modelId::filename`, value = EventEmitter
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
    const files = await listModelFiles(modelId, token)
    res.json({ modelId, files })
  } catch (err) {
    res.status(502).json({ error: `HuggingFace API error: ${err.message}` })
  }
})

// ---------------------------------------------------------------------------
// GET /api/models/:owner/:repo/download/:filename
// Download a model file with real-time SSE progress
// ---------------------------------------------------------------------------
router.get('/:owner/:repo/download/:filename', (req, res) => {
  const modelId = `${req.params.owner}/${req.params.repo}`
  const filename = req.params.filename
  const token = req.headers['x-hf-token'] || process.env.HF_TOKEN || undefined
  const downloadKey = `${modelId}::${filename}`

  if (activeDownloads.has(downloadKey)) {
    // Already downloading — send an error so the client knows
    const sse = createSSE(res)
    sse.send('error', { message: `Download already in progress for ${filename}` })
    sse.close()
    return
  }

  const sse = createSSE(res)
  sse.send('start', { modelId, filename, modelsDir: MODELS_DIR })

  const emitter = downloadFile(modelId, filename, MODELS_DIR, token)
  activeDownloads.set(downloadKey, emitter)

  emitter.on('progress', (data) => {
    sse.send('progress', data)
  })

  emitter.on('done', (data) => {
    activeDownloads.delete(downloadKey)
    sse.send('done', data)
    sse.close()
  })

  emitter.on('error', (data) => {
    activeDownloads.delete(downloadKey)
    sse.send('error', data)
    sse.close()
  })

  // If the client disconnects, cancel the download
  req.on('close', () => {
    activeDownloads.delete(downloadKey)
    cancelDownload(MODELS_DIR, filename)
  })
})

// ---------------------------------------------------------------------------
// DELETE /api/models/:owner/:repo/download/:filename
// Cancel an in-progress download (removes the .part file)
// ---------------------------------------------------------------------------
router.delete('/:owner/:repo/download/:filename', (req, res) => {
  const modelId = `${req.params.owner}/${req.params.repo}`
  const filename = req.params.filename
  const downloadKey = `${modelId}::${filename}`

  activeDownloads.delete(downloadKey)
  const removed = cancelDownload(MODELS_DIR, filename)
  res.json({ cancelled: removed, filename })
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
