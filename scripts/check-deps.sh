#!/bin/bash

# Dependency Checker for Llama.cpp Management Suite
# Checks for missing build dependencies and GPU toolkits,
# then prints the install commands needed for your platform.

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Platform detection ────────────────────────────────────────────────

detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v lsb_release &> /dev/null; then
            local distro
            distro=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
        elif [ -f /etc/os-release ]; then
            local distro
            distro=$(. /etc/os-release && echo "$ID")
        fi
        case "$distro" in
            ubuntu|debian|linuxmint|pop) echo "debian" ;;
            fedora|rhel|rocky|almalinux|centos) echo "fedora" ;;
            arch|manjaro|endeavouros) echo "arch" ;;
            alpine) echo "alpine" ;;
            *) echo "linux" ;;
        esac
    else
        echo "unknown"
    fi
}

PLATFORM=$(detect_platform)

# ── Tracking arrays ───────────────────────────────────────────────────

MISSING_CORE=()      # essential build tools
MISSING_GPU=()       # optional GPU packages
MISSING_BLAS=()      # BLAS / math libraries

ALL_OK=true

# ── Helper functions ──────────────────────────────────────────────────

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
miss() { echo -e "  ${RED}✗${NC} $1 ${YELLOW}— $2${NC}"; ALL_OK=false; }
skip() { echo -e "  ${BLUE}–${NC} $1 (skipped — $2)"; }
info() { echo -e "  ${CYAN}ℹ${NC} $1"; }

check_cmd() {
    local cmd=$1 label=${2:-$1} hint=$3
    if command -v "$cmd" &> /dev/null; then
        ok "$label"
        return 0
    else
        miss "$label" "$hint"
        return 1
    fi
}

# ── Core build tools ─────────────────────────────────────────────────

echo ""
echo "=========================================="
echo "  Llama.cpp Dependency Checker"
echo "=========================================="
echo ""
echo "Platform: $PLATFORM"
echo ""

echo "Core Build Tools"
echo "─────────────────────────────────────────"

check_cmd git        "git"        "version control"       || MISSING_CORE+=(git)
check_cmd cmake      "cmake"      "build system generator" || MISSING_CORE+=(cmake)
check_cmd pkg-config "pkg-config" "library discovery tool" || MISSING_CORE+=(pkg-config)
check_cmd gcc        "gcc"        "C compiler"             || MISSING_CORE+=(gcc)
check_cmd g++        "g++"        "C++ compiler"           || MISSING_CORE+=(g++)
check_cmd make       "make"       "build automation"       || MISSING_CORE+=(make)
check_cmd wget       "wget"       "file downloader"        || MISSING_CORE+=(wget)
check_cmd curl       "curl"       "data transfer"          || MISSING_CORE+=(curl)

echo ""

# ── BLAS / math library ──────────────────────────────────────────────

echo "BLAS / Math Libraries"
echo "─────────────────────────────────────────"

BLAS_FOUND=false

# Check for any BLAS library via pkg-config or ldconfig
if command -v pkg-config &> /dev/null && pkg-config --exists blas 2>/dev/null; then
    ok "BLAS (found via pkg-config)"
    BLAS_FOUND=true
elif command -v pkg-config &> /dev/null && pkg-config --exists openblas 2>/dev/null; then
    ok "OpenBLAS (found via pkg-config)"
    BLAS_FOUND=true
elif ldconfig -p 2>/dev/null | grep -q libblas; then
    ok "BLAS (found via ldconfig)"
    BLAS_FOUND=true
elif ldconfig -p 2>/dev/null | grep -q libopenblas; then
    ok "OpenBLAS (found via ldconfig)"
    BLAS_FOUND=true
elif [ -f /usr/include/cblas.h ] || [ -f /usr/include/openblas/cblas.h ]; then
    ok "BLAS headers found"
    BLAS_FOUND=true
elif [[ "$PLATFORM" == "macos" ]] && [ -d /Library/Developer/CommandLineTools ] || [ -d /Applications/Xcode.app ]; then
    ok "Accelerate framework (macOS built-in BLAS)"
    BLAS_FOUND=true
fi

if [ "$BLAS_FOUND" = false ]; then
    miss "BLAS" "linear algebra library for CPU acceleration"
    MISSING_BLAS+=(blas)
fi

echo ""

# ── GPU backends ──────────────────────────────────────────────────────

echo "GPU Backends (optional)"
echo "─────────────────────────────────────────"

# CUDA
HAS_NVIDIA_GPU=false
if lspci 2>/dev/null | grep -qi nvidia; then
    HAS_NVIDIA_GPU=true
