# Llama.cpp Management Suite

A comprehensive set of bash scripts for installing, compiling, upgrading, launching, and managing Llama.cpp on various hardware configurations.

## Features

- **Hardware Detection**: Automatically detect and configure for your system's capabilities
- **Multi-Platform Support**: Works on Ubuntu/Debian, Fedora, Arch Linux, Alpine, macOS, and Windows
- **GPU Acceleration**: Support for Nvidia CUDA, AMD ROCm, Vulkan, and Apple Silicon
- **Model Management**: Download models from HuggingFace directly
- **Process Management**: Start, stop, restart, and monitor Llama.cpp instances
- **Memory Management**: Cleanup GPU and CPU memory after use
- **Safe Upgrades**: Backup and rollback capabilities

## Installation

### Prerequisites

- Bash shell
- Root/sudo privileges for installation
- Internet connection for downloading dependencies and models

### Quick Start

1. Clone or download this repository
2. Navigate to the scripts directory
3. Run the main script:

```bash
cd scripts
./llama.sh
```

Or use individual commands:

```bash
# Install Llama.cpp
./install/install-lamacpp.sh

# Compile with GPU support
./compile/compile-lamacpp.sh

# Launch server
./launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99

# Manage server
./manage/manage-lamacpp.sh start
```

## Scripts

### Main Entry Point

- **`llama.sh`** - Unified interface to all management functions

### Hardware Detection

- **`detect-hardware.sh`** - Detect system hardware and capabilities

### Installation

- **`install/install-lamacpp.sh`** - Install Llama.cpp with hardware detection

### Compilation

- **`compile/compile-lamacpp.sh`** - Compile Llama.cpp for specific hardware

### Upgrading

- **`upgrade/upgrade-lamacpp.sh`** - Upgrade existing Llama.cpp installations

### Launching

- **`launch/launch-lamacpp.sh`** - Launch Llama.cpp server with various options

### Management

- **`manage/manage-lamacpp.sh`** - Manage Llama.cpp instances (start/stop/restart)

### Termination

- **`terminate/terminate-lamacpp.sh`** - Terminate all instances and free memory

## Usage Examples

### Install Llama.cpp

```bash
sudo ./install/install-lamacpp.sh
```

This will:
- Detect your hardware
- Install dependencies
- Download and compile Llama.cpp
- Create configuration files
- Set up systemd service

### Compile Llama.cpp

```bash
./compile/compile-lamacpp.sh
```

Choose from options:
- All backends (recommended)
- CPU only
- CUDA (Nvidia GPU)
- ROCm (AMD GPU)
- Vulkan (Cross-platform GPU)
- Metal (Apple Silicon)
- Custom configuration

### Upgrade Llama.cpp

```bash
sudo ./upgrade/upgrade-lamacpp.sh
```

This will:
- Backup your current installation
- Download latest version
- Compile with same/hardware-specific settings
- Preserve configuration and models

### Launch Server

```bash
# Basic launch
./launch/launch-lamacpp.sh --model /path/to/model.gguf

# With GPU offloading
./launch/launch-lamacpp.sh --model /path/to/model.gguf --ngl 99

# From HuggingFace
./launch/launch-lamacpp.sh --hf meta-llama/Llama-2-7b-chat-hf

# Background mode
./launch/launch-lamacpp.sh --model /path/to/model.gguf --daemon

# Custom configuration
./launch/launch-lamacpp.sh --model /path/to/model.gguf --port 8080 --host 0.0.0.0 --threads 16 --context-size 2048
```

### Manage Server

```bash
# Start server
./manage/manage-lamacpp.sh start

# Stop server
./manage/manage-lamacpp.sh stop

# Restart server
./manage/manage-lamacpp.sh restart

# Check status
./manage/manage-lamacpp.sh status

# View logs
./manage/manage-lamacpp.sh logs

# Monitor in real-time
./manage/manage-lamacpp.sh monitor

# List all instances
./manage/manage-lamacpp.sh list
```

