<script setup>
import { reactive, computed, watch, ref, onMounted } from 'vue'
import { getLocalModels } from '../api.js'

const props = defineProps({
  params: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
})

const emit = defineEmits(['update:args'])

// Local models for model-select dropdown
const localModels = ref([])
const loadingModels = ref(false)

async function fetchLocalModels() {
  loadingModels.value = true
  try {
    const data = await getLocalModels()
    localModels.value = data.models || []
  } catch (err) {
    console.error('Failed to fetch local models:', err)
    localModels.value = []
  }
  loadingModels.value = false
}

onMounted(() => {
  // Only fetch if we have a model-select param
  if (props.params.some(p => p.type === 'model-select')) {
    fetchLocalModels()
  }
})

// Reactive map of param id → current value
const values = reactive({})

// Initialise / reset when params list changes (new script selected)
watch(
  () => props.params,
  (params) => {
    // Clear old keys
    for (const key of Object.keys(values)) delete values[key]
    // Seed defaults
    for (const p of params) {
      if (p.type === 'flag') values[p.id] = false
      else if (p.type === 'select') values[p.id] = ''
      else values[p.id] = ''
    }
  },
  { immediate: true },
)

// Build the argv string that gets passed to the script
const builtArgs = computed(() => {
  const parts = []

  for (const p of props.params) {
    const val = values[p.id]

    if (p.envVar) continue // env vars are handled separately

    if (p.type === 'flag') {
      if (val) parts.push(p.id)
    } else if (p.positional) {
      if (val) parts.push(val)
    } else {
      if (val !== '' && val !== null && val !== undefined) {
        parts.push(p.id, val)
      }
    }
  }

  return parts.join(' ')
})

// Build env var prefix  (e.g. "INSTALL_DIR=/foo BUILD_DIR=/bar")
const builtEnv = computed(() => {
  const pairs = []
  for (const p of props.params) {
    if (!p.envVar) continue
    const val = values[p.id]
    if (val !== '' && val !== null && val !== undefined) {
      pairs.push(`${p.id}=${val}`)
    }
  }
  return pairs.join(' ')
})

// Combined string exposed to parent: "ENV=val script args"
watch([builtArgs, builtEnv], () => {
  emit('update:args', { args: builtArgs.value, env: builtEnv.value })
}, { immediate: true })
</script>

<template>
  <div v-if="params.length > 0" class="space-y-3">
    <div
      v-for="param in params"
      :key="param.id"
      class="grid grid-cols-[10rem_1fr] items-start gap-3"
    >
      <!-- Label + hint -->
      <div class="pt-2">
        <p class="text-sm font-medium text-gray-700 leading-tight">{{ param.label }}</p>
        <p class="text-xs text-gray-400 mt-0.5 leading-snug">{{ param.desc }}</p>
      </div>

      <!-- Input -->
      <div class="pt-1">
        <!-- Flag (checkbox toggle) -->
        <template v-if="param.type === 'flag'">
          <button
            type="button"
            :disabled="disabled"
            @click="values[param.id] = !values[param.id]"
            class="flex items-center gap-2 px-3 py-1.5 rounded-lg border text-sm font-medium transition-all"
            :class="values[param.id]
              ? 'bg-mint-500 border-mint-500 text-white'
              : 'bg-white border-gray-200 text-gray-500 hover:border-mint-300 hover:text-mint-600'"
          >
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <polyline v-if="values[param.id]" points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
              <circle v-else cx="12" cy="12" r="9" stroke-width="1.5"/>
            </svg>
            {{ values[param.id] ? 'Enabled' : 'Disabled' }}
          </button>
        </template>

        <!-- Select -->
        <template v-else-if="param.type === 'select'">
          <select
            v-model="values[param.id]"
            :disabled="disabled"
            class="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm text-gray-800 bg-white focus:outline-none focus:border-mint-400 focus:ring-2 focus:ring-mint-100 transition-all disabled:opacity-50"
          >
            <option value="">— none —</option>
            <option v-for="opt in param.options" :key="opt" :value="opt">{{ opt }}</option>
          </select>
        </template>

        <!-- Model Select (dropdown of downloaded models) -->
        <template v-else-if="param.type === 'model-select'">
          <div class="space-y-2">
            <select
              v-model="values[param.id]"
              :disabled="disabled || loadingModels"
              class="w-full px-3 py-2 rounded-xl border border-gray-200 text-sm text-gray-800 bg-white focus:outline-none focus:border-mint-400 focus:ring-2 focus:ring-mint-100 transition-all disabled:opacity-50"
            >
              <option value="">— select a model —</option>
              <option v-for="model in localModels" :key="model.filename" :value="model.path">
                {{ model.filename }}
              </option>
            </select>
            <div v-if="localModels.length === 0 && !loadingModels" class="flex items-start gap-2 px-3 py-2 rounded-lg bg-amber-50 border border-amber-100">
              <svg class="w-4 h-4 text-amber-500 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" stroke-linecap="round" stroke-linejoin="round"/>
                <line x1="12" y1="9" x2="12" y2="13" stroke-linecap="round"/>
                <circle cx="12" cy="17" r="0.5" fill="currentColor"/>
              </svg>
              <p class="text-xs text-amber-700 leading-relaxed">
                No models found. Download models using the "Download Models" section in the sidebar.
              </p>
            </div>
          </div>
        </template>

        <!-- Number -->
        <template v-else-if="param.type === 'number'">
          <input
            v-model="values[param.id]"
            type="number"
            :placeholder="param.placeholder || ''"
            :disabled="disabled"
            class="w-full px-3 py-2 rounded-xl border border-gray-200 font-mono text-sm text-gray-800 placeholder-gray-300 focus:outline-none focus:border-mint-400 focus:ring-2 focus:ring-mint-100 transition-all disabled:opacity-50"
          />
        </template>

        <!-- Text (default) -->
        <template v-else>
          <input
            v-model="values[param.id]"
            type="text"
            :placeholder="param.placeholder || ''"
            :disabled="disabled"
            class="w-full px-3 py-2 rounded-xl border border-gray-200 font-mono text-sm text-gray-800 placeholder-gray-300 focus:outline-none focus:border-mint-400 focus:ring-2 focus:ring-mint-100 transition-all disabled:opacity-50"
          />
        </template>
      </div>
    </div>
  </div>

  <p v-else class="text-sm text-gray-400 italic">
    This script takes no configurable parameters.
  </p>
</template>
