<script setup>
import { ref } from 'vue'

const props = defineProps({
  code: { type: String, required: true },
  lang: { type: String, default: 'bash' },
})

const copied = ref(false)

async function copy() {
  try {
    await navigator.clipboard.writeText(props.code)
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  } catch {
    // Clipboard API unavailable (non-HTTPS or no focus)
  }
}
</script>

<template>
  <div class="relative group rounded-xl overflow-hidden border border-gray-100 bg-gray-950">
    <!-- Top bar -->
    <div class="flex items-center justify-between px-4 py-2.5 bg-gray-900 border-b border-gray-800">
      <div class="flex items-center gap-1.5">
        <div class="w-3 h-3 rounded-full bg-red-500/70"></div>
        <div class="w-3 h-3 rounded-full bg-yellow-500/70"></div>
        <div class="w-3 h-3 rounded-full bg-green-500/70"></div>
      </div>
      <span class="text-xs font-mono text-gray-500">{{ lang }}</span>
      <button
        @click="copy"
        class="flex items-center gap-1.5 text-xs text-gray-400 hover:text-mint-400 transition-colors px-2 py-1 rounded-md hover:bg-gray-800"
      >
        <svg v-if="!copied" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2" stroke-linecap="round" stroke-linejoin="round"/>
          <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        <svg v-else class="w-3.5 h-3.5 text-mint-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        {{ copied ? 'Copied!' : 'Copy' }}
      </button>
    </div>
    <!-- Code -->
    <pre class="p-4 overflow-x-auto text-sm font-mono leading-relaxed text-gray-300"><code>{{ code }}</code></pre>
  </div>
</template>
