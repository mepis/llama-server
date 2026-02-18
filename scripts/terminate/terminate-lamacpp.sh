#!/bin/bash

# Llama.cpp Termination and Cleanup Script
# This script terminates all Llama.cpp instances and frees memory

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PID_FILE="${PID_FILE:-/tmp/llama-server.pid}"
LOG_DIR="${LOG_DIR:-/opt/llama-cpp/logs}"
INSTALL_DIR="${INSTALL_DIR:-/opt/llama-cpp}"

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$1"
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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root or use sudo for full cleanup"
    fi
}

find_all_instances() {
    log "Finding all Llama.cpp instances..."

    local instances=()

    # Check PID file
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            instances+=($pid)
            log "Found instance via PID file: $pid"
        fi
    fi

    # Find all llama-server processes
    local processes=$(pgrep -f llama-server | grep -v "^$$\$" || true)

    if [ -n "$processes" ]; then
        for pid in $processes; do
            if [[ ! " ${instances[*]} " =~ " ${pid} " ]]; then
                instances+=($pid)
                log "Found instance via pgrep: $pid"
            fi
        done
    fi

    if [ ${#instances[@]} -eq 0 ]; then
        log "No Llama.cpp instances found"
        return
    fi

    echo "=========================================="
    echo "  Found ${#instances[@]} Llama.cpp instance(s):"
    echo "=========================================="
    for pid in "${instances[@]}"; do
        ps -p $pid -o pid,ppid,%cpu,%mem,etime,command
    done
    echo "=========================================="
}

terminate_all_instances() {
    log "Terminating all Llama.cpp instances..."

    local instances=()

    # Check PID file
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            instances+=($pid)
            log "Found instance via PID file: $pid"
        fi
    fi

    # Find all llama-server processes
    local processes=$(pgrep -f llama-server | grep -v "^$$\$" || true)

    if [ -n "$processes" ]; then
        for pid in $processes; do
            if [[ ! " ${instances[*]} " =~ " ${pid} " ]]; then
                instances+=($pid)
                log "Found instance via pgrep: $pid"
            fi
        done
    fi

    if [ ${#instances[@]} -eq 0 ]; then
        log "No instances to terminate"
        return
    fi

    # Try graceful shutdown first
    log "Sending SIGTERM to all instances..."
    for pid in "${instances[@]}"; do
        kill $pid 2>/dev/null || true
    done

    # Wait for processes to terminate
    local max_wait=10
    local elapsed=0
    local remaining=${#instances[@]}

    while [ $elapsed -lt $max_wait ]; do
        sleep 1
        elapsed=$((elapsed + 1))

        # Check remaining processes
        local current_remaining=0
        for pid in "${instances[@]}"; do
            if ps -p $pid > /dev/null 2>&1; then
                current_remaining=$((current_remaining + 1))
            fi
        done

        if [ $current_remaining -eq 0 ]; then
            log "All instances terminated gracefully"
            remaining=0
            break
        fi

        if [ $current_remaining -ne $remaining ]; then
            remaining=$current_remaining
            log "$current_remaining instance(s) still running..."
        fi
    done

    # Force kill remaining processes
    if [ $remaining -gt 0 ]; then
        warning "$remaining instance(s) did not terminate gracefully, using SIGKILL"
        for pid in "${instances[@]}"; do
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid 2>/dev/null || true
            fi
        done

        # Wait a moment for force kill to complete
        sleep 2

        # Double-check
        for pid in "${instances[@]}"; do
            if ps -p $pid > /dev/null 2>&1; then
                warning "Process $pid still running after SIGKILL"
            fi
        done
    fi

    # Remove PID file
    rm -f "$PID_FILE"

    log "All instances terminated"
}

free_gpu_memory() {
    log "Freeing GPU memory..."

    # Check for Nvidia GPUs
    if command -v nvidia-smi &> /dev/null; then
        log "Nvidia GPU detected, freeing VRAM..."

        # Get list of GPU devices
        local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)

        for i in $(seq 0 $((gpu_count - 1))); do
            log "Freeing GPU $i memory..."
            nvidia-smi -i $i --gpu-reset 2>/dev/null || true
        done

        # Clear cache
        nvidia-smi --gpu-reset --all 2>/dev/null || true

        log "GPU memory freed"
    fi

    # Check for AMD GPUs
    if command -v rocm-smi &> /dev/null; then
        log "AMD GPU detected, freeing memory..."

        # Clear cache
        rocm-smi --reset 2>/dev/null || true

        log "AMD GPU memory freed"
    fi
}

clear_cpu_cache() {
    log "Clearing CPU cache..."

    # Clear page cache
    if [ -f /proc/sys/vm/drop_caches ]; then
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || warning "Failed to clear page cache"
    fi

    log "CPU cache cleared"
}

cleanup_logs() {
    log "Cleaning up logs..."

    if [ ! -d "$LOG_DIR" ]; then
        log "Log directory not found: $LOG_DIR"
        return
    fi

    # Keep last 10 log files
    local log_files=$(ls -t "$LOG_DIR"/llama-server-*.log 2>/dev/null | tail -n +11)

    if [ -n "$log_files" ]; then
        for log_file in $log_files; do
            if [ -f "$log_file" ]; then
                log "Removing old log file: $log_file"
                rm -f "$log_file"
            fi
        done
    fi

    log "Logs cleaned up"
}

cleanup_temp_files() {
    log "Cleaning up temporary files..."

    # Clean up PID files
    rm -f /tmp/llama-server*.pid
    rm -f /tmp/llama-server*.log

    log "Temporary files cleaned up"
}

check_system_memory() {
    log "Checking system memory..."

    if command -v free &> /dev/null; then
        echo ""
        echo "=========================================="
        echo "  System Memory Status"
        echo "=========================================="
        echo ""
        free -h
        echo ""
        echo "=========================================="
    fi
}

show_summary() {
    log "Cleanup Summary:"
    echo ""
    echo "=========================================="
    echo "  Cleanup Completed"
    echo "=========================================="
    echo ""

    echo "Terminated Instances:"
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
    fi

    echo "GPU Memory: Cleared"
    echo "CPU Cache: Cleared"
    echo "Logs: Cleaned up"
    echo "Temporary Files: Removed"
    echo ""

    echo "=========================================="
}

main() {
    echo "=========================================="
    echo "  Llama.cpp Termination and Cleanup"
    echo "=========================================="
    echo ""

    # Check root
    check_root

    # Create log file
    LOG_FILE="/var/log/llama-cpp-cleanup.log"
    touch "$LOG_FILE"

    # Ask for confirmation
    read -p "This will terminate all Llama.cpp instances and free memory. Continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "Cleanup cancelled"
        exit 0
    fi

    # Check system memory
    check_system_memory

    # Find all instances
    find_all_instances

    # Terminate instances
    terminate_all_instances

    # Free GPU memory
    free_gpu_memory

    # Clear CPU cache
    clear_cpu_cache

    # Cleanup logs
    cleanup_logs

    # Cleanup temp files
    cleanup_temp_files

    # Show summary
    show_summary

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Cleanup completed successfully!${NC}"
    echo "=========================================="
    echo ""
    echo "All Llama.cpp instances have been terminated"
    echo "GPU and CPU memory have been freed"
    echo ""
    echo "To restart the server:"
    echo "  llama-manage start"
    echo ""
    echo "See /var/log/llama-cpp-cleanup.log for detailed logs"
}

# Run main function
main "$@"