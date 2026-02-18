<script setup>
import CodeBlock from '../components/CodeBlock.vue'

const backends = [
  {
    id: 'cuda',
    name: 'Nvidia CUDA',
    shortName: 'CUDA',
    color: 'text-green-600',
    bg: 'bg-green-50',
    border: 'border-green-200',
    badge: 'bg-green-100 text-green-700',
    icon: 'N',
    iconBg: 'bg-green-500',
    desc: 'Best-in-class GPU acceleration with full CUDA support. Supports Unified Memory for running models larger than VRAM.',
    requirements: ['nvidia-smi in PATH', 'CUDA toolkit ≥ 11.x', 'Driver ≥ 520.0 for CUDA 12'],
    cmake: '-DGGML_CUDA=ON',
    umemory: true,
    notes: [
      'Use --ngl 99 to offload all layers to GPU',
      'Enable Unified Memory for models larger than VRAM',
      'CUDA is detected automatically by nvidia-smi',
    ],
    verifyCmd: 'nvidia-smi\nnvcc --version',
    launchExample: './scripts/launch/launch-lamacpp.sh \\\n  --model model.Q4_K_M.gguf \\\n  --ngl 99 \\\n  --unified-memory',
  },
  {
    id: 'rocm',
    name: 'AMD ROCm',
    shortName: 'ROCm',
    color: 'text-red-600',
    bg: 'bg-red-50',
    border: 'border-red-200',
    badge: 'bg-red-100 text-red-700',
    icon: 'A',
    iconBg: 'bg-red-500',
    desc: 'AMD GPU acceleration via the ROCm/HIP stack. Auto-detects GPU architecture for optimal compilation.',
    requirements: ['rocm-smi in PATH', 'hipconfig in PATH', 'ROCm ≥ 5.6'],
    cmake: '-DGGML_HIP=ON -DGPU_TARGETS=gfx1100',
    umemory: false,
    notes: [
      'GPU target (gfx****) is auto-detected from rocm-smi',
      'HIP compilers (HIPCXX, HIP_PATH) set automatically',
      'RX 5000 series and newer recommended',
    ],
    verifyCmd: 'rocm-smi\nhipconfig --version',
    launchExample: './scripts/launch/launch-lamacpp.sh \\\n  --model model.Q4_K_M.gguf \\\n  --ngl 99',
  },
  {
    id: 'vulkan',
    name: 'Vulkan',
    shortName: 'Vulkan',
    color: 'text-purple-600',
    bg: 'bg-purple-50',
    border: 'border-purple-200',
    badge: 'bg-purple-100 text-purple-700',
    icon: 'V',
    iconBg: 'bg-purple-500',
    desc: 'Cross-platform GPU support. Works with Nvidia, AMD, and Intel GPUs as an alternative to CUDA/ROCm.',
    requirements: ['vulkaninfo in PATH', 'Vulkan 1.2+ driver', 'glslang-tools / shaderc'],
    cmake: '-DGGML_VULKAN=ON',
    umemory: false,
    notes: [
      'More portable than CUDA/ROCm but generally slower',
      'Good option for AMD GPUs without ROCm drivers',
      'Intel Arc GPUs are well-supported via Vulkan',
    ],
    verifyCmd: 'vulkaninfo --summary',
    launchExample: './scripts/launch/launch-lamacpp.sh \\\n  --model model.Q4_K_M.gguf \\\n  --ngl 99',
  },
  {
    id: 'metal',
    name: 'Apple Metal',
    shortName: 'Metal',
    color: 'text-gray-600',
    bg: 'bg-gray-50',
    border: 'border-gray-200',
    badge: 'bg-gray-100 text-gray-700',
    icon: '',
    iconBg: 'bg-gray-700',
    desc: 'Apple Silicon GPU acceleration via Metal. Unified memory means the GPU can access all system RAM — no VRAM limits.',
    requirements: ['macOS 12.0+ (Monterey)', 'Apple M1/M2/M3 chip'],
    cmake: '-DGGML_METAL=ON',
    umemory: false,
    notes: [
      'Unified memory = GPU uses full system RAM (e.g. 64 GB)',
      'No separate VRAM limit — run very large models',
      'Automatically enabled when macOS + Apple Silicon detected',
    ],
    verifyCmd: 'sysctl -n machdep.cpu.brand_string',
    launchExample: './scripts/launch/launch-lamacpp.sh \\\n  --model model.Q4_K_M.gguf \\\n  --ngl 99',
  },
  {
    id: 'cpu',
    name: 'CPU (BLAS)',
    shortName: 'CPU',
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    border: 'border-blue-200',
    badge: 'bg-blue-100 text-blue-700',
    icon: 'C',
    iconBg: 'bg-blue-500',
    desc: 'Optimized CPU inference using AVX2, AVX-512, or ARM NEON. BLAS acceleration available via OpenBLAS, BLIS, or Intel MKL.',
    requirements: ['No special hardware', 'Optional: AVX2/AVX-512 CPU', 'Optional: BLIS or Intel oneMKL'],
    cmake: '-DGGML_BLAS=ON -DGGML_NATIVE=ON',
    umemory: false,
    notes: [
      'GGML_NATIVE=ON enables best available instruction set',
      'BLIS often outperforms OpenBLAS on AMD CPUs',
      'Intel oneMKL is best for Intel CPUs',
    ],
    verifyCmd: 'grep -m1 flags /proc/cpuinfo | grep -oE "avx2|avx512|fma"',
    launchExample: './scripts/launch/launch-lamacpp.sh \\\n  --model model.Q4_K_M.gguf \\\n  --no-gpu \\\n  --threads 16',
  },
  {
    id: 'intel',
    name: 'Intel oneAPI',
    shortName: 'Intel',
    color: 'text-sky-600',
    bg: 'bg-sky-50',
    border: 'border-sky-200',
    badge: 'bg-sky-100 text-sky-700',
    icon: 'I',
    iconBg: 'bg-sky-500',
    desc: 'Intel GPU and CPU acceleration via the oneAPI toolkit, including Intel MKL for matrix operations.',
    requirements: ['Intel oneAPI toolkit', 'icx and icpx compilers', 'Intel Arc GPU (optional)'],
    cmake: '-DGGML_BLAS_VENDOR=Intel10_64lp -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx',
    umemory: false,
    notes: [
      'icx/icpx compilers auto-detected from PATH',
      'Intel MKL provides excellent CPU performance',
      'SYCL backend requires additional setup',
    ],
    verifyCmd: 'source /opt/intel/oneapi/setvars.sh\nicx --version',
    launchExample: './scripts/launch/launch-lamacpp.sh \\\n  --model model.Q4_K_M.gguf \\\n  --ngl 99',
  },
]

