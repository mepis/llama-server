# Script Reference Documentation

Detailed reference for all scripts in the Llama.cpp Management Suite.

## Overview

| Script | Location | Purpose | Requires Root |
|--------|----------|---------|---------------|
| `detect-hardware.sh` | `scripts/` | Detect system hardware | No |
| `install-lamacpp.sh` | `scripts/install/` | Install Llama.cpp | Yes |
| `compile-lamacpp.sh` | `scripts/compile/` | Compile Llama.cpp | No (install step needs root) |
| `upgrade-lamacpp.sh` | `scripts/upgrade/` | Upgrade Llama.cpp | Yes |
| `launch-lamacpp.sh` | `scripts/launch/` | Launch llama-server | No |
| `manage-lamacpp.sh` | `scripts/manage/` | Manage server instances | No |
| `terminate-lamacpp.sh` | `scripts/terminate/` | Terminate and cleanup | Yes |
| `llama.sh` | `scripts/` | Unified interface | Depends on command |

---

## detect-hardware.sh

Detects and displays system hardware capabilities.

### Usage

```bash
./scripts/detect-hardware.sh
```

### Output

- System information (uname)
- CPU model, core count, instruction sets (AVX2, AVX-512, NEON)
- Nvidia GPU information (nvidia-smi)
- AMD GPU information (rocm-smi)
- Apple Silicon information (macOS only)
- Intel GPU / OpenVINO availability
- Memory (free -h)
- Operating system details
- Disk space (df -h)

### Output File

Results are saved to `/tmp/hardware_detection_YYYYMMDD_HHMMSS.txt`.

### Environment Variables

None required.

---

## install-lamacpp.sh

Installs Llama.cpp from source with platform and hardware detection.

### Usage

```bash
sudo ./scripts/install/install-lamacpp.sh
```

### What it does

1. Checks for root privileges
2. Detects platform (Ubuntu/Debian, Fedora, Arch, Alpine, macOS)
3. Installs core build dependencies (git, cmake, build-essential, etc.)
4. Conditionally installs GPU packages based on detected hardware:
   - CUDA toolkit (if Nvidia GPU detected via nvidia-smi)
   - ROCm dev packages (if AMD GPU detected via rocm-smi)
   - Vulkan dev packages (if GPU detected via vulkaninfo or lspci)
5. Clones or updates the Llama.cpp repository from GitHub
6. Builds with hardware-detected backends (CUDA, ROCm, Vulkan, Metal)
7. Installs binaries to `$INSTALL_DIR/bin/`
8. Creates configuration directory and default config
9. Creates systemd service (Linux only)

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_DIR` | `/opt/llama-cpp` | Installation directory |
| `CLONE_DIR` | `/tmp/llama-cpp` | Source code directory |
| `BUILD_DIR` | `/tmp/llama-cpp-build` | Build directory |
| `LOG_FILE` | `/var/log/llama-cpp-install.log` | Log file path |

### Installed Files

- Binaries: `$INSTALL_DIR/bin/llama-server`, `$INSTALL_DIR/bin/llama-cli`
- Config: `$INSTALL_DIR/config/default.yaml`
- Symlinks: `/usr/local/bin/llama-server`, `/usr/local/bin/llama-cli`
- Service: `/etc/systemd/system/llama-server.service` (Linux)

---

## compile-lamacpp.sh

Interactive script for compiling Llama.cpp with custom backend selection.

### Usage

```bash
./scripts/compile/compile-lamacpp.sh
```

### Interactive Options

1. **All backends** - Compiles with CUDA, ROCm, Vulkan, and Metal (if available)
2. **CPU only** - No GPU acceleration
3. **CUDA** - Nvidia GPU (requires nvidia-smi)
4. **ROCm** - AMD GPU (requires rocm-smi and hipconfig)
5. **Vulkan** - Cross-platform GPU (requires vulkaninfo)
6. **Metal** - Apple Silicon (macOS only)
7. **Custom** - Enter custom CMake arguments

### CMake Options Configured

| Option | Flag | Description |
|--------|------|-------------|
| CUDA support | `-DGGML_CUDA=ON` | Enable Nvidia CUDA backend |
| ROCm support | `-DGGML_HIP=ON` | Enable AMD ROCm/HIP backend |
| Vulkan support | `-DGGML_VULKAN=ON` | Enable Vulkan backend |
| Metal support | `-DGGML_METAL=ON` | Enable Apple Metal backend |
| BLAS | `-DGGML_BLAS=ON` | Enable BLAS acceleration |
| CUDA Unified Memory | `-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=ON` | Enable CUDA UVM |
| Native optimizations | `-DGGML_NATIVE=ON` | Enable AVX2/AVX-512/NEON |
| BLIS | `-DGGML_BLAS_VENDOR=BLIS` | Use BLIS as BLAS provider |
| Intel oneMKL | `-DGGML_BLAS_VENDOR=Intel10_64lp` | Use Intel MKL |
| Static build | `-DBUILD_SHARED_LIBS=OFF` | Build static library |

### ROCm Notes

For ROCm builds, the following environment variables are set automatically:
- `HIPCXX` - Path to HIP clang compiler
- `HIP_PATH` - HIP installation path
- `GPU_TARGETS` - Detected GPU architecture (e.g., gfx1100)

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCE_DIR` | `/tmp/llama-cpp` | Source code directory |
| `BUILD_DIR` | `/tmp/llama-cpp-build` | Build directory |
| `INSTALL_DIR` | `/opt/llama-cpp` | Installation directory |
| `LOG_FILE` | `/var/log/llama-cpp-compile.log` | Log file path |

