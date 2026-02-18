<script setup>
import { ref } from 'vue'
import ScriptCard from '../components/ScriptCard.vue'
import ScriptModal from '../components/ScriptModal.vue'
import CodeBlock from '../components/CodeBlock.vue'
import { scripts } from '../data/scripts.js'

const selectedScript = ref(null)

const quickStart = `# 1. Clone the repository
git clone https://github.com/mepis/llama-server.git
cd llama-server

# 2. Detect your hardware
./scripts/detect-hardware.sh

# 3. Install Llama.cpp
sudo ./scripts/install/install-lamacpp.sh

# 4. Launch with a model
./scripts/launch/launch-lamacpp.sh --hf bartowski/Llama-3.2-3B-Instruct-GGUF`

const stats = [
  { value: '8', label: 'Management Scripts' },
  { value: '5+', label: 'Platforms Supported' },
  { value: '6', label: 'GPU Backends' },
  { value: '100%', label: 'Bash Native' },
]

const features = [
  {
    icon: 'cpu',
    title: 'Hardware-Aware',
    desc: 'Automatically detects your CPU, GPU, and memory to build and configure for maximum performance.',
  },
  {
    icon: 'download',
    title: 'HuggingFace Ready',
    desc: 'Download and run models directly from HuggingFace using the native -hf flag — no manual downloads.',
  },
  {
    icon: 'shield',
    title: 'Safe Upgrades',
    desc: 'Upgrade with confidence. Automatic backup and rollback means you can always recover.',
  },
  {
    icon: 'zap',
    title: 'GPU Acceleration',
    desc: 'Full support for CUDA, ROCm, Vulkan, Metal, and CUDA Unified Memory for large models.',
  },
  {
    icon: 'activity',
    title: 'Process Management',
    desc: 'Start, stop, restart, and monitor instances with full log management and health checks.',
  },
  {
    icon: 'trash',
    title: 'Complete Cleanup',
    desc: 'One command terminates all instances, resets GPU memory, and clears system caches.',
  },
]
</script>

