<script setup>
import { ref } from 'vue'
import CodeBlock from '../components/CodeBlock.vue'
import { scripts } from '../data/scripts.js'

const sections = [
  { id: 'overview', label: 'Overview' },
  { id: 'quickstart', label: 'Quick Start' },
  { id: 'hardware', label: 'Hardware' },
  { id: 'scripts', label: 'All Scripts' },
  { id: 'troubleshoot', label: 'Troubleshooting' },
]

const active = ref('overview')

function scrollTo(id) {
  active.value = id
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
}

const commonErrors = [
  {
    problem: 'llama-server binary not found',
    solution: 'Run the install script first: ./scripts/install/install-lamacpp.sh',
    code: 'which llama-server\nls ~/.local/llama-cpp/bin/llama-server',
  },
  {
    problem: 'Port 8080 already in use',
    solution: 'Kill the process or use a different port with --port',
    code: 'lsof -t -i:8080 | xargs kill -9\n# Or use different port:\n./scripts/launch/launch-lamacpp.sh --model model.gguf --port 8081',
  },
  {
    problem: 'GPU out of memory (CUDA OOM)',
    solution: 'Use fewer GPU layers, enable Unified Memory, or use a more quantized model',
    code: '# Reduce layers (try 20, 40, 60...)\n./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 20\n\n# Or enable Unified Memory\n./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --unified-memory',
  },
  {
    problem: 'cmake: not found / too old',
    solution: 'Install CMake 3.21+ from your package manager or Kitware\'s repo',
    code: 'sudo apt-get install cmake\ncmake --version',
  },
  {
    problem: 'nvidia-smi: command not found',
    solution: 'Install the Nvidia driver. The CUDA toolkit includes nvidia-smi.',
    code: 'sudo apt-get install nvidia-driver-535\n# Reboot after driver install',
  },
]

const serverApiExample = `# Health check
curl http://localhost:8080/health

# Chat completion
curl http://localhost:8080/v1/chat/completions \\
  -H "Content-Type: application/json" \\
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello!"}]}'`

const extDocs = [
  { title: 'Llama.cpp GitHub', href: 'https://github.com/ggml-org/llama.cpp', desc: 'Main repository and issue tracker' },
  { title: 'Build Documentation', href: 'https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md', desc: 'Official CMake build guide' },
  { title: 'Server API Reference', href: 'https://github.com/ggml-org/llama.cpp/tree/master/tools/server', desc: 'REST API endpoints for the server' },
  { title: 'Function Calling', href: 'https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md', desc: 'Tool/function calling support' },
  { title: 'Multimodal Models', href: 'https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md', desc: 'Vision and multimodal model support' },
  { title: 'BLIS Backend', href: 'https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/BLIS.md', desc: 'BLIS BLAS library integration' },
  { title: 'SYCL Backend', href: 'https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md', desc: 'Intel SYCL backend for oneAPI' },
  { title: 'GGUF Model Hub', href: 'https://huggingface.co/models?library=gguf', desc: 'HuggingFace GGUF model repository' },
]

const backends = [
  { name: 'Nvidia CUDA', cmake: '-DGGML_CUDA=ON', desc: 'Best-in-class GPU acceleration with Unified Memory support', color: 'bg-green-50 text-green-700 border-green-200' },
  { name: 'AMD ROCm', cmake: '-DGGML_HIP=ON', desc: 'AMD GPU acceleration via ROCm/HIP', color: 'bg-red-50 text-red-700 border-red-200' },
  { name: 'Vulkan', cmake: '-DGGML_VULKAN=ON', desc: 'Cross-platform GPU (Nvidia, AMD, Intel)', color: 'bg-purple-50 text-purple-700 border-purple-200' },
  { name: 'Apple Metal', cmake: '-DGGML_METAL=ON', desc: 'Apple Silicon GPU with unified memory', color: 'bg-gray-50 text-gray-700 border-gray-200' },
  { name: 'CPU (BLAS)', cmake: '-DGGML_BLAS=ON -DGGML_NATIVE=ON', desc: 'Optimized CPU via AVX2/AVX-512/NEON + OpenBLAS', color: 'bg-blue-50 text-blue-700 border-blue-200' },
  { name: 'Intel oneAPI', cmake: '-DGGML_BLAS_VENDOR=Intel10_64lp', desc: 'Intel GPU and CPU via oneAPI toolkit', color: 'bg-sky-50 text-sky-700 border-sky-200' },
]

