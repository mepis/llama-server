import { defineStore } from 'pinia'
import { ref } from 'vue'
import {
  searchHFModels,
  getHFModelFiles,
  getLocalModels,
  modelDownloadUrl,
  cancelModelDownload,
} from '../api.js'

export const useModelsStore = defineStore('models', () => {
  // HF Token — persisted across sessions
  const hfToken = ref(localStorage.getItem('llama-hf-token') || '')

  function setHfToken(token) {
    hfToken.value = token
    if (token) localStorage.setItem('llama-hf-token', token)
    else localStorage.removeItem('llama-hf-token')
  }

  // ── Search ──────────────────────────────────────────────────────────────────
  const query = ref('')
  const searching = ref(false)
  const searchError = ref('')
  const results = ref([])

  async function doSearch() {
    const q = query.value.trim()
    if (!q) return
    searching.value = true
    searchError.value = ''
    results.value = []
    expandedModel.value = null
    variants.value = []
    try {
      const data = await searchHFModels(q, 20, hfToken.value || undefined)
      results.value = data.results || []
    } catch (e) {
      searchError.value = e.message
    }
    searching.value = false
  }

  // ── File / variant listing ──────────────────────────────────────────────────
  const expandedModel = ref(null)
  const variants = ref([])
  const loadingFiles = ref(false)
  const filesError = ref('')

  async function toggleVariants(modelId) {
    if (expandedModel.value === modelId) {
      expandedModel.value = null
      variants.value = []
      return
    }
    expandedModel.value = modelId
    variants.value = []
    filesError.value = ''
    loadingFiles.value = true
    try {
      const data = await getHFModelFiles(modelId, hfToken.value || undefined)
      variants.value = data.variants || []
    } catch (e) {
      filesError.value = e.message
    }
    loadingFiles.value = false
  }

  // ── Local models (shared with ScriptParamForm) ──────────────────────────────
  const localModels = ref([])
  const modelsDir = ref('')
  const loadingLocal = ref(false)

  async function refreshLocal() {
    loadingLocal.value = true
    try {
      const data = await getLocalModels()
      localModels.value = data.models || []
      modelsDir.value = data.modelsDir || ''
    } catch {
      /* non-fatal */
    }
    loadingLocal.value = false
  }

  // ── Downloads ───────────────────────────────────────────────────────────────
  // active downloads: key = `modelId::label`
  const downloads = ref({})

  function dlKey(modelId, label) {
    return `${modelId}::${label}`
  }

  function startDownload(modelId, variant) {
    const key = dlKey(modelId, variant.label)
    if (downloads.value[key]?.active) return

    downloads.value[key] = {
      active: true,
      percent: 0,
      downloaded: 0,
      total: 0,
      fileIndex: 0,
      fileTotal: variant.files.length,
      done: false,
      error: '',
    }

    const url = modelDownloadUrl(modelId, variant.files, variant.label)
    const es = new EventSource(url)

    es.addEventListener('progress', (e) => {
      const d = JSON.parse(e.data)
      downloads.value[key] = {
        ...downloads.value[key],
        percent: d.percent ?? downloads.value[key].percent,
        downloaded: d.downloaded ?? downloads.value[key].downloaded,
        total: d.total ?? downloads.value[key].total,
        fileIndex: d.fileIndex ?? downloads.value[key].fileIndex,
        active: true,
      }
    })

    es.addEventListener('file-start', (e) => {
      const d = JSON.parse(e.data)
      downloads.value[key] = {
        ...downloads.value[key],
        fileIndex: d.fileIndex,
        percent: 0,
        downloaded: 0,
        total: 0,
      }
    })

    es.addEventListener('done', () => {
      downloads.value[key] = {
        ...downloads.value[key],
        active: false,
        done: true,
        percent: 100,
      }
      es.close()
      refreshLocal()
    })

    es.addEventListener('error', (e) => {
      let msg = 'Download failed'
      try { msg = JSON.parse(e.data).message } catch {}
      downloads.value[key] = {
        ...downloads.value[key],
        active: false,
        error: msg,
      }
      es.close()
    })
  }

  async function doCancel(modelId, label) {
    const key = dlKey(modelId, label)
    try {
      await cancelModelDownload(modelId, label)
    } catch {}
    downloads.value[key] = {
      ...downloads.value[key],
      active: false,
      error: 'Cancelled',
    }
  }

  return {
    hfToken, setHfToken,
    query, searching, searchError, results, doSearch,
    expandedModel, variants, loadingFiles, filesError, toggleVariants,
    localModels, modelsDir, loadingLocal, refreshLocal,
    downloads, dlKey, startDownload, doCancel,
  }
})
