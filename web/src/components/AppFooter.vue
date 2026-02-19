<template>
  <footer class="bg-white border-t border-gray-100 mt-auto">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
        <!-- Brand -->
        <div class="md:col-span-2">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-8 h-8 rounded-lg bg-mint-500 flex items-center justify-center">
              <svg viewBox="0 0 24 24" fill="none" class="w-5 h-5 text-white" stroke="currentColor" stroke-width="2">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" stroke-linecap="round"/>
                <path d="M8 12l2 2 4-4" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <span class="font-semibold text-gray-900">Llama<span class="text-mint-500">.cpp</span> Suite</span>
          </div>
          <p class="text-sm text-gray-500 leading-relaxed max-w-xs">
            A comprehensive set of bash scripts for managing Llama.cpp across all hardware configurations.
          </p>
        </div>

        <!-- Links -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Navigation</h3>
          <ul class="space-y-2">
            <li v-for="link in nav" :key="link.to">
              <router-link :to="link.to" class="text-sm text-gray-600 hover:text-mint-600 transition-colors">
                {{ link.label }}
              </router-link>
            </li>
          </ul>
        </div>

        <!-- External -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Resources</h3>
          <ul class="space-y-2">
            <li v-for="link in external" :key="link.href">
              <a :href="link.href" target="_blank" rel="noopener" class="text-sm text-gray-600 hover:text-mint-600 transition-colors flex items-center gap-1">
                {{ link.label }}
                <svg class="w-3 h-3 opacity-50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" stroke-linecap="round"/>
                  <polyline points="15 3 21 3 21 9" stroke-linecap="round" stroke-linejoin="round"/>
                  <line x1="10" y1="14" x2="21" y2="3" stroke-linecap="round"/>
                </svg>
              </a>
            </li>
          </ul>
        </div>
      </div>

      <div class="mt-10 pt-6 border-t border-gray-100 flex flex-col sm:flex-row items-center justify-between gap-4">
        <p class="text-xs text-gray-400">
          Built for the Llama.cpp community. MIT License.
        </p>
        <div class="flex items-center gap-1 text-xs text-gray-400">
          <span>Powered by</span>
          <a href="https://github.com/ggml-org/llama.cpp" target="_blank" class="text-mint-600 hover:text-mint-700 font-medium">llama.cpp</a>
        </div>
      </div>
    </div>
  </footer>
</template>

<script setup>
const nav = [
  { to: '/', label: 'Scripts' },
  { to: '/hardware', label: 'Hardware' },
  { to: '/docs', label: 'Documentation' },
]

const external = [
  { href: 'https://github.com/ggml-org/llama.cpp', label: 'Llama.cpp GitHub' },
  { href: 'https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md', label: 'Build Docs' },
  { href: 'https://github.com/ggml-org/llama.cpp/tree/master/tools/server', label: 'Server API' },
  { href: 'https://huggingface.co/models?library=gguf', label: 'GGUF Models' },
]
</script>
