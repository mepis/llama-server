import { defineComponent, h } from 'vue'

// SVG icon components
const IconDetect = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('circle', { cx: '12', cy: '12', r: '3' }),
    h('path', { d: 'M6.34 6.34a8 8 0 1011.31 11.31M17.66 6.34A8 8 0 016.34 17.66', 'stroke-linecap': 'round' }),
  ])
})

const IconInstall = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('path', { d: 'M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
    h('polyline', { points: '7 10 12 15 17 10', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
    h('line', { x1: '12', y1: '15', x2: '12', y2: '3', 'stroke-linecap': 'round' }),
  ])
})

const IconCompile = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('polyline', { points: '16 18 22 12 16 6', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
    h('polyline', { points: '8 6 2 12 8 18', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
  ])
})

const IconUpgrade = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('polyline', { points: '17 11 12 6 7 11', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
    h('line', { x1: '12', y1: '18', x2: '12', y2: '6', 'stroke-linecap': 'round' }),
    h('circle', { cx: '12', cy: '21', r: '1', fill: 'currentColor' }),
  ])
})

const IconLaunch = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('path', { d: 'M22 2L11 13', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
    h('path', { d: 'M22 2L15 22l-4-9-9-4 19-7z', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
  ])
})

const IconManage = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('rect', { x: '3', y: '3', width: '18', height: '18', rx: '2', 'stroke-linecap': 'round' }),
    h('path', { d: 'M9 9h.01M15 9h.01M9 15h.01M15 15h.01', 'stroke-linecap': 'round' }),
  ])
})

const IconTerminate = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('circle', { cx: '12', cy: '12', r: '10' }),
    h('rect', { x: '9', y: '9', width: '6', height: '6', 'stroke-linecap': 'round' }),
  ])
})

