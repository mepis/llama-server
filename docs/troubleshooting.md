# Troubleshooting Guide

Common issues and solutions for the Llama.cpp Management Suite.

---

## Installation Issues

### Permission Denied

**Symptom:** `Please run as root or use sudo`

**Solution:**
```bash
sudo ./scripts/install/install-lamacpp.sh
```

**Note:** Installation requires root to install packages, write to `/opt/`, and create systemd services.

---

### CMake Version Too Old

**Symptom:** `CMake 3.x required but only 2.x found`

**Solution:**
```bash
# Ubuntu/Debian - install newer CMake
sudo apt-get install cmake
# If still too old, install from Kitware's repo:
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc | sudo apt-key add -
sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'
sudo apt-get update && sudo apt-get install cmake
```

---

### Git Clone Fails

**Symptom:** `fatal: unable to access 'https://github.com/ggml-org/llama.cpp'`

**Solution:**
```bash
# Check internet connectivity
curl -I https://github.com

# Try with proxy if behind firewall
export https_proxy=http://your-proxy:port
git clone https://github.com/ggml-org/llama.cpp /tmp/llama-cpp

# Set git proxy
git config --global http.proxy http://your-proxy:port
```

---

### Missing Build Dependencies

**Symptom:** `Missing dependencies: git cmake gcc g++`

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install git cmake build-essential

# Fedora/RHEL
sudo dnf install git cmake gcc gcc-c++ make

# Arch Linux
sudo pacman -S git cmake base-devel

# Alpine
sudo apk add git cmake build-base
```

---

## Compilation Issues

### CUDA Not Found

**Symptom:** `nvcc: command not found` or CUDA cmake errors

**Solution:**
```bash
# Check if nvidia-smi works
nvidia-smi

# Install CUDA toolkit
sudo apt-get install nvidia-cuda-toolkit

# Or install from NVIDIA's official repo:
# https://developer.nvidia.com/cuda-downloads

# Verify CUDA is in PATH
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

---

### ROCm Build Fails

**Symptom:** `hipconfig: command not found` or HIP compilation errors

**Solution:**
```bash
# Install ROCm
sudo apt-get install rocm-dev

# Source ROCm environment
source /opt/rocm/share/rocm/setup.env
# Or:
export PATH=$PATH:/opt/rocm/bin

# Verify hipconfig
hipconfig --version

# Set correct GPU target manually
export GPU_TARGETS=gfx1100  # Replace with your GPU's gfx version
```

**Find your GPU target:**
```bash
rocminfo | grep -E 'Name:|gfx'
```

---

### Compilation Out of Memory

**Symptom:** Compilation killed due to OOM or very slow due to swap

**Solution:**
```bash
# Reduce parallel jobs in compile-lamacpp.sh
# Edit the line:
cmake --build "$BUILD_DIR" --config Release -j 2  # Use 2 instead of nproc

# Or set an environment variable
export MAKEFLAGS="-j2"
```

---

### Static Library Linking Errors

**Symptom:** `undefined reference to ...` during linking

**Solution:**
```bash
# Don't use static build (answer 'n' to static build question)
# Or ensure all dependencies are installed:
sudo apt-get install libopenblas-dev libblas-dev liblapack-dev
```

---

## Launch Issues

### llama-server Binary Not Found

**Symptom:** `Missing dependencies: llama-server binary`

**Solution:**
```bash
# Check if installed
which llama-server
ls /usr/local/bin/llama-server
ls /opt/llama-cpp/bin/llama-server

# If not installed, run installation first:
sudo ./scripts/install/install-lamacpp.sh

# Or compile and install manually:
./scripts/compile/compile-lamacpp.sh

# Add to PATH if in custom location
export PATH=/opt/llama-cpp/bin:$PATH
```

---

### Port Already In Use

**Symptom:** `Port 8080 is already in use`

