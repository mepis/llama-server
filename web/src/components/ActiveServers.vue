<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const instances = ref([])
const loading = ref(true)
const error = ref(null)
let pollInterval = null

async function fetchInstances() {
  try {
    const res = await fetch('/api/instances')
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const data = await res.json()
    instances.value = data.instances
    error.value = null
  } catch (err) {
    error.value = err.message
    console.error('Failed to fetch instances:', err)
  } finally {
    loading.value = false
  }
}

async function stopInstance(name) {
  if (!confirm(`Stop server instance "${name}"?`)) return

  try {
    const res = await fetch(`/api/instances/${name}`, { method: 'DELETE' })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    await fetchInstances()
  } catch (err) {
    alert(`Failed to stop instance: ${err.message}`)
  }
}

onMounted(() => {
  fetchInstances()
  // Poll every 3 seconds
  pollInterval = setInterval(fetchInstances, 3000)
})

onUnmounted(() => {
  if (pollInterval) clearInterval(pollInterval)
})
</script>

<template>
  <div class="bg-white border border-gray-100 rounded-xl overflow-hidden">
    <div class="px-4 py-3 border-b border-gray-100 bg-gray-50/50 flex items-center justify-between">
      <h3 class="text-sm font-semibold text-gray-700">Active Servers</h3>
      <span class="text-xs text-gray-400">{{ instances.length }} running</span>
    </div>

    <div v-if="loading" class="px-4 py-8 text-center text-sm text-gray-400">
      <div class="inline-block w-4 h-4 border-2 border-gray-300 border-t-mint-500 rounded-full animate-spin"></div>
      <span class="ml-2">Loading...</span>
    </div>

    <div v-else-if="error" class="px-4 py-6 text-center">
      <p class="text-sm text-red-600">{{ error }}</p>
    </div>

    <div v-else-if="instances.length === 0" class="px-4 py-8 text-center">
      <svg class="w-12 h-12 mx-auto text-gray-300 mb-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <circle cx="12" cy="12" r="10"/>
        <line x1="12" y1="8" x2="12" y2="12"/>
        <line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
      <p class="text-sm text-gray-500">No servers running</p>
      <p class="text-xs text-gray-400 mt-1">Launch a server with --daemon to see it here</p>
    </div>

    <div v-else class="divide-y divide-gray-50">
      <div
        v-for="inst in instances"
        :key="inst.name"
        class="px-4 py-3 hover:bg-gray-50/50 transition-colors"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2 mb-1">
              <h4 class="text-sm font-medium text-gray-900 truncate">{{ inst.name }}</h4>
              <span
                v-if="inst.running"
                class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-green-50 text-green-700 border border-green-200"
              >
                <span class="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
                Running
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-gray-50 text-gray-500 border border-gray-200"
              >
                Stopped
              </span>
            </div>

            <div class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-gray-500 mt-2">
              <div class="flex items-center gap-1.5">
                <svg class="w-3 h-3 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
                  <line x1="8" y1="21" x2="16" y2="21"/>
                  <line x1="12" y1="17" x2="12" y2="21"/>
                </svg>
                <code class="font-mono">{{ inst.host }}:{{ inst.port }}</code>
              </div>

              <div class="flex items-center gap-1.5">
                <svg class="w-3 h-3 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="12" cy="12" r="10"/>
                  <polyline points="12 6 12 12 16 14"/>
                </svg>
                <span>{{ inst.uptime || 'N/A' }}</span>
              </div>

              <div class="flex items-center gap-1.5 col-span-2">
                <svg class="w-3 h-3 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M13 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V9z"/>
                  <polyline points="13 2 13 9 20 9"/>
                </svg>
                <span class="truncate" :title="inst.model">{{ inst.model }}</span>
              </div>

              <div class="flex items-center gap-1.5">
                <svg class="w-3 h-3 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="4" y="4" width="16" height="16" rx="2" ry="2"/>
                  <rect x="9" y="9" width="6" height="6"/>
                  <line x1="9" y1="1" x2="9" y2="4"/>
                  <line x1="15" y1="1" x2="15" y2="4"/>
                  <line x1="9" y1="20" x2="9" y2="23"/>
                  <line x1="15" y1="20" x2="15" y2="23"/>
                  <line x1="20" y1="9" x2="23" y2="9"/>
                  <line x1="20" y1="14" x2="23" y2="14"/>
                  <line x1="1" y1="9" x2="4" y2="9"/>
                  <line x1="1" y1="14" x2="4" y2="14"/>
                </svg>
                <span>{{ inst.ngl }} GPU layers</span>
              </div>

              <div class="flex items-center gap-1.5">
                <svg class="w-3 h-3 text-gray-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/>
                  <polyline points="7.5 4.21 12 6.81 16.5 4.21"/>
                  <polyline points="7.5 19.79 7.5 14.6 3 12"/>
                  <polyline points="21 12 16.5 14.6 16.5 19.79"/>
                  <polyline points="3.27 6.96 12 12.01 20.73 6.96"/>
                  <line x1="12" y1="22.08" x2="12" y2="12"/>
                </svg>
                <span>{{ inst.context }} context</span>
              </div>
            </div>
          </div>

          <button
            v-if="inst.running"
            @click="stopInstance(inst.name)"
            class="shrink-0 px-2.5 py-1.5 text-xs font-medium rounded-lg bg-red-50 hover:bg-red-100 text-red-600 border border-red-200 transition-colors"
            title="Stop server"
          >
            Stop
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
