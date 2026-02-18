'use strict'

const express = require('express')
const router = express.Router()
const { execSync } = require('child_process')
const path = require('path')
const { ROOT } = require('../lib/scriptRunner')

const DETECT_SCRIPT = path.join(ROOT, 'scripts', 'detect-hardware.sh')

// Run a command safely and return stdout, or null on failure
function tryExec(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', timeout: 5000 }).trim()
  } catch {
    return null
  }
}

// GET /api/hardware — detect hardware capabilities
router.get('/', (req, res) => {
  const info = {}

  // CPU info
  info.cpu = {
    model: tryExec("grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2") || 'Unknown',
    cores: parseInt(tryExec("nproc") || '0', 10),
    avx2: (parseInt(tryExec("grep -c avx2 /proc/cpuinfo"), 10) || 0) > 0,
    avx512: (parseInt(tryExec("grep -c avx512f /proc/cpuinfo"), 10) || 0) > 0,
  }

  // Memory
  const memTotal = tryExec("grep MemTotal /proc/meminfo | awk '{print $2}'")
  info.memory = {
    totalKB: parseInt(memTotal || '0', 10),
    totalGB: memTotal ? (parseInt(memTotal, 10) / 1024 / 1024).toFixed(1) : 'Unknown',
  }

  // NVIDIA GPU
  const nvidiaSmi = tryExec("nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv,noheader 2>/dev/null")
  if (nvidiaSmi) {
    info.nvidia = nvidiaSmi.split('\n').filter(Boolean).map(line => {
      const parts = line.split(',').map(s => s.trim())
      return {
        name: parts[0] || 'Unknown',
        vram: parts[1] || 'Unknown',
        driver: parts[2] || 'Unknown',
        computeCap: parts[3] || 'Unknown',
      }
    })
    // Check for Unified Memory support (compute cap >= 6.0)
    info.unifiedMemorySupported = info.nvidia.some(gpu => {
      const cap = parseFloat(gpu.computeCap)
      return !isNaN(cap) && cap >= 6.0
    })
  } else {
    info.nvidia = null
    info.unifiedMemorySupported = false
  }

  // AMD ROCm
  const rocmSmi = tryExec("rocm-smi --showname 2>/dev/null")
  if (rocmSmi) {
    info.amd = { available: true, output: rocmSmi }
    info.rocmVersion = tryExec("cat /opt/rocm/version 2>/dev/null") || 'Unknown'
  } else {
    info.amd = null
  }

  // Vulkan
  const vulkanInfo = tryExec("vulkaninfo --summary 2>/dev/null | head -20")
  if (vulkanInfo) {
    info.vulkan = { available: true, summary: vulkanInfo }
  } else {
    info.vulkan = null
  }

  // Apple Metal (macOS only)
  if (process.platform === 'darwin') {
    const metalOutput = tryExec("system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Metal|Chipset' | head -5")
    info.metal = metalOutput ? { available: true, output: metalOutput } : null
  } else {
    info.metal = null
  }

  // Intel GPU
  const intelGpu = tryExec("ls /dev/dri/renderD* 2>/dev/null && lspci 2>/dev/null | grep -i 'Intel.*VGA\\|VGA.*Intel'")
  if (intelGpu) {
    info.intel = { available: true, output: intelGpu }
  } else {
    info.intel = null
  }

  // Recommended backend
  if (info.nvidia && info.nvidia.length > 0) {
    info.recommendedBackend = 'CUDA'
  } else if (info.amd) {
    info.recommendedBackend = 'ROCm'
  } else if (info.metal) {
    info.recommendedBackend = 'Metal'
  } else if (info.vulkan) {
    info.recommendedBackend = 'Vulkan'
  } else if (info.intel) {
    info.recommendedBackend = 'Intel (SYCL)'
  } else {
    info.recommendedBackend = 'CPU'
  }

  res.json(info)
})

module.exports = router