### Terminate and Cleanup

```bash
sudo ./terminate/terminate-lamacpp.sh
```

This will:
- Terminate all Llama.cpp instances
- Free GPU memory
- Clear CPU cache
- Clean up old logs
- Remove temporary files

### Hardware Detection

```bash
./detect-hardware.sh
```

Displays:
- CPU information
- GPU information
- Memory status
- Operating system
- Disk space

## Configuration

### Default Configuration

Location: `/opt/llama-cpp/config/default.yaml`

```yaml
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
```

### Environment Variables

- `INSTALL_DIR` - Installation directory (default: ~/.local/llama-cpp)
- `BUILD_DIR` - Build directory (default: ~/.local/llama-cpp/build)
- `LOG_FILE` - Log file path
- `PORT` - Server port (default: 8080)
- `HOST` - Server host (default: 0.0.0.0)

## Supported Hardware

### Nvidia
- CUDA support with Unified Memory
- Automatic compute capability detection
- Optional MMQ and cuBLAS kernels

### AMD
- ROCm support
- Automatic GPU target detection
- Optional rocWMMA support

### Apple Silicon
- Metal support
- Automatic device detection
- Optimized for Apple M-series chips

### Intel
- OpenVINO support
- oneMKL support
- ZenDNN support

### Cross-Platform
- Vulkan support
- WebGPU (experimental)
- CPU with various instruction sets (AVX2, AVX-512, ARM NEON)

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Use sudo for installation and management commands
   - Ensure scripts are executable: `chmod +x scripts/*.sh`

2. **Port Already in Use**
   - Check what's using the port: `lsof -i :8080`
   - Choose a different port: `--port 8081`

3. **Model Not Found**
   - Verify model path: `ls -la /path/to/model.gguf`
   - Download model first: `--hf <model-name>`

4. **GPU Not Detected**
   - Install required drivers
   - Check with: `nvidia-smi` or `rocm-smi`

5. **Compilation Failed**
   - Check dependencies: `./compile/compile-lamacpp.sh`
   - Review build logs
   - Try CPU-only build

### Debug Mode

Enable debug logging:

```bash
export GGML_LOG_LEVEL=debug
./launch/launch-lamacpp.sh --model /path/to/model.gguf
```

### Getting Help

```bash
# View help for any command
./llama.sh help
./launch/launch-lamacpp.sh --help
./manage/manage-lamacpp.sh --help
```

## Documentation

- [Main Llama.cpp Documentation](https://github.com/ggml-org/llama.cpp)
- [Build Documentation](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)
- [Function Calling](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md)
- [Multimodal Models](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md)
- [Speculative Decoding](https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md)

## Contributing

This project is open source and welcomes contributions. Please follow these guidelines:

1. Submit pull requests to the main repository
2. Test your changes on different platforms
3. Update documentation as needed
4. Follow the existing code style

## License

This project is provided as-is for educational and personal use. Please refer to the Llama.cpp project for licensing information.

## Support

For issues and questions:
- Check the troubleshooting section above
- Review the [Llama.cpp documentation](https://github.com/ggml-org/llama.cpp)
- Check the progress.md file for detailed project status
- Review the summary.md file for comprehensive project information

## Changelog

### Version 1.0.0 (February 16, 2026)
- Initial release
- Core scripts implemented
- Hardware detection
- Multi-platform support
- GPU acceleration support
- Model download from HuggingFace
- Process management
- Memory cleanup

## Acknowledgments

- [Llama.cpp](https://github.com/ggml-org/llama.cpp) - The underlying LLM library
- [Hugging Face](https://huggingface.co/) - Model hosting and distribution
- [NVIDIA](https://developer.nvidia.com/cuda-toolkit) - CUDA support
- [AMD](https://rocm.docs.amd.com/) - ROCm support
- [Vulkan](https://vulkan.lunarg.com/) - Cross-platform GPU support