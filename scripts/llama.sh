#!/bin/bash

# Llama.cpp Management Suite - Main Entry Script
# This script provides a unified interface to all Llama.cpp management scripts

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPTS_DIR="${SCRIPTS_DIR:-$(dirname "$(readlink -f "$0")")}"

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_menu() {
    clear
    echo "=========================================="
    echo "  Llama.cpp Management Suite"
    echo "=========================================="
    echo ""
    echo "This script provides a unified interface to all Llama.cpp management tools."
    echo ""
    echo "Select an option:"
    echo ""
    echo "  ${CYAN}1.${NC} Install Llama.cpp"
    echo "  ${CYAN}2.${NC} Compile Llama.cpp"
    echo "  ${CYAN}3.${NC} Upgrade Llama.cpp"
    echo "  ${CYAN}4.${NC} Launch Llama.cpp Server"
    echo "  ${CYAN}5.${NC} Manage Llama.cpp Server"
    echo "  ${CYAN}6.${NC} Terminate and Cleanup"
    echo "  ${CYAN}7.${NC} Detect Hardware"
    echo "  ${CYAN}8.${NC} Show System Info"
    echo "  ${CYAN}9.${NC} View Documentation"
    echo "  ${CYAN}0.${NC} Exit"
    echo ""
    echo "=========================================="
}

show_help() {
    echo "=========================================="
    echo "  Llama.cpp Management Suite - Help"
    echo "=========================================="
    echo ""
    echo "Usage: llama [OPTION]"
    echo ""
    echo "Options:"
    echo "  install        Install Llama.cpp with hardware detection"
    echo "  compile        Compile Llama.cpp for specific hardware"
    echo "  upgrade        Upgrade existing Llama.cpp installation"
    echo "  launch         Launch Llama.cpp server"
    echo "  manage         Manage Llama.cpp server (start/stop/restart)"
    echo "  terminate      Terminate all Llama.cpp instances and cleanup"
    echo "  detect         Detect system hardware"
    echo "  info           Show system information"
    echo "  docs           View documentation"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  llama install"
    echo "  llama compile --cuda"
    echo "  llama launch --model /path/to/model.gguf"
    echo "  llama manage start"
    echo "  llama terminate"
    echo ""
    echo "For more information about a specific command, run:"
    echo "  llama <command> --help"
    echo ""
}

show_documentation() {
    echo "=========================================="
    echo "  Llama.cpp Documentation"
    echo "=========================================="
    echo ""
    echo "Main Documentation:"
    echo "  https://github.com/ggml-org/llama.cpp"
    echo ""
    echo "Build Documentation:"
    echo "  https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md"
    echo ""
    echo "Function Calling:"
    echo "  https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md"
    echo ""
    echo "Multimodal Models:"
    echo "  https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md"
    echo ""
    echo "Speculative Decoding:"
    echo "  https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md"
    echo ""
    echo "BLIS Backend:"
    echo "  https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/BLIS.md"
    echo ""
    echo "SYCL Backend:"
    echo "  https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md"
    echo ""
    echo "Server:"
    echo "  https://github.com/ggml-org/llama.cpp/tree/master/tools/server"
    echo ""
    echo "=========================================="
}

show_system_info() {
    echo "=========================================="
    echo "  System Information"
    echo "=========================================="
    echo ""

    echo "Operating System:"
    echo "  $OSTYPE"
    echo ""

    if command -v uname &> /dev/null; then
        echo "Kernel:"
        echo "  $(uname -a)"
        echo ""
    fi

    echo "CPU Information:"
    if command -v lscpu &> /dev/null; then
        lscpu
    else
        echo "  Unable to retrieve CPU information"
    fi
    echo ""

    echo "Memory Information:"
    if command -v free &> /dev/null; then
        free -h
    else
        echo "  Unable to retrieve memory information"
    fi
    echo ""

    echo "Disk Information:"
    if command -v df &> /dev/null; then
        df -h
    else
        echo "  Unable to retrieve disk information"
    fi
    echo ""

    echo "GPU Information:"
    if command -v nvidia-smi &> /dev/null; then
        echo "  Nvidia GPUs:"
        nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv
    fi

    if command -v rocm-smi &> /dev/null; then
        echo ""
        echo "  AMD GPUs:"
        rocm-smi --showlibver
    fi

    if command -v vulkaninfo &> /dev/null; then
        echo ""
        echo "  Vulkan GPUs:"
        vulkaninfo --summary 2>/dev/null | grep -E "GPU name|deviceName" | head -5
    fi
    echo ""

    echo "=========================================="
}

