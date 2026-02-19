#!/usr/bin/env bash
# download-model.sh — Download a GGUF model from HuggingFace
#
# Usage:
#   download-model.sh <model_id> <filename> [dest_dir]
#
# Examples:
#   download-model.sh TheBloke/Mistral-7B-Instruct-v0.2-GGUF mistral-7b-instruct-v0.2.Q4_K_M.gguf
#   download-model.sh bartowski/gemma-2-2b-it-GGUF gemma-2-2b-it-Q4_K_M.gguf /data/models
#
# Environment variables:
#   HF_TOKEN    - HuggingFace access token (required for gated models)
#   MODELS_DIR  - default destination directory (overridden by 3rd argument)

set -euo pipefail

# ---- argument parsing -------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <model_id> <filename> [dest_dir]" >&2
  echo "  model_id  : HuggingFace repo, e.g. TheBloke/Mistral-7B-GGUF" >&2
  echo "  filename  : file inside the repo, e.g. mistral-7b.Q4_K_M.gguf" >&2
  echo "  dest_dir  : local save directory (default: \$MODELS_DIR or ./models)" >&2
  exit 1
fi

MODEL_ID="$1"
FILENAME="$2"
DEST_DIR="${3:-${MODELS_DIR:-$(dirname "$0")/../../models}}"

# Resolve to absolute path
DEST_DIR="$(realpath -m "$DEST_DIR")"
mkdir -p "$DEST_DIR"

DEST_FILE="${DEST_DIR}/${FILENAME}"
TMP_FILE="${DEST_FILE}.part"

echo "Model   : ${MODEL_ID}"
echo "File    : ${FILENAME}"
echo "Save to : ${DEST_DIR}"

# ---- check if already downloaded --------------------------------------------
if [[ -f "$DEST_FILE" ]]; then
  echo "Already downloaded: ${DEST_FILE}"
  exit 0
fi

# ---- build download URL -----------------------------------------------------
# HuggingFace CDN URL pattern
HF_URL="https://huggingface.co/${MODEL_ID}/resolve/main/${FILENAME}"

echo "URL     : ${HF_URL}"

# ---- prefer huggingface-cli if available ------------------------------------
if command -v huggingface-cli &>/dev/null; then
  echo "Downloading via huggingface-cli..."
  HF_ARGS=(
    download
    "$MODEL_ID"
    "$FILENAME"
    --local-dir "$DEST_DIR"
    --local-dir-use-symlinks False
  )
  if [[ -n "${HF_TOKEN:-}" ]]; then
    HF_ARGS+=(--token "$HF_TOKEN")
  fi
  huggingface-cli "${HF_ARGS[@]}"
  echo "Done: ${DEST_FILE}"
  exit 0
fi

# ---- fall back to wget / curl -----------------------------------------------
CURL_ARGS=(
  --location          # follow redirects
  --fail              # non-zero exit on HTTP errors
  --continue-at -     # resume partial downloads
  --progress-bar
  --output "$TMP_FILE"
)

if [[ -n "${HF_TOKEN:-}" ]]; then
  CURL_ARGS+=(--header "Authorization: Bearer ${HF_TOKEN}")
fi

if command -v curl &>/dev/null; then
  echo "Downloading via curl..."
  curl "${CURL_ARGS[@]}" "$HF_URL"
  mv "$TMP_FILE" "$DEST_FILE"
  echo "Done: ${DEST_FILE}"
  exit 0
fi

WGET_ARGS=(
  --continue          # resume partial downloads
  --show-progress
  --output-document "$TMP_FILE"
)

if [[ -n "${HF_TOKEN:-}" ]]; then
  WGET_ARGS+=(--header "Authorization: Bearer ${HF_TOKEN}")
fi

if command -v wget &>/dev/null; then
  echo "Downloading via wget..."
  wget "${WGET_ARGS[@]}" "$HF_URL"
  mv "$TMP_FILE" "$DEST_FILE"
  echo "Done: ${DEST_FILE}"
  exit 0
fi

echo "Error: none of huggingface-cli, curl, or wget are available." >&2
exit 1
