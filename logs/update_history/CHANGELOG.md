# Llama.cpp Management Suite - Update History

## [04c3e8b] - 2026-02-18 - Updated readme

Updated README with improved project documentation. Added `pkg-config` to
dependency checks in `check-deps.sh` and `install-lamacpp.sh`, and improved
Vulkan detection to check for dev headers and shader compilers instead of
only the `vulkaninfo` binary.

**Files changed:** README.md, scripts/check-deps.sh, scripts/install/install-lamacpp.sh

---

## [89d7aa6] - 2026-02-18 - Resolving build script issues due to missing deps

Added a new `check-deps.sh` script that scans the system for all
dependencies required to build Llama.cpp (core build tools, BLAS, GPU
toolkits, SSL headers) and outputs platform-specific install commands.
Integrated the script into `llama.sh` (menu option 8 and CLI command
`check-deps`), the Express server script runner, and the Vue frontend
script catalog.

**Files changed:** scripts/check-deps.sh (new), scripts/llama.sh,
server/lib/scriptRunner.js, web/src/data/scripts.js

---

## [bd8061a] - 2026-02-18 - Resolved various website and script errors

Major update removing the `sudo` requirement from install, compile, and
upgrade scripts. All default paths changed from system directories to
user-local locations (`~/.local/llama-cpp`). Dependency installation
replaced with dependency checking that advises the user on what to install.
Symlinks now target `~/.local/bin/` instead of `/usr/local/bin/`. Systemd
service creation removed. Clone and build directories moved from `/tmp/` to
`~/.local/llama-cpp/src` and `~/.local/llama-cpp/build`. Launch, manage,
and terminate scripts updated to match new default paths. Documentation and
web app metadata updated to reflect all path changes. Fixed the `detect`
script ID mismatch in the server script runner (was `detect-hardware`,
frontend sends `detect`).

**Files changed:** README.md, docs/hardware.md, docs/scripts.md,
docs/troubleshooting.md, scripts/compile/compile-lamacpp.sh,
scripts/install/install-lamacpp.sh, scripts/launch/launch-lamacpp.sh,
scripts/manage/manage-lamacpp.sh, scripts/terminate/terminate-lamacpp.sh,
scripts/upgrade/upgrade-lamacpp.sh, server/lib/scriptRunner.js,
web/src/data/scripts.js, web/src/pages/DocsPage.vue,
web/src/pages/HomePage.vue

---

## [6e48146] - 2026-02-18 - Resolved frontend display issues

Fixed multiple Vue frontend issues preventing proper page rendering:

- Removed `<transition>` wrapper from `<router-view>` in App.vue to
  eliminate footer disappearing on navigation and layout collapse.
- Wrapped HomePage.vue and ScriptsPage.vue content in single root `<div>`
  elements (Vue transitions require single root children).
- Fixed docs page sidebar links by extracting inline `document.getElementById`
  to a `scrollTo()` method in `<script setup>`.
- Fixed page scroll being permanently locked by ScriptModal.vue setting
  `document.body.style.overflow = 'hidden'` on mount regardless of modal
  state; changed to a `watch()` on the `script` prop.

**Files changed:** web/src/App.vue, web/src/components/ScriptModal.vue,
web/src/pages/DocsPage.vue, web/src/pages/HomePage.vue,
web/src/pages/ScriptsPage.vue

---

## [35c4809] - 2026-02-18 - Fixed invalid header/footer links

Fixed navigation links in AppHeader.vue and AppFooter.vue not loading pages.
Switched Vue Router from `createWebHashHistory()` to `createWebHistory()`
to match the Express server's SPA fallback configuration. Updated
package.json start script.

**Files changed:** package.json, web/src/main.js

---

## [fd8ce0a] - 2026-02-18 - Web application and server infrastructure

Added the complete web application and Express server:

- Express 5 server with API routes for scripts, status, logs, processes,
  and hardware detection.
- Server-side script runner with SSE streaming of script output.
- Vue 3 frontend with Vite, Tailwind CSS v4, and Vue Router 4.
- Pages: Home, Scripts, Hardware, Docs.
- Components: AppHeader, AppFooter, ScriptCard, ScriptModal with terminal
  output, CodeBlock.
- Script catalog data with metadata, environment variables, and usage
  examples.
- Full documentation suite: hardware guide, scripts reference,
  troubleshooting guide.

**Files changed:** 48 files (server/, web/, docs/, scripts/, package.json,
.gitignore)

---

## [9ff051b] - 2026-02-16 - Project restructure and script suite

Restructured project from submodule-based layout to standalone repository.
Removed the llama.cpp git submodule. Added all management scripts:

- `install-lamacpp.sh` - Platform-aware installation with GPU detection
- `compile-lamacpp.sh` - Interactive compilation with backend selection
- `upgrade-lamacpp.sh` - Safe upgrade with backup and rollback
- `launch-lamacpp.sh` - Server launcher with HuggingFace model support
- `manage-lamacpp.sh` - Start/stop/restart/monitor management
- `terminate-lamacpp.sh` - Process termination and resource cleanup
- `detect-hardware.sh` - Hardware detection (CPU, GPU, memory)
- `llama.sh` - Unified CLI entry point with interactive menu

Added README, project documentation, and package.json.

**Files changed:** 17 files (.gitmodules removed, scripts/, docs/, README.md,
package.json)

---

## [a6960d2] - 2026-02-15 - Initial documentation

Added project instructions and progress tracking documents. Updated
llama.cpp submodule reference.

**Files changed:** backend/llama.cpp, instructions.md (new), progress.md (new)

---

## [24bfe8e] - 2026-02-15 - Initial commit

Initial repository setup with llama.cpp submodule.
