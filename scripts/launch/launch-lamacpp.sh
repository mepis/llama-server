#!/bin/bash

# Llama.cpp Launch Script
# This script launches Llama.cpp server with various configuration options

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFIG_DIR="${CONFIG_DIR:-$HOME/.local/llama-cpp/config}"
MODELS_DIR="${MODELS_DIR:-$HOME/.local/llama-cpp/models}"
LOG_DIR="${LOG_DIR:-$HOME/.local/llama-cpp/logs}"
INSTANCES_DIR="${INSTANCES_DIR:-$HOME/.local/llama-cpp/instances}"
PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"
INSTANCE_NAME="${INSTANCE_NAME:-default}"

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

parse_arguments() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --model|-m)
                MODEL_PATH="$2"
                shift 2
                ;;
            --config|-c)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --port|-p)
                PORT="$2"
                shift 2
                ;;
            --host|-H)
                HOST="$2"
                shift 2
                ;;
            --ngl)
                NGL="$2"
                shift 2
                ;;
            --threads)
                THREADS="$2"
                shift 2
                ;;
            --context|-C)
                CONTEXT_SIZE="$2"
                shift 2
                ;;
            --batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            --log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            --unified-memory|-um)
                UNIFIED_MEMORY=1
                shift
                ;;
            --hf|-huggingface)
                MODEL_NAME="$2"
                shift 2
                ;;
            --download-only|-d)
                DOWNLOAD_ONLY=1
                shift
                ;;
            --daemon|-D)
                DAEMON=1
                shift
                ;;
            --background|-b)
                BACKGROUND=1
                shift
                ;;
            --no-gpu|-ng)
                NO_GPU=1
                shift
                ;;
            --no-webui)
                NO_WEBUI=1
                shift
                ;;
            --name|-n)
                INSTANCE_NAME="$2"
                shift 2
                ;;
            --list-devices|-l)
                LIST_DEVICES=1
                shift
                ;;
            --version|-v)
                VERSION=1
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

show_help() {
    echo "=========================================="
    echo "  Llama.cpp Server Launcher"
    echo "=========================================="
    echo ""
    echo "Usage: llama-server [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --model, -m PATH       Path to the model file"
    echo "  --config, -c FILE      Path to configuration file"
    echo "  --port, -p PORT        Port to listen on (default: 8080)"
    echo "  --host, -H HOST        Host to bind to (default: 0.0.0.0)"
    echo "  --ngl NUM              Number of GPU layers to offload (default: 99)"
    echo "  --threads NUM          Number of threads (default: $(nproc))"
    echo "  --context, -C SIZE     Context size (default: 2048)"
    echo "  --batch-size SIZE      Batch size (default: 512)"
    echo "  --log-level LEVEL      Log level (info, warning, error, debug)"
    echo "  --unified-memory, -um  Enable CUDA unified memory"
    echo "  --hf, -huggingface NAME Download model from HuggingFace"
    echo "  --download-only, -d   Only download model, don't start server"
    echo "  --daemon, -D           Run as daemon (background process)"
    echo "  --background, -b      Run in background (alternative to --daemon)"
    echo "  --no-gpu, -ng          Disable GPU acceleration"
    echo "  --no-webui             Disable built-in web interface"
    echo "  --name, -n NAME        Instance name (for running multiple servers)"
    echo "  --list-devices, -l    List available devices"
    echo "  --version, -v         Show version information"
    echo "  --help, -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  llama-server --model ~/.local/llama-cpp/models/model.gguf --ngl 99"
    echo "  llama-server --hf meta-llama/Llama-2-7b-chat-hf --port 8081"
    echo "  llama-server --config ~/.local/llama-cpp/config/server.yaml --daemon"
    echo ""
}

