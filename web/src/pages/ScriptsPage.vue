<script setup>
import { ref, computed } from 'vue'
import ScriptCard from '../components/ScriptCard.vue'
import ScriptModal from '../components/ScriptModal.vue'
import { scripts } from '../data/scripts.js'

const selectedScript = ref(null)
const activeTag = ref('All')

const allTags = computed(() => {
  const tags = new Set(['All'])
  scripts.forEach(s => s.tags.forEach(t => tags.add(t)))
  return [...tags]
})

const filtered = computed(() => {
  if (activeTag.value === 'All') return scripts
  return scripts.filter(s => s.tags.includes(activeTag.value))
})
</script>

<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
    <!-- Header -->
    <div class="mb-12">
      <div class="inline-flex items-center gap-2 bg-mint-50 border border-mint-200 text-mint-700 text-xs font-semibold px-3 py-1.5 rounded-full mb-4">
        8 Scripts
      </div>
      <h1 class="text-4xl font-bold text-gray-900 mb-3">Management Scripts</h1>
      <p class="text-lg text-gray-500 max-w-2xl">
        Every script in the suite, with full parameter references and copy-ready examples.
      </p>
    </div>

    <!-- Tag filter -->
    <div class="flex flex-wrap gap-2 mb-10">
      <button
        v-for="tag in allTags"
        :key="tag"
        @click="activeTag = tag"
        class="px-4 py-1.5 rounded-full text-sm font-medium border transition-all"
        :class="activeTag === tag
          ? 'bg-mint-500 text-white border-mint-500'
          : 'bg-white text-gray-600 border-gray-200 hover:border-mint-300 hover:text-mint-600'"
      >
        {{ tag }}
      </button>
    </div>

    <!-- Grid -->
    <div class="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
      <ScriptCard
        v-for="script in filtered"
        :key="script.id"
        :script="script"
        @click="selectedScript = $event"
      />
    </div>

    <!-- Legend -->
    <div class="mt-16 p-6 bg-mint-50 rounded-2xl border border-mint-100">
      <h2 class="text-sm font-semibold text-mint-800 mb-4">Script File Locations</h2>
      <div class="grid sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <div v-for="s in scripts" :key="s.id" class="flex items-start gap-2">
          <div class="w-1.5 h-1.5 rounded-full bg-mint-400 mt-2 shrink-0"></div>
          <div>
            <p class="text-xs font-medium text-gray-700">{{ s.name }}</p>
            <p class="text-xs text-gray-400 font-mono">{{ s.file }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>

  <ScriptModal :script="selectedScript" @close="selectedScript = null" />
</template>