const quantizations = [
  { q: 'Q8_0', vram: '~8 GB', quality: 'Highest', note: 'Near-lossless' },
  { q: 'Q6_K', vram: '~6 GB', quality: 'Very High', note: 'Recommended' },
  { q: 'Q5_K_M', vram: '~5 GB', quality: 'High', note: '' },
  { q: 'Q4_K_M', vram: '~4 GB', quality: 'Good', note: 'Best balance' },
  { q: 'Q3_K_M', vram: '~3 GB', quality: 'OK', note: '' },
  { q: 'Q2_K', vram: '~2 GB', quality: 'Low', note: 'Highly quantized' },
]
</script>

<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
    <!-- Header -->
    <div class="mb-12">
      <div class="inline-flex items-center gap-2 bg-mint-50 border border-mint-200 text-mint-700 text-xs font-semibold px-3 py-1.5 rounded-full mb-4">
        Documentation
      </div>
      <h1 class="text-4xl font-bold text-gray-900 mb-3">Docs & Reference</h1>
      <p class="text-lg text-gray-500 max-w-2xl">Usage guides, troubleshooting, and links to official documentation.</p>
    </div>

    <div class="grid lg:grid-cols-4 gap-8">
      <!-- Sidebar nav -->
      <div class="hidden lg:block">
        <nav class="sticky top-24 space-y-1">
          <a
            v-for="s in sections"
            :key="s.id"
            :href="`#${s.id}`"
            @click.prevent="scrollTo(s.id)"
            class="block px-3 py-2 text-sm rounded-lg transition-all"
            :class="active === s.id
              ? 'bg-mint-50 text-mint-700 font-medium'
              : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'"
          >
            {{ s.label }}
          </a>
        </nav>
      </div>

      <!-- Content -->
      <div class="lg:col-span-3 space-y-16">

        <!-- Overview -->
        <section id="overview">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Overview</h2>
          <p class="text-gray-600 leading-relaxed mb-4">
            The <strong>Llama.cpp Management Suite</strong> is a collection of bash scripts that handle the full lifecycle of running local LLMs via <a href="https://github.com/ggml-org/llama.cpp" class="text-mint-600 hover:underline">llama.cpp</a>:
          </p>
          <ul class="space-y-2 mb-6">
            <li v-for="item in ['Hardware detection (CPU, GPU, memory)', 'Platform-specific installation', 'Hardware-optimized compilation', 'Server launch with HuggingFace model download', 'Instance management (start/stop/monitor)', 'Full cleanup and GPU memory reset']" :key="item" class="flex items-start gap-2 text-sm text-gray-600">
              <svg class="w-4 h-4 text-mint-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              {{ item }}
            </li>
          </ul>
          <div class="bg-gray-50 rounded-xl p-5 border border-gray-100">
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Project Structure</h3>
            <CodeBlock code="llama-server/
