<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import CodeBlock from './CodeBlock.vue'
import TerminalOutput from './TerminalOutput.vue'

const props = defineProps({
  script: { type: Object, default: null },
})
const emit = defineEmits(['close'])

// Tab state
const activeTab = ref('docs') // 'docs' | 'run'

// Run state
const terminalRef = ref(null)
const sseUrl = ref(null)
const customArgs = ref('')
const isRunning = ref(false)

function buildSseUrl() {
  const BASE = '/api'
  const args = customArgs.value.trim().split(/\s+/).filter(Boolean)
  const params = new URLSearchParams()
  args.forEach(a => params.append('arg', a))
  const qs = params.toString()
  return `${BASE}/scripts/${props.script.id}/run${qs ? '?' + qs : ''}`
}

function runScript() {
  if (isRunning.value) return
  isRunning.value = true
  activeTab.value = 'run'
  sseUrl.value = buildSseUrl()
}

function onDone(code) {
  isRunning.value = false
  sseUrl.value = null
}

function onError(msg) {
  isRunning.value = false
  sseUrl.value = null
}

function onKey(e) {
  if (e.key === 'Escape') emit('close')
}

onMounted(() => {
  document.addEventListener('keydown', onKey)
  document.body.style.overflow = 'hidden'
  activeTab.value = 'docs'
})

onUnmounted(() => {
  document.removeEventListener('keydown', onKey)
  document.body.style.overflow = ''
  sseUrl.value = null
})
</script>