const quantTable = [
  { q: 'Q8_0', vram: '~8 GB', quality: 'Highest', speed: 'Slowest', note: 'Near-lossless' },
  { q: 'Q6_K', vram: '~6 GB', quality: 'Very High', speed: 'Slow', note: 'Recommended for quality' },
  { q: 'Q5_K_M', vram: '~5 GB', quality: 'High', speed: 'Medium', note: '' },
  { q: 'Q4_K_M', vram: '~4 GB', quality: 'Good', speed: 'Fast', note: 'Best balance' },
  { q: 'Q3_K_M', vram: '~3 GB', quality: 'OK', speed: 'Faster', note: '' },
  { q: 'Q2_K', vram: '~2 GB', quality: 'Low', speed: 'Fastest', note: 'Highly quantized' },
]

const active = ref('cuda')
const currentBackend = computed(() => backends.find(b => b.id === active.value))

import { ref, computed } from 'vue'
</script>

<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
    <!-- Header -->
    <div class="mb-12">
      <div class="inline-flex items-center gap-2 bg-mint-50 border border-mint-200 text-mint-700 text-xs font-semibold px-3 py-1.5 rounded-full mb-4">
        6 Backends
      </div>
      <h1 class="text-4xl font-bold text-gray-900 mb-3">Hardware Support</h1>
      <p class="text-lg text-gray-500 max-w-2xl">
        The suite auto-detects your hardware and configures the best backend. Select a backend to explore configuration details.
      </p>
    </div>

    <!-- Backend selector + detail -->
    <div class="grid lg:grid-cols-3 gap-6 mb-16">
      <!-- Sidebar list -->
      <div class="space-y-2">
        <button
          v-for="b in backends"
          :key="b.id"
          @click="active = b.id"
          class="w-full text-left flex items-center gap-3 px-4 py-3 rounded-xl border transition-all"
          :class="active === b.id
            ? `border-mint-300 bg-mint-50`
            : 'border-transparent hover:bg-gray-50'"
        >
          <div class="w-8 h-8 rounded-lg text-white text-xs font-bold flex items-center justify-center shrink-0 text-sm" :class="b.iconBg">
            <svg v-if="b.id === 'metal'" viewBox="0 0 24 24" class="w-4 h-4 fill-current">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83"/>
            </svg>
            <span v-else>{{ b.icon }}</span>
          </div>
          <div>
            <p class="text-sm font-semibold" :class="active === b.id ? 'text-mint-700' : 'text-gray-700'">{{ b.name }}</p>
            <p class="text-xs text-gray-400">{{ b.cmake }}</p>
          </div>
        </button>
      </div>

      <!-- Detail panel -->
      <div v-if="currentBackend" class="lg:col-span-2 bg-white rounded-2xl border border-gray-100 p-6 space-y-6">
        <!-- Title -->
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl text-white font-bold flex items-center justify-center text-sm" :class="currentBackend.iconBg">
            <svg v-if="currentBackend.id === 'metal'" viewBox="0 0 24 24" class="w-5 h-5 fill-current">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83"/>
            </svg>
            <span v-else>{{ currentBackend.icon }}</span>
          </div>
          <div>
            <h2 class="font-semibold text-gray-900 text-lg">{{ currentBackend.name }}</h2>
            <span class="text-xs font-medium px-2 py-0.5 rounded-full" :class="currentBackend.badge">
              {{ currentBackend.id.toUpperCase() }} Backend
            </span>
          </div>
          <span v-if="currentBackend.umemory" class="ml-auto text-xs bg-mint-50 text-mint-700 border border-mint-200 px-2.5 py-1 rounded-full font-medium">
            Unified Memory
          </span>
        </div>

        <p class="text-gray-600 leading-relaxed">{{ currentBackend.desc }}</p>

        <!-- Requirements -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Requirements</h3>
          <ul class="space-y-1.5">
            <li v-for="r in currentBackend.requirements" :key="r" class="flex items-center gap-2 text-sm text-gray-600">
              <svg class="w-4 h-4 text-mint-500 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <polyline points="20 6 9 17 4 12" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
              {{ r }}
            </li>
          </ul>
        </div>

        <!-- CMake flag -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">CMake Flag</h3>
          <code class="text-sm font-mono bg-gray-900 text-mint-400 px-4 py-2.5 rounded-lg block">{{ currentBackend.cmake }}</code>
        </div>

        <!-- Verify -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Verify Installation</h3>
          <CodeBlock :code="currentBackend.verifyCmd" lang="bash" />
        </div>

        <!-- Launch example -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Launch Example</h3>
          <CodeBlock :code="currentBackend.launchExample" lang="bash" />
        </div>

        <!-- Notes -->
        <div>
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">Notes</h3>
          <ul class="space-y-1.5">
            <li v-for="n in currentBackend.notes" :key="n" class="flex items-start gap-2 text-sm text-gray-500">
              <span class="text-mint-400 mt-0.5 shrink-0">—</span>
              {{ n }}
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Quantization table -->
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-900 mb-2">Model Quantization Reference</h2>
      <p class="text-gray-500 mb-8">VRAM requirements for a 7B parameter model. Scale proportionally for larger models.</p>

      <div class="rounded-2xl border border-gray-100 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 border-b border-gray-100">
                <th class="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Quantization</th>
                <th class="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">VRAM (7B)</th>
                <th class="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Quality</th>
                <th class="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Speed</th>
                <th class="text-left px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wider">Notes</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(row, i) in quantTable"
                :key="row.q"
                :class="i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'"
                class="border-b border-gray-50"
              >
                <td class="px-5 py-3.5">
                  <code class="font-mono font-medium text-mint-700 bg-mint-50 px-2 py-0.5 rounded">{{ row.q }}</code>
                </td>
                <td class="px-5 py-3.5 text-gray-700 font-medium">{{ row.vram }}</td>
                <td class="px-5 py-3.5 text-gray-600">{{ row.quality }}</td>
                <td class="px-5 py-3.5 text-gray-600">{{ row.speed }}</td>
                <td class="px-5 py-3.5">
                  <span v-if="row.note" class="text-xs bg-mint-50 text-mint-700 border border-mint-100 px-2 py-0.5 rounded-full">{{ row.note }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- CUDA Unified Memory callout -->
    <div class="bg-gradient-to-br from-mint-50 to-white border border-mint-200 rounded-2xl p-8">
      <div class="flex items-start gap-4">
        <div class="w-12 h-12 bg-mint-500 rounded-xl flex items-center justify-center shrink-0">
          <svg class="w-6 h-6 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>
        <div>
          <h3 class="font-semibold text-gray-900 mb-2">CUDA Unified Memory</h3>
          <p class="text-gray-600 text-sm leading-relaxed mb-4">
            Run models larger than your GPU's VRAM by using CUDA Unified Virtual Memory (UVM). The OS transparently pages between GPU and CPU memory. Performance is lower than pure VRAM inference but enables much larger models.
          </p>
          <CodeBlock code="# Enable at runtime (no recompile needed)
./scripts/launch/launch-lamacpp.sh \\
  --model llama-70b.Q4_K_M.gguf \\
  --ngl 99 \\
  --unified-memory

# Or set environment variable directly
export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
llama-server --model llama-70b.Q4_K_M.gguf --ngl 99" lang="bash" />
        </div>
      </div>
    </div>
  </div>
</template>