elif [ -d /proc/driver/nvidia ] 2>/dev/null; then
    HAS_NVIDIA_GPU=true
fi

if [ "$HAS_NVIDIA_GPU" = true ]; then
    if command -v nvidia-smi &> /dev/null; then
        ok "nvidia-smi (Nvidia driver)"
    else
        miss "nvidia-smi" "Nvidia driver not installed"
        MISSING_GPU+=(nvidia-driver)
    fi
    if command -v nvcc &> /dev/null; then
        ok "nvcc (CUDA toolkit)"
    else
        miss "nvcc" "CUDA compiler toolkit"
        MISSING_GPU+=(cuda-toolkit)
    fi
else
    skip "CUDA" "no Nvidia GPU detected"
fi

# ROCm
HAS_AMD_GPU=false
if lspci 2>/dev/null | grep -qi "amd.*radeon\|amd.*rx\|advanced micro.*display\|amd.*navi\|amd.*vega"; then
    HAS_AMD_GPU=true
fi

if [ "$HAS_AMD_GPU" = true ]; then
    if command -v rocm-smi &> /dev/null; then
        ok "rocm-smi (ROCm runtime)"
    else
        miss "rocm-smi" "AMD ROCm runtime"
        MISSING_GPU+=(rocm)
    fi
    if command -v hipconfig &> /dev/null; then
        ok "hipconfig (HIP compiler)"
    else
        miss "hipconfig" "AMD HIP development tools"
        MISSING_GPU+=(hip)
    fi
else
    skip "ROCm" "no AMD GPU detected"
fi

# Vulkan
HAS_ANY_GPU=false
if lspci 2>/dev/null | grep -qiE "VGA|3D|Display"; then
    HAS_ANY_GPU=true
fi

if [ "$HAS_ANY_GPU" = true ]; then
    VULKAN_DEV=false
    VULKAN_GLSLANG=false

    # Check for Vulkan dev headers (libvulkan-dev / vulkan-loader-devel / etc.)
    if command -v pkg-config &> /dev/null && pkg-config --exists vulkan 2>/dev/null; then
        VULKAN_DEV=true
    elif [ -f /usr/include/vulkan/vulkan.h ] || [ -f /usr/local/include/vulkan/vulkan.h ]; then
        VULKAN_DEV=true
    elif ldconfig -p 2>/dev/null | grep -q libvulkan; then
        VULKAN_DEV=true
    fi

    # Check for glslc shader compiler (from shaderc/glslc package)
    # Note: glslangValidator (from glslang-tools) is NOT sufficient — CMake requires glslc
    if command -v glslc &> /dev/null; then
        VULKAN_GLSLANG=true
    fi

    if [ "$VULKAN_DEV" = true ] && [ "$VULKAN_GLSLANG" = true ]; then
        ok "Vulkan development libraries and glslc shader compiler"
    elif [ "$VULKAN_DEV" = true ]; then
        ok "Vulkan development libraries"
        miss "glslc" "Vulkan shader compiler (required by CMake)"
        MISSING_GPU+=(vulkan-glslang)
    elif [ "$VULKAN_GLSLANG" = true ]; then
        miss "Vulkan dev headers" "Vulkan development libraries"
        MISSING_GPU+=(vulkan-dev)
        ok "Vulkan shader compiler"
    else
        miss "Vulkan" "Vulkan development packages"
        MISSING_GPU+=(vulkan)
    fi
else
    skip "Vulkan" "no GPU detected"
fi

# Metal (macOS only)
if [[ "$PLATFORM" == "macos" ]]; then
    if command -v xcrun &> /dev/null && xcrun --sdk macosx --show-sdk-path &> /dev/null; then
        ok "Metal (Xcode SDK)"
    else
        miss "Metal SDK" "Xcode command-line tools required"
        MISSING_GPU+=(xcode-cli)
    fi
else
    skip "Metal" "macOS only"
fi

echo ""

# ── SSL library ───────────────────────────────────────────────────────

echo "Other Libraries"
echo "─────────────────────────────────────────"

SSL_FOUND=false
if command -v pkg-config &> /dev/null && pkg-config --exists openssl 2>/dev/null; then
    ok "OpenSSL development headers"
    SSL_FOUND=true
elif [ -f /usr/include/openssl/ssl.h ] || [ -f /usr/include/openssl/opensslv.h ]; then
    ok "OpenSSL development headers"
    SSL_FOUND=true