<template>
  <div>
  <!-- Hero -->
  <section class="relative overflow-hidden bg-white">
    <!-- Background decoration -->
    <div class="absolute inset-0 pointer-events-none">
      <div class="absolute top-0 right-0 w-[600px] h-[600px] rounded-full bg-mint-50 blur-3xl opacity-60 translate-x-1/3 -translate-y-1/4"></div>
      <div class="absolute bottom-0 left-0 w-[400px] h-[400px] rounded-full bg-mint-100 blur-3xl opacity-40 -translate-x-1/3 translate-y-1/4"></div>
    </div>

    <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-16 sm:pt-28 sm:pb-24">
      <div class="max-w-3xl">
        <!-- Badge -->
        <div class="inline-flex items-center gap-2 bg-mint-50 border border-mint-200 text-mint-700 text-xs font-semibold px-3 py-1.5 rounded-full mb-8">
          <span class="w-1.5 h-1.5 rounded-full bg-mint-500 animate-pulse"></span>
          Bash Scripts · Llama.cpp Management Suite
        </div>

        <!-- Headline -->
        <h1 class="text-5xl sm:text-6xl font-bold text-gray-900 leading-tight tracking-tight mb-6">
          Run local LLMs
          <br />
          <span class="text-mint-500">on any hardware</span>
        </h1>
        <p class="text-xl text-gray-500 leading-relaxed mb-10 max-w-2xl">
          A complete set of bash scripts for installing, compiling, launching, and managing Llama.cpp — with hardware detection, multi-GPU support, and HuggingFace integration.
        </p>

        <!-- CTAs -->
        <div class="flex flex-wrap gap-4">
          <router-link
            to="/scripts"
            class="inline-flex items-center gap-2 bg-mint-500 hover:bg-mint-600 text-white font-semibold px-6 py-3 rounded-xl shadow-sm hover:shadow-md transition-all"
          >
            Browse Scripts
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M5 12h14M12 5l7 7-7 7" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </router-link>
          <a
            href="https://github.com/ggml-org/llama.cpp"
            target="_blank"
            rel="noopener"
            class="inline-flex items-center gap-2 bg-white border border-gray-200 text-gray-700 font-semibold px-6 py-3 rounded-xl hover:border-gray-300 hover:bg-gray-50 transition-all"
          >
            <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2A10 10 0 0 0 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2z"/>
            </svg>
            llama.cpp Docs
          </a>
        </div>
      </div>
    </div>
  </section>

  <!-- Stats bar -->
  <section class="border-y border-gray-100 bg-mint-50/50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-6">
        <div v-for="s in stats" :key="s.label" class="text-center">
          <p class="text-3xl font-bold text-mint-600">{{ s.value }}</p>
          <p class="text-sm text-gray-500 mt-0.5">{{ s.label }}</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Quick start -->
  <section class="py-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="grid lg:grid-cols-2 gap-12 items-start">
      <div>
        <h2 class="text-3xl font-bold text-gray-900 mb-4">Get started in minutes</h2>
        <p class="text-gray-500 leading-relaxed mb-8">
          Clone the repository, detect your hardware, and you're running a local LLM — no Docker, no Python virtualenvs, just bash.
        </p>
        <div class="space-y-4">
          <div v-for="(step, i) in ['Clone &amp; enter repo', 'Detect hardware', 'Install Llama.cpp', 'Download &amp; run a model']" :key="i" class="flex items-center gap-4">
            <div class="w-7 h-7 rounded-full bg-mint-100 text-mint-700 text-xs font-bold flex items-center justify-center shrink-0">
              {{ i + 1 }}
            </div>
            <span class="text-sm text-gray-600" v-html="step"></span>
          </div>
        </div>
      </div>
      <div>
        <CodeBlock :code="quickStart" lang="bash" />
      </div>
    </div>
  </section>

  <!-- Features grid -->
  <section class="py-20 bg-gray-50/50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="text-center mb-14">
        <h2 class="text-3xl font-bold text-gray-900 mb-3">Everything you need</h2>
        <p class="text-gray-500 max-w-xl mx-auto">From first install to production monitoring, the suite covers the full lifecycle.</p>
      </div>

      <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-for="f in features" :key="f.title" class="bg-white rounded-2xl p-6 border border-gray-100 hover:border-mint-200 hover:shadow-sm transition-all">
          <div class="w-10 h-10 bg-mint-50 rounded-xl flex items-center justify-center mb-4">
            <!-- cpu -->
            <svg v-if="f.icon === 'cpu'" class="w-5 h-5 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/>
              <line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/>
              <line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/>
              <line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/>
              <line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/>
            </svg>
            <!-- download -->
            <svg v-else-if="f.icon === 'download'" class="w-5 h-5 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" stroke-linecap="round" stroke-linejoin="round"/>
              <polyline points="7 10 12 15 17 10" stroke-linecap="round" stroke-linejoin="round"/>
              <line x1="12" y1="15" x2="12" y2="3" stroke-linecap="round"/>
            </svg>
            <!-- shield -->
            <svg v-else-if="f.icon === 'shield'" class="w-5 h-5 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            <!-- zap -->
            <svg v-else-if="f.icon === 'zap'" class="w-5 h-5 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            <!-- activity -->
            <svg v-else-if="f.icon === 'activity'" class="w-5 h-5 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            <!-- trash -->
            <svg v-else-if="f.icon === 'trash'" class="w-5 h-5 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="3 6 5 6 21 6" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h3 class="font-semibold text-gray-900 mb-2">{{ f.title }}</h3>
          <p class="text-sm text-gray-500 leading-relaxed">{{ f.desc }}</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Scripts preview -->
  <section class="py-20 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex items-end justify-between mb-10">
      <div>
        <h2 class="text-3xl font-bold text-gray-900 mb-2">All scripts</h2>
        <p class="text-gray-500">Click any card to explore parameters and examples.</p>
      </div>
      <router-link to="/scripts" class="text-sm font-medium text-mint-600 hover:text-mint-700 flex items-center gap-1">
        View all
        <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M5 12h14M12 5l7 7-7 7" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </router-link>
    </div>

    <div class="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <ScriptCard
        v-for="script in scripts.slice(0, 4)"
        :key="script.id"
        :script="script"
        @click="selectedScript = $event"
      />
    </div>
  </section>

  <ScriptModal :script="selectedScript" @close="selectedScript = null" />
  </div>
</template>