execute_install() {
    log "Starting installation..."
    if [ -f "$SCRIPTS_DIR/install/install-lamacpp.sh" ]; then
        bash "$SCRIPTS_DIR/install/install-lamacpp.sh" "$@"
    else
        error "Installation script not found: $SCRIPTS_DIR/install/install-lamacpp.sh"
    fi
}

execute_compile() {
    log "Starting compilation..."
    if [ -f "$SCRIPTS_DIR/compile/compile-lamacpp.sh" ]; then
        bash "$SCRIPTS_DIR/compile/compile-lamacpp.sh" "$@"
    else
        error "Compilation script not found: $SCRIPTS_DIR/compile/compile-lamacpp.sh"
    fi
}

execute_upgrade() {
    log "Starting upgrade..."
    if [ -f "$SCRIPTS_DIR/upgrade/upgrade-lamacpp.sh" ]; then
        bash "$SCRIPTS_DIR/upgrade/upgrade-lamacpp.sh" "$@"
    else
        error "Upgrade script not found: $SCRIPTS_DIR/upgrade/upgrade-lamacpp.sh"
    fi
}

execute_launch() {
    log "Starting launch..."
    if [ -f "$SCRIPTS_DIR/launch/launch-lamacpp.sh" ]; then
        bash "$SCRIPTS_DIR/launch/launch-lamacpp.sh" "$@"
    else
        error "Launch script not found: $SCRIPTS_DIR/launch/launch-lamacpp.sh"
    fi
}

execute_manage() {
    log "Starting management..."
    if [ -f "$SCRIPTS_DIR/manage/manage-lamacpp.sh" ]; then
        bash "$SCRIPTS_DIR/manage/manage-lamacpp.sh" "$@"
    else
        error "Management script not found: $SCRIPTS_DIR/manage/manage-lamacpp.sh"
    fi
}

execute_terminate() {
    log "Starting termination..."
    if [ -f "$SCRIPTS_DIR/terminate/terminate-lamacpp.sh" ]; then
        bash "$SCRIPTS_DIR/terminate/terminate-lamacpp.sh" "$@"
    else
        error "Termination script not found: $SCRIPTS_DIR/terminate/terminate-lamacpp.sh"
    fi
}

execute_detect() {
    log "Detecting hardware..."
    if [ -f "$SCRIPTS_DIR/detect-hardware.sh" ]; then
        bash "$SCRIPTS_DIR/detect-hardware.sh" "$@"
    else
        error "Detection script not found: $SCRIPTS_DIR/detect-hardware.sh"
    fi
}

main() {
    # Check if command is provided
    if [ $# -gt 0 ]; then
        local command=$1
        shift

        case $command in
            install)
                execute_install "$@"
                ;;
            compile)
                execute_compile "$@"
                ;;
            upgrade)
                execute_upgrade "$@"
                ;;
            launch)
                execute_launch "$@"
                ;;
            manage)
                execute_manage "$@"
                ;;
            terminate)
                execute_terminate "$@"
                ;;
            detect)
                execute_detect "$@"
                ;;
            info)
                show_system_info
                ;;
            docs)
                show_documentation
                ;;
            help|--help|-h)
                show_help
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} Unknown command: $command" >&2
                show_help
                exit 1
                ;;
        esac
        return
    fi

    # Interactive mode
    while true; do
        show_menu
        read -p "Enter your choice [0-9]: " choice

        case $choice in
            1)
                execute_install
                ;;
            2)
                execute_compile
                ;;
            3)
                execute_upgrade
                ;;
            4)
                execute_launch
                ;;
            5)
                execute_manage
                ;;
            6)
                execute_terminate
                ;;
            7)
                execute_detect
                ;;
            8)
                show_system_info
                ;;
            9)
                show_documentation
                ;;
            0)
                echo "Exiting..."
                exit 0
                ;;
            *)
                warning "Invalid choice. Please enter 0-9."
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"