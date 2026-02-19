'use strict'

const https = require('https')
const http = require('http')
const path = require('path')
const { spawn } = require('child_process')
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
 * Locate the llama-cli binary.
 * Checks common install paths in priority order.
 */
function findLlamaCli() {
  const candidates = [
    path.join(process.env.HOME || '', '.local', 'llama-cpp', 'bin', 'llama-cli'),
    '/usr/local/bin/llama-cli',
    'llama-cli', // rely on PATH
  ]
  // Return the first absolute path that could plausibly exist; PATH fallback is always last
  for (const c of candidates) {
    if (!c.includes('/')) return c          // PATH lookup — always valid to try
    try {
      require('fs').accessSync(c)
      return c
    } catch { /* not found */ }
  }
  return 'llama-cli'
}

/**
 * Download a single GGUF file from HuggingFace using llama-cli --download-only.
 * Emits: 'progress' { downloaded, total, percent, line }
 *         'done'     { filename, destPath }
 *         'error'    { message }
 *
 * @param {string} modelId   - e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} filename  - e.g. "mistral-7b.Q4_K_M.gguf"
 * @param {string} destDir   - local directory to save the file
 * @param {string} [token]   - optional HF access token
 * @returns {{ emitter: EventEmitter, child: ChildProcess }}
 */
function downloadFile(modelId, filename, destDir, token) {
  const emitter = new EventEmitter()
  const llamaCli = findLlamaCli()

  // llama-cli uses --hf-repo and --hf-file for model selection,
  // and --model to specify the output path.
  const destPath = path.join(destDir, filename)

  const args = [
    '--hf-repo', modelId,
    '--hf-file', filename,
    '--model',   destPath,
    '--download-only',
    '--no-display-prompt',
  ]

  const env = { ...process.env }
  if (token) env.HF_TOKEN = token

  require('fs').mkdirSync(destDir, { recursive: true })

  const child = spawn(llamaCli, args, {
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  })

  // llama-cli writes download progress to stderr in the form:
  //   llama_model_loader: - type  f16:  ...
  //   or curl-style:  % Total   % Received ...
  // We forward every stderr line as a progress event and also try to
  // parse percentage numbers so the frontend progress bar stays live.
  const progressRe = /(\d+(?:\.\d+)?)\s*%/

  function parseLine(line) {
    const m = line.match(progressRe)
    const percent = m ? Math.min(100, Math.round(parseFloat(m[1]))) : null
    emitter.emit('progress', { line, percent })
  }

  let stdoutBuf = ''
  child.stdout.on('data', (chunk) => {
    stdoutBuf += chunk.toString()
    const lines = stdoutBuf.split('\n')
    stdoutBuf = lines.pop()            // keep incomplete last line
    for (const l of lines) if (l.trim()) parseLine(l)
  })

  let stderrBuf = ''
  child.stderr.on('data', (chunk) => {
    stderrBuf += chunk.toString()
    const lines = stderrBuf.split('\n')
    stderrBuf = lines.pop()
    for (const l of lines) if (l.trim()) parseLine(l)
  })

  child.on('close', (code) => {
    // Flush any remaining buffered output
    if (stdoutBuf.trim()) parseLine(stdoutBuf)
    if (stderrBuf.trim()) parseLine(stderrBuf)

    if (code === 0) {
      emitter.emit('done', { filename, destPath })
    } else if (code !== null) {
      // code === null means we killed it (cancel)
      emitter.emit('error', { message: `llama-cli exited with code ${code}` })
    }
  })

  child.on('error', (err) => {
    emitter.emit('error', {
      message: err.code === 'ENOENT'
        ? `llama-cli not found. Install llama.cpp first (run the Install script).`
        : err.message,
    })
  })

  return { emitter, child }
}

/**
 * Cancel an in-progress download by killing the llama-cli child process.
 * @param {ChildProcess} child - the process returned by downloadFile
 */
function cancelDownload(child) {
  if (!child) return false
  try {
    child.kill('SIGTERM')
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
  const fs = require('fs')
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