check_model() {
    # If using -hf flag, the model will be downloaded by llama-server itself
    if [ -n "$MODEL_NAME" ] && [ -z "$MODEL_PATH" ]; then
        log "HuggingFace model specified: $MODEL_NAME (will be downloaded by llama-server)"
        return 0
    fi

    if [ -z "$MODEL_PATH" ]; then
        # Try to find model from config
        if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
            MODEL_PATH=$(grep -oP "model_file: '\K[^']+" "$CONFIG_FILE" || true)
        fi
    fi

    # Check if model exists
    if [ -z "$MODEL_PATH" ]; then
        warning "No model specified. Use --model /path/to/model.gguf or --hf owner/repo to specify a model."
        exit 1
    fi

    if [ ! -f "$MODEL_PATH" ]; then
        error "Model file not found: $MODEL_PATH"
    fi

    log "Using model: $MODEL_PATH"
}

download_model() {
    if [ -z "$MODEL_NAME" ]; then
        return
    fi

    info "Downloading model from HuggingFace: $MODEL_NAME"

    # Create models directory if it doesn't exist
    mkdir -p "$MODELS_DIR"

    # Determine model file extension
    case "$MODEL_NAME" in
        *gguf*)
            MODEL_FILE="$MODELS_DIR/$(basename "$MODEL_NAME" .gguf).gguf"
            ;;
        *)
            MODEL_FILE="$MODELS_DIR/$MODEL_NAME.gguf"
            ;;
    esac

    # Check if model already exists
    if [ -f "$MODEL_FILE" ]; then
        warning "Model already exists at $MODEL_FILE"
        if [ -n "$DOWNLOAD_ONLY" ]; then
            log "Download-only mode: model already exists, exiting"
            exit 0
        fi
        MODEL_PATH="$MODEL_FILE"
        return
    fi

    # Download model from HuggingFace
    log "Downloading model to $MODEL_FILE"

    # Try different download methods
    if command -v wget &> /dev/null; then
        wget -q --show-progress \
            "https://huggingface.co/$MODEL_NAME/resolve/main/${MODEL_NAME##*/}.gguf" \
            -O "$MODEL_FILE" 2>&1 | \
            while read line; do
                echo "$line" | grep -E "saved|downloaded|%" | tail -1
            done
    elif command -v curl &> /dev/null; then
        curl -L -o "$MODEL_FILE" \
            "https://huggingface.co/$MODEL_NAME/resolve/main/${MODEL_NAME##*/}.gguf" \
            --progress-bar
    else
        error "Neither wget nor curl is available for downloading models"
    fi

    if [ ! -f "$MODEL_FILE" ]; then
        error "Failed to download model"
    fi

    log "Model downloaded successfully to $MODEL_FILE"
    MODEL_PATH="$MODEL_FILE"
}

check_dependencies() {
    log "Checking dependencies..."

    local missing_deps=()

    if [ ! -f "$HOME/.local/bin/llama-server" ] && [ ! -f "$HOME/.local/llama-cpp/bin/llama-server" ] && [ ! -f "/usr/local/bin/llama-server" ]; then
        missing_deps+=("llama-server binary")
    fi

    if [ -n "$NO_GPU" ]; then
        log "GPU acceleration disabled"
    else
        # Check for GPU support
        if command -v nvidia-smi &> /dev/null; then
            log "Nvidia GPU detected"
        fi
        if command -v rocm-smi &> /dev/null; then
            log "AMD GPU detected"
        fi
        if command -v vulkaninfo &> /dev/null; then
            log "Vulkan GPU detected"
        fi
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
    fi

    log "Dependencies are satisfied"
}

check_port() {
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        warning "Port $PORT is already in use"
        read -p "Kill existing process on port $PORT? [y/N]: " kill_existing
        if [[ "$kill_existing" =~ ^[Yy]$ ]]; then
            lsof -t -i:$PORT | xargs kill -9 2>/dev/null || true
            log "Existing process killed"
        else
            error "Port $PORT is in use. Please choose a different port or kill the existing process"
        fi
    fi
}

list_devices() {
    log "Available devices:"

    if command -v nvidia-smi &> /dev/null; then
        echo ""
        echo "Nvidia GPUs:"
        nvidia-smi --query-gpu=index,name,driver_version,memory.total --format=csv
    fi

    if command -v rocm-smi &> /dev/null; then
        echo ""
        echo "AMD GPUs:"
        rocm-smi --showlibver
    fi

    if command -v vulkaninfo &> /dev/null; then
        echo ""
        echo "Vulkan GPUs:"
        vulkaninfo --summary | grep -E "GPU name|deviceName"
    fi

    echo ""
    echo "CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)"
    exit 0
}

