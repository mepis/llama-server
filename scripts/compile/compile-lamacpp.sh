#!/bin/bash

# Llama.cpp Compilation Script
# This script compiles Llama.cpp with support for various hardware backends

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_DIR="${SOURCE_DIR:-$HOME/.local/llama-cpp/src}"
BUILD_DIR="${BUILD_DIR:-$HOME/.local/llama-cpp/build}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/llama-cpp}"
LOG_DIR="${INSTALL_DIR}/logs"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/compile.log}"

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

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null
}

check_dependencies() {
    log "Checking build dependencies..."

    local missing_deps=()

    for cmd in git cmake gcc g++; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
        error "Please install them using your package manager:"
        error "  Ubuntu/Debian: sudo apt-get install git cmake build-essential"
        error "  Fedora: sudo dnf install git cmake gcc gcc-c++ make"
        exit 1
    fi

    log "All dependencies are installed"
}

detect_hardware() {
    log "Detecting hardware..."

    local hardware=()
    local cuda=false
    local rocm=false
    local vulkan=false
    local metal=false
    local apple_silicon=false

    # CPU
    info "CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)"
    info "CPU Cores: $(nproc)"
    info "CPU Flags: $(grep -oP 'avx2|avx512|sse4_2|fma|avx_vnni' /proc/cpuinfo | sort -u | xargs)"

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
            apple_silicon=true
        fi
    fi

    # Save hardware configuration (ensure build dir exists first)
    mkdir -p "$BUILD_DIR"
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
Apple Silicon: $apple_silicon
EOF

    echo "cuda=$cuda" >> "$BUILD_DIR/hardware_config.txt"
    echo "rocm=$rocm" >> "$BUILD_DIR/hardware_config.txt"
    echo "vulkan=$vulkan" >> "$BUILD_DIR/hardware_config.txt"
    echo "metal=$metal" >> "$BUILD_DIR/hardware_config.txt"

    log "Hardware detection completed"
}

show_compilation_options() {
    echo ""
    echo "=========================================="
    echo "  Compilation Options"
    echo "=========================================="
    echo ""
    echo "Available backends:"
    echo "  [1] All backends (recommended for most systems)"
    echo "  [2] CPU only"
    echo "  [3] CUDA (Nvidia GPU)"
    echo "  [4] ROCm (AMD GPU)"
    echo "  [5] Vulkan (Cross-platform GPU)"
    echo "  [6] Metal (Apple Silicon)"
    echo "  [7] Custom configuration"
    echo ""
    read -p "Select compilation option [1-7]: " choice

    case $choice in
        1)
            BACKENDS="CUDA ROCm Vulkan Metal"
            ;;
        2)
            BACKENDS=""
            info "Building with CPU only"
            ;;
        3)
            BACKENDS="CUDA"
            info "Building with CUDA support"
            ;;
        4)
            BACKENDS="ROCm"
            info "Building with ROCm support"
            ;;
        5)
            BACKENDS="Vulkan"
            info "Building with Vulkan support"
            ;;
        6)
            BACKENDS="Metal"
            info "Building with Metal support"
            ;;
        7)
            read -p "Enter CMake arguments: " cmake_args
            BACKENDS=""
            ;;
        *)
            error "Invalid selection"
            exit 1
            ;;
    esac
}

