# Progress Summary

## Project Instructions

This project aims to create a server that manages llama.cpp servers. The system should automate installing, updating, and configuring llama.cpp servers with the following requirements:
- Launch llama.cpp on start
- Include llama.cpp as a git submodule
- Function to kill the server, including llama.cpp
- Functions to update and recompile llama.cpp
- Automations to compile llama.cpp based on hardware present on the machine
- Expose all llama.cpp endpoints
- Detailed documentation
- Support to download models from huggingface
- Support to launch multiple llama.cpp servers for different functions (embeddings, image generation, OCR functions, audio generation, etc.)
- Support to re-launch llama.cpp servers
- API support to manage server configs
- Include a `/help` endpoint that returns documentation of each endpoint
- Reroute llama.cpp endpoints to the correct llama.cpp server based on endpoint type

## Project Contents

This is a new project in its initial stages:
- Git repository initialized
- Single instruction file (instructions.md)
- llama.cpp backend submodule added at /backend/llama.cpp
- Documentation files available in /backend/llama.cpp/docs/
- Build documentation available at /backend/llama.cpp/docs/build.md