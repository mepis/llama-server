# Instructions

Create a variety of bash scripts for installing, compiling, upgrading, launching, and managing Llama.cpp

**Step-by-step Instructions**:

1. Read through this instruction file thoroughly before proceeding.
2. Inspect this project folder thoroughly to understand its existing contents.
3. Create a brief summary of this instruction set and project folder contents. Save the summary to the progress.md file.
4. Read any available documentation for the technologies listed in the Technical Requirements section, and understand what the values in the Mongo DB docs represent. Summarize your understanding in the progress.md file.
5. Develop a list of technical requirements to complete this project, and save them to the progress.md file.
6. Develop small and easily completable phases to complete this project, and save them to the progress.md file.
7. Create detailed todo lists for each phase of this project, and save them to the progress.md file.
8. Review all phases, todo lists, action items, etc. in the progress.md file to ensure it does not contain any gaps in requirements.
9. Begin work on creating the application, completing one todo list at a time. After completing each todo list, test the completed work for any errors or bugs before moving to the next todo list. Update the progress.md file after completing a todo list and QA testing results before moving to the next todo list.
10. After completing the project, create a summary of all work completed. Save the summary to a file called summary.md in the logs folder.
11. Create detailed documentation for this project in the docs folder.

**Documentation**:

- https://github.com/ggml-org/llama.cpp
- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/BLIS.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md
- https://github.com/ggml-org/llama.cpp/tree/master/tools/server

**Additional Info**:

A log file called 'progress.md' contains all progress completed for this project thus far. This file must be updated as work on this project is completed. It should be written so other LLMs can read and understand the progress completed on this project and resume work as needed. The progress.md file is located in the 'docs' folder.

**Requirements**
When appropriate, scripts should take the hardware of the local computer into account.

Nvidia builds support should include Unified Memory.

Compile Llama.cpp against all available hardware able to accelerate LLMs.

Downloading models from Huggingface using the -hf parameter should be supported.

Include a script that terminates all instances of Llama.cpp and frees any memory used by Llama.cpp/