const IconEntry = defineComponent({
  render: () => h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
    h('path', { d: 'M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
    h('polyline', { points: '9 22 9 12 15 12 15 22', 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
  ])
})

export const scripts = [
  {
    id: 'detect',
    name: 'Hardware Detection',
    file: 'scripts/detect-hardware.sh',
    description: 'Detect CPU, GPU, and memory configuration to determine optimal build settings.',
    longDescription: 'Scans your system for all relevant hardware including CPU instruction sets, Nvidia/AMD/Apple GPUs, memory configuration, and operating system. Results are saved to a timestamped file for reference.',
    icon: IconDetect,
    iconBg: 'bg-blue-50',
    iconColor: 'text-blue-500',
    tags: ['Detection', 'Hardware'],
    requiresRoot: false,
    features: [
      'CPU model, core count, and instruction sets (AVX2, AVX-512, NEON)',
      'Nvidia GPU detection via nvidia-smi',
      'AMD GPU detection via rocm-smi',
      'Apple Silicon detection (macOS)',
      'Memory and disk space reporting',
      'Results saved to /tmp/hardware_detection_*.txt',
    ],
    usage: './scripts/detect-hardware.sh',
    examples: [
      { label: 'Run detection', code: './scripts/detect-hardware.sh' },
    ],
  },
  {
    id: 'install',
    name: 'Installation',
    file: 'scripts/install/install-lamacpp.sh',
    description: 'One-command install: detects platform, installs deps, clones, builds, and deploys Llama.cpp.',
    longDescription: 'Platform-aware installation script that detects your OS and hardware, installs only the necessary dependencies (CUDA/ROCm/Vulkan conditionally), clones the official Llama.cpp repository, compiles with hardware-specific backends, and creates a systemd service on Linux.',
    icon: IconInstall,
    iconBg: 'bg-mint-50',
    iconColor: 'text-mint-600',
    tags: ['Install', 'Multi-platform'],
    requiresRoot: true,
    features: [
      'Platform detection: Ubuntu/Debian, Fedora, Arch, Alpine, macOS',
      'Conditional GPU package installation (only what you have)',
      'CUDA, ROCm, Vulkan, and Metal backend support',
      'Systemd service creation (Linux)',
      'Default configuration file generation',
      'Comprehensive error handling and logging',
    ],
    usage: 'sudo ./scripts/install/install-lamacpp.sh',
    env: [
      { name: 'INSTALL_DIR', default: '/opt/llama-cpp', desc: 'Installation directory' },
      { name: 'CLONE_DIR', default: '/tmp/llama-cpp', desc: 'Source code clone directory' },
      { name: 'BUILD_DIR', default: '/tmp/llama-cpp-build', desc: 'CMake build directory' },
      { name: 'LOG_FILE', default: '/var/log/llama-cpp-install.log', desc: 'Installation log file' },
    ],
    examples: [
      { label: 'Standard installation', code: 'sudo ./scripts/install/install-lamacpp.sh' },
      { label: 'Custom install directory', code: 'INSTALL_DIR=/usr/local/llama sudo ./scripts/install/install-lamacpp.sh' },
    ],
  },
  {
    id: 'compile',
    name: 'Compilation',
    file: 'scripts/compile/compile-lamacpp.sh',
    description: 'Interactive compilation with backend selection: CUDA, ROCm, Vulkan, Metal, or all at once.',
    longDescription: 'Advanced compilation script offering interactive backend selection and fine-grained optimization options. Supports all Llama.cpp hardware backends including CUDA Unified Memory, BLIS, Intel oneMKL, and native CPU instruction sets.',
    icon: IconCompile,
    iconBg: 'bg-purple-50',
    iconColor: 'text-purple-500',
    tags: ['Compile', 'CMake', 'GPU'],
    requiresRoot: false,
    features: [
      'Interactive backend menu: All, CPU, CUDA, ROCm, Vulkan, Metal, Custom',
      'CUDA Unified Memory support (GGML_CUDA_ENABLE_UNIFIED_MEMORY)',
      'Native CPU optimizations (AVX2, AVX-512, ARM NEON)',
      'BLAS vendor selection: OpenBLAS, BLIS, Intel oneMKL',
      'Static vs shared library option',
      'ROCm HIP compiler detection with GPU target auto-detection',
      'Parallel compilation using all CPU cores',
    ],
    usage: './scripts/compile/compile-lamacpp.sh',
    env: [
      { name: 'SOURCE_DIR', default: '/tmp/llama-cpp', desc: 'Cloned source directory' },
      { name: 'BUILD_DIR', default: '/tmp/llama-cpp-build', desc: 'CMake build output directory' },
      { name: 'INSTALL_DIR', default: '/opt/llama-cpp', desc: 'Final installation directory' },
      { name: 'LOG_FILE', default: '/var/log/llama-cpp-compile.log', desc: 'Compilation log file' },
    ],
    examples: [
      { label: 'Interactive compilation', code: './scripts/compile/compile-lamacpp.sh' },
    ],
  },
  {
    id: 'upgrade',
    name: 'Upgrade',
    file: 'scripts/upgrade/upgrade-lamacpp.sh',
    description: 'Safely upgrade Llama.cpp with automatic backup and rollback on failure.',
    longDescription: 'Upgrade your existing Llama.cpp installation safely. Creates a timestamped backup of your current installation, pulls the latest source, recompiles with hardware detection, and rolls back automatically if anything goes wrong.',
    icon: IconUpgrade,
    iconBg: 'bg-orange-50',
    iconColor: 'text-orange-500',
    tags: ['Upgrade', 'Backup', 'Rollback'],
    requiresRoot: true,
    features: [
      'Timestamped backup of current installation',
      'Preserves models and configuration files',
      'Hardware detection for optimized recompilation',
      'Systemd service stop/start management',
      'Automatic rollback if upgrade fails',
      'Verification of new installation before committing',
    ],
    usage: 'sudo ./scripts/upgrade/upgrade-lamacpp.sh',
    examples: [
      { label: 'Standard upgrade', code: 'sudo ./scripts/upgrade/upgrade-lamacpp.sh' },
    ],
  },
  {
    id: 'launch',
    name: 'Launch Server',
    file: 'scripts/launch/launch-lamacpp.sh',
    description: 'Launch llama-server with GPU offloading, HuggingFace model download, and daemon mode.',
    longDescription: 'Full-featured server launcher with comprehensive argument parsing. Supports native llama-server model download via the -hf flag, CUDA Unified Memory via environment variables, foreground/background/daemon modes, and automatic port conflict resolution.',
    icon: IconLaunch,
    iconBg: 'bg-mint-50',
    iconColor: 'text-mint-600',
    tags: ['Launch', 'Server', 'HuggingFace'],
    requiresRoot: false,
    features: [
      'HuggingFace model download via native llama-server -hf flag',
      'GPU layer offloading control (--ngl)',
      'CUDA Unified Memory via GGML_CUDA_ENABLE_UNIFIED_MEMORY',
      'Daemon and background modes with PID file management',
      'Port conflict detection and resolution',
      'Server health verification after launch',
      'Log file management with timestamped filenames',
    ],
    usage: './scripts/launch/launch-lamacpp.sh [OPTIONS]',
    options: [
      { flag: '--model, -m PATH', desc: 'Path to local GGUF model file' },
      { flag: '--hf REPO', desc: 'Download model from HuggingFace (e.g. bartowski/Llama-3.2-3B-Instruct-GGUF)' },
      { flag: '--port, -p PORT', desc: 'Server port (default: 8080)' },
      { flag: '--host, -H HOST', desc: 'Bind address (default: 0.0.0.0)' },
      { flag: '--ngl NUM', desc: 'Number of GPU layers to offload (99 = all)' },
      { flag: '--threads NUM', desc: 'Number of CPU threads' },
      { flag: '--context, -C SIZE', desc: 'Context window size in tokens' },
      { flag: '--unified-memory', desc: 'Enable CUDA Unified Memory (larger-than-VRAM models)' },
      { flag: '--daemon, -D', desc: 'Run as background daemon (nohup)' },
      { flag: '--no-gpu', desc: 'Disable GPU acceleration' },
    ],
    env: [
      { name: 'PORT', default: '8080', desc: 'Default server port' },
      { name: 'HOST', default: '0.0.0.0', desc: 'Default bind address' },
      { name: 'LOG_DIR', default: '/opt/llama-cpp/logs', desc: 'Log directory' },
      { name: 'GGML_CUDA_ENABLE_UNIFIED_MEMORY', default: '0', desc: 'Enable CUDA UVM (set to 1)' },
    ],
    examples: [
      { label: 'Basic launch', code: './scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf' },
      { label: 'Full GPU offload', code: './scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99' },
      { label: 'HuggingFace model', code: './scripts/launch/launch-lamacpp.sh --hf bartowski/Llama-3.2-3B-Instruct-GGUF' },
      { label: 'Daemon with Unified Memory', code: './scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --unified-memory --daemon' },
      { label: 'Custom port, CPU only', code: './scripts/launch/launch-lamacpp.sh --model model.gguf --port 8081 --no-gpu --threads 16' },
    ],
  },
  {
    id: 'manage',
    name: 'Management',
    file: 'scripts/manage/manage-lamacpp.sh',
    description: 'Start, stop, restart, monitor logs, and list running instances.',
    longDescription: 'Server management script for day-to-day operation of Llama.cpp instances. Provides start/stop/restart controls, real-time log monitoring, process listing with resource stats, and network connection monitoring.',
    icon: IconManage,
    iconBg: 'bg-indigo-50',
    iconColor: 'text-indigo-500',
    tags: ['Manage', 'Monitor', 'Logs'],
    requiresRoot: false,
    features: [
      'Start, stop, restart server instances',
      'Status check with CPU and memory usage',
      'Real-time log tailing (monitor mode)',
      'Process listing with PID and resource stats',
      'Network connection monitoring',
      'Log file browsing with filtering',
    ],
    usage: './scripts/manage/manage-lamacpp.sh COMMAND',
    options: [
      { flag: 'start', desc: 'Start the server' },
      { flag: 'stop', desc: 'Stop the server gracefully' },
      { flag: 'restart', desc: 'Stop and restart the server' },
      { flag: 'status', desc: 'Show server status and resource usage' },
      { flag: 'logs', desc: 'View recent log entries' },
      { flag: 'monitor', desc: 'Real-time monitoring (Ctrl+C to exit)' },
      { flag: 'list', desc: 'List all running llama-server processes' },
    ],
    examples: [
      { label: 'Check status', code: './scripts/manage/manage-lamacpp.sh status' },
      { label: 'View logs', code: './scripts/manage/manage-lamacpp.sh logs' },
      { label: 'Real-time monitor', code: './scripts/manage/manage-lamacpp.sh monitor' },
      { label: 'Restart server', code: './scripts/manage/manage-lamacpp.sh restart' },
    ],
  },
  {
    id: 'terminate',
    name: 'Terminate & Cleanup',
    file: 'scripts/terminate/terminate-lamacpp.sh',
    description: 'Kill all instances, reset GPU memory, and clear CPU caches.',
    longDescription: 'Nuclear option for stopping Llama.cpp and freeing all resources. Finds all running llama-server processes, terminates them gracefully then forcefully, resets GPU memory for both Nvidia and AMD, clears Linux CPU caches, and removes temporary files.',
    icon: IconTerminate,
    iconBg: 'bg-red-50',
    iconColor: 'text-red-500',
    tags: ['Terminate', 'Cleanup', 'Memory'],
    requiresRoot: true,
    features: [
      'Finds all llama-server processes via PID file and pgrep',
      'Graceful SIGTERM with 5-second wait, then SIGKILL',
      'Nvidia GPU memory reset (nvidia-smi -r)',
      'AMD GPU memory reset (rocm-smi)',
      'Linux CPU/IO cache clearing (drop_caches)',
      'PID file and temporary file cleanup',
      'Old log file removal (>7 days)',
      'Memory status display after cleanup',
    ],
    usage: 'sudo ./scripts/terminate/terminate-lamacpp.sh',
    examples: [
      { label: 'Full cleanup', code: 'sudo ./scripts/terminate/terminate-lamacpp.sh' },
    ],
  },
  {
    id: 'llama',
    name: 'Unified Interface',
    file: 'scripts/llama.sh',
    description: 'Single entrypoint: interactive menu or command-line mode for all operations.',
    longDescription: 'The main entrypoint for the entire suite. Run without arguments for an interactive numbered menu, or pass a command for non-interactive use in scripts and automation.',
    icon: IconEntry,
    iconBg: 'bg-teal-50',
    iconColor: 'text-teal-600',
    tags: ['Interface', 'Menu', 'CLI'],
    requiresRoot: false,
    features: [
      'Interactive numbered menu (1-9)',
      'Command-line mode for automation',
      'Delegates arguments to individual scripts',
      'System information display',
      'Documentation URL viewer',
    ],
    usage: './scripts/llama.sh [COMMAND]',
    options: [
      { flag: 'install', desc: 'Run installation script' },
      { flag: 'compile', desc: 'Run compilation script' },
      { flag: 'upgrade', desc: 'Run upgrade script' },
      { flag: 'launch [ARGS]', desc: 'Launch server with arguments' },
      { flag: 'manage [CMD]', desc: 'Manage server (start/stop/status...)' },
      { flag: 'terminate', desc: 'Terminate all instances' },
      { flag: 'detect', desc: 'Run hardware detection' },
      { flag: 'info', desc: 'Show system information' },
      { flag: 'docs', desc: 'Show documentation links' },
      { flag: 'help', desc: 'Show help message' },
    ],
    examples: [
      { label: 'Interactive mode', code: './scripts/llama.sh' },
      { label: 'Launch server', code: './scripts/llama.sh launch --model model.gguf --ngl 99' },
      { label: 'Check status', code: './scripts/llama.sh manage status' },
      { label: 'Hardware detect', code: './scripts/llama.sh detect' },
    ],
  },
]
