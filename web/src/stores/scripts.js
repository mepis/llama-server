import { defineStore } from 'pinia'
import { ref } from 'vue'
import { scripts } from '../data/scripts.js'

export const useScriptsStore = defineStore('scripts', () => {
  const selected = ref(scripts[0])
  const sseUrl = ref(null)
  const isRunning = ref(false)
  const paramArgs = ref({ args: '', env: '' })

  function selectScript(script) {
    selected.value = script
    sseUrl.value = null
    isRunning.value = false
    paramArgs.value = { args: '', env: '' }
  }

  function runScript() {
    if (isRunning.value) return
    const combined = [paramArgs.value.env, paramArgs.value.args].filter(Boolean).join(' ').trim()
    const parts = combined.split(/\s+/).filter(Boolean)
    const qs = new URLSearchParams()
    parts.forEach(a => qs.append('arg', a))
    const qStr = qs.toString()
    isRunning.value = true
    sseUrl.value = `/api/scripts/${selected.value.id}/run${qStr ? '?' + qStr : ''}`
  }

  function onDone() {
    isRunning.value = false
    sseUrl.value = null
  }

  function onError() {
    isRunning.value = false
    sseUrl.value = null
  }

  return { selected, sseUrl, isRunning, paramArgs, selectScript, runScript, onDone, onError }
})