check_version() {
    if [ -f "$HOME/.local/llama-cpp/bin/llama-server" ]; then
        llama_server="$HOME/.local/llama-cpp/bin/llama-server"
    elif [ -f "/usr/local/bin/llama-server" ]; then
        llama_server="/usr/local/bin/llama-server"
    else
        llama_server=$(which llama-server)
    fi

    if [ -n "$llama_server" ]; then
        version=$("$llama_server" --version 2>&1 | head -1 || echo "Unknown version")
        log "Llama.cpp version: $version"
    fi
    exit 0
}

build_command() {
    local cmd="llama-server"

    # Check which binary to use
    if [ -f "$HOME/.local/llama-cpp/bin/llama-server" ]; then
        cmd="$HOME/.local/llama-cpp/bin/llama-server"
    elif [ -f "/usr/local/bin/llama-server" ]; then
        cmd="/usr/local/bin/llama-server"
    fi

    # Add arguments
    if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        cmd="$cmd --config $CONFIG_FILE"
    fi

    # Use -hf flag natively if MODEL_NAME is set (llama-server supports -hf directly)
    if [ -n "$MODEL_NAME" ] && [ -z "$MODEL_PATH" ]; then
        cmd="$cmd -hf $MODEL_NAME"
    elif [ -n "$MODEL_PATH" ]; then
        cmd="$cmd --model $MODEL_PATH"
    fi

    if [ -n "$PORT" ]; then
        cmd="$cmd --port $PORT"
    fi

    if [ -n "$HOST" ]; then
        cmd="$cmd --host $HOST"
    fi

    if [ -n "$NGL" ]; then
        cmd="$cmd -ngl $NGL"
    fi

    if [ -n "$THREADS" ]; then
        cmd="$cmd -t $THREADS"
    fi

    if [ -n "$CONTEXT_SIZE" ]; then
        cmd="$cmd -c $CONTEXT_SIZE"
    fi

    if [ -n "$BATCH_SIZE" ]; then
        cmd="$cmd -b $BATCH_SIZE"
    fi

    # Unified Memory is controlled via environment variable (not a server flag)
    if [ -n "$UNIFIED_MEMORY" ]; then
        export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
    fi

    if [ "$NO_GPU" = "1" ]; then
        cmd="$cmd -ngl 0"
    fi

    if [ "$NO_WEBUI" = "1" ]; then
        cmd="$cmd --no-webui"
    fi

    # Set environment variables
    export GGML_LOG_LEVEL="${LOG_LEVEL:-info}"

    log "Command to execute: $cmd" >&2
    echo "" >&2

    echo "$cmd"
}