elif [[ "$PLATFORM" == "macos" ]]; then
    ok "LibreSSL (macOS built-in)"
    SSL_FOUND=true
fi

if [ "$SSL_FOUND" = false ]; then
    miss "OpenSSL dev" "SSL/TLS development headers"
    MISSING_CORE+=(openssl-dev)
fi

echo ""

# ── Generate install commands ─────────────────────────────────────────

TOTAL_MISSING=$(( ${#MISSING_CORE[@]} + ${#MISSING_BLAS[@]} + ${#MISSING_GPU[@]} ))

if [ "$TOTAL_MISSING" -eq 0 ]; then
    echo "=========================================="
    echo -e "  ${GREEN}All dependencies are installed!${NC}"
    echo "=========================================="
    echo ""
    echo "Your system is ready to build Llama.cpp."
    echo ""
    exit 0
fi

echo "=========================================="
echo "  Install Commands"
echo "=========================================="
echo ""

# ── Map missing items to platform packages ────────────────────────────

build_package_list() {
    local -n pkgs=$1
    local -n missing=$2
    local platform=$3

    for dep in "${missing[@]}"; do
        case "$platform" in
            debian)
                case "$dep" in
                    git)         pkgs+=(git) ;;
                    cmake)       pkgs+=(cmake) ;;
                    pkg-config)  pkgs+=(pkg-config) ;;
                    gcc)         pkgs+=(build-essential) ;;
                    g++)         pkgs+=(build-essential) ;;
                    make)        pkgs+=(build-essential) ;;
                    wget)        pkgs+=(wget) ;;
                    curl)        pkgs+=(curl) ;;
                    openssl-dev) pkgs+=(libssl-dev) ;;
                    blas)        pkgs+=(libopenblas-dev) ;;
                esac
                ;;
            fedora)
                case "$dep" in
                    git)         pkgs+=(git) ;;
                    cmake)       pkgs+=(cmake) ;;
                    pkg-config)  pkgs+=(pkgconf-pkg-config) ;;
                    gcc)         pkgs+=(gcc) ;;
                    g++)         pkgs+=(gcc-c++) ;;
                    make)        pkgs+=(make) ;;
                    wget)        pkgs+=(wget) ;;
                    curl)        pkgs+=(curl) ;;
                    openssl-dev) pkgs+=(openssl-devel) ;;
                    blas)        pkgs+=(openblas-devel) ;;
                esac
                ;;
            arch)
                case "$dep" in
                    git)         pkgs+=(git) ;;
                    cmake)       pkgs+=(cmake) ;;
                    pkg-config)  pkgs+=(pkgconf) ;;
                    gcc|g++|make) pkgs+=(base-devel) ;;
                    wget)        pkgs+=(wget) ;;
                    curl)        pkgs+=(curl) ;;
                    openssl-dev) pkgs+=(openssl) ;;
                    blas)        pkgs+=(openblas) ;;
                esac
                ;;
            alpine)
                case "$dep" in
                    git)         pkgs+=(git) ;;
                    cmake)       pkgs+=(cmake) ;;
                    pkg-config)  pkgs+=(pkgconf) ;;
                    gcc|g++|make) pkgs+=(build-base) ;;
                    wget)        pkgs+=(wget) ;;
                    curl)        pkgs+=(curl) ;;
                    openssl-dev) pkgs+=(openssl-dev) ;;
                    blas)        pkgs+=(openblas-dev) ;;
                esac
                ;;
            macos)
                case "$dep" in
                    git)         pkgs+=(git) ;;
                    cmake)       pkgs+=(cmake) ;;
                    pkg-config)  pkgs+=(pkg-config) ;;
                    wget)        pkgs+=(wget) ;;
                    curl)        pkgs+=(curl) ;;
                    blas)        pkgs+=(openblas) ;;
                esac
                ;;
        esac
    done
}

