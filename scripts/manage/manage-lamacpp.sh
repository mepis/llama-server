#!/bin/bash

# Llama.cpp Management Script
# This script manages Llama.cpp instances (start, stop, restart, list)

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
CONFIG_DIR="${CONFIG_DIR:-/opt/llama-cpp/config}"

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

list_processes() {
    log "Listing Llama.cpp processes..."

    echo ""
    echo "=========================================="
    echo "  Running Llama.cpp Instances"
    echo "=========================================="
    echo ""

    # Check PID file
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            echo "PID File: $PID_FILE"
            echo "PID: $pid"
            echo "Status: Running"
            echo ""
            ps -p $pid -o pid,ppid,%cpu,%mem,etime,command
            echo ""
        else
            warning "PID file exists but process is not running (PID: $pid)"
            echo ""
        fi
    fi

    # Find all llama-server processes
    local processes=$(pgrep -f llama-server | grep -v "^$$\$" || true)

    if [ -z "$processes" ]; then
        echo "No Llama.cpp processes found"
        return
    fi

    echo "Found $(echo "$processes" | wc -l) process(es):"
    echo ""

    for pid in $processes; do
        echo "PID: $pid"
        ps -p $pid -o pid,ppid,%cpu,%mem,etime,command
        echo ""
    done

    echo "=========================================="
}

start() {
    log "Starting Llama.cpp server..."

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            error "Server is already running (PID: $pid)"
        else
            warning "Stale PID file found, removing..."
            rm -f "$PID_FILE"
        fi
    fi

    # Start the server
    if [ -f "/usr/local/bin/llama-server" ]; then
        /usr/local/bin/llama-server &
    elif [ -f "/opt/llama-cpp/bin/llama-server" ]; then
        /opt/llama-cpp/bin/llama-server &
    else
        error "llama-server binary not found"
        exit 1
    fi

    local pid=$!
    echo $pid > "$PID_FILE"

    # Wait a moment and check if it started
    sleep 2

    if ps -p $pid > /dev/null 2>&1; then
        log "Server started successfully (PID: $pid)"
        echo ""
        echo "=========================================="
        echo "  Server Started"
        echo "=========================================="
        echo ""
        echo "PID: $pid"
        echo "Log file: $LOG_DIR/llama-server-$(date +%Y%m%d_%H%M%S).log"
        echo "Access: http://localhost:8080"
        echo ""
    else
        error "Server failed to start"
        rm -f "$PID_FILE"
        exit 1
    fi
}

stop() {
    log "Stopping Llama.cpp server..."

    # Check if running
    if [ ! -f "$PID_FILE" ]; then
        error "No PID file found, server may not be running"
        exit 1
    fi

    local pid=$(cat "$PID_FILE")

    if ! ps -p $pid > /dev/null 2>&1; then
        error "Server is not running (PID: $pid)"
        rm -f "$PID_FILE"
        exit 1
    fi

    # Try graceful shutdown first
    log "Sending SIGTERM to process $pid..."
    kill $pid

    # Wait for process to terminate
    local max_wait=10
    local elapsed=0

    while ps -p $pid > /dev/null 2>&1; do
        if [ $elapsed -ge $max_wait ]; then
            warning "Process did not terminate gracefully, using SIGKILL"
            kill -9 $pid
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Remove PID file
    rm -f "$PID_FILE"

    # Check if process was killed
    if ! ps -p $pid > /dev/null 2>&1; then
        log "Server stopped successfully"
        echo ""
        echo "=========================================="
        echo "  Server Stopped"
        echo "=========================================="
        echo ""
    else
        error "Failed to stop server"
        exit 1
    fi
}

restart() {
    log "Restarting Llama.cpp server..."

    # Stop first
    stop

    # Wait a moment
    sleep 2

    # Start again
    start
}

