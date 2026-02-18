<script setup>
import { ref, watch, nextTick, onBeforeUnmount } from 'vue'

const props = defineProps({
  // SSE event source URL to connect to (null = not running)
  url: { type: String, default: null },
  // Whether to auto-scroll to bottom
  autoScroll: { type: Boolean, default: true },
})

const emit = defineEmits(['done', 'error'])

const lines = ref([])
const exitCode = ref(null)
const running = ref(false)
const pid = ref(null)
const terminalRef = ref(null)
let eventSource = null

function scrollToBottom() {
  if (!props.autoScroll || !terminalRef.value) return
  nextTick(() => {
    terminalRef.value.scrollTop = terminalRef.value.scrollHeight
  })
}

function connect(url) {
  disconnect()
  lines.value = []
  exitCode.value = null
  running.value = true
  pid.value = null

  eventSource = new EventSource(url)

  eventSource.addEventListener('start', (e) => {
    const data = JSON.parse(e.data)
    lines.value.push({ type: 'meta', text: `Starting: ${data.script} ${data.args.join(' ')}` })
    scrollToBottom()
  })

  eventSource.addEventListener('pid', (e) => {
    const data = JSON.parse(e.data)
    pid.value = data.pid
    lines.value.push({ type: 'meta', text: `PID: ${data.pid}` })
    scrollToBottom()
  })

  eventSource.addEventListener('stdout', (e) => {
    const data = JSON.parse(e.data)
    lines.value.push({ type: 'stdout', text: data.line })
    scrollToBottom()
  })

  eventSource.addEventListener('stderr', (e) => {
    const data = JSON.parse(e.data)
    lines.value.push({ type: 'stderr', text: data.line })
    scrollToBottom()
  })

  eventSource.addEventListener('exit', (e) => {
    const data = JSON.parse(e.data)
    exitCode.value = data.code
    running.value = false
    lines.value.push({ type: 'exit', text: `Process exited with code ${data.code}` })
    scrollToBottom()
    eventSource.close()
    emit('done', data.code)
  })

  eventSource.addEventListener('error', (e) => {
    let msg = 'Connection error'
    try { msg = JSON.parse(e.data).message } catch {}
    lines.value.push({ type: 'error', text: msg })
    running.value = false
    scrollToBottom()
    eventSource.close()
    emit('error', msg)
  })

  eventSource.onerror = () => {
    // Prevent EventSource from auto-reconnecting — this is a one-shot script run
    if (running.value) {
      lines.value.push({ type: 'error', text: 'Connection lost' })
      scrollToBottom()
      disconnect()
      emit('error', 'Connection lost')
    }
  }
}

function disconnect() {
  if (eventSource) {
    eventSource.close()
    eventSource = null
  }
  running.value = false
}

function clear() {
  lines.value = []
  exitCode.value = null
  pid.value = null
}

watch(() => props.url, (url) => {
  if (url) connect(url)
  else disconnect()
})

onBeforeUnmount(disconnect)

defineExpose({ connect, disconnect, clear, lines, running, pid, exitCode })
</script>

<template>
  <div class="rounded-xl overflow-hidden border border-gray-200 shadow-sm">
    <!-- Terminal header bar -->
    <div class="bg-gray-800 px-4 py-2.5 flex items-center gap-2">
      <span class="w-3 h-3 rounded-full bg-red-500"></span>
      <span class="w-3 h-3 rounded-full bg-yellow-500"></span>
      <span class="w-3 h-3 rounded-full bg-green-500"></span>
      <span class="ml-3 text-gray-400 text-xs font-mono">terminal</span>
      <div class="ml-auto flex items-center gap-3">
        <span v-if="running" class="flex items-center gap-1.5 text-xs text-mint-400">
          <span class="inline-block w-2 h-2 rounded-full bg-mint-400 animate-pulse"></span>
          Running{{ pid ? ` (PID ${pid})` : '' }}
        </span>
        <span
          v-else-if="exitCode !== null"
          class="text-xs"
          :class="exitCode === 0 ? 'text-mint-400' : 'text-red-400'"
        >
          Exited {{ exitCode === 0 ? 'successfully' : `with code ${exitCode}` }}
        </span>
        <button
          v-if="lines.length > 0"
          @click="clear"
          class="text-gray-500 hover:text-gray-300 text-xs cursor-pointer transition-colors"
        >
          Clear
        </button>
      </div>
    </div>

    <!-- Output area -->
    <div
      ref="terminalRef"
      class="bg-gray-900 p-4 h-80 overflow-y-auto font-mono text-sm leading-relaxed"
    >
      <div v-if="lines.length === 0" class="text-gray-600 italic">
        Output will appear here...
      </div>
      <div
        v-for="(line, i) in lines"
        :key="i"
        class="whitespace-pre-wrap break-all"
        :class="{
          'text-gray-400 text-xs': line.type === 'meta',
          'text-gray-100': line.type === 'stdout',
          'text-yellow-400': line.type === 'stderr',
          'text-red-400': line.type === 'error',
          'text-mint-400 text-xs mt-1': line.type === 'exit',
        }"
      >{{ line.text }}</div>
    </div>
  </div>
</template>
