<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  searchHFModels,
  getHFModelFiles,
  getLocalModels,
  modelDownloadUrl,
  cancelModelDownload,
} from '../api.js'

// ── State ──────────────────────────────────────────────────────────────────

const hfToken     = ref('')
const query       = ref('')
const searching   = ref(false)
const searchError = ref('')
const results     = ref([])       // HF search results

const expandedModel  = ref(null)  // modelId whose files are shown
const modelFiles     = ref([])
const loadingFiles   = ref(false)
const filesError     = ref('')

const localModels    = ref([])
const loadingLocal   = ref(false)

// active downloads: Map<downloadKey, { progress, total, percent, done, error }>
const downloads      = ref({})

// ── Helpers ────────────────────────────────────────────────────────────────

function downloadKey(modelId, filename) { return `${modelId}::${filename}` }

function fmtBytes(bytes) {
  if (!bytes) return '?'
  if (bytes < 1024 ** 2) return (bytes / 1024).toFixed(1) + ' KB'
  if (bytes < 1024 ** 3) return (bytes / 1024 ** 2).toFixed(1) + ' MB'
  return (bytes / 1024 ** 3).toFixed(2) + ' GB'
}

// ── Local models ───────────────────────────────────────────────────────────

async function refreshLocal() {
  loadingLocal.value = true
  try {
    const data = await getLocalModels()
    localModels.value = data.models || []
  } catch { /* non-fatal */ }
  loadingLocal.value = false
}

onMounted(refreshLocal)

// ── Search ─────────────────────────────────────────────────────────────────

async function doSearch() {
  const q = query.value.trim()
  if (!q) return
  searching.value = true
  searchError.value = ''
  results.value = []
  expandedModel.value = null
  modelFiles.value = []
  try {
    const data = await searchHFModels(q, 20, hfToken.value || undefined)
    results.value = data.results || []
  } catch (e) {
    searchError.value = e.message
  }
  searching.value = false
}

// ── File listing ───────────────────────────────────────────────────────────

async function toggleFiles(modelId) {
  if (expandedModel.value === modelId) {
    expandedModel.value = null
    modelFiles.value = []
    return
  }
  expandedModel.value = modelId
  modelFiles.value = []
  filesError.value = ''
  loadingFiles.value = true
  try {
    const data = await getHFModelFiles(modelId, hfToken.value || undefined)
    modelFiles.value = (data.files || []).filter(f => f.type === 'gguf')
  } catch (e) {
    filesError.value = e.message
  }
  loadingFiles.value = false
}

// ── Download ───────────────────────────────────────────────────────────────

function startDownload(modelId, filename) {
  const key = downloadKey(modelId, filename)
  if (downloads.value[key]?.active) return

  downloads.value[key] = { active: true, percent: 0, downloaded: 0, total: 0, done: false, error: '' }

  const url = modelDownloadUrl(modelId, filename)
  const es = new EventSource(url)

  es.addEventListener('progress', e => {
    const d = JSON.parse(e.data)
    downloads.value[key] = { ...downloads.value[key], ...d, active: true }
  })

  es.addEventListener('done', e => {
    const d = JSON.parse(e.data)
    downloads.value[key] = { ...downloads.value[key], ...d, active: false, done: true, percent: 100 }
    es.close()
    refreshLocal()
  })

  es.addEventListener('error', e => {
    let msg = 'Download failed'
    try { msg = JSON.parse(e.data).message } catch {}
    downloads.value[key] = { ...downloads.value[key], active: false, error: msg }
    es.close()
  })
}

async function doCancel(modelId, filename) {
  const key = downloadKey(modelId, filename)
  try { await cancelModelDownload(modelId, filename) } catch {}
  downloads.value[key] = { ...downloads.value[key], active: false, error: 'Cancelled' }
}

// ── Computed ───────────────────────────────────────────────────────────────

const ggufFiles = computed(() => modelFiles.value.filter(f => f.type === 'gguf'))
</script>

