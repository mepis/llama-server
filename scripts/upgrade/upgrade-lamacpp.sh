#!/bin/bash

# Llama.cpp Upgrade Script
# This script upgrades existing Llama.cpp installations

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CURRENT_INSTALL_DIR="${CURRENT_INSTALL_DIR:-/opt/llama-cpp}"
BACKUP_DIR="${BACKUP_DIR:-/opt/llama-cpp-backup}"
SOURCE_DIR="${SOURCE_DIR:-/tmp/llama-cpp}"
BUILD_DIR="${BUILD_DIR:-/tmp/llama-cpp-upgrade-build}"
LOG_FILE="${LOG_FILE:-/var/log/llama-cpp-upgrade.log}"

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root or use sudo"
        exit 1
    fi
}

check_installation() {
    if [ ! -d "$CURRENT_INSTALL_DIR" ]; then
        error "Llama.cpp not installed in $CURRENT_INSTALL_DIR"
        error "Please run the installation script first"
        exit 1
    fi

    if [ ! -f "$CURRENT_INSTALL_DIR/bin/llama-server" ]; then
        error "Llama.cpp binaries not found in $CURRENT_INSTALL_DIR/bin"
        exit 1
    fi

    log "Existing installation found at $CURRENT_INSTALL_DIR"
}

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)

    log "Creating backup... (this may take a while)"

    mkdir -p "$BACKUP_DIR"

    # Backup entire installation
    tar -czf "$BACKUP_DIR/llama-cpp-backup-$timestamp.tar.gz" -C "$CURRENT_INSTALL_DIR" .

    # Also backup configuration
    if [ -d "$CURRENT_INSTALL_DIR/config" ]; then
        tar -czf "$BACKUP_DIR/llama-cpp-config-$timestamp.tar.gz" -C "$CURRENT_INSTALL_DIR" config
    fi

    # Backup models
    if [ -d "$CURRENT_INSTALL_DIR/models" ]; then
        tar -czf "$BACKUP_DIR/llama-cpp-models-$timestamp.tar.gz" -C "$CURRENT_INSTALL_DIR" models
    fi

    log "Backup created: $BACKUP_DIR/llama-cpp-backup-$timestamp.tar.gz"
}

stop_services() {
    log "Stopping Llama.cpp services..."

    # Stop systemd service if running
    if systemctl is-active --quiet llama-server; then
        systemctl stop llama-server
        log "Systemd service stopped"
    fi

    # Find and kill llama-server processes
    pkill -f llama-server || true
    log "All llama-server processes stopped"
}

backup_old_binaries() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUP_DIR/binaries-$timestamp"

    mkdir -p "$backup_dir"

    if [ -d "$CURRENT_INSTALL_DIR/bin" ]; then
        cp -r "$CURRENT_INSTALL_DIR/bin" "$backup_dir/"
        log "Old binaries backed up to $backup_dir"
    fi

    if [ -d "$CURRENT_INSTALL_DIR/lib" ]; then
        cp -r "$CURRENT_INSTALL_DIR/lib" "$backup_dir/"
        log "Old libraries backed up to $backup_dir"
    fi

    if [ -d "$CURRENT_INSTALL_DIR/include" ]; then
        cp -r "$CURRENT_INSTALL_DIR/include" "$backup_dir/"
        log "Old include files backed up to $backup_dir"
    fi
}

clone_repository() {
    log "Cloning updated Llama.cpp repository..."

    cd /tmp

    if [ -d "$SOURCE_DIR" ]; then
        log "Repository already exists. Updating..."
        cd "$SOURCE_DIR"
        git pull
    else
        log "Cloning from GitHub..."
        git clone https://github.com/ggml-org/llama.cpp "$SOURCE_DIR"
    fi

    log "Repository updated successfully"
}

detect_hardware() {
    log "Detecting hardware for new build..."

    local hardware=()
    local cuda=false
    local rocm=false
    local vulkan=false
    local metal=false

    # CPU
    info "CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)"
    info "CPU Cores: $(nproc)"

    # GPU Detection
    if command -v nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader)
        info "Nvidia GPU: $gpu_info"
        cuda=true
    fi

    if command -v rocm-smi &> /dev/null; then
        gpu_info=$(rocm-smi --showlibver | grep -E "HIP version|ROCm version" | head -2)
        info "AMD GPU: $gpu_info"
        rocm=true
    fi

    if command -v vulkaninfo &> /dev/null; then
        gpu_info=$(vulkaninfo --summary | grep -E "GPU name|deviceName" | head -2)
        info "Vulkan GPU: $gpu_info"
        vulkan=true
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v sysctl &> /dev/null && sysctl -n machdep.cpu.brand_string | grep -iq "apple"; then
            info "Apple Silicon detected"
            metal=true
        fi
    fi

    # Save hardware configuration
    cat > "$BUILD_DIR/hardware_config.txt" <<EOF