<template>
  <teleport to="body">
    <transition name="modal">
      <div
        v-if="script"
        class="fixed inset-0 z-[100] flex items-end sm:items-center justify-center p-0 sm:p-4"
      >
        <!-- Overlay -->
        <div
          class="absolute inset-0 bg-gray-950/40 backdrop-blur-sm"
          @click="emit('close')"
        />

        <!-- Panel -->
        <div class="relative bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl w-full sm:max-w-2xl max-h-[90vh] overflow-y-auto">
          <!-- Header -->
          <div class="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between rounded-t-3xl sm:rounded-t-2xl z-10">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-lg flex items-center justify-center" :class="script.iconBg">
                <component :is="script.icon" class="w-4 h-4" :class="script.iconColor" />
              </div>
              <div>
                <h2 class="font-semibold text-gray-900 text-base">{{ script.name }}</h2>
                <p class="text-xs text-gray-400 font-mono">{{ script.file }}</p>
              </div>
            </div>
            <button
              @click="emit('close')"
              class="p-2 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-50 transition-all"
            >
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 6L6 18M6 6l12 12" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
          </div>

          <!-- Tabs -->
          <div class="flex border-b border-gray-100 px-6">
            <button
              @click="activeTab = 'docs'"
              class="py-3 px-1 mr-6 text-sm font-medium border-b-2 transition-colors"
              :class="activeTab === 'docs'
                ? 'border-mint-500 text-mint-600'
                : 'border-transparent text-gray-400 hover:text-gray-600'"
            >
              Documentation
            </button>
            <button
              @click="activeTab = 'run'"
              class="py-3 px-1 text-sm font-medium border-b-2 transition-colors"
              :class="activeTab === 'run'
                ? 'border-mint-500 text-mint-600'
                : 'border-transparent text-gray-400 hover:text-gray-600'"
            >
              Run Script
              <span
                v-if="isRunning"
                class="ml-1.5 inline-block w-1.5 h-1.5 rounded-full bg-mint-500 animate-pulse"
              ></span>
            </button>
          </div>

          <!-- Docs Tab -->
          <div v-if="activeTab === 'docs'" class="p-6 space-y-6">
            <!-- Description -->
            <p class="text-gray-600 leading-relaxed">{{ script.longDescription }}</p>

            <!-- Requires root badge -->
            <div class="flex items-center gap-2 flex-wrap">
              <span
                class="inline-flex items-center gap-1 text-xs font-medium px-2.5 py-1 rounded-full"
                :class="script.requiresRoot
                  ? 'bg-amber-50 text-amber-700 border border-amber-200'
                  : 'bg-mint-50 text-mint-700 border border-mint-200'"
              >
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path v-if="script.requiresRoot" d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke-linecap="round" stroke-linejoin="round"/>
                  <path v-else d="M20 7H4a2 2 0 00-2 2v10a2 2 0 002 2h16a2 2 0 002-2V9a2 2 0 00-2-2z" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                {{ script.requiresRoot ? 'Requires sudo' : 'No root needed' }}
              </span>
              <span
                v-for="tag in script.tags"
                :key="tag"
                class="text-xs font-medium px-2.5 py-1 rounded-full bg-gray-50 text-gray-500 border border-gray-100"
              >{{ tag }}</span>
            </div>

            <!-- Features -->
            <div v-if="script.features">
              <h3 class="text-sm font-semibold text-gray-700 mb-3">Features</h3>
              <ul class="space-y-2">
                <li
                  v-for="feat in script.features"
                  :key="feat"
                  class="flex items-start gap-2.5 text-sm text-gray-600"
                >
                  <svg class="w-4 h-4 text-mint-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                  {{ feat }}
                </li>
              </ul>
            </div>

            <!-- Usage -->
            <div v-if="script.usage">
              <h3 class="text-sm font-semibold text-gray-700 mb-3">Usage</h3>
              <CodeBlock :code="script.usage" lang="bash" />
            </div>

            <!-- Options -->
            <div v-if="script.options">
              <h3 class="text-sm font-semibold text-gray-700 mb-3">Key Options</h3>
              <div class="rounded-xl border border-gray-100 overflow-hidden">
                <div
                  v-for="(opt, i) in script.options"
                  :key="opt.flag"
                  class="flex flex-col sm:flex-row sm:items-start gap-1 sm:gap-4 px-4 py-3 text-sm"
                  :class="i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'"
                >
                  <code class="text-mint-700 font-mono text-xs bg-mint-50 px-2 py-0.5 rounded shrink-0">{{ opt.flag }}</code>
                  <span class="text-gray-600">{{ opt.desc }}</span>
                </div>
              </div>
            </div>

            <!-- Examples -->
            <div v-if="script.examples && script.examples.length">
              <h3 class="text-sm font-semibold text-gray-700 mb-3">Examples</h3>
              <div class="space-y-3">
                <div v-for="ex in script.examples" :key="ex.label">
                  <p class="text-xs text-gray-400 mb-1.5">{{ ex.label }}</p>
                  <CodeBlock :code="ex.code" lang="bash" />
                </div>
              </div>
            </div>

            <!-- Env vars -->
            <div v-if="script.env && script.env.length">
              <h3 class="text-sm font-semibold text-gray-700 mb-3">Environment Variables</h3>
              <div class="rounded-xl border border-gray-100 overflow-hidden">
                <div
                  v-for="(v, i) in script.env"
                  :key="v.name"
                  class="flex flex-col sm:flex-row sm:items-start gap-1 sm:gap-4 px-4 py-3 text-sm"
                  :class="i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'"
                >
                  <code class="text-gray-700 font-mono text-xs bg-gray-100 px-2 py-0.5 rounded shrink-0 whitespace-nowrap">{{ v.name }}</code>
                  <span class="text-gray-500 text-xs">default: <code class="text-mint-700">{{ v.default }}</code></span>
                  <span class="text-gray-600 sm:ml-auto">{{ v.desc }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Run Tab -->
          <div v-else-if="activeTab === 'run'" class="p-6 space-y-4">
            <!-- Warning for root scripts -->
            <div
              v-if="script.requiresRoot"
              class="flex items-start gap-3 p-4 rounded-xl bg-amber-50 border border-amber-200 text-sm text-amber-700"
            >
              <svg class="w-4 h-4 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" stroke-linecap="round" stroke-linejoin="round"/>
                <line x1="12" y1="9" x2="12" y2="13" stroke-linecap="round"/>
                <line x1="12" y1="17" x2="12.01" y2="17" stroke-linecap="round"/>
              </svg>
              <span>This script requires root privileges. The server process must have sudo access for it to run successfully.</span>
            </div>

            <!-- Args input -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Arguments
                <span class="text-gray-400 font-normal ml-1">(optional, space-separated)</span>
              </label>
              <input
                v-model="customArgs"
                type="text"
                :placeholder="script.usage ? script.usage.split(' ').slice(1).join(' ') : '--help'"
                class="w-full px-4 py-2.5 rounded-xl border border-gray-200 font-mono text-sm text-gray-800 placeholder-gray-300 focus:outline-none focus:border-mint-400 focus:ring-2 focus:ring-mint-100 transition-all"
                :disabled="isRunning"
                @keydown.enter="runScript"
              />
            </div>

            <!-- Run button -->
            <button
              @click="runScript"
              :disabled="isRunning"
              class="w-full py-2.5 rounded-xl font-medium text-sm transition-all"
              :class="isRunning
                ? 'bg-gray-100 text-gray-400 cursor-not-allowed'
                : 'bg-mint-500 hover:bg-mint-600 text-white shadow-sm hover:shadow-md'"
            >
              <span v-if="isRunning" class="flex items-center justify-center gap-2">
                <span class="inline-block w-3 h-3 border-2 border-gray-300 border-t-gray-500 rounded-full animate-spin"></span>
                Running...
              </span>
              <span v-else>Run {{ script.name }}</span>
            </button>

            <!-- Terminal output -->
            <TerminalOutput
              ref="terminalRef"
              :url="sseUrl"
              @done="onDone"
              @error="onError"
            />
          </div>
        </div>
      </div>
    </transition>
  </teleport>
</template>

<style scoped>
.modal-enter-active, .modal-leave-active {
  transition: opacity 0.2s ease;
}
.modal-enter-from, .modal-leave-to {
  opacity: 0;
}
.modal-enter-active .relative,
.modal-leave-active .relative {
  transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.modal-enter-from .relative {
  transform: translateY(20px);
}
.modal-leave-to .relative {
  transform: translateY(20px);
}
</style>
