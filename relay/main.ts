/**
 * Sovereign Agent API Relay
 *
 * A minimal relay service that forwards API requests to OpenRouter,
 * adding authentication from a local config file.
 *
 * This allows running OpenCode on a remote machine (Work VM) while
 * keeping API keys secure on a trusted machine (Pi) and avoiding
 * network monitoring on the remote machine.
 *
 * Endpoints:
 *   /health          - Health check
 *   /stats           - Usage statistics
 *   /setup           - Client setup script (downloads bundle via tunnel)
 *   /bundle.tar.gz   - Fresh tarball of repo for client setup
 *   /api/v1/*        - Proxied to OpenRouter
 *
 * Usage:
 *   bun run main.ts
 *
 * Environment Variables:
 *   CONFIG_PATH - Path to config.json (default: ../config.json)
 *   RELAY_PORT  - Port to listen on (default: 8080)
 *   RELAY_HOST  - Host to bind to (default: 127.0.0.1)
 *   LOG_LEVEL   - Logging level: debug, info, warn, error (default: info)
 *   REPO_PATH   - Path to sovereign-agent repo (default: parent of relay dir)
 */

import { existsSync, readFileSync } from "fs";
import { resolve, dirname } from "path";
import { $ } from "bun";

// Configuration
const CONFIG_PATH = process.env.CONFIG_PATH || resolve(import.meta.dir, "../config.json");
const RELAY_PORT = parseInt(process.env.RELAY_PORT || "8080", 10);
const RELAY_HOST = process.env.RELAY_HOST || "127.0.0.1";
const LOG_LEVEL = process.env.LOG_LEVEL || "info";
const REPO_PATH = process.env.REPO_PATH || resolve(import.meta.dir, "..");
const OPENROUTER_BASE = "https://openrouter.ai";

// Log levels
const LOG_LEVELS: Record<string, number> = { debug: 0, info: 1, warn: 2, error: 3 };
const currentLogLevel = LOG_LEVELS[LOG_LEVEL] ?? 1;

function log(level: string, message: string, data?: unknown) {
  if (LOG_LEVELS[level] >= currentLogLevel) {
    const timestamp = new Date().toISOString();
    const prefix = `[${timestamp}] [${level.toUpperCase()}]`;
    if (data) {
      console.log(`${prefix} ${message}`, data);
    } else {
      console.log(`${prefix} ${message}`);
    }
  }
}

// Load configuration
interface Config {
  openrouter_api_key: string;
  site_url?: string;
  site_name?: string;
  relay?: {
    allowed_paths?: string[];
    rate_limit?: number;
  };
}

function loadConfig(): Config {
  if (!existsSync(CONFIG_PATH)) {
    log("error", `Config file not found: ${CONFIG_PATH}`);
    process.exit(1);
  }

  try {
    const content = readFileSync(CONFIG_PATH, "utf-8");
    const config = JSON.parse(content) as Config;

    if (!config.openrouter_api_key) {
      log("error", "Missing openrouter_api_key in config");
      process.exit(1);
    }

    return config;
  } catch (err) {
    log("error", `Failed to load config: ${err}`);
    process.exit(1);
  }
}

const config = loadConfig();
log("info", `Loaded config from ${CONFIG_PATH}`);

// Allowed API paths (security: only forward expected endpoints)
const ALLOWED_PATHS = config.relay?.allowed_paths || [
  "/api/v1/chat/completions",
  "/api/v1/completions",
  "/api/v1/models",
  "/api/v1/auth/key",
  "/api/v1/generation",
];

// Request tracking for cost monitoring
let requestCount = 0;
let totalTokensIn = 0;
let totalTokensOut = 0;

