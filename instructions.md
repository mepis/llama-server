# Instructions

**Summary**:
Create a server that manages llama.cpp servers. It's goal should be to automate installing, updating, and configuring llama.cpp servers. It should be easy to use and expose/serve all llama.cpp endpoints.


**Step-by-step Instructions**:

1. Read through this instruction file thoroughly before proceeding.
2. Inspect this project folder thoroughly to understand its existing contents.
3. Create a brief summary of this instruction set and project folder contents. Save the summary to the progress.md file.
4. Analyze the records in the Mongo DB table and understand the data that the Mongo DB docs provide. Make sure to analyze documents that include the proxy, devicetracker, email, phone, and proxy.transaction_details nested objects. Document your findings in the progress.md file.
5. Read the documentation links listed above, and understand what the values in the Mongo DB docs represent. Summarize your understanding in the progress.md file.
6. Develop a list of technical requirements to complete this project, and save them to the progress.md file.
7. Develop small and easily completable phases to complete this project, and save them to the progress.md file.
8. Create detailed todo lists for each phase of this project, and save them to the progress.md file.
9. Review all phases, todo lists, action items, etc. in the progress.md file to ensure it does not contain any gaps in requirements.
10. Begin work on creating the application, completing one todo list at a time. After completing each todo list, test the completed work for any errors or bugs before moving to the next todo list. Update the progress.md file after completing a todo list and QA testing resuls before moving to the next todo list.
11. After completing the project, create a summary of all work completed. Save the summary to a file called summary.md in the logs folder.
12. Create detailed documentation for this project in the docs folder.

## App Requirements
- launch llama.cpp on start
- include llama.cpp as a git submodule
- include function to kill the server, including llama.cpp
- include functions to update and recompile llama.cpp
- include automations to compile llama.cpp based on the hardware present on the machine
- expose all endpoints from llama.cpp
- detailed documentation
- support to download models from huggingface
- support to launch multiple llama.cpp servers for different functions (eg. embedings, imgage generation, OCR functions, audio generation, etc.)
- support to re-launch llama.cpp servers
- api support to manage server configs
- include a /help endpoint that returns documentation of each endpoint
- reroute llama.cpp endpoints to the correct llama.cpp server based on endpoint type ( eg. embedings -> embeding server, etc.), one endpoint and port to call for external apps

## Documentation
- llama.cpp web server documentation: https://github.com/ggml-org/llama.cpp/tree/master/tools/server