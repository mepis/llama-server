# Hardware Configuration Guide

This guide explains how to configure Llama.cpp for different hardware backends and how to get the best performance from each.

## Hardware Detection

Before installing or compiling, run the hardware detection script to understand your system:

```bash
./scripts/detect-hardware.sh
```

The output will show:
- CPU model and instruction sets (AVX2, AVX-512, NEON)
- GPU availability and type
- Total system memory
- Available disk space

---

## Nvidia GPU (CUDA)

### Requirements

- Nvidia GPU with CUDA compute capability 5.0 or higher
- CUDA toolkit installed (check with `nvidia-smi`)
- NVIDIA driver >= 520.0 for CUDA 12.x

### Verify CUDA Installation

```bash
nvidia-smi
nvcc --version
```

### Build Configuration

The `compile-lamacpp.sh` script automatically detects Nvidia GPUs and enables CUDA support:
- CMake flag: `-DGGML_CUDA=ON`

### GPU Layer Offloading

Use `--ngl` to specify how many layers to offload to GPU. Setting it to 99 offloads all layers:

```bash
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99
```

For a partial GPU offload (useful when model doesn't fit entirely in VRAM):
```bash
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 30
```

### CUDA Unified Memory

CUDA Unified Memory (UVM) allows models larger than your GPU's VRAM to be loaded by transparently paging between GPU and CPU memory. This is slower than pure GPU inference but allows using large models on systems with limited VRAM.

**Enable during compilation:**
```bash
# In compile-lamacpp.sh, answer 'y' to: "Enable CUDA Unified Memory support?"
# This sets: -DGGML_CUDA_ENABLE_UNIFIED_MEMORY=ON
```

**Enable at runtime (without recompiling):**
```bash
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --unified-memory
# Or manually:
export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
llama-server --model /path/to/model.gguf
```

**When to use Unified Memory:**
- Model size > GPU VRAM (e.g., 13B model on 8GB GPU)
- Testing large models before upgrading hardware
- Note: Performance will be lower than pure VRAM inference

### Optimizing VRAM Usage

```bash
# Use quantized model (Q4_K_M recommended balance)
./scripts/launch/launch-lamacpp.sh --model model.Q4_K_M.gguf --ngl 99

# Reduce context size to save VRAM
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --context 2048

# Reduce batch size
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --batch-size 256
```

### Check GPU Memory During Inference

```bash
nvidia-smi --loop=1  # Real-time GPU monitoring
```

---

## AMD GPU (ROCm)

### Requirements

- AMD GPU supported by ROCm (RX 5000 series and newer recommended)
- ROCm 5.6 or higher installed
- `rocm-smi` and `hipconfig` available in PATH

### Verify ROCm Installation

```bash
rocm-smi
hipconfig --version
```

### Supported GPU Architectures

Common ROCm GPU targets (automatically detected):
- `gfx1100` - RX 7900 XTX / RX 7900 XT
- `gfx1030` - RX 6900 XT / RX 6800 XT
- `gfx908` - Instinct MI100
- `gfx906` - Radeon VII / Instinct MI50

### Build Configuration

The compile script automatically detects ROCm and sets:
```bash
HIPCXX=$(hipconfig -l)/clang
HIP_PATH=$(hipconfig -p)
cmake -DGGML_HIP=ON -DGPU_TARGETS=gfx1100 ...
```

### Install ROCm on Ubuntu/Debian

```bash
# Add ROCm repository
wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ jammy main' | \
  sudo tee /etc/apt/sources.list.d/rocm.list
sudo apt-get update
sudo apt-get install rocm-dev rocm-libs
```

### Environment Variables for ROCm

```bash
export HSA_OVERRIDE_GFX_VERSION=10.3.0  # Override GPU version if needed
export ROCM_PATH=/opt/rocm
```

---

## Apple Silicon (Metal)

### Requirements

- macOS 12.0 (Monterey) or later
- Apple M1, M2, M3, or later chip

### Verify Apple Silicon

```bash
sysctl -n machdep.cpu.brand_string  # Should show "Apple M..."
system_profiler SPDisplaysDataType | grep Metal
```

### Build Configuration

Automatically detected on macOS, sets:
```bash
cmake -DGGML_METAL=ON ...
```

### Apple Silicon Advantages

- Unified Memory Architecture: CPU and GPU share the same memory pool
- GPU can access the full system RAM (e.g., 64GB on M2 Max)
- No separate VRAM limit - models up to system RAM can run on GPU
- Very efficient for medium-to-large models

### macOS Installation

```bash
# Install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then run install script
./scripts/install/install-lamacpp.sh
```

### Metal-Specific Settings

```bash
# On Apple Silicon, use high layer count (GPU handles system RAM)
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99
```

---

## Vulkan (Cross-Platform GPU)

### Requirements

- Any modern GPU with Vulkan 1.2+ support
- Vulkan loader and ICD installed
- `vulkaninfo` available

### Verify Vulkan

```bash
vulkaninfo --summary
```

### Supported GPUs

- Nvidia GPUs (via Vulkan driver, alternative to CUDA)
- AMD GPUs (via RADV or AMDVLK)
- Intel GPUs (via ANV)
- Mobile GPUs (Adreno, Mali via custom drivers)

### Build Configuration

```bash
cmake -DGGML_VULKAN=ON ...
```

### Install Vulkan on Ubuntu/Debian

```bash
sudo apt-get install libvulkan-dev vulkan-tools glslang-tools
```

### Notes

- Vulkan is generally slower than CUDA/ROCm for ML workloads
- Useful for systems without CUDA/ROCm drivers
- Good for AMD GPUs on Linux without ROCm support

---

## Intel GPU (OpenVINO / SYCL)

### Requirements

- Intel GPU (Arc, Iris Xe, or integrated)
- Intel oneAPI toolkit with DPC++/SYCL compiler
- `icx` and `icpx` compilers in PATH

### Verify Intel oneAPI

```bash
icx --version
source /opt/intel/oneapi/setvars.sh
```

### Build Configuration

When `icx` is detected, the compile script offers Intel oneMKL:
```bash
cmake -DGGML_BLAS_VENDOR=Intel10_64lp \
      -DCMAKE_C_COMPILER=icx \
      -DCMAKE_CXX_COMPILER=icpx ...
```

### Install Intel oneAPI

```bash
# Ubuntu/Debian
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
  sudo gpg --dearmor -o /usr/share/keyrings/oneapi-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] \
  https://apt.repos.intel.com/oneapi all main" | \
  sudo tee /etc/apt/sources.list.d/oneAPI.list
sudo apt-get update
sudo apt-get install intel-oneapi-compiler-dpcpp-cpp intel-oneapi-mkl-devel
source /opt/intel/oneapi/setvars.sh
```

---

## CPU-Only (No GPU)

### CPU Instruction Set Support

The compile script enables native CPU optimizations by default (`-DGGML_NATIVE=ON`), which uses the best instruction sets available:

| Instruction Set | CPUs | Speedup |
|----------------|------|---------|
| AVX2 + FMA | Intel Haswell+, AMD Zen2+ | 2-4x vs base |
| AVX-512 | Intel Skylake-SP+, AMD Zen4 | 4-8x vs base |
| ARM NEON | Apple Silicon, ARM Cortex-A | 2-4x vs base |
| ARM SVE | ARMv8.2+, Apple M1+ | 4-8x vs base |

### Check CPU Flags

```bash
grep -m1 'flags' /proc/cpuinfo | grep -oE 'avx2|avx512|fma|neon'
```

### BLAS Acceleration

For CPU-only inference, BLAS libraries accelerate matrix operations:

**OpenBLAS (default, automatic):**
```bash
# Included automatically with -DGGML_BLAS=ON
```

**BLIS (recommended for performance):**
```bash
sudo apt-get install libblis-dev
# During compile, answer 'y' to BLIS question
# Sets: -DGGML_BLAS_VENDOR=BLIS
```

**Intel oneMKL (best for Intel CPUs):**
```bash
# Requires Intel oneAPI toolkit
# During compile, answer 'y' to oneMKL question
# Sets: -DGGML_BLAS_VENDOR=Intel10_64lp
```

### CPU Thread Tuning

```bash
# Use all physical cores (hyperthreading may not help)
THREADS=$(nproc --ignore=2)  # Leave 2 threads for OS
./scripts/launch/launch-lamacpp.sh --model model.gguf --threads $THREADS
```

### Recommended Quantization for CPU

| Quantization | Memory | Quality | Speed |
|-------------|--------|---------|-------|
| Q8_0 | ~8GB/7B | Highest | Slowest |
| Q6_K | ~6GB/7B | Very High | Slow |
| Q5_K_M | ~5GB/7B | High | Medium |
| Q4_K_M | ~4GB/7B | Good | Fast |
| Q3_K_M | ~3GB/7B | OK | Faster |
| Q2_K | ~2GB/7B | Low | Fastest |

---

## Multi-Backend Builds

You can compile with multiple backends simultaneously. The runtime will automatically select the best available backend.

### Build with CUDA + Vulkan fallback

```bash
# In compile-lamacpp.sh, select option 1 (All backends)
# Or manually:
cmake -S ~/.local/llama-cpp/src -B ~/.local/llama-cpp/build \
  -DGGML_CUDA=ON \
  -DGGML_VULKAN=ON \
  -DGGML_BLAS=ON \
  -DGGML_NATIVE=ON \
  -DCMAKE_BUILD_TYPE=Release
```

### Hardware Priority

When multiple backends are compiled in, llama.cpp selects in this order:
1. CUDA (if Nvidia GPU and CUDA available)
2. ROCm/HIP (if AMD GPU and ROCm available)
3. Metal (if macOS)
4. Vulkan (if Vulkan GPU available)
5. CPU (always available)

---

## Memory Requirements

### GPU VRAM Requirements by Model Size

| Model | Q4_K_M VRAM | Q8_0 VRAM |
|-------|-------------|-----------|
| 1B params | ~1GB | ~1.5GB |
| 3B params | ~2GB | ~4GB |
| 7B params | ~4GB | ~8GB |
| 13B params | ~8GB | ~16GB |
| 34B params | ~20GB | ~40GB |
| 70B params | ~40GB | ~80GB |

### RAM Requirements (CPU inference)

Similar to VRAM requirements above, but using system RAM. Additional RAM is needed for KV cache (scales with context size):

```
KV cache size ≈ 2 * context_size * num_layers * num_heads * head_size * dtype_bytes
```

For a 7B model with 4096 context and fp16: ~2GB additional RAM.

---

## Performance Tuning

### General Tips

1. Use the largest quantization that fits in VRAM/RAM for best quality
2. Set `--ngl 99` to maximize GPU utilization
3. Match `--threads` to physical CPU cores (not logical/hyperthreaded)
4. Reduce `--batch-size` if OOM errors occur during prompt processing
5. Use `--context` conservatively - larger contexts use more memory

### CUDA Tuning

```bash
# Maximize GPU throughput
./scripts/launch/launch-lamacpp.sh \
  --model model.gguf \
  --ngl 99 \
  --threads 4 \
  --batch-size 512 \
  --context 4096

# Environment tuning
export CUDA_VISIBLE_DEVICES=0    # Use specific GPU
export GGML_CUDA_NO_PEER_COPY=1  # Disable peer copy if issues
```

### Monitoring Performance

```bash
# GPU utilization
watch -n 0.5 nvidia-smi

# CPU and memory
htop

# Server metrics (if server is running)
curl http://localhost:8080/metrics
```