Hardware Configuration
====================
Date: $(date)
OS: $OSTYPE
CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)
CPU Cores: $(nproc)
CUDA: $cuda
ROCm: $rocm
Vulkan: $vulkan
Metal: $metal
EOF

    echo "cuda=$cuda" >> "$BUILD_DIR/hardware_config.txt"
    echo "rocm=$rocm" >> "$BUILD_DIR/hardware_config.txt"
    echo "vulkan=$vulkan" >> "$BUILD_DIR/hardware_config.txt"
    echo "metal=$metal" >> "$BUILD_DIR/hardware_config.txt"

    log "Hardware detection completed"
}

configure_build() {
    log "Configuring build..."

    cd "$BUILD_DIR"

    # Start with basic configuration
    local cmake_args="-B . -DCMAKE_BUILD_TYPE=Release -DGGML_LOG_LEVEL=info -DGGML_NATIVE=OFF"

    # Add backend support based on detected hardware
    if command -v nvidia-smi &> /dev/null; then
        log "Enabling CUDA support..."
        cmake_args="$cmake_args -DGGML_CUDA=ON"
    fi

    if command -v rocm-smi &> /dev/null; then
        log "Enabling ROCm support..."
        HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -p)" \
            cmake_args="$cmake_args -DGGML_HIP=ON -DGPU_TARGETS=$(rocm-smi --showabi | head -1)"
    fi

    if command -v vulkaninfo &> /dev/null; then
        log "Enabling Vulkan support..."
        cmake_args="$cmake_args -DGGML_VULKAN=ON"
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v sysctl &> /dev/null && sysctl -n machdep.cpu.brand_string | grep -iq "apple"; then
            log "Enabling Metal support..."
            cmake_args="$cmake_args -DGGML_METAL=ON"
        fi
    fi

    # Add BLAS support for CPU
    cmake_args="$cmake_args -DGGML_BLAS=ON"

    # Ask about Unified Memory for CUDA
    read -p "Enable CUDA Unified Memory support? [y/N]: " enable_unified_memory
    if [[ "$enable_unified_memory" =~ ^[Yy]$ ]]; then
        cmake_args="$cmake_args -DGGML_CUDA_ENABLE_UNIFIED_MEMORY=ON"
        log "CUDA Unified Memory enabled"
    fi

    # Ask about additional optimizations
    read -p "Enable AVX2 optimization? [Y/n]: " enable_avx2
    if [[ "$enable_avx2" =~ ^[Nn]$ ]]; then
        cmake_args="$cmake_args -DGGML_NATIVE=OFF"
    else
        cmake_args="$cmake_args -DGGML_NATIVE=ON"
    fi

    # Ask about BLIS
    read -p "Enable BLIS optimization? [y/N]: " enable_blis
    if [[ "$enable_blis" =~ ^[Yy]$ ]]; then
        cmake_args="$cmake_args -DGGML_BLAS_VENDOR=BLIS"
    fi

    # Ask about Intel oneMKL
    if command -v icx &> /dev/null; then
        read -p "Enable Intel oneMKL support? [y/N]: " enable_intel
        if [[ "$enable_intel" =~ ^[Yy]$ ]]; then
            cmake_args="$cmake_args -DGGML_BLAS_VENDOR=Intel10_64lp -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx"
            log "Intel oneMKL enabled"
        fi
    fi

    # Ask about static build
    read -p "Build static library? [y/N]: " enable_static
    if [[ "$enable_static" =~ ^[Yy]$ ]]; then
        cmake_args="$cmake_args -DBUILD_SHARED_LIBS=OFF"
        log "Static build enabled"
    fi

    # Execute cmake
    info "Running: cmake $cmake_args"
    eval cmake $cmake_args

    if [ $? -ne 0 ]; then
        error "CMake configuration failed"
        exit 1
    fi

    log "Build configuration completed"
}

compile_project() {
    log "Starting compilation..."

    cd "$BUILD_DIR"

    # Determine number of parallel jobs
    local parallel_jobs=$(nproc)
    info "Using $parallel_jobs parallel jobs"

    # Build
    cmake --build . --config Release -j $parallel_jobs

    if [ $? -ne 0 ]; then
        error "Compilation failed"
        exit 1
    fi

    log "Compilation completed successfully"
}

install_new_binaries() {
    log "Installing new binaries..."

    # Create installation directory
    mkdir -p "$CURRENT_INSTALL_DIR"
    mkdir -p "$CURRENT_INSTALL_DIR/bin"
    mkdir -p "$CURRENT_INSTALL_DIR/lib"
    mkdir -p "$CURRENT_INSTALL_DIR/include"

    # Copy new binaries
    if [ -d "$BUILD_DIR/bin" ]; then
        cp -r "$BUILD_DIR/bin/"* "$CURRENT_INSTALL_DIR/bin/"
        log "New binaries installed to $CURRENT_INSTALL_DIR/bin"
    fi

    # Copy new libraries
    if [ -d "$BUILD_DIR/lib" ]; then
        cp -r "$BUILD_DIR/lib/"* "$CURRENT_INSTALL_DIR/lib/"
        log "New libraries installed to $CURRENT_INSTALL_DIR/lib"
    fi

    # Copy new include files
    if [ -d "$BUILD_DIR/include" ]; then
        cp -r "$BUILD_DIR/include/"* "$CURRENT_INSTALL_DIR/include/"
        log "New include files installed to $CURRENT_INSTALL_DIR/include"
    fi

    # Copy static libraries
    if [ -d "$BUILD_DIR" ]; then
        find "$BUILD_DIR" -name "*.a" -exec cp {} "$CURRENT_INSTALL_DIR/lib/" \;
        log "New static libraries installed"
    fi

    # Create symlinks
    ln -sf "$CURRENT_INSTALL_DIR/bin/llama-server" /usr/local/bin/llama-server
    ln -sf "$CURRENT_INSTALL_DIR/bin/llama-cli" /usr/local/bin/llama-cli

    log "Installation completed"
}

