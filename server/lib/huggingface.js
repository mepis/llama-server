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

// Quant tags in rough quality order (used for sorting)
const QUANT_ORDER = [
  'Q8_0', 'Q6_K', 'Q5_K_M', 'Q5_K_S', 'Q5_0',
  'Q4_K_M', 'Q4_K_S', 'Q4_0',
  'Q3_K_L', 'Q3_K_M', 'Q3_K_S',
  'Q2_K', 'Q2_K_S',
  'IQ4_XS', 'IQ4_NL', 'IQ3_M', 'IQ3_S', 'IQ3_XS', 'IQ2_M', 'IQ2_S', 'IQ2_XS', 'IQ1_M', 'IQ1_S',
  'F16', 'BF16', 'F32',
]

/**
 * Group a flat list of GGUF file objects (from listModelFiles) into variants.
 *
 * Each variant represents one logical model file the user would want to
 * download — either a single .gguf file or a sharded set (e.g. model-00001-of-00004.gguf).
 *
 * Returns an array of:
 * {
 *   label:    string   — human-readable name, e.g. "Q4_K_M" or "F16 (4 shards)"
 *   quant:    string   — quantisation tag extracted from the filename, e.g. "Q4_K_M"
 *   files:    string[] — one or more filenames that make up this variant
 *   totalSize: number|null
 *   sharded:  boolean
 * }
 */
function groupGgufFiles(files) {
  // Only work with gguf files
  const gguf = files.filter(f => f.type === 'gguf')

  // Shard pattern: anything ending in -NNNNN-of-NNNNN.gguf
  const shardRe = /^(.+?)-(\d{5})-of-(\d{5})\.gguf$/i

  const shardGroups = {}   // stem → [file, ...]
  const singles     = []

  for (const f of gguf) {
    const name = f.path.split('/').pop()
    const m    = name.match(shardRe)
    if (m) {
      const stem = m[1]  // everything before -00001-of-00004
      if (!shardGroups[stem]) shardGroups[stem] = []
      shardGroups[stem].push(f)
    } else {
      singles.push(f)
    }
  }

  const variants = []

  // Sharded sets
  for (const [stem, shards] of Object.entries(shardGroups)) {
    shards.sort((a, b) => a.path.localeCompare(b.path))
    const quant = extractQuant(stem)
    const totalSize = shards.every(s => s.size != null)
      ? shards.reduce((s, f) => s + f.size, 0)
      : null
    variants.push({
      label:     quant ? `${quant} (${shards.length} shards)` : `${stem} (${shards.length} shards)`,
      quant:     quant || 'Unknown',
      files:     shards.map(s => s.path),
      totalSize,
      sharded:   true,
    })
  }

  // Single files
  for (const f of singles) {
    const name  = f.path.split('/').pop()
    const quant = extractQuant(name)
    variants.push({
      label:     quant || name.replace(/\.gguf$/i, ''),
      quant:     quant || 'Other',
      files:     [f.path],
      totalSize: f.size,
      sharded:   false,
    })
  }

  // Sort by quant quality order; unknowns go last
  variants.sort((a, b) => {
    const ai = QUANT_ORDER.indexOf(a.quant.toUpperCase())
    const bi = QUANT_ORDER.indexOf(b.quant.toUpperCase())
    const ar = ai === -1 ? 999 : ai
    const br = bi === -1 ? 999 : bi
    return ar - br
  })

  return variants
}

/**
 * Extract a quantisation tag from a filename or stem.
 * Returns e.g. "Q4_K_M", "IQ3_M", "F16", or null.
 */
function extractQuant(name) {
  // Order matters: try longer/more-specific patterns first
  const patterns = [
    /\b(IQ[1-4]_(?:XS|NL|[MSX]+))\b/i,
    /\b(Q[2-8]_K_[LMSX])\b/i,
    /\b(Q[2-8]_K)\b/i,
    /\b(Q[2-8]_[01])\b/i,
    /\b(BF16|F16|F32)\b/i,
  ]
  for (const re of patterns) {
    const m = name.match(re)
    if (m) return m[1].toUpperCase()
  }
  return null
}

module.exports = {
  searchModels,
  listModelFiles,
  groupGgufFiles,
  downloadFile,
  cancelDownload,
  listLocalModels,
}