execute_command() {
    local cmd="$1"

    # Create directories
    mkdir -p "$LOG_DIR"
    mkdir -p "$INSTANCES_DIR"

    # Check if instance name is already running
    local pid_file="$INSTANCES_DIR/${INSTANCE_NAME}.pid"
    if [ -f "$pid_file" ]; then
        local existing_pid=$(cat "$pid_file")
        if ps -p "$existing_pid" > /dev/null 2>&1; then
            error "Instance '$INSTANCE_NAME' is already running with PID $existing_pid. Use --name to specify a different instance."
        else
            warning "Removing stale PID file for instance '$INSTANCE_NAME'"
            rm -f "$pid_file"
        fi
    fi

    # Check if port is already in use
    if command -v lsof &> /dev/null; then
        if lsof -Pi :${PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
            error "Port ${PORT} is already in use. Please choose a different port with --port"
        fi
    fi

    # Set log file
    local log_file="$LOG_DIR/llama-server-${INSTANCE_NAME}-$(date +%Y%m%d_%H%M%S).log"

    log "Starting server instance: $INSTANCE_NAME"
    log "Log file: $log_file"
    log "PID: $$"

    # Execute command
    if [ "$DAEMON" = "1" ]; then
        nohup $cmd > "$log_file" 2>&1 &
        local pid=$!
        echo $pid > "$pid_file"

        # Save instance metadata
        cat > "$INSTANCES_DIR/${INSTANCE_NAME}.json" <<EOF
{
  "name": "$INSTANCE_NAME",
  "pid": $pid,
  "port": $PORT,
  "host": "$HOST",
  "model": "${MODEL_PATH:-${MODEL_NAME:-unknown}}",
  "log_file": "$log_file",
  "started_at": "$(date -Iseconds)",
  "ngl": "${NGL:-99}",
  "context": "${CONTEXT_SIZE:-2048}"
}
EOF
        log "Server started in daemon mode with PID: $pid"
        log "Instance name: $INSTANCE_NAME"
        log "Port: $PORT"
    elif [ "$BACKGROUND" = "1" ]; then
        $cmd > "$log_file" 2>&1 &
        local pid=$!
        echo $pid > "$pid_file"

        # Save instance metadata
        cat > "$INSTANCES_DIR/${INSTANCE_NAME}.json" <<EOF
{
  "name": "$INSTANCE_NAME",
  "pid": $pid,
  "port": $PORT,
  "host": "$HOST",
  "model": "${MODEL_PATH:-${MODEL_NAME:-unknown}}",
  "log_file": "$log_file",
  "started_at": "$(date -Iseconds)",
  "ngl": "${NGL:-99}",
  "context": "${CONTEXT_SIZE:-2048}"
}
EOF
        log "Server started in background with PID: $pid"
        log "Instance name: $INSTANCE_NAME"
        log "Port: $PORT"
    else
        $cmd
    fi
}

verify_server() {
    if [ "$DAEMON" = "1" ] || [ "$BACKGROUND" = "1" ]; then
        log "Waiting for server to start..."
        sleep 2

        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if ps -p $pid > /dev/null; then
                log "Server is running with PID: $pid"
                log "Access the server at: http://$HOST:$PORT"
            else
                warning "Server process died. Check logs in $LOG_DIR"
            fi
        else
            warning "No PID file found. Check if server is running"
        fi
    fi
}

cleanup() {
    if [ -f "$PID_FILE" ]; then
        rm -f "$PID_FILE"
    fi
}

# Main execution
main() {
    # Save argument count before parse_arguments consumes $@
    local arg_count=$#

    # Initialize variables
    MODEL_PATH=""
    CONFIG_FILE=""
    NGL=""
    THREADS=""
    CONTEXT_SIZE=""
    BATCH_SIZE=""
    LOG_LEVEL=""
    UNIFIED_MEMORY=""
    MODEL_NAME=""
    DOWNLOAD_ONLY=0
    DAEMON=0
    BACKGROUND=0
    NO_GPU=0
    LIST_DEVICES=0
    VERSION=0
    LOG_FILE="$LOG_DIR/llama-server-launch.log"

    # Show help if no arguments (check before parsing)
    if [ "$arg_count" -eq 0 ]; then
        show_help
        exit 0
    fi

    # Parse arguments
    parse_arguments "$@"

    # Show version if requested
    if [ "$VERSION" = "1" ]; then
        check_version
    fi

    # List devices if requested
    if [ "$LIST_DEVICES" = "1" ]; then
        list_devices
    fi

    # Check dependencies
    check_dependencies

    # Download model from HuggingFace if specified (before check_model)
    download_model

    # Exit early in download-only mode (before starting server)
    if [ "$DOWNLOAD_ONLY" = "1" ]; then
        log "Download-only mode: exiting"
        exit 0
    fi

    # Check model (skip if --hf was used and handled by download_model)
    check_model

    # Check port
    check_port

    # Build command
    local cmd=$(build_command)

    # Execute command
    execute_command "$cmd"

    # Verify server
    verify_server

    # Cleanup on exit (only if not running in background/daemon)
    if [ "$DAEMON" != "1" ] && [ "$BACKGROUND" != "1" ]; then
        cleanup
    fi
}

# Run main function
main "$@"