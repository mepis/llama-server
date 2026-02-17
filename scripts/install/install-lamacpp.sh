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
INSTALL_DIR="${INSTALL_DIR:-/opt/llama-cpp}"
CLONE_DIR="${CLONE_DIR:-/tmp/llama-cpp}"
BUILD_DIR="${BUILD_DIR:-/tmp/llama-cpp-build}"
LOG_FILE="${LOG_FILE:-/var/log/llama-cpp-install.log}"

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root or use sudo"
        exit 1
    fi
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

install_dependencies() {
    local platform=$1

    log "Installing dependencies for $platform..."

    case "$platform" in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                git \
                cmake \
                build-essential \
                wget \
                curl \
                libssl-dev \
                nvidia-cuda-toolkit \
                rocm-dev \
                vulkan-loader-dev \
                libvulkan-dev \
                glslc
            ;;
        fedora|rhel|rocky|almalinux)
            dnf install -y \
                git \
                cmake \
                gcc \
                gcc-c++ \
                make \
                wget \
                curl \
                openssl-devel \
                cuda \
                mesa-libGL-devel \
                vulkan-loader-devel \
                shaderc
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm \
                git \
                cmake \
                base-devel \
                wget \
                curl \
                openssl \
                vulkan-tools \
                mesa
            ;;
        alpine)
            apk add --no-cache \
                git \
                cmake \
                build-base \
                wget \
                curl \
                openssl-dev \
                mesa-gl \
                vulkan-loader-dev
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install cmake git wget curl
            else
                warning "Homebrew not found. Please install Homebrew first."
                exit 1
            fi
            ;;
        windows)
            warning "Windows installation requires manual setup. Please refer to build documentation."
            exit 1
            ;;
    esac

    log "Dependencies installed successfully"
}

setup_cuda() {
    if command -v nvidia-smi &> /dev/null; then
        log "CUDA detected. Setting up CUDA support..."
        if [[ "$platform" == "ubuntu" ]] || [[ "$platform" == "debian" ]]; then
            apt-get install -y nvidia-cuda-toolkit
        elif [[ "$platform" == "fedora" ]]; then
            dnf install -y cuda
        fi
        log "CUDA support configured"
    else
        warning "No CUDA detected. CUDA support will not be available."
    fi
}

setup_rocm() {
    if command -v rocm-smi &> /dev/null; then
        log "ROCm detected. Setting up ROCm support..."
        if [[ "$platform" == "ubuntu" ]] || [[ "$platform" == "debian" ]]; then
            apt-get install -y rocm-dev
        fi
        log "ROCm support configured"
    else
        warning "No ROCm detected. ROCm support will not be available."
    fi
}

setup_vulkan() {
    if command -v vulkaninfo &> /dev/null; then
        log "Vulkan detected. Setting up Vulkan support..."
        if [[ "$platform" == "ubuntu" ]] || [[ "$platform" == "debian" ]]; then
            apt-get install -y libvulkan-dev glslc
        elif [[ "$platform" == "fedora" ]]; then
            dnf install -y vulkan-loader-devel shaderc
        fi
        log "Vulkan support configured"
    else
        warning "No Vulkan detected. Vulkan support will not be available."
    fi
}

clone_repository() {
    log "Cloning Llama.cpp repository..."

    cd /tmp
    if [ -d "$CLONE_DIR" ]; then
        log "Repository already exists. Updating..."
        cd "$CLONE_DIR"
        git pull
    else
        log "Cloning from GitHub..."
        git clone https://github.com/ggml-org/llama.cpp "$CLONE_DIR"
    fi

    log "Repository cloned successfully"
}

build_lamacpp() {
    local platform=$1

    log "Building Llama.cpp..."

    cd "$CLONE_DIR"

    # Create build directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Configure build based on platform and hardware
    log "Configuring build with hardware detection..."

    local cmake_args="-B . -DCMAKE_BUILD_TYPE=Release -DGGML_LOG_LEVEL=info"

    # Add GPU support based on detection
    if command -v nvidia-smi &> /dev/null; then
        log "Adding CUDA support..."
        cmake_args="$cmake_args -DGGML_CUDA=ON"
    fi

    if command -v rocm-smi &> /dev/null; then
        log "Adding ROCm support..."
        cmake_args="$cmake_args -DGGML_HIP=ON"
    fi

    if command -v vulkaninfo &> /dev/null; then
        log "Adding Vulkan support..."
        cmake_args="$cmake_args -DGGML_VULKAN=ON"
    fi

    # Add BLAS support for CPU
    cmake_args="$cmake_args -DGGML_BLAS=ON"

    # Build
    log "Running cmake..."
    eval cmake $cmake_args

    log "Building with parallel jobs (using $(nproc) cores)..."
    cmake --build . --config Release -j $(nproc)

    log "Build completed successfully"
}

install_to_system() {
    log "Installing Llama.cpp to system..."

    # Create installation directory
    mkdir -p "$INSTALL_DIR"

    # Copy binaries
    if [ -d "$BUILD_DIR" ]; then
        cp -r "$BUILD_DIR/bin" "$INSTALL_DIR/"
    fi

    # Create configuration directory
    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/models"
    mkdir -p "$INSTALL_DIR/logs"

    # Create symlink for main binary
    ln -sf "$INSTALL_DIR/bin/llama-server" /usr/local/bin/llama-server

    # Create symlink for CLI
    ln -sf "$INSTALL_DIR/bin/llama-cli" /usr/local/bin/llama-cli

    log "Installation completed successfully"
}

create_config() {
    log "Creating default configuration..."

    cat > "$INSTALL_DIR/config/default.yaml" <<EOF
# Llama.cpp Configuration
# This file contains default configuration settings

# Model settings
model_path: "/opt/llama-cpp/models"
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
log_file: "/opt/llama-cpp/logs/llama-server.log"

# Unified Memory for CUDA
unified_memory: true
EOF

    log "Configuration file created"
}

create_service() {
    log "Creating systemd service..."

    cat > /etc/systemd/system/llama-server.service <<EOF
[Unit]
Description=Llama.cpp Server
After=network.target

[Service]
Type=simple
User=llama
Group=llama
WorkingDirectory=/opt/llama-cpp
Environment="PATH=/usr/local/bin:\${PATH}"
ExecStart=/usr/local/bin/llama-server --config /opt/llama-cpp/config/default.yaml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log "Systemd service created"
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

    # Check root
    check_root

    # Detect platform
    local platform=$(detect_platform)
    log "Platform detected: $platform"

    # Create log file
    touch "$LOG_FILE"

    # Install dependencies
    install_dependencies "$platform"

    # Setup GPU support
    setup_cuda
    setup_rocm
    setup_vulkan

    # Clone repository
    clone_repository

    # Build Llama.cpp
    build_lamacpp "$platform"

    # Install to system
    install_to_system

    # Create configuration
    create_config

    # Create service (on Linux)
    if [[ "$platform" == "ubuntu" ]] || [[ "$platform" == "debian" ]] || [[ "$platform" == "fedora" ]] || [[ "$platform" == "arch" ]]; then
        create_service
    fi

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
    echo "To start the server as a service:"
    echo "  sudo systemctl start llama-server"
    echo "  sudo systemctl enable llama-server"
    echo ""
    echo "To download models from HuggingFace:"
    echo "  llama-server --model /path/to/model.gguf -hf <model-name>"
    echo ""
    echo "See $LOG_FILE for detailed installation logs"
}

# Run main function
main "$@"