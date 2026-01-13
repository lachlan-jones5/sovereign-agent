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
import { spawn } from "child_process";

// Helper to run shell commands (compatible with older Bun versions on arm64)
async function exec(command: string, cwd?: string): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve) => {
    const proc = spawn("sh", ["-c", command], { 
      cwd: cwd || process.cwd(),
      stdio: ["ignore", "pipe", "pipe"],
    });
    
    let stdout = "";
    let stderr = "";
    
    proc.stdout?.on("data", (data) => { stdout += data.toString(); });
    proc.stderr?.on("data", (data) => { stderr += data.toString(); });
    
    proc.on("close", (code) => {
      resolve({ stdout, stderr, exitCode: code ?? 0 });
    });
    
    proc.on("error", (err) => {
      resolve({ stdout: "", stderr: err.message, exitCode: 1 });
    });
  });
}

// Helper to run shell commands and get output as a readable stream
function execStream(command: string, cwd?: string): ReadableStream<Uint8Array> {
  const proc = spawn("sh", ["-c", command], { 
    cwd: cwd || process.cwd(),
    stdio: ["ignore", "pipe", "pipe"],
  });
  
  return new ReadableStream({
    start(controller) {
      proc.stdout?.on("data", (data) => {
        controller.enqueue(new Uint8Array(data));
      });
      
      proc.stdout?.on("end", () => {
        controller.close();
      });
      
      proc.on("error", (err) => {
        controller.error(err);
      });
      
      proc.stderr?.on("data", (data) => {
        log("debug", `tar stderr: ${data.toString()}`);
      });
    },
    cancel() {
      proc.kill();
    }
  });
}

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
  idleTimeout: 120, // 2 minutes for large bundle downloads

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

set -uo pipefail

# Use the port this script was fetched from (injected by relay), or env var, or default
RELAY_PORT="\${RELAY_PORT:-${RELAY_PORT}}"
INSTALL_DIR="\${INSTALL_DIR:-\$PWD/sovereign-agent}"

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

# Handle existing OpenCode installation
OPENCODE_CONFIG_DIR="\$HOME/.config/opencode"
if [[ -d "\$OPENCODE_CONFIG_DIR" ]]; then
    BACKUP_DIR="\$HOME/.config/opencode.backup.\$(date +%Y%m%d_%H%M%S)"
    echo "Existing OpenCode config found at \$OPENCODE_CONFIG_DIR"
    echo "Backing up to \$BACKUP_DIR..."
    mv "\$OPENCODE_CONFIG_DIR" "\$BACKUP_DIR"
    echo "Backup complete"
    echo ""
fi

# Check for required tools and install if missing FIRST
echo "Checking dependencies..."

# Install Bun if missing
if ! command -v bun &>/dev/null; then
    echo "Installing Bun..."
    if curl -fsSL https://bun.sh/install | bash; then
        export BUN_INSTALL="\$HOME/.bun"
        export PATH="\$BUN_INSTALL/bin:\$PATH"
    else
        echo "Warning: Bun installation failed - will try again in install.sh"
    fi
fi

# Install Go if missing (user-local, no sudo required)
if ! command -v go &>/dev/null; then
    echo "Installing Go..."
    GO_VERSION="1.23.4"
    GO_INSTALL_DIR="\$HOME/.local/go"
    ARCH=\$(uname -m)
    case "\$ARCH" in
        x86_64) GOARCH="amd64" ;;
        aarch64|arm64) GOARCH="arm64" ;;
        *) 
            echo "Warning: Unsupported architecture \$ARCH for Go auto-install"
            echo "Please install Go manually: https://go.dev/doc/install"
            GOARCH=""
            ;;
    esac
    if [[ -n "\$GOARCH" ]]; then
        mkdir -p "\$HOME/.local"
        if curl -fsSL "https://go.dev/dl/go\${GO_VERSION}.linux-\${GOARCH}.tar.gz" | tar -C "\$HOME/.local" -xzf -; then
            export PATH="\$GO_INSTALL_DIR/bin:\$PATH"
            echo "export PATH=\"\$GO_INSTALL_DIR/bin:\\\$PATH\"" >> "\$HOME/.bashrc"
            echo "Go installed to \$GO_INSTALL_DIR"
        else
            echo "Warning: Go installation failed"
            echo "Please install Go manually: https://go.dev/doc/install"
        fi
    fi