status() {
    log "Checking Llama.cpp server status..."

    echo ""
    echo "=========================================="
    echo "  Server Status"
    echo "=========================================="
    echo ""

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")

        if ps -p $pid > /dev/null 2>&1; then
            echo "Status: Running"
            echo "PID: $pid"
            echo ""

            echo "Resource Usage:"
            ps -p $pid -o pid,%cpu,%mem,etime,vsz,rss,command
            echo ""

            # Try to get more details if possible
            if [ -f "/usr/local/bin/llama-server" ] || [ -f "/opt/llama-cpp/bin/llama-server" ]; then
                local server_binary="/usr/local/bin/llama-server"
                if [ ! -f "$server_binary" ]; then
                    server_binary="/opt/llama-cpp/bin/llama-server"
                fi

                # Try to get model info
                if [ -f "$server_binary" ]; then
                    echo "Server Information:"
                    "$server_binary" --help 2>&1 | head -5 || true
                fi
            fi

            echo "=========================================="
        else
            echo "Status: Stopped"
            echo "PID file exists but process is not running"
            warning "Remove stale PID file: rm $PID_FILE"
            echo "=========================================="
        fi
    else
        echo "Status: Stopped"
        echo "No PID file found"
        echo "=========================================="
    fi
}

logs() {
    log "Showing Llama.cpp logs..."

    if [ ! -d "$LOG_DIR" ]; then
        error "Log directory not found: $LOG_DIR"
        exit 1
    fi

    # Find latest log file
    local latest_log=$(ls -t "$LOG_DIR"/llama-server-*.log 2>/dev/null | head -1)

    if [ -z "$latest_log" ]; then
        error "No log files found in $LOG_DIR"
        exit 1
    fi

    log "Latest log file: $latest_log"
    echo ""
    echo "=========================================="
    echo "  Log Output"
    echo "=========================================="
    echo ""
    tail -100 "$latest_log"
    echo ""
    echo "=========================================="
}

monitor() {
    log "Monitoring Llama.cpp server..."

    # Check if running
    if [ ! -f "$PID_FILE" ]; then
        error "Server is not running"
        exit 1
    fi

    local pid=$(cat "$PID_FILE")

    if ! ps -p $pid > /dev/null 2>&1; then
        error "Server is not running"
        exit 1
    fi

    echo ""
    echo "=========================================="
    echo "  Server Monitoring (Ctrl+C to exit)"
    echo "=========================================="
    echo ""

    while true; do
        clear
        echo "=========================================="
        echo "  Server Monitoring"
        echo "  $(date)"
        echo "=========================================="
        echo ""

        echo "Process Information:"
        ps -p $pid -o pid,ppid,%cpu,%mem,etime,command
        echo ""

        echo "Resource Usage:"
        ps -p $pid -o %cpu,%mem,vsz,rss,cmd --no-headers
        echo ""

        echo "Network Connections:"
        netstat -tlnp 2>/dev/null | grep $pid || echo "No network connections found"
        echo ""

        echo "=========================================="
        echo "  Press Ctrl+C to exit"
        echo "=========================================="

        sleep 5
    done
}

show_help() {
    echo "=========================================="
    echo "  Llama.cpp Management Script"
    echo "=========================================="
    echo ""
    echo "Usage: llama-manage [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start       Start the Llama.cpp server"
    echo "  stop        Stop the Llama.cpp server"
    echo "  restart     Restart the Llama.cpp server"
    echo "  status      Show server status"
    echo "  logs        Show server logs"
    echo "  monitor     Monitor server in real-time"
    echo "  list        List all running instances"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  llama-manage start"
    echo "  llama-manage stop"
    echo "  llama-manage restart"
    echo "  llama-manage status"
    echo "  llama-manage logs"
    echo "  llama-manage monitor"
    echo "  llama-manage list"
    echo ""
}

main() {
    # Check if command is provided
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    case $command in
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs
            ;;
        monitor)
            monitor
            ;;
        list)
            list_processes
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
}

# Run main function
main "$@"