**Solution:**
```bash
# Find what's using the port
lsof -i :8080
ss -tlnp | grep :8080

# Kill the process
lsof -t -i:8080 | xargs kill -9

# Or use a different port
./scripts/launch/launch-lamacpp.sh --model model.gguf --port 8081
```

---

### Model File Not Found

**Symptom:** `Model file not found: /path/to/model.gguf`

**Solution:**
```bash
# Verify model path
ls -la /path/to/model.gguf

# Download model from HuggingFace instead
./scripts/launch/launch-lamacpp.sh --hf bartowski/Llama-3.2-3B-Instruct-GGUF

# List available models
ls /opt/llama-cpp/models/
```

---

### GPU Out of Memory

**Symptom:** `CUDA error: out of memory` or model fails to load

**Solutions:**

1. **Reduce GPU layers:**
```bash
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 20  # Start low
```

2. **Enable Unified Memory:**
```bash
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --unified-memory
```

3. **Use smaller quantization:**
```bash
# Use Q4_K_M instead of Q8_0 or fp16
./scripts/launch/launch-lamacpp.sh --model model.Q4_K_M.gguf --ngl 99
```

4. **Reduce context size:**
```bash
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --context 512
```

5. **Reduce batch size:**
```bash
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --batch-size 64
```

---

### Server Starts But Is Unreachable

**Symptom:** Server reports started but `curl http://localhost:8080` fails

**Solution:**
```bash
# Check if server is actually running
./scripts/manage/manage-lamacpp.sh status
ps aux | grep llama-server

# Check logs for errors
./scripts/manage/manage-lamacpp.sh logs

# Check if port is listening
ss -tlnp | grep 8080
netstat -tlnp | grep 8080

# Try binding to localhost only
./scripts/launch/launch-lamacpp.sh --model model.gguf --host 127.0.0.1 --port 8080

# Check firewall
sudo ufw status
sudo iptables -L | grep 8080
```

---

### Server Crashes Immediately

**Symptom:** Server process exits immediately after starting

**Solution:**
```bash
# Run in foreground to see error output
./scripts/launch/launch-lamacpp.sh --model model.gguf

# Check recent logs
./scripts/manage/manage-lamacpp.sh logs

# Enable debug logging
export GGML_LOG_LEVEL=debug
llama-server --model model.gguf --port 8080 2>&1 | head -50
```

---

## GPU Detection Issues

### Nvidia GPU Not Detected

**Symptom:** `No Nvidia GPU detected` when GPU is present

**Solution:**
```bash
# Check Nvidia driver status
nvidia-smi
lspci | grep -i nvidia

# Install/reinstall Nvidia drivers
sudo apt-get install nvidia-driver-535  # Or latest version

# Load Nvidia kernel module
sudo modprobe nvidia

# Check if driver is loaded
lsmod | grep nvidia
```

---

### AMD GPU Not Detected

**Symptom:** `No AMD GPU detected` when AMD GPU is present

**Solution:**
```bash
# Check if ROCm is installed
which rocm-smi
ls /opt/rocm/

# Check GPU visibility
lspci | grep -i amd
/opt/rocm/bin/rocminfo

# Add user to video/render groups
sudo usermod -aG video,render $USER
# Log out and back in, then retry
```

---

### Vulkan Not Available

**Symptom:** Vulkan build fails or `vulkaninfo` not found

**Solution:**
```bash
# Install Vulkan tools
sudo apt-get install vulkan-tools libvulkan-dev

# Verify GPU has Vulkan support
vulkaninfo --summary

# Install Vulkan ICD for your GPU:
# Nvidia: nvidia-driver (includes Vulkan)
# AMD: sudo apt-get install mesa-vulkan-drivers
# Intel: sudo apt-get install intel-media-va-driver mesa-vulkan-drivers
```

---

## Management Issues

### Cannot Stop Server

**Symptom:** `manage-lamacpp.sh stop` fails or server keeps running