---

## upgrade-lamacpp.sh

Safely upgrades an existing Llama.cpp installation.

### Usage

```bash
sudo ./scripts/upgrade/upgrade-lamacpp.sh
```

### What it does

1. Detects existing installation
2. Creates timestamped backup of current installation
3. Updates source code (git pull)
4. Detects current hardware configuration
5. Recompiles with same or better backends
6. Stops systemd service if running
7. Replaces installation with new build
8. Preserves models and configuration
9. Restarts service
10. Verifies upgrade success; rolls back on failure

### Backup Location

Backups are stored at `$INSTALL_DIR.backup.YYYYMMDD_HHMMSS/`.

### Environment Variables

Same as `install-lamacpp.sh`.

---

## launch-lamacpp.sh

Launches the Llama.cpp server with comprehensive configuration options.

### Usage

```bash
./scripts/launch/launch-lamacpp.sh [OPTIONS]
```

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--model PATH` | `-m` | Path to GGUF model file | - |
| `--hf REPO` | | Download and use model from HuggingFace | - |
| `--config FILE` | `-c` | Path to configuration YAML file | - |
| `--port PORT` | `-p` | Server port | 8080 |
| `--host HOST` | `-H` | Bind address | 0.0.0.0 |
| `--ngl NUM` | | GPU layers to offload | - |
| `--threads NUM` | | Number of CPU threads | - |
| `--context SIZE` | `-C` | Context window size | - |
| `--batch-size SIZE` | | Batch size for prompt processing | - |
| `--log-level LEVEL` | | Log level (info/warning/error/debug) | info |
| `--unified-memory` | `-um` | Enable CUDA Unified Memory | - |
| `--no-gpu` | `-ng` | Disable GPU acceleration | - |
| `--daemon` | `-D` | Run as daemon (nohup background) | - |
| `--background` | `-b` | Run in background | - |
| `--download-only` | `-d` | Only download model, don't start server | - |
| `--list-devices` | `-l` | List available GPU devices | - |
| `--version` | `-v` | Show llama-server version | - |
| `--help` | | Show help message | - |

### HuggingFace Model Download

The `--hf` flag passes the model repository directly to llama-server's native `-hf` flag. The binary handles downloading and caching automatically.

```bash
# Download and run a model from HuggingFace
./scripts/launch/launch-lamacpp.sh --hf bartowski/Llama-3.2-3B-Instruct-GGUF
```

### CUDA Unified Memory

When `--unified-memory` is specified, the script sets:
```bash
export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
```

This allows models larger than VRAM to be loaded by using unified CPU+GPU memory.

### Process Management

- PID file: `/tmp/llama-server.pid`
- Log files: `$LOG_DIR/llama-server-YYYYMMDD_HHMMSS.log`
- The server can be stopped with `manage-lamacpp.sh stop` or `terminate-lamacpp.sh`

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_DIR` | `/opt/llama-cpp/config` | Configuration directory |
| `MODELS_DIR` | `/opt/llama-cpp/models` | Models directory |
| `LOG_DIR` | `/opt/llama-cpp/logs` | Log directory |
| `PID_FILE` | `/tmp/llama-server.pid` | PID file path |
| `PORT` | `8080` | Default port |
| `HOST` | `0.0.0.0` | Default bind address |

### Examples