build_gpu_package_list() {
    local -n pkgs=$1
    local -n missing=$2
    local platform=$3

    for dep in "${missing[@]}"; do
        case "$platform" in
            debian)
                case "$dep" in
                    nvidia-driver)  pkgs+=(nvidia-driver) ;;
                    cuda-toolkit)   pkgs+=(nvidia-cuda-toolkit) ;;
                    rocm)           pkgs+=(rocm-dev) ;;
                    hip)            pkgs+=(hip-dev) ;;
                    vulkan)         pkgs+=(libvulkan-dev glslc) ;;
                    vulkan-dev)     pkgs+=(libvulkan-dev) ;;
                    vulkan-glslang) pkgs+=(glslc) ;;
                esac
                ;;
            fedora)
                case "$dep" in
                    nvidia-driver)  pkgs+=(akmod-nvidia) ;;
                    cuda-toolkit)   pkgs+=(cuda) ;;
                    rocm)           pkgs+=(rocm-dev) ;;
                    hip)            pkgs+=(hip-devel) ;;
                    vulkan)         pkgs+=(vulkan-loader-devel glslc) ;;
                    vulkan-dev)     pkgs+=(vulkan-loader-devel) ;;
                    vulkan-glslang) pkgs+=(glslc) ;;
                esac
                ;;
            arch)
                case "$dep" in
                    nvidia-driver)  pkgs+=(nvidia) ;;
                    cuda-toolkit)   pkgs+=(cuda) ;;
                    rocm)           pkgs+=(rocm-hip-sdk) ;;
                    hip)            pkgs+=(rocm-hip-sdk) ;;
                    vulkan)         pkgs+=(vulkan-icd-loader vulkan-headers shaderc) ;;
                    vulkan-dev)     pkgs+=(vulkan-icd-loader vulkan-headers) ;;
                    vulkan-glslang) pkgs+=(shaderc) ;;
                esac
                ;;
            macos)
                case "$dep" in
                    xcode-cli) ;; # handled separately
                esac
                ;;
        esac
    done
}

# Build the package lists
CORE_PKGS=()
GPU_PKGS=()

ALL_MISSING=("${MISSING_CORE[@]}" "${MISSING_BLAS[@]}")
build_package_list CORE_PKGS ALL_MISSING "$PLATFORM"
build_gpu_package_list GPU_PKGS MISSING_GPU "$PLATFORM"

# Deduplicate
dedupe() {
    local -n arr=$1
    local -A seen
    local result=()
    for item in "${arr[@]}"; do
        if [ -z "${seen[$item]+x}" ]; then
            seen[$item]=1
            result+=("$item")
        fi
    done
    arr=("${result[@]}")
}

dedupe CORE_PKGS
dedupe GPU_PKGS

# Print install commands
if [ ${#CORE_PKGS[@]} -gt 0 ]; then
    echo -e "${CYAN}Core build dependencies:${NC}"
    echo ""
    case "$PLATFORM" in
        debian)
            echo "  sudo apt-get update && sudo apt-get install -y ${CORE_PKGS[*]}"
            ;;
        fedora)
            echo "  sudo dnf install -y ${CORE_PKGS[*]}"
            ;;
        arch)
            echo "  sudo pacman -Sy --noconfirm ${CORE_PKGS[*]}"
            ;;
        alpine)
            echo "  sudo apk add --no-cache ${CORE_PKGS[*]}"
            ;;
        macos)
            # gcc/g++/make come from Xcode CLI tools, not brew
            local brew_pkgs=()
            for p in "${CORE_PKGS[@]}"; do
                brew_pkgs+=("$p")
            done
            if [ ${#brew_pkgs[@]} -gt 0 ]; then
                echo "  brew install ${brew_pkgs[*]}"
            fi
            # Check if Xcode CLI tools are needed
            if ! xcode-select -p &> /dev/null; then
                echo "  xcode-select --install"
            fi
            ;;
        *)
            echo "  # Could not detect package manager. Install these manually:"
            echo "  # ${CORE_PKGS[*]}"
            ;;
    esac
    echo ""
fi

if [ ${#GPU_PKGS[@]} -gt 0 ]; then
    echo -e "${CYAN}GPU backend packages:${NC}"
    echo ""
    case "$PLATFORM" in
        debian)
            echo "  sudo apt-get install -y ${GPU_PKGS[*]}"
            ;;
        fedora)
            echo "  sudo dnf install -y ${GPU_PKGS[*]}"
            ;;
        arch)
            echo "  sudo pacman -Sy --noconfirm ${GPU_PKGS[*]}"
            ;;
        *)
            echo "  # Install these GPU packages for your distribution:"
            echo "  # ${GPU_PKGS[*]}"
            ;;
    esac
    echo ""
fi

# Handle Xcode CLI tools separately (no sudo needed)
for dep in "${MISSING_GPU[@]}"; do
    if [ "$dep" = "xcode-cli" ]; then
        echo -e "${CYAN}macOS developer tools (no sudo required):${NC}"
        echo ""
        echo "  xcode-select --install"
        echo ""
    fi
done

echo "=========================================="
echo ""
echo "After installing, re-run this script to verify:"
echo "  ./scripts/check-deps.sh"
echo ""