**Solution:**
```bash
# Find the process manually
ps aux | grep llama-server

# Kill by PID
kill -TERM $(cat /tmp/llama-server.pid)

# Force kill if still running
kill -KILL $(pgrep -f llama-server)

# Or use terminate script
sudo ./scripts/terminate/terminate-lamacpp.sh
```

---

### Systemd Service Won't Start

**Symptom:** `sudo systemctl start llama-server` fails

**Solution:**
```bash
# Check service status
sudo systemctl status llama-server

# View service logs
sudo journalctl -u llama-server -n 50

# Edit service file to fix issues
sudo systemctl edit llama-server --full

# Common fix: ensure binary exists
which llama-server

# Reload after editing
sudo systemctl daemon-reload
sudo systemctl restart llama-server
```

---

### Log Files Growing Too Large

**Symptom:** Disk space consumed by log files

**Solution:**
```bash
# View log directory size
du -sh /opt/llama-cpp/logs/

# Clean old logs (terminate script does this automatically)
sudo ./scripts/terminate/terminate-lamacpp.sh

# Manual cleanup
find /opt/llama-cpp/logs/ -name "*.log" -mtime +7 -delete

# Set up log rotation
sudo cat > /etc/logrotate.d/llama-cpp <<EOF
/opt/llama-cpp/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
```

---

## Performance Issues

### Slow Inference Speed

**Symptom:** Tokens per second is lower than expected

**Diagnosis:**
```bash
# Check if GPU is being used
nvidia-smi  # Look for GPU utilization > 0%

# Check current inference stats
curl http://localhost:8080/metrics
```

**Solutions:**

1. **Ensure GPU layers are being used:**
```bash
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99
```

2. **Enable native CPU optimizations (if CPU inference):**
```bash
# Recompile with GGML_NATIVE=ON (answer 'y' to native optimizations in compile script)
```

3. **Increase batch size for parallel requests:**
```bash
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --batch-size 1024
```

4. **Use a more quantized model for speed:**
```bash
# Q4_K_M is often the sweet spot for quality/speed
./scripts/launch/launch-lamacpp.sh --model model.Q4_K_M.gguf --ngl 99
```

---

### High CPU Usage When Using GPU

**Symptom:** CPU usage is 100% even when GPU is handling inference

**Solution:**
```bash
# Reduce CPU threads (some CPU work is unavoidable for tokenization/sampling)
./scripts/launch/launch-lamacpp.sh --model model.gguf --ngl 99 --threads 4

# Check if model is actually on GPU
nvidia-smi  # GPU memory should be mostly used
```

---

## Debug Mode

Enable verbose logging for detailed troubleshooting:

```bash
# Set debug log level
export GGML_LOG_LEVEL=debug

# Run server directly with verbose output
llama-server --model /path/to/model.gguf --port 8080 2>&1 | tee /tmp/llama-debug.log

# Or use launch script with debug
./scripts/launch/launch-lamacpp.sh --model model.gguf --log-level debug
```

---

## Getting Additional Help

1. Check the [Llama.cpp GitHub Issues](https://github.com/ggml-org/llama.cpp/issues)
2. Review the [Server Documentation](https://github.com/ggml-org/llama.cpp/tree/master/tools/server)
3. Check `docs/hardware.md` for hardware-specific guidance
4. Review `docs/scripts.md` for script parameter reference
5. Check `logs/summary.md` for known limitations of this suite

### Collecting Debug Information

When reporting issues, collect:
```bash
# Hardware info
./scripts/detect-hardware.sh > /tmp/hw-info.txt

# Script version and OS
uname -a >> /tmp/hw-info.txt
cat /etc/os-release >> /tmp/hw-info.txt

# llama-server version
llama-server --version 2>&1 >> /tmp/hw-info.txt

# Recent logs
./scripts/manage/manage-lamacpp.sh logs >> /tmp/hw-info.txt
```
