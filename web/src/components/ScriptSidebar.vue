<script setup>
import { ref } from 'vue'
import { storeToRefs } from 'pinia'
import TerminalOutput from './TerminalOutput.vue'
import ScriptParamForm from './ScriptParamForm.vue'
import ActiveServers from './ActiveServers.vue'
import { scripts } from '../data/scripts.js'
import { useScriptsStore } from '../stores/scripts.js'

const store = useScriptsStore()
const { selected, sseUrl, isRunning } = storeToRefs(store)

// Ref to the ScriptParamForm component for calling reset()
const paramFormRef = ref(null)
</script>

<template>
  <div class="flex h-[calc(100vh-4rem)] overflow-hidden">

    <!-- ── Left sidebar: script list ──────────────────────────────── -->
    <aside class="w-64 shrink-0 border-r border-gray-100 bg-white overflow-y-auto flex flex-col">

      <div class="px-4 pt-4 pb-3">
        <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Scripts</p>
      </div>

      <nav class="flex-1 px-2 pb-2 space-y-0.5">
        <button
          v-for="script in scripts"
          :key="script.id"
          @click="store.selectScript(script)"
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
          <div class="flex-1">
            <h1 class="text-2xl font-bold text-gray-900 leading-tight">{{ selected.name }}</h1>
            <p class="text-sm text-gray-500 mt-1">{{ selected.description }}</p>
            <p class="text-xs text-gray-400 font-mono mt-1.5">{{ selected.file }}</p>
          </div>
        </div>

        <!-- Script execution -->
        <div class="space-y-4">
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

          <!-- Parameter form -->
          <div>
            <div class="flex items-center justify-between mb-3">
              <p class="text-sm font-semibold text-gray-700">Parameters</p>
              <button
                v-if="!isRunning"
                @click="paramFormRef?.reset()"
                class="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 transition-colors"
                title="Reset parameters to defaults"
              >
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polyline points="1 4 1 10 7 10" stroke-linecap="round" stroke-linejoin="round"/>
                  <path d="M3.51 15a9 9 0 102.13-9.36L1 10" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                Reset
              </button>
            </div>
            <ScriptParamForm
              ref="paramFormRef"
              :params="selected.params || []"
              :scriptId="selected.id"
              :disabled="isRunning"
              @update:args="store.paramArgs = $event"
            />
          </div>

          <!-- Run button -->
          <button
            @click="store.runScript()"
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

          <!-- Active servers list (only for launch script) -->
          <ActiveServers v-if="selected.id === 'launch'" class="mt-4" />

          <!-- Terminal -->
          <TerminalOutput
            :url="sseUrl"
            @done="store.onDone()"
            @error="store.onError()"
          />
        </div>

      </div>
    </main>

  </div>
</template>