fi

# Install jq if missing
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y jq 2>/dev/null || echo "Warning: jq installation failed (may need sudo)"
    elif command -v apk &>/dev/null; then
        sudo apk add jq 2>/dev/null || echo "Warning: jq installation failed (may need sudo)"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y jq 2>/dev/null || echo "Warning: jq installation failed (may need sudo)"
    else
        echo "Warning: Could not install jq - please install manually"
    fi
fi

echo ""

# Download and extract the bundle
echo "Downloading sovereign-agent bundle..."
mkdir -p "\$INSTALL_DIR"
cd "\$INSTALL_DIR"

# Use curl with progress bar (-#) and save to temp file first to avoid partial extraction
BUNDLE_TMP="\$(mktemp)"
if ! curl -# -f "http://localhost:\$RELAY_PORT/bundle.tar.gz" -o "\$BUNDLE_TMP"; then
    rm -f "\$BUNDLE_TMP"
    echo "Error: Bundle download failed"
    exit 1
fi

echo "Extracting bundle..."
if ! tar -xzf "\$BUNDLE_TMP"; then
    rm -f "\$BUNDLE_TMP"
    echo "Error: Bundle extraction failed"
    echo "Try running manually:"
    echo "  curl -# http://localhost:\$RELAY_PORT/bundle.tar.gz -o /tmp/bundle.tar.gz"
    echo "  tar -xzvf /tmp/bundle.tar.gz"
    exit 1
fi
rm -f "\$BUNDLE_TMP"

# Create client config (always overwrite for fresh relay client setup)
echo "Creating relay client config..."
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

# Verify bundle was extracted correctly
if [[ ! -f install.sh ]]; then
    echo "Error: Bundle extraction failed - install.sh not found"
    echo "Try running manually:"
    echo "  mkdir -p \$INSTALL_DIR && cd \$INSTALL_DIR"
    echo "  curl -sf http://localhost:\$RELAY_PORT/bundle.tar.gz | tar -xzvf -"
    exit 1
fi

# Run install
echo ""
echo "Running install.sh..."
chmod +x install.sh
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

    // Bundle endpoint - creates fresh tarball of repo on demand (streamed)
    if (path === "/bundle.tar.gz") {
      log("info", "Generating fresh bundle (streaming)...");
      log("info", `REPO_PATH: ${REPO_PATH}`);
      
      try {
        // Pull latest and update submodules (ignore failures - may not be a git repo or offline)
        await exec("git pull --quiet 2>/dev/null || true", REPO_PATH);
        await exec("git submodule update --init --recursive --depth 1 2>/dev/null || true", REPO_PATH);
        
        // Verify essential files exist
        const checkResult = await exec("ls -la install.sh lib/ relay/ vendor/ 2>&1 || echo 'MISSING FILES'", REPO_PATH);
        log("info", `File check: ${checkResult.stdout.substring(0, 200)}`);
        
        // Get approximate size first (for progress indicator)
        const sizeResult = await exec(
          `tar -czf - --exclude='.git' --exclude='config.json' --exclude='node_modules' --exclude='.env' --exclude='*.log' --exclude='tests' . 2>/dev/null | wc -c`,
          REPO_PATH
        );
        const estimatedSize = parseInt(sizeResult.stdout.trim()) || 0;
        log("info", `Estimated bundle size: ${(estimatedSize / 1024 / 1024).toFixed(2)} MB`);
        
        // Stream tarball directly - avoids buffering the whole thing in memory
        const tarStream = execStream(
          `tar -czf - --exclude='.git' --exclude='config.json' --exclude='node_modules' --exclude='.env' --exclude='*.log' --exclude='tests' .`,
          REPO_PATH
        );
        
        const headers: Record<string, string> = {
          "Content-Type": "application/gzip",
          "Content-Disposition": "attachment; filename=sovereign-agent.tar.gz",
        };
        
        // Add Content-Length if we got a size estimate (enables curl progress bar)
        if (estimatedSize > 0) {
          headers["Content-Length"] = String(estimatedSize);
        }
        
        return new Response(tarStream, { headers });
      } catch (err) {
        log("error", `Failed to create bundle: ${err}`);
        return new Response(
          JSON.stringify({ error: "Failed to create bundle", details: String(err), repo_path: REPO_PATH }),
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