configure_build() {
    log "Configuring build..."

    # Ensure build directory exists before using it
    mkdir -p "$BUILD_DIR"

    # Start with basic configuration: source dir is SOURCE_DIR, build dir is BUILD_DIR
    local cmake_args="-S $SOURCE_DIR -B $BUILD_DIR -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF"

    # Track ROCm environment variables separately
    local rocm_env=""

    # Add backend support
    for backend in $BACKENDS; do
        case $backend in
            CUDA)
                if command -v nvidia-smi &> /dev/null; then
                    log "Enabling CUDA support..."
                    cmake_args="$cmake_args -DGGML_CUDA=ON"

                    # Set compatible CUDA architectures based on toolkit version
                    if command -v nvcc &> /dev/null; then
                        local cuda_ver
                        cuda_ver=$(nvcc --version | grep -oP 'release \K[0-9]+\.[0-9]+')
                        local cuda_major=${cuda_ver%%.*}
                        local cuda_minor=${cuda_ver#*.}
                        log "Detected CUDA toolkit version: $cuda_ver"

                        local cuda_archs=""
                        if [ "$cuda_major" -ge 13 ] || { [ "$cuda_major" -eq 12 ] && [ "$cuda_minor" -ge 8 ]; }; then
                            cuda_archs="60;70;75;80;86;89;90;100;120"
                        elif [ "$cuda_major" -eq 12 ] && [ "$cuda_minor" -ge 6 ]; then
                            cuda_archs="60;70;75;80;86;89;90;100"
                        elif [ "$cuda_major" -eq 12 ] && [ "$cuda_minor" -ge 4 ]; then
                            cuda_archs="60;70;75;80;86;89;90"
                        elif [ "$cuda_major" -eq 12 ]; then
                            cuda_archs="60;70;75;80;86;89;90"
                        elif [ "$cuda_major" -eq 11 ]; then
                            cuda_archs="60;70;75;80;86"
                        else
                            cuda_archs="60;70;75"
                        fi

                        cmake_args="$cmake_args -DCMAKE_CUDA_ARCHITECTURES=$cuda_archs"
                        log "Setting CUDA architectures: $cuda_archs"
                    fi
                else
                    warning "CUDA not detected, skipping CUDA support"
                fi
                ;;
            ROCm)
                if command -v rocm-smi &> /dev/null && command -v hipconfig &> /dev/null; then
                    log "Enabling ROCm support..."
                    local hipcxx="$(hipconfig -l)/clang"
                    local hip_path="$(hipconfig -p)"
                    local gpu_targets="$(rocm-smi --showabi 2>/dev/null | grep -oE 'gfx[0-9]+' | head -1 || echo 'gfx900')"
                    rocm_env="HIPCXX=$hipcxx HIP_PATH=$hip_path"
                    cmake_args="$cmake_args -DGGML_HIP=ON -DGPU_TARGETS=$gpu_targets"
                else
                    warning "ROCm not detected, skipping ROCm support"
                fi
                ;;
            Vulkan)
                if command -v vulkaninfo &> /dev/null; then
                    log "Enabling Vulkan support..."
                    cmake_args="$cmake_args -DGGML_VULKAN=ON"
                else
                    warning "Vulkan not detected, skipping Vulkan support"
                fi
                ;;
            Metal)
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    log "Enabling Metal support..."
                    cmake_args="$cmake_args -DGGML_METAL=ON"
                else
                    warning "Metal only available on macOS, skipping Metal support"
                fi
                ;;
        esac
    done

    # Add BLAS support for CPU
    cmake_args="$cmake_args -DGGML_BLAS=ON"

    # Ask about Unified Memory for CUDA (only when CUDA is in BACKENDS)
    if echo "$BACKENDS" | grep -q "CUDA"; then
        read -p "Enable CUDA Unified Memory support? (recommended for systems with limited GPU memory) [y/N]: " enable_unified_memory
        if [[ "$enable_unified_memory" =~ ^[Yy]$ ]]; then
            cmake_args="$cmake_args -DGGML_CUDA_ENABLE_UNIFIED_MEMORY=ON"
            log "CUDA Unified Memory enabled"
        fi
    fi

    # Ask about additional optimizations
    read -p "Enable native CPU optimizations (AVX2/AVX-512/NEON)? [Y/n]: " enable_native
    if [[ "$enable_native" =~ ^[Nn]$ ]]; then
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

    # Execute cmake (with optional ROCm environment variables)
    info "Running: ${rocm_env:+$rocm_env }cmake $cmake_args"
    if [ -n "$rocm_env" ]; then
        eval "$rocm_env cmake $cmake_args"
    else
        eval cmake "$cmake_args"
    fi

    if [ $? -ne 0 ]; then
        error "CMake configuration failed"
        exit 1
    fi

    log "Build configuration completed"
}

compile_project() {
    log "Starting compilation..."

    # Determine number of parallel jobs
    local parallel_jobs=$(nproc)
    info "Using $parallel_jobs parallel jobs"

    # Build using the build directory directly (no cd needed)
    cmake --build "$BUILD_DIR" --config Release -j "$parallel_jobs"

    if [ $? -ne 0 ]; then
        error "Compilation failed"
        exit 1
    fi

    log "Compilation completed successfully"
}

