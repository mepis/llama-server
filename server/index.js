"use strict";

const express = require("express");
const path = require("path");
const fs = require("fs");

const scriptsRouter = require("./routes/scripts");
const statusRouter = require("./routes/status");
const logsRouter = require("./routes/logs");
const processesRouter = require("./routes/processes");
const instancesRouter = require("./routes/instances");
const hardwareRouter = require("./routes/hardware");
const modelsRouter = require("./routes/models");
const { shutdown: shutdownScripts } = require("./lib/scriptRunner");

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(express.json({ limit: "1mb" }));

// CORS for development
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).end();
  next();
});

// API Routes
app.use("/api/scripts", scriptsRouter);
app.use("/api/status", statusRouter);
app.use("/api/logs", logsRouter);
app.use("/api/processes", processesRouter);
app.use("/api/instances", instancesRouter);
app.use("/api/hardware", hardwareRouter);
app.use("/api/models", modelsRouter);

// API 404 handler — prevents SPA fallback from catching bad API routes
app.all("/api/{*path}", (req, res) => {
  res.status(404).json({ error: "API endpoint not found" });
});

// Serve Vue frontend from web/dist
const distPath = path.join(__dirname, "..", "web", "dist");
if (fs.existsSync(distPath)) {
  app.use(express.static(distPath));
  // SPA fallback — serve index.html for all non-API routes (Express 5: use named wildcard)
  app.get("{*path}", (req, res) => {
    res.sendFile(path.join(distPath, "index.html"));
  });
} else {
  app.get("/", (req, res) => {
    res.json({
      message: "Llama.cpp Management API",
      note: "Frontend not built. Run: cd web && npm run build",
      api: [
        "GET  /api/scripts",
        "POST /api/scripts/:id/run",
        "GET  /api/status",
        "GET  /api/logs",
        "GET  /api/processes",
        "DELETE /api/processes/:pid",
        "GET  /api/hardware",
        "GET  /api/models",
        "GET  /api/models/search?q=<query>",
        "GET  /api/models/downloads",
        "GET  /api/models/:owner/:repo/files",
        "GET  /api/models/:owner/:repo/download/:filename",
        "DELETE /api/models/:owner/:repo/download/:filename",
      ],
    });
  });
}

// Error handling middleware
app.use((err, _req, res, _next) => {
  if (err.type === "entity.parse.failed") {
    return res.status(400).json({ error: "Invalid JSON in request body" });
  }
  console.error("Unhandled error:", err.message);
  res.status(500).json({ error: "Internal server error" });
});

const server = app.listen(PORT, () => {
  console.log(
    `Llama.cpp Management Server running on http://localhost:${PORT}`,
  );
  if (!fs.existsSync(distPath)) {
    console.log("  Note: Frontend not built. Run: cd web && npm run build");
  }
});

// Graceful shutdown — kill all spawned child processes
function gracefulShutdown(signal) {
  console.log(`\n${signal} received. Shutting down...`);
  shutdownScripts();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 5000);
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

module.exports = { app, server };
