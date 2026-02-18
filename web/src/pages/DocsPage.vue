<script setup>
import { ref } from 'vue'
import CodeBlock from '../components/CodeBlock.vue'

const sections = [
  { id: 'overview', label: 'Overview' },
  { id: 'quickstart', label: 'Quick Start' },
  { id: 'install', label: 'Installation' },
  { id: 'compile', label: 'Compilation' },
  { id: 'launch', label: 'Launch & Server' },
  { id: 'manage', label: 'Management' },
  { id: 'terminate', label: 'Terminate' },
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
    solution: 'Run the install script first: sudo ./scripts/install/install-lamacpp.sh',
    code: 'which llama-server\nls /opt/llama-cpp/bin/llama-server',
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
              { label: 'Install Llama.cpp', code: 'sudo ./scripts/install/install-lamacpp.sh' },
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

        <!-- Installation -->
        <section id="install">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Installation</h2>
          <p class="text-gray-600 mb-6">The installation script detects your platform and hardware, installs only the necessary dependencies, builds from source, and optionally creates a systemd service.</p>
          <CodeBlock code="# Standard install (requires sudo)
sudo ./scripts/install/install-lamacpp.sh

# Custom install directory
INSTALL_DIR=/usr/local/llama sudo ./scripts/install/install-lamacpp.sh

# Default installed paths:
# Binaries: /opt/llama-cpp/bin/
# Symlinks: /usr/local/bin/llama-server
# Config:   /opt/llama-cpp/config/default.yaml
# Models:   /opt/llama-cpp/models/
# Logs:     /opt/llama-cpp/logs/
# Service:  /etc/systemd/system/llama-server.service" lang="bash" />

          <div class="mt-6 grid sm:grid-cols-2 gap-4">
            <div v-for="plat in ['Ubuntu/Debian (apt)', 'Fedora/RHEL (dnf)', 'Arch/Manjaro (pacman)', 'macOS (Homebrew)']" :key="plat" class="flex items-center gap-2 text-sm bg-white border border-gray-100 rounded-lg px-4 py-3">
              <svg class="w-4 h-4 text-mint-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              <span class="text-gray-600">{{ plat }}</span>
            </div>
          </div>
        </section>

        <!-- Compilation -->
        <section id="compile">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Compilation</h2>
          <p class="text-gray-600 mb-6">For advanced control over backends and optimizations, use the interactive compile script. It presents a menu for selecting backends and asks about CUDA Unified Memory, CPU optimizations, BLAS vendor, and more.</p>
          <CodeBlock code="# Interactive compilation
./scripts/compile/compile-lamacpp.sh

# Backends you can choose from:
# [1] All backends (CUDA + ROCm + Vulkan + Metal)
# [2] CPU only
# [3] CUDA (Nvidia GPU)
# [4] ROCm (AMD GPU)
# [5] Vulkan (cross-platform)
# [6] Metal (Apple Silicon)
# [7] Custom CMake flags" lang="bash" />

          <div class="mt-6 bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-800">
            <strong>Tip:</strong> Enable CUDA Unified Memory during compilation with
            <code class="font-mono bg-amber-100 px-1 rounded">-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=ON</code> to run models larger than your VRAM, or enable it at runtime with <code class="font-mono bg-amber-100 px-1 rounded">--unified-memory</code>.
          </div>
        </section>

        <!-- Launch -->
        <section id="launch">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Launch & Server</h2>
          <p class="text-gray-600 mb-6">The launch script supports the full llama-server API with ergonomic defaults and background modes.</p>
          <div class="space-y-4">
            <div>
              <p class="text-xs text-gray-400 mb-2">Local model</p>
              <CodeBlock code="./scripts/launch/launch-lamacpp.sh \
  --model /opt/llama-cpp/models/model.Q4_K_M.gguf \
  --ngl 99 \
  --port 8080" lang="bash" />
            </div>
            <div>
              <p class="text-xs text-gray-400 mb-2">HuggingFace download</p>
              <CodeBlock code="./scripts/launch/launch-lamacpp.sh \
  --hf bartowski/Llama-3.2-3B-Instruct-GGUF \
  --port 8080" lang="bash" />
            </div>
            <div>
              <p class="text-xs text-gray-400 mb-2">Daemon mode with Unified Memory</p>
              <CodeBlock code="./scripts/launch/launch-lamacpp.sh \
  --model model.gguf \
  --ngl 99 \
  --unified-memory \
  --daemon" lang="bash" />
            </div>
            <div>
              <p class="text-xs text-gray-400 mb-2">Server API (once running)</p>
              <CodeBlock :code="serverApiExample" lang="bash" />
            </div>
          </div>
        </section>

        <!-- Management -->
        <section id="manage">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Management</h2>
          <CodeBlock code="# Check status
./scripts/manage/manage-lamacpp.sh status

# View logs
./scripts/manage/manage-lamacpp.sh logs

# Real-time monitoring
./scripts/manage/manage-lamacpp.sh monitor

# Stop server
./scripts/manage/manage-lamacpp.sh stop

# Restart
./scripts/manage/manage-lamacpp.sh restart

# List all processes
./scripts/manage/manage-lamacpp.sh list" lang="bash" />
        </section>

        <!-- Terminate -->
        <section id="terminate">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Terminate & Cleanup</h2>
          <p class="text-gray-600 mb-4">The terminate script kills all llama-server processes and frees GPU memory. Useful after testing or when you need to reclaim VRAM.</p>
          <CodeBlock code="# Full cleanup (requires sudo for GPU reset and cache clear)
sudo ./scripts/terminate/terminate-lamacpp.sh

# What it does:
# 1. SIGTERM to all llama-server PIDs
# 2. Wait 5 seconds for graceful shutdown
# 3. SIGKILL any remaining processes
# 4. nvidia-smi -r (reset Nvidia GPU memory)
# 5. rocm-smi (reset AMD GPU state)
# 6. echo 3 > /proc/sys/vm/drop_caches (Linux cache clear)
# 7. Remove /tmp/llama-server.pid
# 8. Clean old log files (>7 days)" lang="bash" />
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
