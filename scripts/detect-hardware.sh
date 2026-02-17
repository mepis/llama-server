#!/bin/bash

# Hardware Detection Script
# This script detects various hardware configurations including:
# - CPU (architecture, instruction sets)
# - GPU (Nvidia, AMD, Apple Silicon, Intel)
# - Memory configuration
# - Operating system

set -e

echo "=== Hardware Detection Script ==="
echo ""

# Get system information
echo "System Information:"
echo "-------------------"
uname -a
echo ""

# CPU Information
echo "CPU Information:"
echo "----------------"
if command -v lscpu &> /dev/null; then
    lscpu
else
    echo "lscpu command not found"
fi
echo ""

# GPU Detection
echo "GPU Detection:"
echo "--------------"

# Nvidia GPU
if command -v nvidia-smi &> /dev/null; then
    echo "Nvidia GPU detected:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    UNIFIED_MEMORY_SUPPORTED=true
else
    echo "No Nvidia GPU detected"
    UNIFIED_MEMORY_SUPPORTED=false
fi
echo ""

# AMD GPU
if command -v rocm-smi &> /dev/null; then
    echo "AMD GPU detected:"
    rocm-smi
else
    echo "No AMD GPU detected"
fi
echo ""

# Apple Silicon
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v sysctl &> /dev/null && sysctl -n machdep.cpu.brand_string | grep -iq "apple"; then
        echo "Apple Silicon detected:"
        sysctl -n machdep.cpu.brand_string
        echo ""
        echo "Core count: $(sysctl -n hw.ncpu)"
        echo "Memory: $(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )) GB"
    else
        echo "No Apple Silicon detected"
    fi
else
    echo "Apple Silicon only available on macOS"
fi
echo ""

# Intel GPU (OpenVINO)
if command -v icd-loader &> /dev/null; then
    echo "Intel GPU with OpenVINO detected"
else
    echo "No Intel GPU with OpenVINO detected"
fi
echo ""

# Memory Information
echo "Memory Information:"
echo "-------------------"
if command -v free &> /dev/null; then
    free -h
else
    echo "free command not found"
fi
echo ""

# Operating System
echo "Operating System:"
echo "-----------------"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux"
    if command -v lsb_release &> /dev/null; then
        lsb_release -a 2>/dev/null
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS"
    sw_vers
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "Windows"
else
    echo "Unknown OS"
fi
echo ""

# Disk Information
echo "Disk Information:"
echo "-----------------"
if command -v df &> /dev/null; then
    df -h
else
    echo "df command not found"
fi
echo ""

# Save detection results to file
OUTPUT_FILE="/tmp/hardware_detection_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "Hardware Detection Report"
    echo "Generated: $(date)"
    echo ""
    echo "Nvidia Unified Memory Support: $UNIFIED_MEMORY_SUPPORTED"
} > "$OUTPUT_FILE"

echo "Detection results saved to: $OUTPUT_FILE"
echo ""
echo "=== Detection Complete ==="