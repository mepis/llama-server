"use strict";

const https = require("https");
const http = require("http");
const fs = require("fs");
const path = require("path");
const { EventEmitter } = require("events");

const HF_API_BASE = "https://huggingface.co";
const HF_API_MODELS = "https://huggingface.co/api/models";

/**
 * Perform a simple HTTPS GET and resolve with parsed JSON.
 * @param {string} url
 * @param {object} headers
 * @returns {Promise<object>}
 */
function fetchJSON(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith("https") ? https : http;
    const req = protocol.get(url, { headers }, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return fetchJSON(res.headers.location, headers)
          .then(resolve)
          .catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
      }
      let body = "";
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(body));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on("error", reject);
    req.setTimeout(15000, () => {
      req.destroy(new Error("Request timed out"));
    });
  });
}

/**
 * Search HuggingFace for GGUF models.
 * @param {string} query - search term
 * @param {number} limit - max results (default 20)
 * @param {string} [token] - optional HF access token
 * @returns {Promise<Array>}
 */
async function searchModels(query, limit = 20, token) {
  const params = new URLSearchParams({
    search: query,
    filter: "gguf",
    limit: String(limit),
    sort: "downloads",
    direction: "-1",
  });
  const url = `${HF_API_MODELS}?${params}`;
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const results = await fetchJSON(url, headers);
  return results.map((m) => ({
    id: m.modelId || m.id,
    author: m.author,
    downloads: m.downloads,
    likes: m.likes,
    lastModified: m.lastModified,
    tags: m.tags || [],
    private: m.private || false,
  }));
}

/**
 * List files in a HuggingFace model repository.
 * @param {string} modelId  - e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} [token]
 * @returns {Promise<Array<{path, size, type}>>}
 */
async function listModelFiles(modelId, token) {
  const url = `${HF_API_BASE}/api/models/${modelId.split("/").map(encodeURIComponent).join("/")}`;
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const data = await fetchJSON(url, headers);
  const siblings = data.siblings || [];
  return siblings.map((f) => ({
    path: f.rfilename,
    size: f.size || null,
    type: f.rfilename.endsWith(".gguf")
      ? "gguf"
      : f.rfilename.endsWith(".json")
        ? "config"
        : "other",
  }));
}

/**
 * Download a single GGUF file from HuggingFace using Node.js HTTP streaming.
 * Supports resume via Range header if a partial file already exists.
 *
 * Emits: 'progress' { downloaded, total, percent }
 *         'done'     { filename, destPath }
 *         'error'    { message }
 *
 * @param {string} modelId   - e.g. "TheBloke/Mistral-7B-GGUF"
 * @param {string} filename  - e.g. "mistral-7b.Q4_K_M.gguf"
 * @param {string} destDir   - local directory to save the file
 * @param {string} [token]   - optional HF access token
 * @returns {{ emitter: EventEmitter, cancel: Function }}
 */