├── scripts/
│   ├── llama.sh                  # Unified entry point
│   ├── detect-hardware.sh        # Hardware detection
│   ├── install/install-lamacpp.sh
│   ├── compile/compile-lamacpp.sh
│   ├── upgrade/upgrade-lamacpp.sh
│   ├── launch/launch-lamacpp.sh
│   ├── manage/manage-lamacpp.sh
│   └── terminate/terminate-lamacpp.sh
└── docs/
    ├── scripts.md                # Script reference
    ├── hardware.md               # Hardware guide
    └── troubleshooting.md        # Troubleshooting" lang="bash" />
          </div>
        </section>

        <!-- Quick Start -->
        <section id="quickstart">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Quick Start</h2>
          <div class="space-y-6">
            <div v-for="(step, i) in [
              { label: 'Clone the repository', code: 'git clone https://github.com/mepis/llama-server.git\ncd llama-server' },
              { label: 'Detect your hardware', code: './scripts/detect-hardware.sh' },
              { label: 'Install Llama.cpp', code: './scripts/install/install-lamacpp.sh' },
              { label: 'Run a model from HuggingFace', code: '# Downloads and runs automatically\n./scripts/launch/launch-lamacpp.sh \\\n  --hf bartowski/Llama-3.2-3B-Instruct-GGUF \\\n  --ngl 99' },
              { label: 'Or use the unified interface', code: './scripts/llama.sh' },
            ]" :key="step.label" class="flex gap-4">
              <div class="w-7 h-7 rounded-full bg-mint-100 text-mint-700 text-xs font-bold flex items-center justify-center shrink-0 mt-1">{{ i + 1 }}</div>
              <div class="flex-1">
                <p class="text-sm font-medium text-gray-700 mb-2">{{ step.label }}</p>
                <CodeBlock :code="step.code" lang="bash" />
              </div>
            </div>
          </div>
        </section>

        <!-- Hardware -->
        <section id="hardware">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">Hardware Support</h2>
          <p class="text-gray-600 mb-8">The installation script auto-detects your hardware and configures the optimal backend. All major GPU vendors are supported.</p>

          <!-- Backends -->
          <div class="space-y-3 mb-12">
            <div
              v-for="backend in backends"
              :key="backend.name"
              class="flex items-start gap-4 p-4 rounded-xl border transition-colors"
              :class="backend.color"
            >
              <div class="flex-1">
                <h3 class="font-semibold text-gray-900 mb-1">{{ backend.name }}</h3>
                <p class="text-sm text-gray-600 mb-2">{{ backend.desc }}</p>
                <code class="text-xs font-mono bg-white/50 px-2 py-1 rounded">{{ backend.cmake }}</code>
              </div>
            </div>
          </div>

          <!-- Quantization -->
          <div>
            <h3 class="text-xl font-bold text-gray-900 mb-3">Model Quantization</h3>
            <p class="text-gray-500 mb-6">VRAM requirements for a 7B parameter model. Scale proportionally for larger models.</p>

            <div class="rounded-xl border border-gray-100 overflow-hidden">
              <table class="w-full text-sm">
                <thead>
                  <tr class="bg-gray-50 border-b border-gray-100">
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase">Quant</th>
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase">VRAM (7B)</th>
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase">Quality</th>
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(row, i) in quantizations"
                    :key="row.q"
                    :class="i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'"
                  >
                    <td class="px-4 py-3">
                      <code class="font-mono font-medium text-mint-700 bg-mint-50 px-2 py-0.5 rounded text-xs">{{ row.q }}</code>
                    </td>
                    <td class="px-4 py-3 text-gray-700 font-medium">{{ row.vram }}</td>
                    <td class="px-4 py-3 text-gray-600">{{ row.quality }}</td>
                    <td class="px-4 py-3">
                      <span v-if="row.note" class="text-xs bg-mint-50 text-mint-700 px-2 py-0.5 rounded-full">{{ row.note }}</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Unified Memory callout -->
          <div class="mt-8 bg-gradient-to-br from-mint-50 to-white border border-mint-200 rounded-xl p-6">
            <div class="flex items-start gap-3">
              <div class="w-10 h-10 bg-mint-500 rounded-lg flex items-center justify-center shrink-0">
                <svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </div>
              <div class="flex-1">
                <h4 class="font-semibold text-gray-900 mb-2">CUDA Unified Memory</h4>
                <p class="text-sm text-gray-600 mb-3">
                  Run models larger than your GPU's VRAM using CUDA Unified Virtual Memory. The OS pages between GPU and CPU memory transparently.
                </p>
                <CodeBlock code="./scripts/launch/launch-lamacpp.sh --model large-model.gguf --ngl 99 --unified-memory" lang="bash" />
              </div>
            </div>
          </div>
        </section>

        <!-- All Scripts -->
        <section id="scripts">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">All Scripts Reference</h2>
          <p class="text-gray-600 mb-8">Complete documentation for all available scripts in the management suite.</p>

          <div class="space-y-12">
            <div
              v-for="script in scripts"
              :key="script.id"
              class="border border-gray-100 rounded-2xl overflow-hidden bg-white"
            >
              <!-- Script header -->
              <div class="px-6 py-5 border-b border-gray-100 flex items-start gap-4" :class="script.iconBg + '/10'">
                <div class="w-12 h-12 rounded-xl flex items-center justify-center shrink-0" :class="script.iconBg">
                  <component :is="script.icon" class="w-6 h-6" :class="script.iconColor" />
                </div>
                <div class="flex-1 min-w-0">
                  <h3 class="text-xl font-bold text-gray-900">{{ script.name }}</h3>
                  <p class="text-sm text-gray-500 font-mono mt-1">{{ script.file }}</p>
                  <p class="text-sm text-gray-600 mt-2">{{ script.description }}</p>
                </div>
              </div>

              <!-- Script body -->
              <div class="px-6 py-5 space-y-6">
                <!-- Long description -->
                <div>
                  <p class="text-sm text-gray-600 leading-relaxed">{{ script.longDescription }}</p>
                </div>

                <!-- Badges -->
                <div class="flex items-center gap-2 flex-wrap">
                  <span
                    class="inline-flex items-center gap-1 text-xs font-medium px-2.5 py-1 rounded-full"
                    :class="script.requiresRoot
                      ? 'bg-amber-50 text-amber-700 border border-amber-200'
                      : 'bg-mint-50 text-mint-700 border border-mint-200'"
                  >
                    {{ script.requiresRoot ? 'Requires sudo' : 'No root needed' }}
                  </span>
                  <span
                    v-for="tag in script.tags"
                    :key="tag"
                    class="text-xs font-medium px-2.5 py-1 rounded-full bg-gray-50 text-gray-500 border border-gray-100"
                  >{{ tag }}</span>
                </div>

                <!-- Features -->
                <div v-if="script.features && script.features.length">
                  <h4 class="text-sm font-semibold text-gray-700 mb-3">Features</h4>
                  <ul class="space-y-2">
                    <li
                      v-for="feat in script.features"
                      :key="feat"
                      class="flex items-start gap-2 text-sm text-gray-600"
                    >
                      <svg class="w-4 h-4 text-mint-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                        <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
                      </svg>
                      {{ feat }}
                    </li>
                  </ul>
                </div>

                <!-- Usage -->
                <div>
                  <h4 class="text-sm font-semibold text-gray-700 mb-3">Usage</h4>
                  <CodeBlock :code="script.usage" lang="bash" />
                </div>

                <!-- Examples -->
                <div v-if="script.examples && script.examples.length">
                  <h4 class="text-sm font-semibold text-gray-700 mb-3">Examples</h4>
                  <div class="space-y-3">
                    <div v-for="ex in script.examples" :key="ex.label">
                      <p class="text-xs text-gray-500 mb-1.5">{{ ex.label }}</p>
                      <CodeBlock :code="ex.code" lang="bash" />
                    </div>
                  </div>
                </div>

                <!-- Options (if available) -->
                <div v-if="script.options && script.options.length">
                  <h4 class="text-sm font-semibold text-gray-700 mb-3">Options</h4>
                  <div class="rounded-xl border border-gray-100 overflow-hidden">
                    <div
                      v-for="(opt, i) in script.options"
                      :key="opt.flag"
                      class="flex flex-col sm:flex-row sm:items-start gap-2 sm:gap-4 px-4 py-3 text-sm"
                      :class="i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'"
                    >
                      <code class="text-gray-700 font-mono text-xs bg-gray-100 px-2 py-1 rounded shrink-0">{{ opt.flag }}</code>
                      <span class="text-gray-600">{{ opt.desc }}</span>
                    </div>
                  </div>
                </div>

                <!-- Environment Variables -->
                <div v-if="script.env && script.env.length">
                  <h4 class="text-sm font-semibold text-gray-700 mb-3">Environment Variables</h4>
                  <div class="rounded-xl border border-gray-100 overflow-hidden">
                    <div
                      v-for="(v, i) in script.env"
                      :key="v.name"
                      class="flex flex-col sm:flex-row sm:items-start gap-1 sm:gap-4 px-4 py-3 text-sm"
                      :class="i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'"
                    >
                      <code class="text-gray-700 font-mono text-xs bg-gray-100 px-2 py-1 rounded shrink-0">{{ v.name }}</code>
                      <span class="text-gray-500 text-xs">default: <code class="text-mint-700">{{ v.default }}</code></span>
                      <span class="text-gray-600 sm:ml-auto">{{ v.desc }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- Troubleshooting -->
        <section id="troubleshoot">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">Troubleshooting</h2>
          <div class="space-y-6">
            <div
              v-for="err in commonErrors"
              :key="err.problem"
              class="border border-gray-100 rounded-xl overflow-hidden"
            >
              <div class="bg-red-50 border-b border-red-100 px-5 py-3">
                <p class="text-sm font-semibold text-red-700">{{ err.problem }}</p>
              </div>
              <div class="px-5 py-3 bg-white">
                <p class="text-sm text-gray-600 mb-3">{{ err.solution }}</p>
                <CodeBlock :code="err.code" lang="bash" />
              </div>
            </div>
          </div>
        </section>

        <!-- External docs -->
        <section id="external">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">External References</h2>
          <div class="grid sm:grid-cols-2 gap-4">
            <a
              v-for="doc in extDocs"
              :key="doc.href"
              :href="doc.href"
              target="_blank"
              rel="noopener"
              class="flex items-start gap-3 p-4 bg-white border border-gray-100 rounded-xl hover:border-mint-200 hover:shadow-sm transition-all group"
            >
              <div class="w-8 h-8 bg-mint-50 rounded-lg flex items-center justify-center shrink-0 group-hover:bg-mint-100 transition-colors">
                <svg class="w-4 h-4 text-mint-600" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6" stroke-linecap="round"/>
                  <polyline points="15 3 21 3 21 9" stroke-linecap="round" stroke-linejoin="round"/>
                  <line x1="10" y1="14" x2="21" y2="3" stroke-linecap="round"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-semibold text-gray-800 group-hover:text-mint-700 transition-colors">{{ doc.title }}</p>
                <p class="text-xs text-gray-400 mt-0.5">{{ doc.desc }}</p>
              </div>
            </a>
          </div>
        </section>

      </div>
    </div>
  </div>
</template>
