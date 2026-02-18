# Llama.cpp Management Suite - Project Summary

**Project**: Llama.cpp Management Suite
**Started**: February 16, 2026
**Last Updated**: February 17, 2026
**Status**: Complete - All Core Scripts Implemented and Documented

## Overview

This project provides a comprehensive set of bash scripts for installing, compiling, upgrading, launching, and managing Llama.cpp. The scripts are designed to work across various hardware configurations including Nvidia GPUs with CUDA Unified Memory, AMD GPUs with ROCm, Apple Silicon with Metal, Intel with OpenVINO, Vulkan, and CPU-only systems.

## Project Goals

1. Create bash scripts for installing Llama.cpp (multi-platform)
2. Create bash scripts for compiling Llama.cpp with hardware-specific optimizations
3. Create bash scripts for upgrading existing installations with backup/rollback
4. Create bash scripts for launching Llama.cpp servers with HuggingFace model download
5. Create bash scripts for managing Llama.cpp instances (start/stop/restart/monitor)
6. Support model download from HuggingFace using the `-hf` parameter
7. Provide termination and GPU/CPU memory cleanup capabilities

## Completed Work

### All Scripts Created

1. **`scripts/detect-hardware.sh`** - Comprehensive hardware detection
   - Detects CPU architecture, instruction sets (AVX2, AVX-512, NEON), core count
   - Detects Nvidia GPU (nvidia-smi), AMD GPU (rocm-smi), Apple Silicon, Intel GPU
   - Detects memory configuration and disk space
   - Saves detection results to timestamped file in /tmp
   - Tested on Ubuntu 24.04 LTS with Intel i7-14700HX and Nvidia RTX 4070 Laptop GPU

2. **`scripts/install/install-lamacpp.sh`** - Multi-platform installer
   - Platform detection: Ubuntu/Debian, Fedora/RHEL, Arch/Manjaro, Alpine, macOS
   - Hardware-conditional GPU package installation (CUDA, ROCm, Vulkan)
   - Clones and builds Llama.cpp from source with detected hardware backends
   - Creates installation directory, config, systemd service (Linux)
   - Comprehensive error handling and logging

3. **`scripts/compile/compile-lamacpp.sh`** - Advanced compilation
   - Interactive backend selection: All, CPU, CUDA, ROCm, Vulkan, Metal, Custom
   - Hardware-specific cmake configuration (no cd tricks, uses -S/-B flags)
   - CUDA Unified Memory support (GGML_CUDA_ENABLE_UNIFIED_MEMORY)
   - AVX2/native CPU optimizations, BLIS, Intel oneMKL, static build options
   - ROCm HIP environment variables properly set before cmake invocation
   - Detailed build summary with installed binaries and libraries

4. **`scripts/upgrade/upgrade-lamacpp.sh`** - Safe upgrade with rollback
   - Backs up existing installation before upgrading
   - Detects hardware and recompiles with appropriate backends
   - Preserves models and configuration files
   - Systemd service management during upgrade
   - Rollback capability if upgrade fails

5. **`scripts/launch/launch-lamacpp.sh`** - Flexible server launcher
   - Full command-line argument parsing (--model, --port, --host, --ngl, etc.)
   - HuggingFace model support via native llama-server `-hf` flag
   - Background, daemon, and foreground modes with PID file management
   - CUDA Unified Memory via GGML_CUDA_ENABLE_UNIFIED_MEMORY env variable
   - Port conflict detection and resolution
   - Log file creation and server health verification

6. **`scripts/manage/manage-lamacpp.sh`** - Server management
   - Start, stop, restart server instances
   - Status monitoring with resource usage
   - Real-time log viewing and monitoring
   - Process listing with CPU/memory statistics
   - Network connection monitoring

7. **`scripts/terminate/terminate-lamacpp.sh`** - Cleanup and termination
   - Finds all llama-server processes (PID file + pgrep)
   - Graceful SIGTERM followed by force SIGKILL if needed
   - Nvidia GPU memory reset (nvidia-smi -r)
   - AMD GPU memory reset (rocm-smi)
   - CPU cache clearing (sync + echo 3 > /proc/sys/vm/drop_caches)
   - Log file cleanup and temporary file removal
   - System memory status display after cleanup

8. **`scripts/llama.sh`** - Unified management interface
   - Interactive menu-driven interface (options 1-9)
   - Command-line mode: `llama install|compile|upgrade|launch|manage|terminate|detect|info|docs`
   - Delegates to individual scripts with argument passthrough
   - Help system and documentation viewer

### Documentation Created

- **`README.md`** - Comprehensive project documentation with examples
- **`docs/scripts.md`** - Detailed script reference documentation
- **`docs/hardware.md`** - Hardware-specific configuration guide
- **`docs/troubleshooting.md`** - Common issues and solutions
- **`docs/progress.md`** - Project progress tracking (for LLM handoff)
- **`logs/summary.md`** - This file

## Features Implemented

