#!/bin/bash

# Llama.cpp Installation Script
# This script installs Llama.cpp on various platforms with hardware detection

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/llama-cpp}"
CLONE_DIR="${CLONE_DIR:-$HOME/.local/llama-cpp/src}"
BUILD_DIR="${BUILD_DIR:-$HOME/.local/llama-cpp/build}"
LOG_DIR="${INSTALL_DIR}/logs"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/install.log}"

# Compile-time options (override auto-detection)
# GPU_BACKEND: auto | cuda | rocm | vulkan | sycl | opencl | cpu
GPU_BACKEND="${GPU_BACKEND:-auto}"
# CUDA_ARCHITECTURES: e.g. "86;89;90" — leave empty for auto-detect
CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
BLAS_VENDOR="${BLAS_VENDOR:-OpenBLAS}"
GGML_NATIVE="${GGML_NATIVE:-ON}"

# Functions
log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v lsb_release &> /dev/null; then
            DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
            VERSION=$(lsb_release -sr)
            log "Detected Linux distribution: $DISTRO $VERSION"
        fi
        if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "debian" ]]; then
            echo "ubuntu"
        elif [[ "$DISTRO" == "fedora" ]] || [[ "$DISTRO" == "rhel" ]] || [[ "$DISTRO" == "rocky" ]] || [[ "$DISTRO" == "almalinux" ]]; then
            echo "fedora"
        elif [[ "$DISTRO" == "arch" ]] || [[ "$DISTRO" == "manjaro" ]]; then
            echo "arch"
        elif [[ "$DISTRO" == "alpine" ]]; then
            echo "alpine"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

check_dependencies() {
    local platform=$1
    local missing_deps=()

    log "Checking core build dependencies..."

    for cmd in git cmake pkg-config gcc g++ make wget curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warning "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install them using your package manager:"
        case "$platform" in
            ubuntu|debian)
                echo "  sudo apt-get update && sudo apt-get install -y git cmake pkg-config build-essential wget curl libssl-dev"
                ;;
            fedora|rhel|rocky|almalinux)
                echo "  sudo dnf install -y git cmake pkgconf-pkg-config gcc gcc-c++ make wget curl openssl-devel"
                ;;
            arch|manjaro)
                echo "  sudo pacman -Sy --noconfirm git cmake pkgconf base-devel wget curl openssl"
                ;;
            alpine)
                echo "  sudo apk add --no-cache git cmake pkgconf build-base wget curl openssl-dev"
                ;;
            macos)
                echo "  brew install cmake pkg-config git wget curl"
                ;;
        esac
        echo ""
        read -p "Continue anyway? [y/N]: " cont
        if [[ ! "$cont" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log "All core dependencies are installed"
    fi
}

check_gpu_support() {
    local platform=$1

    # CUDA
    if command -v nvidia-smi &> /dev/null; then
        log "Nvidia GPU detected. CUDA support will be enabled."
        if ! command -v nvcc &> /dev/null; then
            warning "nvcc not found. CUDA toolkit may not be installed."
            echo "  Install with: sudo apt-get install nvidia-cuda-toolkit (Ubuntu/Debian)"
        fi
    else
        log "No Nvidia GPU detected. Skipping CUDA setup."
    fi

    # ROCm
    if command -v rocm-smi &> /dev/null; then
        log "AMD GPU with ROCm detected. ROCm support will be enabled."
    else
        log "No AMD GPU with ROCm detected. Skipping ROCm setup."
    fi

    # Vulkan
    if command -v vulkaninfo &> /dev/null || lspci 2>/dev/null | grep -qiE "VGA|3D|Display"; then
        log "Vulkan-capable GPU detected."
        if ! command -v vulkaninfo &> /dev/null; then
            warning "vulkaninfo not found. Vulkan dev packages may not be installed."
            case "$platform" in
                ubuntu|debian)
                    echo "  Install with: sudo apt-get install libvulkan-dev glslang-tools"
                    ;;
                fedora)
                    echo "  Install with: sudo dnf install vulkan-loader-devel glslang"
                    ;;
                arch|manjaro)
                    echo "  Install with: sudo pacman -S vulkan-icd-loader vulkan-headers shaderc"
                    ;;
            esac
        fi
    fi
}