function downloadFile(modelId, filename, destDir, token) {
  const emitter = new EventEmitter();

  fs.mkdirSync(destDir, { recursive: true });

  const destPath = path.join(destDir, filename);
  const partPath = destPath + ".part";

  let cancelled = false;
  let currentReq = null;

  function cancel() {
    cancelled = true;
    if (currentReq) {
      currentReq.destroy();
      currentReq = null;
    }
  }

  function doRequest(url, resumeFrom) {
    if (cancelled) return;

    const isHttps = url.startsWith("https");
    const protocol = isHttps ? https : http;
    const headers = {};
    if (token) headers["Authorization"] = `Bearer ${token}`;
    if (resumeFrom > 0) headers["Range"] = `bytes=${resumeFrom}-`;

    const req = protocol.get(url, { headers }, (res) => {
      // Follow redirects
      if (
        res.statusCode === 301 ||
        res.statusCode === 302 ||
        res.statusCode === 307 ||
        res.statusCode === 308
      ) {
        currentReq = null;
        doRequest(res.headers.location, resumeFrom);
        return;
      }

      if (res.statusCode !== 200 && res.statusCode !== 206) {
        emitter.emit("error", {
          message: `HTTP ${res.statusCode} downloading ${filename}`,
        });
        return;
      }

      // Total size: Content-Length for fresh download, or resumeFrom + Content-Length for resume
      const contentLength = parseInt(res.headers["content-length"] || "0", 10);
      const total = resumeFrom + contentLength;

      let downloaded = resumeFrom;
      const flags = resumeFrom > 0 ? "a" : "w";
      const fileStream = fs.createWriteStream(partPath, { flags });

      // Inactivity timeout: cancel if no data received for 60s
      let inactivityTimer = null;
      function resetInactivity() {
        clearTimeout(inactivityTimer);
        inactivityTimer = setTimeout(() => {
          req.destroy(
            new Error("Download stalled — no data received for 60 seconds"),
          );
        }, 60000);
      }
      resetInactivity();

      res.on("data", (chunk) => {
        if (cancelled) return;
        resetInactivity();
        downloaded += chunk.length;
        fileStream.write(chunk);
        const percent =
          total > 0
            ? Math.min(100, Math.round((downloaded / total) * 100))
            : null;
        emitter.emit("progress", { downloaded, total, percent });
      });

      res.on("end", () => {
        clearTimeout(inactivityTimer);
        fileStream.end(() => {
          if (cancelled) return;
          // Rename .part → final file
          try {
            fs.renameSync(partPath, destPath);
            emitter.emit("done", { filename, destPath });
          } catch (err) {
            emitter.emit("error", {
              message: `Failed to finalise file: ${err.message}`,
            });
          }
        });
      });

      res.on("error", (err) => {
        clearTimeout(inactivityTimer);
        fileStream.end();
        if (!cancelled) emitter.emit("error", { message: err.message });
      });
    });

    req.on("error", (err) => {
      if (!cancelled) emitter.emit("error", { message: err.message });
    });

    currentReq = req;
  }

  // Build the HuggingFace CDN URL
  const encodedId = modelId.split("/").map(encodeURIComponent).join("/");
  const encodedFile = filename.split("/").map(encodeURIComponent).join("/");
  const url = `${HF_API_BASE}/${encodedId}/resolve/main/${encodedFile}`;

  // Resume if a .part file exists
  let resumeFrom = 0;
  try {
    resumeFrom = fs.statSync(partPath).size;
  } catch {
    /* no partial file */
  }

  doRequest(url, resumeFrom);

  return { emitter, cancel };
}

/**
 * Cancel an in-progress download.
 * @param {{ cancel: Function }} handle - the object returned by downloadFile
 */
function cancelDownload(handle) {
  if (!handle || typeof handle.cancel !== "function") return false;
  handle.cancel();
  return true;
}

/**
 * List already-downloaded model files in the models directory.
 * @param {string} modelsDir
 * @returns {Array<{filename, size, path}>}
 */