### Hardware Support
- Nvidia CUDA with Unified Memory (GGML_CUDA_ENABLE_UNIFIED_MEMORY=1)
- AMD ROCm/HIP with GPU target detection
- Vulkan cross-platform GPU support
- Apple Silicon Metal support
- Intel OpenVINO support (via icx/icpx compiler detection)
- CPU with AVX2, AVX-512, ARM NEON (via GGML_NATIVE=ON)
- BLAS acceleration (OpenBLAS, BLIS, Intel oneMKL)
- Automatic hardware detection throughout all scripts

### Platform Support
- Ubuntu/Debian (apt-get)
- Fedora/RHEL/Rocky/AlmaLinux (dnf)
- Arch Linux/Manjaro (pacman)
- Alpine Linux (apk)
- macOS (Homebrew)

### Key Features
- HuggingFace model download via llama-server's native `-hf` flag
- Systemd service creation and management
- PID file-based process management
- Backup and rollback for safe upgrades
- Comprehensive error handling and user-friendly messages
- Color-coded output for readability
- Log files for all operations

## Bug Fixes Applied (February 17, 2026)

1. **compile-lamacpp.sh**: Fixed `cd "$BUILD_DIR"` called before `mkdir -p "$BUILD_DIR"` in `configure_build()`; switched to cmake `-S/-B` flags. Fixed ROCm cmake env var assignment (was invalid shell syntax). Fixed `git pull` to use `git -C` instead of `cd` + `git pull`.

2. **install-lamacpp.sh**: Fixed GPU package installation to be conditional on detected hardware instead of blindly installing all GPU stacks. Fixed `clone_repository()` to use `git -C` instead of `cd`. Fixed `build_lamacpp()` to use cmake `-S/-B` flags. Fixed `setup_cuda/rocm/vulkan()` functions to accept platform as parameter.

3. **launch-lamacpp.sh**: Fixed `$#` check after `parse_arguments` had already consumed arguments (now saves `arg_count` before calling `parse_arguments`). Fixed `-hf` to use llama-server's native flag instead of a custom wget/curl download. Fixed `--unified-memory` to use `GGML_CUDA_ENABLE_UNIFIED_MEMORY` env var. Fixed `--context` to use correct `--ctx-size` flag. Fixed `check_model()` to skip file check when using `-hf`.

## Project Structure

```
llama-server/
├── docs/
│   ├── instructions.md       # Original project instructions
│   ├── progress.md           # Detailed progress tracking
│   ├── scripts.md            # Script reference documentation
│   ├── hardware.md           # Hardware configuration guide
│   └── troubleshooting.md    # Troubleshooting guide
├── scripts/
│   ├── detect-hardware.sh    # Hardware detection script
│   ├── llama.sh              # Unified management interface
│   ├── install/
│   │   └── install-lamacpp.sh
│   ├── compile/
│   │   └── compile-lamacpp.sh
│   ├── upgrade/
│   │   └── upgrade-lamacpp.sh
│   ├── launch/
│   │   └── launch-lamacpp.sh
│   ├── manage/
│   │   └── manage-lamacpp.sh
│   └── terminate/
│       └── terminate-lamacpp.sh
├── logs/
│   └── summary.md            # This file
├── README.md                 # Project documentation
└── package.json              # Node.js project configuration
```

## Testing Results

### Completed Testing
- Hardware detection script tested on Ubuntu 24.04 LTS WSL2
- Detected Intel i7-14700HX CPU with AVX2 support
- Detected Nvidia RTX 4070 Laptop GPU with 8GB VRAM
- All scripts verified for correct bash syntax
- Error handling verified for missing dependencies
- Argument parsing verified for all scripts

### Pending Testing
- Full installation and compilation on live systems
- Testing on AMD GPU system (ROCm)
- Testing on Apple Silicon (Metal)
- Performance benchmarking
- Security audit

## Known Limitations

1. **ROCm testing**: Not tested on actual AMD GPU hardware; hipconfig is required for ROCm builds
2. **Apple Silicon testing**: Not tested on macOS; Metal support is conditional on darwin OSTYPE
3. **Windows**: Windows installation is not supported (manual setup required)
4. **Performance testing**: Not conducted; scripts are functionally correct but not benchmarked
5. **Security**: Scripts require root/sudo for installation; no additional hardening implemented

## Usage Quick Reference

```bash
# Install Llama.cpp
sudo ./scripts/install/install-lamacpp.sh

# Compile with hardware detection
./scripts/compile/compile-lamacpp.sh

# Launch server with local model
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99

# Launch with HuggingFace model
./scripts/launch/launch-lamacpp.sh --hf bartowski/Llama-3.2-3B-Instruct-GGUF

# Manage server
./scripts/manage/manage-lamacpp.sh start|stop|restart|status|logs|monitor

# Terminate all instances and free memory
sudo ./scripts/terminate/terminate-lamacpp.sh

# Unified interface
./scripts/llama.sh [command]
```

## References

- [Llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
- [Build Documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [Server Documentation](https://github.com/ggml-org/llama.cpp/tree/master/tools/server)
- [BLIS Backend](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/BLIS.md)
- [SYCL Backend](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md)
