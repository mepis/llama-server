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