```bash
# Basic usage with local model
./scripts/launch/launch-lamacpp.sh --model /opt/llama-cpp/models/model.gguf

# Full GPU offload
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99

# HuggingFace download with custom port
./scripts/launch/launch-lamacpp.sh --hf bartowski/Meta-Llama-3.1-8B-Instruct-GGUF --port 8081

# Run as daemon
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --daemon

# CPU-only with many threads
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --no-gpu --threads 16

# Large context with Unified Memory
./scripts/launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99 --unified-memory --context 8192
```

---

## manage-lamacpp.sh

Manages running Llama.cpp server instances.

### Usage

```bash
./scripts/manage/manage-lamacpp.sh COMMAND [OPTIONS]
```

### Commands

| Command | Description |
|---------|-------------|
| `start` | Start the server (uses launch script) |
| `stop` | Stop the server gracefully |
| `restart` | Stop and restart the server |
| `status` | Show server status and resource usage |
| `logs` | View recent log entries |
| `monitor` | Real-time monitoring (Ctrl+C to exit) |
| `list` | List all running llama-server processes |

### Examples

```bash
# Check if server is running
./scripts/manage/manage-lamacpp.sh status

# View last 50 log lines
./scripts/manage/manage-lamacpp.sh logs

# Real-time monitoring
./scripts/manage/manage-lamacpp.sh monitor

# List all instances with PID info
./scripts/manage/manage-lamacpp.sh list

# Restart server
./scripts/manage/manage-lamacpp.sh restart
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PID_FILE` | `/tmp/llama-server.pid` | PID file path |
| `LOG_DIR` | `/opt/llama-cpp/logs` | Log directory |

---

## terminate-lamacpp.sh

Terminates all Llama.cpp instances and frees GPU/CPU memory.

### Usage

```bash
sudo ./scripts/terminate/terminate-lamacpp.sh
```

### What it does

1. Finds all running llama-server processes (via PID file and pgrep)
2. Sends SIGTERM for graceful shutdown (waits 5 seconds)
3. Sends SIGKILL to any remaining processes
4. Resets Nvidia GPU memory (`nvidia-smi -r`) if Nvidia GPU present
5. Resets AMD GPU state (`rocm-smi`) if AMD GPU present
6. Clears Linux CPU/IO cache (`sync && echo 3 > /proc/sys/vm/drop_caches`)
7. Removes temporary files and PID file
8. Optionally cleans old log files (>7 days)
9. Displays memory status after cleanup

### Notes

- Root is required for GPU memory reset and cache clearing
- GPU memory reset may not work on all Nvidia GPUs
- Cache clearing on Linux drops page cache, dentries, and inodes

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PID_FILE` | `/tmp/llama-server.pid` | PID file path |
| `LOG_DIR` | `/opt/llama-cpp/logs` | Log directory |
| `INSTALL_DIR` | `/opt/llama-cpp` | Installation directory |

---

## llama.sh

Unified management interface for all Llama.cpp operations.

### Usage

```bash
# Interactive menu
./scripts/llama.sh

# Command-line mode
./scripts/llama.sh COMMAND [ARGS...]
```

### Commands

| Command | Description |
|---------|-------------|
| `install` | Run installation script |
| `compile` | Run compilation script |
| `upgrade` | Run upgrade script |
| `launch [ARGS]` | Launch server (passes args to launch script) |
| `manage [CMD]` | Manage server (passes command to manage script) |
| `terminate` | Run termination script |
| `detect` | Run hardware detection |
| `info` | Show system information |
| `docs` | Display documentation URLs |
| `help` | Show help message |

### Examples

```bash
# Interactive mode
./scripts/llama.sh

# Install
./scripts/llama.sh install

# Compile
./scripts/llama.sh compile

# Launch with model
./scripts/llama.sh launch --model /path/to/model.gguf --ngl 99

# Manage
./scripts/llama.sh manage status

# Detect hardware
./scripts/llama.sh detect
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SCRIPTS_DIR` | Script directory | Base directory for sub-scripts |

---

## Common Environment Variables

These variables can be set to customize script behavior across all scripts:

```bash
export INSTALL_DIR=/opt/llama-cpp      # Installation directory
export BUILD_DIR=/tmp/llama-cpp-build  # Build directory
export LOG_DIR=/opt/llama-cpp/logs     # Log directory
export PID_FILE=/tmp/llama-server.pid  # PID file
export PORT=8080                        # Default server port
export HOST=0.0.0.0                    # Default bind address
```

## Runtime Environment Variables

These are set during server execution:

```bash
export GGML_LOG_LEVEL=info             # llama.cpp log level
export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1  # Enable CUDA Unified Memory
```