clone_repository() {
    log "Cloning Llama.cpp repository..."

    if [ -d "$CLONE_DIR" ]; then
        log "Repository already exists. Updating..."
        git -C "$CLONE_DIR" pull
    else
        log "Cloning from GitHub..."
        git clone https://github.com/ggml-org/llama.cpp "$CLONE_DIR"
    fi

    log "Repository cloned successfully"
}

build_lamacpp() {
    local platform=$1

    log "Building Llama.cpp..."

    # Create build directory
    mkdir -p "$BUILD_DIR"

    # Configure build based on platform and hardware
    log "Configuring build with hardware detection..."

    # Use -S (source) and -B (build) to avoid cd
    local cmake_args="-S $CLONE_DIR -B $BUILD_DIR -DCMAKE_BUILD_TYPE=${BUILD_TYPE}"

    log "GPU backend: ${GPU_BACKEND}"

    # ── GPU backend selection ──────────────────────────────────────────────
    if [ "$GPU_BACKEND" = "cpu" ]; then
        log "CPU-only build — skipping all GPU backends"
    elif [ "$GPU_BACKEND" = "cuda" ] || { [ "$GPU_BACKEND" = "auto" ] && command -v nvidia-smi &> /dev/null; }; then
        log "Adding CUDA support..."
        cmake_args="$cmake_args -DGGML_CUDA=ON"

        # CUDA architectures: use override or auto-detect from nvcc version
        local cuda_archs="${CUDA_ARCHITECTURES}"
        if [ -z "$cuda_archs" ] && command -v nvcc &> /dev/null; then
            local cuda_ver
            cuda_ver=$(nvcc --version | grep -oP 'release \K[0-9]+\.[0-9]+')
            local cuda_major=${cuda_ver%%.*}
            local cuda_minor=${cuda_ver#*.}
            log "Detected CUDA toolkit version: $cuda_ver"

            if [ "$cuda_major" -ge 13 ] || { [ "$cuda_major" -eq 12 ] && [ "$cuda_minor" -ge 8 ]; }; then
                cuda_archs="60;70;75;80;86;89;90;100;120"
            elif [ "$cuda_major" -eq 12 ] && [ "$cuda_minor" -ge 6 ]; then
                cuda_archs="60;70;75;80;86;89;90;100"
            elif [ "$cuda_major" -eq 12 ]; then
                cuda_archs="60;70;75;80;86;89;90"
            elif [ "$cuda_major" -eq 11 ]; then
                cuda_archs="60;70;75;80;86"
            else
                cuda_archs="60;70;75"
            fi
        fi

        if [ -n "$cuda_archs" ]; then
            cmake_args="$cmake_args -DCMAKE_CUDA_ARCHITECTURES='$cuda_archs'"
            log "CUDA architectures: $cuda_archs"
        fi

    elif [ "$GPU_BACKEND" = "rocm" ] || { [ "$GPU_BACKEND" = "auto" ] && command -v rocm-smi &> /dev/null && command -v hipconfig &> /dev/null; }; then
        log "Adding ROCm/HIP support..."
        cmake_args="$cmake_args -DGGML_HIP=ON"

    elif [ "$GPU_BACKEND" = "vulkan" ] || [ "$GPU_BACKEND" = "auto" ]; then
        # Vulkan: check dev headers + glslc shader compiler
        local vulkan_dev=false
        if command -v pkg-config &> /dev/null && pkg-config --exists vulkan 2>/dev/null; then
            vulkan_dev=true
        elif [ -f /usr/include/vulkan/vulkan.h ] || [ -f /usr/local/include/vulkan/vulkan.h ]; then
            vulkan_dev=true
        elif ldconfig -p 2>/dev/null | grep -q libvulkan; then
            vulkan_dev=true
        fi

        if [ "$GPU_BACKEND" = "vulkan" ] || { [ "$vulkan_dev" = true ] && command -v glslc &> /dev/null; }; then
            log "Adding Vulkan support..."
            cmake_args="$cmake_args -DGGML_VULKAN=ON"
        elif [ "$vulkan_dev" = true ]; then
            warning "Vulkan dev headers found but glslc missing. Skipping Vulkan. Install: sudo apt-get install glslc"
        fi

    elif [ "$GPU_BACKEND" = "sycl" ]; then
        log "Adding SYCL support (Intel GPU)..."
        cmake_args="$cmake_args -DGGML_SYCL=ON"

    elif [ "$GPU_BACKEND" = "opencl" ]; then
        log "Adding OpenCL support..."
        cmake_args="$cmake_args -DGGML_OPENCL=ON"
    fi

    # macOS Metal (always enabled on macOS unless CPU-only)
    if [[ "$OSTYPE" == "darwin"* ]] && [ "$GPU_BACKEND" != "cpu" ]; then
        log "Adding Metal support..."
        cmake_args="$cmake_args -DGGML_METAL=ON"
    fi

    # ── CPU / BLAS options ─────────────────────────────────────────────────
    cmake_args="$cmake_args -DGGML_NATIVE=${GGML_NATIVE}"

    if [ "${BLAS_VENDOR}" != "None" ]; then
        cmake_args="$cmake_args -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=${BLAS_VENDOR}"
        log "BLAS vendor: ${BLAS_VENDOR}"
    fi

    # Build
    log "Running cmake configuration..."
    eval cmake "$cmake_args"

    log "Building with parallel jobs (using $(nproc) cores)..."
    cmake --build "$BUILD_DIR" --config Release -j "$(nproc)"

    log "Build completed successfully"
}

install_binaries() {
    log "Installing Llama.cpp..."

    # Create installation directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/models"
    mkdir -p "$INSTALL_DIR/logs"

    # Copy binaries
    if [ -d "$BUILD_DIR/bin" ]; then
        cp -r "$BUILD_DIR/bin/"* "$INSTALL_DIR/bin/"
    fi

    # Create symlinks in ~/.local/bin (create if needed)
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    ln -sf "$INSTALL_DIR/bin/llama-server" "$bin_dir/llama-server"
    ln -sf "$INSTALL_DIR/bin/llama-cli" "$bin_dir/llama-cli"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        warning "$bin_dir is not in your PATH"
        echo "  Add it by running: export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "  Or add that line to your ~/.bashrc or ~/.zshrc"
    fi

    log "Installation completed successfully"
}

create_config() {
    log "Creating default configuration..."

    cat > "$INSTALL_DIR/config/default.yaml" <<EOF
# Llama.cpp Configuration
# This file contains default configuration settings

# Model settings
model_path: "$INSTALL_DIR/models"
model_name: ""
model_file: ""

# Server settings
host: "0.0.0.0"
port: 8080
ssl: false

# Hardware settings
ngl: 99  # Number of GPU layers to offload
context_size: 2048

# Performance settings
threads: $(nproc)
batch_size: 512

# Logging
log_level: "info"
log_file: "$INSTALL_DIR/logs/llama-server.log"

# Unified Memory for CUDA
unified_memory: true
EOF

    log "Configuration file created"
}

cleanup() {
    log "Cleaning up temporary files..."

    # Keep source for potential rebuilds
    # rm -rf "$BUILD_DIR"
    # rm -rf "$CLONE_DIR"

    log "Cleanup completed"
}

main() {
    echo "=========================================="
    echo "  Llama.cpp Installation Script"
    echo "=========================================="
    echo ""

    # Detect platform
    local platform=$(detect_platform)
    log "Platform detected: $platform"

    # Create log directory and file
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"

    # Check dependencies (advise on missing ones)
    check_dependencies "$platform"

    # Check GPU support (advise on missing packages)
    check_gpu_support "$platform"

    # Clone repository
    clone_repository

    # Build Llama.cpp
    build_lamacpp "$platform"

    # Install binaries
    install_binaries

    # Create configuration
    create_config

    # Cleanup
    cleanup

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo "=========================================="
    echo ""
    echo "Llama.cpp has been installed to: $INSTALL_DIR"
    echo ""
    echo "To use Llama.cpp:"
    echo "  llama-server --help"
    echo "  llama-cli --help"
    echo ""
    echo "To download models from HuggingFace:"
    echo "  llama-server --model /path/to/model.gguf -hf <model-name>"
    echo ""
    echo "See $LOG_FILE for detailed installation logs"
}

# Run main function
main "$@"
