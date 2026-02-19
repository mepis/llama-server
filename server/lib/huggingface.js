'use strict'

const https = require('https')
const http = require('http')
const fs = require('fs')
const path = require('path')
const { EventEmitter } = require('events')

const HF_API_BASE = 'https://huggingface.co'
const HF_API_MODELS = 'https://huggingface.co/api/models'

/**
 * Perform a simple HTTPS GET and resolve with parsed JSON.
 * @param {string} url
 * @param {object} headers
 * @returns {Promise<object>}
 */
function fetchJSON(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http
    const req = protocol.get(url, { headers }, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return fetchJSON(res.headers.location, headers).then(resolve).catch(reject)
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} for ${url}`))
      }
      let body = ''
      res.on('data', (chunk) => { body += chunk })
      res.on('end', () => {
        try { resolve(JSON.parse(body)) } catch (e) { reject(e) }
      })
    })
    req.on('error', reject)
    req.setTimeout(15000, () => { req.destroy(new Error('Request timed out')) })
  })
}

/**
 * Search HuggingFace for GGUF models.
 * @param {string} query - search term
 * @param {number} limit - max results (default 20)
 * @param {string} [token] - optional HF access token
 * @returns {Promise<Array>}
 */
async function searchModels(query, limit = 20, token) {
  const params = new URLSearchParams({
    search: query,
    filter: 'gguf',
    limit: String(limit),
    sort: 'downloads',
    direction: '-1',
  })
  const url = `${HF_API_MODELS}?${params}`
  const headers = token ? { Authorization: `Bearer ${token}` } : {}
  const results = await fetchJSON(url, headers)
  return results.map((m) => ({
    id: m.modelId || m.id,
    author: m.author,
    downloads: m.downloads,
    likes: m.likes,
    lastModified: m.lastModified,
    tags: m.tags || [],
    private: m.private || false,
  }))
}

/**
 * List files in a HuggingFace model repository.
 * @param {string} modelId  - e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} [token]
 * @returns {Promise<Array<{path, size, type}>>}
 */
async function listModelFiles(modelId, token) {
  const url = `${HF_API_BASE}/api/models/${modelId.split('/').map(encodeURIComponent).join('/')}`
  const headers = token ? { Authorization: `Bearer ${token}` } : {}
  const data = await fetchJSON(url, headers)
  const siblings = data.siblings || []
  return siblings.map((f) => ({
    path: f.rfilename,
    size: f.size || null,
    type: f.rfilename.endsWith('.gguf') ? 'gguf'
        : f.rfilename.endsWith('.json') ? 'config'
        : 'other',
  }))
}

/**
 * Download a single file from HuggingFace with progress events.
 * Emits: 'progress' { downloaded, total, percent }, 'done' { destPath }, 'error' { message }
 *
 * @param {string} modelId   - e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} filename  - e.g. "mistral-7b.Q4_K_M.gguf"
 * @param {string} destDir   - local directory to save the file
 * @param {string} [token]   - optional HF access token
 * @returns {EventEmitter}
 */
function downloadFile(modelId, filename, destDir, token) {
  const emitter = new EventEmitter()

  // Resolve URL — HF CDN redirect pattern
  const fileUrl = `${HF_API_BASE}/${modelId.split('/').map(encodeURIComponent).join('/')}/resolve/main/${encodeURIComponent(filename)}`

  const headers = { 'User-Agent': 'llama-server/1.0' }
  if (token) headers['Authorization'] = `Bearer ${token}`

  fs.mkdirSync(destDir, { recursive: true })
  const destPath = path.join(destDir, filename)
  const tmpPath = destPath + '.part'

  // Resume support: check if partial file exists
  let startByte = 0
  if (fs.existsSync(tmpPath)) {
    startByte = fs.statSync(tmpPath).size
    if (startByte > 0) headers['Range'] = `bytes=${startByte}-`
  }

  function doRequest(url, redirectCount = 0) {
    if (redirectCount > 10) {
      emitter.emit('error', { message: 'Too many redirects' })
      return
    }

    const protocol = url.startsWith('https') ? https : http
    const req = protocol.get(url, { headers }, (res) => {
      // Follow redirects
      if (res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 307 || res.statusCode === 308) {
        return doRequest(res.headers.location, redirectCount + 1)
      }

      if (res.statusCode !== 200 && res.statusCode !== 206) {
        emitter.emit('error', { message: `HTTP ${res.statusCode} downloading ${filename}` })
        return
      }

      const contentLength = parseInt(res.headers['content-length'] || '0', 10)
      const total = res.statusCode === 206
        ? startByte + contentLength
        : contentLength

      let downloaded = startByte
      emitter.emit('progress', { downloaded, total, percent: total ? Math.floor(downloaded / total * 100) : 0 })

      const writeFlag = startByte > 0 ? 'a' : 'w'
      const fileStream = fs.createWriteStream(tmpPath, { flags: writeFlag })

      res.on('data', (chunk) => {
        downloaded += chunk.length
        const percent = total ? Math.floor(downloaded / total * 100) : 0
        emitter.emit('progress', { downloaded, total, percent })
      })

      res.pipe(fileStream)

      fileStream.on('finish', () => {
        fs.renameSync(tmpPath, destPath)
        emitter.emit('done', { destPath, filename, size: downloaded })
      })

      fileStream.on('error', (err) => {
        emitter.emit('error', { message: err.message })
      })

      res.on('error', (err) => {
        emitter.emit('error', { message: err.message })
      })
    })

    req.on('error', (err) => {
      emitter.emit('error', { message: err.message })
    })
  }

  // Kick off asynchronously so caller can attach listeners first
  setImmediate(() => doRequest(fileUrl))

  return emitter
}

/**
 * Cancel an in-progress download by deleting the .part file.
 * @param {string} destDir
 * @param {string} filename
 */
function cancelDownload(destDir, filename) {
  const tmpPath = path.join(destDir, filename + '.part')
  try {
    if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath)
    return true
  } catch {
    return false
  }
}

/**
 * List already-downloaded model files in the models directory.
 * @param {string} modelsDir
 * @returns {Array<{filename, size, path}>}
 */
function listLocalModels(modelsDir) {
  if (!fs.existsSync(modelsDir)) return []
  return fs.readdirSync(modelsDir)
    .filter(f => f.endsWith('.gguf'))
    .map(f => {
      const full = path.join(modelsDir, f)
      const stat = fs.statSync(full)
      return { filename: f, size: stat.size, path: full, mtimeMs: stat.mtimeMs }
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
}

module.exports = {
  searchModels,
  listModelFiles,
  downloadFile,
  cancelDownload,
  listLocalModels,
}
