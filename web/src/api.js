/**
 * API client for the Express backend.
 * During development, Vite proxies /api → http://localhost:3000.
 * In production, the Express server serves everything at the same origin.
 */

const BASE = '/api'

async function get(path) {
  const res = await fetch(`${BASE}${path}`)
  if (!res.ok) throw new Error(`API error ${res.status}: ${await res.text()}`)
  return res.json()
}

async function del(path) {
  const res = await fetch(`${BASE}${path}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`API error ${res.status}: ${await res.text()}`)
  const text = await res.text()
  if (!text) return {}
  return JSON.parse(text)
}

/**
 * Get all available scripts metadata from the server.
 */
export function getScripts() {
  return get('/scripts')
}

/**
 * Get the llama-server process status.
 */
export function getStatus() {
  return get('/status')
}

/**
 * Get log file list.
 */
export function getLogs() {
  return get('/logs')
}

/**
 * Get contents of a specific log file.
 * @param {string} name - Log file name
 * @param {number} lines - Number of tail lines to return
 */
export function getLog(name, lines = 200) {
  return get(`/logs/${encodeURIComponent(name)}?lines=${lines}`)
}

/**
 * Get running llama-server processes.
 */
export function getProcesses() {
  return get('/processes')
}

/**
 * Kill a specific process by PID.
 * @param {number} pid
 */
export function killProcess(pid) {
  return del(`/processes/${pid}`)
}

/**
 * Get hardware information.
 */
export function getHardware() {
  return get('/hardware')
}

// ── HuggingFace / Models ────────────────────────────────────────────────────

/**
 * List locally downloaded .gguf model files.
 */
export function getLocalModels() {
  return get('/models')
}

/**
 * Search HuggingFace for GGUF models.
 * @param {string} query
 * @param {number} limit
 * @param {string} [hfToken]
 */
export function searchHFModels(query, limit = 20, hfToken) {
  const params = new URLSearchParams({ q: query, limit: String(limit) })
  const headers = hfToken ? { 'x-hf-token': hfToken } : {}
  return fetch(`${BASE}/models/search?${params}`, { headers }).then(async r => {
    if (!r.ok) throw new Error(`API error ${r.status}: ${await r.text()}`)
    return r.json()
  })
}

/**
 * List files in a HuggingFace model repository.
 * @param {string} modelId  e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} [hfToken]
 */
export function getHFModelFiles(modelId, hfToken) {
  const [owner, repo] = modelId.split('/')
  const headers = hfToken ? { 'x-hf-token': hfToken } : {}
  return fetch(`${BASE}/models/${owner}/${repo}/files`, { headers }).then(async r => {
    if (!r.ok) throw new Error(`API error ${r.status}: ${await r.text()}`)
    return r.json()
  })
}

/**
 * Build the SSE URL for streaming a model download.
 * @param {string} modelId  e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} filename e.g. "mistral-7b.Q4_K_M.gguf"
 */
export function modelDownloadUrl(modelId, filename) {
  const [owner, repo] = modelId.split('/')
  return `${BASE}/models/${owner}/${repo}/download/${encodeURIComponent(filename)}`
}

/**
 * Cancel an in-progress download.
 */
export function cancelModelDownload(modelId, filename) {
  const [owner, repo] = modelId.split('/')
  return del(`/models/${owner}/${repo}/download/${encodeURIComponent(filename)}`)
}