<template>
  <div class="max-w-3xl mx-auto px-8 py-8 space-y-8">

    <!-- Header -->
    <div class="flex items-start gap-4">
      <div class="w-12 h-12 rounded-xl bg-violet-50 flex items-center justify-center shrink-0">
        <svg class="w-6 h-6 text-violet-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
          <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" stroke-linecap="round" stroke-linejoin="round"/>
          <polyline points="7 10 12 15 17 10" stroke-linecap="round" stroke-linejoin="round"/>
          <line x1="12" y1="15" x2="12" y2="3" stroke-linecap="round"/>
        </svg>
      </div>
      <div>
        <h1 class="text-2xl font-bold text-gray-900 leading-tight">Download Models</h1>
        <p class="text-sm text-gray-400 mt-0.5">Search HuggingFace and download GGUF models directly</p>
      </div>
    </div>

    <!-- HF Token (optional) -->
    <div>
      <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">
        HuggingFace Token
        <span class="normal-case font-normal text-gray-400 ml-1">(optional — required for gated models)</span>
      </label>
      <input
        v-model="hfToken"
        type="password"
        placeholder="hf_..."
        class="w-full px-4 py-2.5 rounded-xl border border-gray-200 font-mono text-sm text-gray-800 placeholder-gray-300 focus:outline-none focus:border-violet-400 focus:ring-2 focus:ring-violet-100 transition-all"
      />
    </div>

    <!-- Search bar -->
    <div>
      <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Search HuggingFace</label>
      <div class="flex gap-2">
        <input
          v-model="query"
          type="text"
          placeholder="e.g. Llama-3, Mistral, Gemma..."
          class="flex-1 px-4 py-2.5 rounded-xl border border-gray-200 text-sm text-gray-800 placeholder-gray-300 focus:outline-none focus:border-violet-400 focus:ring-2 focus:ring-violet-100 transition-all"
          @keydown.enter="doSearch"
        />
        <button
          @click="doSearch"
          :disabled="searching || !query.trim()"
          class="px-5 py-2.5 rounded-xl text-sm font-medium transition-all"
          :class="searching || !query.trim()
            ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
            : 'bg-violet-500 hover:bg-violet-600 text-white shadow-sm'"
        >
          <span v-if="searching" class="flex items-center gap-2">
            <span class="w-3 h-3 border-2 border-violet-300 border-t-white rounded-full animate-spin inline-block"></span>
            Searching
          </span>
          <span v-else>Search</span>
        </button>
      </div>
      <p v-if="searchError" class="mt-2 text-xs text-red-500">{{ searchError }}</p>
    </div>

    <!-- Search results -->
    <div v-if="results.length" class="space-y-2">
      <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Results ({{ results.length }})</p>

      <div
        v-for="model in results"
        :key="model.id"
        class="border border-gray-100 rounded-xl overflow-hidden"
      >
        <!-- Model row -->
        <button
          @click="toggleFiles(model.id)"
          class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-gray-50 transition-colors"
        >
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-gray-900 truncate">{{ model.id }}</p>
            <p class="text-xs text-gray-400 mt-0.5 flex items-center gap-3">
              <span v-if="model.downloads">⬇ {{ model.downloads.toLocaleString() }}</span>
              <span v-if="model.likes">♥ {{ model.likes.toLocaleString() }}</span>
              <span v-if="model.private" class="text-amber-500">private</span>
            </p>
          </div>
          <!-- Chevron -->
          <svg
            class="w-4 h-4 text-gray-400 shrink-0 transition-transform"
            :class="expandedModel === model.id ? 'rotate-180' : ''"
            viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
          >
            <polyline points="6 9 12 15 18 9" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </button>

        <!-- File list (expanded) -->
        <div v-if="expandedModel === model.id" class="border-t border-gray-100 bg-gray-50/50">
          <div v-if="loadingFiles" class="px-4 py-3 text-xs text-gray-400 flex items-center gap-2">
            <span class="w-3 h-3 border-2 border-gray-300 border-t-gray-500 rounded-full animate-spin inline-block"></span>
            Loading files...
          </div>
          <p v-else-if="filesError" class="px-4 py-3 text-xs text-red-500">{{ filesError }}</p>
          <p v-else-if="!ggufFiles.length" class="px-4 py-3 text-xs text-gray-400">No GGUF files found in this repository.</p>

          <div v-else class="divide-y divide-gray-100">
            <div
              v-for="file in ggufFiles"
              :key="file.path"
              class="px-4 py-3"
            >
              <div class="flex items-center gap-3">
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-mono text-gray-800 truncate">{{ file.path }}</p>
                  <p class="text-xs text-gray-400 mt-0.5">{{ fmtBytes(file.size) }}</p>
                </div>

                <!-- Per-file download state -->
                <template v-if="downloads[`${model.id}::${file.path}`]">
                  <template v-if="downloads[`${model.id}::${file.path}`].done">
                    <span class="text-xs text-mint-600 font-medium flex items-center gap-1">
                      <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                        <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
                      </svg>
                      Downloaded
                    </span>
                  </template>
                  <template v-else-if="downloads[`${model.id}::${file.path}`].error">
                    <span class="text-xs text-red-500">{{ downloads[`${model.id}::${file.path}`].error }}</span>
                    <button @click="startDownload(model.id, file.path)" class="text-xs text-violet-600 hover:underline ml-2">Retry</button>
                  </template>
                  <template v-else-if="downloads[`${model.id}::${file.path}`].active">
                    <div class="flex items-center gap-3">
                      <div class="w-32">
                        <div class="h-1.5 rounded-full bg-gray-200 overflow-hidden">
                          <div
                            class="h-full bg-violet-500 transition-all duration-300"
                            :style="{ width: downloads[`${model.id}::${file.path}`].percent + '%' }"
                          ></div>
                        </div>
                        <p class="text-xs text-gray-400 mt-0.5 text-right">
                          {{ fmtBytes(downloads[`${model.id}::${file.path}`].downloaded) }}
                          / {{ fmtBytes(downloads[`${model.id}::${file.path}`].total) }}
                        </p>
                      </div>
                      <button
                        @click="doCancel(model.id, file.path)"
                        class="text-xs text-red-400 hover:text-red-600 transition-colors"
                      >Cancel</button>
                    </div>
                  </template>
                </template>
                <template v-else>
                  <button
                    @click="startDownload(model.id, file.path)"
                    class="px-3 py-1.5 rounded-lg bg-violet-500 hover:bg-violet-600 text-white text-xs font-medium transition-colors"
                  >Download</button>
                </template>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Local models -->
    <div>
      <div class="flex items-center justify-between mb-3">
        <p class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Local Models</p>
        <button
          @click="refreshLocal"
          class="text-xs text-gray-400 hover:text-gray-600 transition-colors flex items-center gap-1"
        >
          <svg class="w-3 h-3" :class="loadingLocal ? 'animate-spin' : ''" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="23 4 23 10 17 10" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M20.49 15a9 9 0 11-2.12-9.36L23 10" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          Refresh
        </button>
      </div>

      <div v-if="!localModels.length" class="text-sm text-gray-400 italic">
        No models downloaded yet.
      </div>
      <div v-else class="rounded-xl border border-gray-100 overflow-hidden divide-y divide-gray-100">
        <div
          v-for="model in localModels"
          :key="model.filename"
          class="flex items-center gap-3 px-4 py-3"
        >
          <svg class="w-4 h-4 text-mint-500 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
            <path d="M13 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V9z" stroke-linecap="round" stroke-linejoin="round"/>
            <polyline points="13 2 13 9 20 9" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-mono text-gray-800 truncate">{{ model.filename }}</p>
            <p class="text-xs text-gray-400 mt-0.5">{{ fmtBytes(model.size) }}</p>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>
