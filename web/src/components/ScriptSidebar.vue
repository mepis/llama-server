<script setup>
import { ref, watch, onBeforeUnmount } from 'vue'
import CodeBlock from './CodeBlock.vue'
import TerminalOutput from './TerminalOutput.vue'
import { scripts } from '../data/scripts.js'

const selected = ref(scripts[0])
const activeTab = ref('docs')

// Run state
const sseUrl = ref(null)
const customArgs = ref('')
const isRunning = ref(false)

function select(script) {
  selected.value = script
  activeTab.value = 'docs'
  sseUrl.value = null
  isRunning.value = false
  customArgs.value = ''
}

function buildSseUrl() {
  const args = customArgs.value.trim().split(/\s+/).filter(Boolean)
  const params = new URLSearchParams()
  args.forEach(a => params.append('arg', a))
  const qs = params.toString()
  return `/api/scripts/${selected.value.id}/run${qs ? '?' + qs : ''}`
}

function runScript() {
  if (isRunning.value) return
  isRunning.value = true
  activeTab.value = 'run'
  sseUrl.value = buildSseUrl()
}

function onDone() {
  isRunning.value = false
  sseUrl.value = null
}

function onError() {
  isRunning.value = false
  sseUrl.value = null
}

onBeforeUnmount(() => {
  sseUrl.value = null
})
</script>

<template>
  <div class="flex h-[calc(100vh-4rem)] overflow-hidden">

    <!-- ── Left sidebar: script list ──────────────────────────────── -->
    <aside class="w-64 shrink-0 border-r border-gray-100 bg-white overflow-y-auto flex flex-col">
      <div class="px-4 pt-5 pb-3">
        <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Scripts</p>
      </div>

      <nav class="flex-1 px-2 pb-4 space-y-0.5">
        <button
          v-for="script in scripts"
          :key="script.id"
          @click="select(script)"
          class="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left transition-all group"
          :class="selected?.id === script.id
            ? 'bg-mint-50 text-mint-700'
            : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'"
        >
          <!-- Icon -->
          <div
            class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0 transition-colors"
            :class="selected?.id === script.id ? script.iconBg : 'bg-gray-100 group-hover:' + script.iconBg"
          >
            <component
              :is="script.icon"
              class="w-4 h-4 transition-colors"
              :class="selected?.id === script.id ? script.iconColor : 'text-gray-400'"
            />
          </div>

          <div class="min-w-0">
            <p class="text-sm font-medium truncate leading-tight">{{ script.name }}</p>
            <p class="text-xs text-gray-400 font-mono truncate mt-0.5">{{ script.file.split('/').pop() }}</p>
          </div>
        </button>
      </nav>
    </aside>

    <!-- ── Right detail panel ─────────────────────────────────────── -->
    <main class="flex-1 overflow-y-auto bg-white">
      <div v-if="selected" class="max-w-3xl mx-auto px-8 py-8">

        <!-- Header -->
        <div class="flex items-start gap-4 mb-6">
          <div class="w-12 h-12 rounded-xl flex items-center justify-center shrink-0" :class="selected.iconBg">
            <component :is="selected.icon" class="w-6 h-6" :class="selected.iconColor" />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-gray-900 leading-tight">{{ selected.name }}</h1>
            <p class="text-sm text-gray-400 font-mono mt-0.5">{{ selected.file }}</p>
          </div>
        </div>

        <!-- Tabs -->
        <div class="flex border-b border-gray-100 mb-6">
          <button
            @click="activeTab = 'docs'"
            class="py-2.5 px-1 mr-6 text-sm font-medium border-b-2 transition-colors"
            :class="activeTab === 'docs'
              ? 'border-mint-500 text-mint-600'
              : 'border-transparent text-gray-400 hover:text-gray-600'"
          >
            Documentation
          </button>
          <button
            @click="activeTab = 'run'"
            class="py-2.5 px-1 text-sm font-medium border-b-2 transition-colors"
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

        <!-- ── Docs tab ── -->
        <div v-if="activeTab === 'docs'" class="space-y-6">
          <p class="text-gray-600 leading-relaxed">{{ selected.longDescription }}</p>

          <!-- Badges -->
          <div class="flex items-center gap-2 flex-wrap">
            <span
              class="inline-flex items-center gap-1 text-xs font-medium px-2.5 py-1 rounded-full"
              :class="selected.requiresRoot
                ? 'bg-amber-50 text-amber-700 border border-amber-200'
                : 'bg-mint-50 text-mint-700 border border-mint-200'"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path v-if="selected.requiresRoot" d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke-linecap="round" stroke-linejoin="round"/>
                <path v-else d="M20 7H4a2 2 0 00-2 2v10a2 2 0 002 2h16a2 2 0 002-2V9a2 2 0 00-2-2z" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              {{ selected.requiresRoot ? 'Requires sudo' : 'No root needed' }}
            </span>
            <span
              v-for="tag in selected.tags"
              :key="tag"
              class="text-xs font-medium px-2.5 py-1 rounded-full bg-gray-50 text-gray-500 border border-gray-100"
            >{{ tag }}</span>
          </div>

          <!-- Features -->
          <div v-if="selected.features">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Features</h3>
            <ul class="space-y-2">
              <li
                v-for="feat in selected.features"
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
          <div v-if="selected.usage">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Usage</h3>
            <CodeBlock :code="selected.usage" lang="bash" />
          </div>

          <!-- Options -->
          <div v-if="selected.options">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Key Options</h3>
            <div class="rounded-xl border border-gray-100 overflow-hidden">
              <div
                v-for="(opt, i) in selected.options"
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
          <div v-if="selected.examples && selected.examples.length">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Examples</h3>
            <div class="space-y-3">
              <div v-for="ex in selected.examples" :key="ex.label">
                <p class="text-xs text-gray-400 mb-1.5">{{ ex.label }}</p>
                <CodeBlock :code="ex.code" lang="bash" />
              </div>
            </div>
          </div>

          <!-- Env vars -->
          <div v-if="selected.env && selected.env.length">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Environment Variables</h3>
            <div class="rounded-xl border border-gray-100 overflow-hidden">
              <div
                v-for="(v, i) in selected.env"
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

        <!-- ── Run tab ── -->
        <div v-else-if="activeTab === 'run'" class="space-y-4">
          <!-- Root warning -->
          <div
            v-if="selected.requiresRoot"
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
              :placeholder="selected.usage ? selected.usage.split(' ').slice(1).join(' ') : '--help'"
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
            <span v-else>Run {{ selected.name }}</span>
          </button>

          <!-- Terminal -->
          <TerminalOutput
            :url="sseUrl"
            @done="onDone"
            @error="onError"
          />
        </div>

      </div>
    </main>

  </div>
</template>