restore_configuration() {
    log "Restoring configuration..."

    # Check if backup exists
    local latest_config=$(ls -t "$BACKUP_DIR"/*config-*.tar.gz 2>/dev/null | head -1)

    if [ -n "$latest_config" ]; then
        tar -xzf "$latest_config" -C "$CURRENT_INSTALL_DIR"
        log "Configuration restored from $latest_config"
    else
        warning "No configuration backup found"
    fi

    # Restore models
    local latest_models=$(ls -t "$BACKUP_DIR"/*models-*.tar.gz 2>/dev/null | head -1)

    if [ -n "$latest_models" ]; then
        tar -xzf "$latest_models" -C "$CURRENT_INSTALL_DIR"
        log "Models restored from $latest_models"
    fi
}

create_config() {
    log "Creating default configuration..."

    cat > "$CURRENT_INSTALL_DIR/config/default.yaml" <<EOF
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

verify_installation() {
    log "Verifying installation..."

    if [ ! -f "$CURRENT_INSTALL_DIR/bin/llama-server" ]; then
        error "llama-server binary not found"
        return 1
    fi

    if [ ! -f "$CURRENT_INSTALL_DIR/bin/llama-cli" ]; then
        error "llama-cli binary not found"
        return 1
    fi

    # Check version
    version=$("$CURRENT_INSTALL_DIR/bin/llama-server" --version 2>&1 | head -1 || echo "Unknown version")
    info "Version: $version"

    log "Installation verified successfully"
}

cleanup() {
    log "Cleaning up temporary files..."

    # Keep build directory for potential rebuilds
    # rm -rf "$BUILD_DIR"

    log "Cleanup completed"
}

show_summary() {
    log "Upgrade Summary:"
    echo ""
    echo "=========================================="
    echo "  Upgrade Summary"
    echo "=========================================="
    echo ""

    if [ -f "$BUILD_DIR/hardware_config.txt" ]; then
        echo "New Hardware Configuration:"
        cat "$BUILD_DIR/hardware_config.txt"
        echo ""
    fi

    echo "Installation Directory: $CURRENT_INSTALL_DIR"
    echo "Backup Directory: $BACKUP_DIR"
    echo ""
    echo "Binaries:"
    if [ -d "$CURRENT_INSTALL_DIR/bin" ]; then
        ls -lh "$CURRENT_INSTALL_DIR/bin/" 2>/dev/null | awk '{print "  " $9, "(" $5 ")"}'
    fi
    echo ""
    echo "=========================================="
}

main() {
    echo "=========================================="
    echo "  Llama.cpp Upgrade Script"
    echo "=========================================="
    echo ""

    # Check root
    check_root

    # Create log file
    touch "$LOG_FILE"

    # Check if installation exists
    check_installation

    # Ask for confirmation
    read -p "This will upgrade your Llama.cpp installation. Continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        error "Upgrade cancelled"
        exit 0
    fi

    # Create backup
    create_backup

    # Stop services
    stop_services

    # Backup old binaries
    backup_old_binaries

    # Clone repository
    clone_repository

    # Detect hardware
    detect_hardware

    # Configure build
    configure_build

    # Compile project
    compile_project

    # Install new binaries
    install_new_binaries

    # Restore configuration
    restore_configuration

    # Create config
    create_config

    # Create service
    create_service

    # Verify installation
    verify_installation

    # Cleanup
    cleanup

    # Show summary
    show_summary

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Upgrade completed successfully!${NC}"
    echo "=========================================="
    echo ""
    echo "Your Llama.cpp installation has been upgraded to the latest version"
    echo ""
    echo "To start the server:"
    echo "  llama-server --help"
    echo "  llama-server --model /path/to/model.gguf"
    echo ""
    echo "To start the server as a service:"
    echo "  sudo systemctl start llama-server"
    echo "  sudo systemctl enable llama-server"
    echo ""
    echo "To see the logs:"
    echo "  sudo journalctl -u llama-server -f"
    echo ""
    echo "If you encounter any issues, restore from backup:"
    echo "  sudo systemctl stop llama-server"
    echo "  sudo tar -xzf $BACKUP_DIR/llama-cpp-backup-*.tar.gz -C /opt"
    echo ""
    echo "See $LOG_FILE for detailed upgrade logs"
}

# Run main function
main "$@"