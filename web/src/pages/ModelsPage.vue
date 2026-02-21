<script setup>
import ModelDownloader from '../components/ModelDownloader.vue'
</script>

<template>
  <div class="flex h-[calc(100vh-4rem)] overflow-hidden">
    <!-- Sidebar -->
    <aside class="w-64 shrink-0 border-r border-gray-100 bg-white overflow-y-auto">
      <div class="px-2 pt-4 pb-3 space-y-1">
        <router-link
          to="/"
          class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-left transition-all text-gray-600 hover:bg-gray-50 hover:text-gray-900"
        >
          <div class="w-8 h-8 rounded-lg bg-mint-100 flex items-center justify-center shrink-0">
            <svg class="w-4 h-4 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
              <path d="M22 2L11 13" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="M22 2L15 22l-4-9-9-4 19-7z" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <div class="min-w-0">
            <p class="text-sm font-medium">Scripts</p>
            <p class="text-xs text-gray-400">Execute</p>
          </div>
        </router-link>

        <router-link
          to="/models"
          class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-left transition-all bg-violet-50 text-violet-700"
        >
          <div class="w-8 h-8 rounded-lg bg-violet-100 flex items-center justify-center shrink-0">
            <svg class="w-4 h-4 text-violet-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" stroke-linecap="round" stroke-linejoin="round"/>
              <polyline points="7 10 12 15 17 10" stroke-linecap="round" stroke-linejoin="round"/>
              <line x1="12" y1="15" x2="12" y2="3" stroke-linecap="round"/>
            </svg>
          </div>
          <div class="min-w-0">
            <p class="text-sm font-medium">Models</p>
            <p class="text-xs text-gray-400">Download</p>
          </div>
        </router-link>

        <router-link
          to="/docs"
          class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-left transition-all text-gray-600 hover:bg-gray-50 hover:text-gray-900"
        >
          <div class="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center shrink-0">
            <svg class="w-4 h-4 text-blue-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z" stroke-linecap="round" stroke-linejoin="round"/>
              <polyline points="14 2 14 8 20 8" stroke-linecap="round" stroke-linejoin="round"/>
              <line x1="16" y1="13" x2="8" y2="13" stroke-linecap="round"/>
              <line x1="16" y1="17" x2="8" y2="17" stroke-linecap="round"/>
              <polyline points="10 9 9 9 8 9" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <div class="min-w-0">
            <p class="text-sm font-medium">Docs</p>
            <p class="text-xs text-gray-400">Reference</p>
          </div>
        </router-link>
      </div>
    </aside>

    <!-- Main content -->
    <main class="flex-1 overflow-hidden">
      <ModelDownloader />
    </main>
  </div>
</template>