install_binaries() {
    log "Installing binaries..."

    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$INSTALL_DIR/lib"
    mkdir -p "$INSTALL_DIR/include"

    # Copy binaries
    if [ -d "$BUILD_DIR/bin" ]; then
        cp -r "$BUILD_DIR/bin/"* "$INSTALL_DIR/bin/"
        log "Binaries installed to $INSTALL_DIR/bin"
    fi

    # Copy libraries
    if [ -d "$BUILD_DIR/lib" ]; then
        cp -r "$BUILD_DIR/lib/"* "$INSTALL_DIR/lib/"
        log "Libraries installed to $INSTALL_DIR/lib"
    fi

    # Copy include files
    if [ -d "$BUILD_DIR/include" ]; then
        cp -r "$BUILD_DIR/include/"* "$INSTALL_DIR/include/"
        log "Include files installed to $INSTALL_DIR/include"
    fi

    # Copy static libraries
    if [ -d "$BUILD_DIR" ]; then
        find "$BUILD_DIR" -name "*.a" -exec cp {} "$INSTALL_DIR/lib/" \;
        log "Static libraries installed"
    fi

    # Create symlinks in ~/.local/bin
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

    log "Installation completed"
}

show_summary() {
    log "Build Summary:"
    echo ""
    echo "=========================================="
    echo "  Build Summary"
    echo "=========================================="
    echo ""

    if [ -f "$BUILD_DIR/hardware_config.txt" ]; then
        echo "Hardware Configuration:"
        cat "$BUILD_DIR/hardware_config.txt"
        echo ""
    fi

    echo "Build Directory: $BUILD_DIR"
    echo "Install Directory: $INSTALL_DIR"
    echo ""
    echo "Binaries:"
    if [ -d "$INSTALL_DIR/bin" ]; then
        ls -lh "$INSTALL_DIR/bin/" 2>/dev/null | awk '{print "  " $9, "(" $5 ")"}'
    fi
    echo ""
    echo "Libraries:"
    if [ -d "$INSTALL_DIR/lib" ]; then
        ls -lh "$INSTALL_DIR/lib/" 2>/dev/null | awk '{print "  " $9, "(" $5 ")"}'
    fi
    echo ""
    echo "Include Files:"
    if [ -d "$INSTALL_DIR/include" ]; then
        ls "$INSTALL_DIR/include/" 2>/dev/null | awk '{print "  " $1}'
    fi
    echo ""
    echo "=========================================="
}

cleanup() {
    log "Cleaning up temporary files..."

    # Keep build directory for potential rebuilds
    # rm -rf "$BUILD_DIR"

    log "Cleanup completed"
}

main() {
    echo "=========================================="
    echo "  Llama.cpp Compilation Script"
    echo "=========================================="
    echo ""

    # Create log directory and file
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"

    # Check dependencies
    check_dependencies

    # Clone repository if not exists
    if [ ! -d "$SOURCE_DIR" ]; then
        log "Cloning Llama.cpp repository..."
        git clone https://github.com/ggml-org/llama.cpp "$SOURCE_DIR"
    else
        log "Repository already exists. Updating..."
        git -C "$SOURCE_DIR" pull
    fi

    # Detect hardware
    detect_hardware

    # Show compilation options
    show_compilation_options

    # Configure build
    configure_build

    # Compile project
    compile_project

    # Install binaries
    install_binaries

    # Show summary
    show_summary

    # Cleanup
    cleanup

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Compilation completed successfully!${NC}"
    echo "=========================================="
    echo ""
    echo "Llama.cpp has been installed to: $INSTALL_DIR"
    echo ""
    echo "To verify the installation:"
    echo "  llama-server --help"
    echo "  llama-cli --help"
    echo ""
    echo "To run the server:"
    echo "  llama-server --model /path/to/model.gguf"
    echo ""
    echo "To test with a small model:"
    echo "  llama-cli -m tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -p 'Hello!' -n 100"
    echo ""
    echo "To download models from HuggingFace:"
    echo "  llama-server --model /path/to/model.gguf -hf <model-name>"
    echo ""
    echo "See $LOG_FILE for detailed compilation logs"
}

# Run main function
main "$@"