// Start the relay server
Bun.serve({
  port: RELAY_PORT,
  hostname: RELAY_HOST,

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    const path = url.pathname;
    const method = req.method;

    log("debug", `${method} ${path}`);

    // Health check endpoint
    if (path === "/health" || path === "/") {
      return new Response(
        JSON.stringify({
          status: "ok",
          relay: "sovereign-agent",
          requests: requestCount,
          tokens: { in: totalTokensIn, out: totalTokensOut },
        }),
        {
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Stats endpoint
    if (path === "/stats") {
      return new Response(
        JSON.stringify({
          requests: requestCount,
          tokens: { in: totalTokensIn, out: totalTokensOut },
          uptime: process.uptime(),
        }),
        {
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Setup script endpoint - serves a script that downloads bundle via tunnel
    if (path === "/setup") {
      const setupScript = `#!/bin/bash
# Sovereign Agent Client Setup (via relay tunnel)
# This script downloads everything through the tunnel - no direct internet access needed.

set -euo pipefail

RELAY_PORT="\${RELAY_PORT:-8080}"
INSTALL_DIR="\${INSTALL_DIR:-\$HOME/sovereign-agent}"

echo "=== Sovereign Agent Client Setup (via tunnel) ==="
echo ""

# Check the tunnel is working
if ! curl -sf "http://localhost:\$RELAY_PORT/health" >/dev/null 2>&1; then
    echo "Error: Cannot reach relay at localhost:\$RELAY_PORT"
    echo "Make sure the reverse tunnel is running on your laptop."
    exit 1
fi

echo "Relay connection OK"
echo ""

# Download and extract the bundle
echo "Downloading sovereign-agent bundle..."
mkdir -p "\$INSTALL_DIR"
cd "\$INSTALL_DIR"

curl -sf "http://localhost:\$RELAY_PORT/bundle.tar.gz" | tar -xzf - --strip-components=1

# Create client config
if [[ ! -f config.json ]]; then
    echo "Creating client config..."
    cat > config.json <<CONFIGEOF
{
  "openrouter_api_key": "",
  "site_url": "https://github.com/lachlan-jones5/sovereign-agent",
  "site_name": "SovereignAgent",

  "models": {
    "orchestrator": "deepseek/deepseek-r1",
    "planner": "anthropic/claude-sonnet-4",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },

  "relay": {
    "enabled": true,
    "mode": "client",
    "port": \$RELAY_PORT
  }
}
CONFIGEOF
fi

# Check for required tools
echo ""
echo "Checking dependencies..."

if ! command -v go &>/dev/null; then
    echo "Warning: 'go' not found - needed for OpenCode"
    echo "Install Go: https://go.dev/doc/install"
fi

if ! command -v bun &>/dev/null; then
    echo "Warning: 'bun' not found - needed for oh-my-opencode"
    echo "Bun will be installed during install.sh if missing"
fi

if ! command -v jq &>/dev/null; then
    echo "Warning: 'jq' not found - needed for config generation"
fi

# Run install
echo ""
echo "Running install.sh..."
./install.sh

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Run OpenCode with:"
echo "  opencode"
echo ""
`;
      return new Response(setupScript, {
        headers: { 
          "Content-Type": "text/x-shellscript",
          "Content-Disposition": "attachment; filename=setup.sh",
        },
      });
    }

    // Bundle endpoint - creates fresh tarball of repo on demand
    if (path === "/bundle.tar.gz") {
      log("info", "Generating fresh bundle...");
      
      try {
        // Pull latest and update submodules
        await $\`cd \${REPO_PATH} && git pull --quiet 2>/dev/null || true\`;
        await $\`cd \${REPO_PATH} && git submodule update --init --recursive --depth 1 2>/dev/null || true\`;
        
        // Create tarball excluding .git dirs, config.json (has API key), and large unnecessary files
        const tarball = await $\`cd \${REPO_PATH} && tar -czf - \\
          --exclude='.git' \\
          --exclude='config.json' \\
          --exclude='node_modules' \\
          --exclude='.env' \\
          --exclude='*.log' \\
          .\`.blob();
        
        log("info", \`Bundle created: \${(tarball.size / 1024 / 1024).toFixed(2)} MB\`);
        
        return new Response(tarball, {
          headers: {
            "Content-Type": "application/gzip",
            "Content-Disposition": "attachment; filename=sovereign-agent.tar.gz",
          },
        });
      } catch (err) {
        log("error", \`Failed to create bundle: \${err}\`);
        return new Response(
          JSON.stringify({ error: "Failed to create bundle", details: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json" },
          }
        );
      }
    }

    // Validate path is allowed
    const isAllowed = ALLOWED_PATHS.some(
      (allowed) => path === allowed || path.startsWith(allowed + "/")
    );

    if (!isAllowed) {
      log("warn", `Blocked request to non-allowed path: ${path}`);
      return new Response(
        JSON.stringify({ error: "Path not allowed" }),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Build target URL
    const targetUrl = `${OPENROUTER_BASE}${path}${url.search}`;

    // Clone and modify headers
    const headers = new Headers(req.headers);

    // Add authentication
    headers.set("Authorization", `Bearer ${config.openrouter_api_key}`);

    // Add OpenRouter-specific headers
    if (config.site_url) {
      headers.set("HTTP-Referer", config.site_url);
    }
    if (config.site_name) {
      headers.set("X-Title", config.site_name);
    }

    // Remove headers that shouldn't be forwarded
    headers.delete("Host");
    headers.delete("Connection");

    try {
      requestCount++;
      log("info", `Forwarding: ${method} ${path} -> ${OPENROUTER_BASE}`);

      // Forward the request
      const response = await fetch(targetUrl, {
        method: req.method,
        headers,
        body: req.body,
        // @ts-ignore - Bun supports duplex
        duplex: "half",
      });

      // Log response status
      log("info", `Response: ${response.status} ${response.statusText}`);

      // Try to track token usage from response headers
      const tokensIn = response.headers.get("x-ratelimit-tokens-remaining");
      const usage = response.headers.get("x-usage");
      if (usage) {
        try {
          const usageData = JSON.parse(usage);
          if (usageData.prompt_tokens) totalTokensIn += usageData.prompt_tokens;
          if (usageData.completion_tokens) totalTokensOut += usageData.completion_tokens;
        } catch {
          // Ignore parsing errors
        }
      }

      // Return the response as-is (streaming works automatically)
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
    } catch (err) {
      log("error", `Request failed: ${err}`);
      return new Response(
        JSON.stringify({ error: "Relay request failed", details: String(err) }),
        {
          status: 502,
          headers: { "Content-Type": "application/json" },
        }
      );
    }
  },

  error(error: Error): Response {
    log("error", `Server error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  },
});

log("info", `Relay listening on http://${RELAY_HOST}:${RELAY_PORT}`);
log("info", `Forwarding to ${OPENROUTER_BASE}`);
log("info", `Allowed paths: ${ALLOWED_PATHS.join(", ")}`);
log("info", `Client setup available at /setup and /bundle.tar.gz`);