function listLocalModels(modelsDir) {
  const fs = require("fs");
  if (!fs.existsSync(modelsDir)) return [];
  const models = fs
    .readdirSync(modelsDir)
    .filter((f) => f.endsWith(".gguf"))
    .map((f) => {
      const full = path.join(modelsDir, f);
      const stat = fs.statSync(full);
      return {
        filename: f,
        size: stat.size,
        path: full,
        mtimeMs: stat.mtimeMs,
      };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  return models;
}

// Quant tags in rough quality order (used for sorting)
const QUANT_ORDER = [
  "Q8_0",
  "Q6_K",
  "Q5_K_M",
  "Q5_K_S",
  "Q5_0",
  "Q4_K_M",
  "Q4_K_S",
  "Q4_0",
  "Q3_K_L",
  "Q3_K_M",
  "Q3_K_S",
  "Q2_K",
  "Q2_K_S",
  "IQ4_XS",
  "IQ4_NL",
  "IQ3_M",
  "IQ3_S",
  "IQ3_XS",
  "IQ2_M",
  "IQ2_S",
  "IQ2_XS",
  "IQ1_M",
  "IQ1_S",
  "F16",
  "BF16",
  "F32",
];

/**
 * Group a flat list of GGUF file objects (from listModelFiles) into variants.
 *
 * Each variant represents one logical model file the user would want to
 * download — either a single .gguf file or a sharded set (e.g. model-00001-of-00004.gguf).
 *
 * Returns an array of:
 * {
 *   label:    string   — human-readable name, e.g. "Q4_K_M" or "F16 (4 shards)"
 *   quant:    string   — quantisation tag extracted from the filename, e.g. "Q4_K_M"
 *   files:    string[] — one or more filenames that make up this variant
 *   totalSize: number|null
 *   sharded:  boolean
 * }
 */
function groupGgufFiles(files) {
  // Only work with gguf files
  const gguf = files.filter((f) => f.type === "gguf");

  // Shard pattern: anything ending in -NNNNN-of-NNNNN.gguf
  const shardRe = /^(.+?)-(\d{5})-of-(\d{5})\.gguf$/i;

  const shardGroups = {}; // stem → [file, ...]
  const singles = [];

  for (const f of gguf) {
    const name = f.path.split("/").pop();
    const m = name.match(shardRe);
    if (m) {
      const stem = m[1]; // everything before -00001-of-00004
      if (!shardGroups[stem]) shardGroups[stem] = [];
      shardGroups[stem].push(f);
    } else {
      singles.push(f);
    }
  }

  const variants = [];

  // Sharded sets
  for (const [stem, shards] of Object.entries(shardGroups)) {
    shards.sort((a, b) => a.path.localeCompare(b.path));
    const quant = extractQuant(stem);
    const totalSize = shards.every((s) => s.size != null)
      ? shards.reduce((s, f) => s + f.size, 0)
      : null;
    variants.push({
      label: quant
        ? `${quant} (${shards.length} shards)`
        : `${stem} (${shards.length} shards)`,
      quant: quant || "Unknown",
      files: shards.map((s) => s.path),
      totalSize,
      sharded: true,
    });
  }

  // Single files
  for (const f of singles) {
    const name = f.path.split("/").pop();
    const quant = extractQuant(name);
    variants.push({
      label: quant || name.replace(/\.gguf$/i, ""),
      quant: quant || "Other",
      files: [f.path],
      totalSize: f.size,
      sharded: false,
    });
  }

  // Sort by quant quality order; unknowns go last
  variants.sort((a, b) => {
    const ai = QUANT_ORDER.indexOf(a.quant.toUpperCase());
    const bi = QUANT_ORDER.indexOf(b.quant.toUpperCase());
    const ar = ai === -1 ? 999 : ai;
    const br = bi === -1 ? 999 : bi;
    return ar - br;
  });

  return variants;
}

/**
 * Extract a quantisation tag from a filename or stem.
 * Returns e.g. "Q4_K_M", "IQ3_M", "F16", or null.
 */
function extractQuant(name) {
  // Order matters: try longer/more-specific patterns first
  const patterns = [
    /\b(IQ[1-4]_(?:XS|NL|[MSX]+))\b/i,
    /\b(Q[2-8]_K_[LMSX])\b/i,
    /\b(Q[2-8]_K)\b/i,
    /\b(Q[2-8]_[01])\b/i,
    /\b(BF16|F16|F32)\b/i,
  ];
  for (const re of patterns) {
    const m = name.match(re);
    if (m) return m[1].toUpperCase();
  }
  return null;
}

module.exports = {
  searchModels,
  listModelFiles,
  groupGgufFiles,
  downloadFile,
  cancelDownload,
  listLocalModels,
};
