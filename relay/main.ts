/**
 * Sovereign Agent API Relay - GitHub Copilot Edition
 *
 * A relay service that forwards API requests to GitHub Copilot API,
 * handling OAuth authentication and token refresh automatically.
 *
 * This allows running OpenCode on a remote machine (Client VM) while
 * keeping the GitHub OAuth token secure on a trusted machine (Pi).
 *
 * Endpoints:
 *   /health          - Health check
 *   /stats           - Usage statistics
 *   /auth/device     - Start device code flow for GitHub Copilot
 *   /auth/status     - Check auth status
 *   /setup           - Client setup script (downloads bundle via tunnel)
 *   /bundle.tar.gz   - Fresh tarball of repo for client setup
 *   /v1/*            - Proxied to GitHub Copilot API
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

import { existsSync, readFileSync, writeFileSync, appendFileSync, mkdirSync } from "fs";
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

// Data capture configuration
const DATA_CAPTURE_ENABLED = process.env.DATA_CAPTURE_ENABLED === "true" || process.env.DATA_CAPTURE_PATH || process.env.DATA_CAPTURE_FORWARD_URL;
const DATA_CAPTURE_PATH = process.env.DATA_CAPTURE_PATH || resolve(import.meta.dir, "../data/captures.jsonl");
const DATA_CAPTURE_FORWARD_URL = process.env.DATA_CAPTURE_FORWARD_URL || ""; // e.g., http://localhost:9090/ingest

// GitHub Copilot constants
const COPILOT_CLIENT_ID = "Iv1.b507a08c87ecfe98";
const COPILOT_API_BASE_DEFAULT = "https://api.individual.githubcopilot.com";
const GITHUB_DEVICE_CODE_URL = "https://github.com/login/device/code";
const GITHUB_ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token";
const GITHUB_COPILOT_TOKEN_URL = "https://api.github.com/copilot_internal/v2/token";

const COPILOT_HEADERS = {
  "User-Agent": "GitHubCopilotChat/0.35.0",
  "Editor-Version": "vscode/1.107.0",
  "Editor-Plugin-Version": "copilot-chat/0.35.0",
  "Copilot-Integration-Id": "vscode-chat",
};

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

// Configuration interface
interface Config {
  // GitHub OAuth token (long-lived, from device code flow)
  github_oauth_token?: string;
  
  // Legacy OpenRouter support (deprecated, will be removed)
  openrouter_api_key?: string;
  
  site_url?: string;
  site_name?: string;
  
  relay?: {
    enabled?: boolean;
    mode?: "server" | "client";
    port?: number;
    allowed_paths?: string[];
  };
}

// Copilot token cache (short-lived API token)
interface CopilotToken {
  token: string;
  expires: number; // Unix timestamp in ms
  apiBase: string; // API endpoint from token response
}

let copilotTokenCache: CopilotToken | null = null;

// Pending device code flows
interface DeviceCodeFlow {
  device_code: string;
  user_code: string;
  verification_uri: string;
  expires_at: number;
  interval: number;
}

const pendingDeviceFlows: Map<string, DeviceCodeFlow> = new Map();

function loadConfig(): Config {
  if (!existsSync(CONFIG_PATH)) {
    log("warn", `Config file not found: ${CONFIG_PATH}, creating empty config`);
    const emptyConfig: Config = {
      site_url: "https://github.com/lachlan-jones5/sovereign-agent",
      site_name: "SovereignAgent",
    };
    writeFileSync(CONFIG_PATH, JSON.stringify(emptyConfig, null, 2));
    return emptyConfig;
  }

  try {
    const content = readFileSync(CONFIG_PATH, "utf-8");
    const config = JSON.parse(content) as Config;
    return config;
  } catch (err) {
    log("error", `Failed to load config: ${err}`);
    process.exit(1);
  }
}

function saveConfig(config: Config) {
  try {
    writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    log("info", "Config saved");
  } catch (err) {
    log("error", `Failed to save config: ${err}`);
  }
}

let config = loadConfig();
log("info", `Loaded config from ${CONFIG_PATH}`);

// Check if we have GitHub OAuth token
function hasGitHubAuth(): boolean {
  return !!config.github_oauth_token;
}

// Get Copilot API token (refreshes if expired)
async function getCopilotToken(): Promise<{ token: string; apiBase: string }> {
  if (!config.github_oauth_token) {
    throw new Error("GitHub OAuth token not configured. Run device code flow first.");
  }

  // Check cache
  if (copilotTokenCache && copilotTokenCache.expires > Date.now()) {
    log("debug", "Using cached Copilot token");
    return { token: copilotTokenCache.token, apiBase: copilotTokenCache.apiBase };
  }

  // Refresh token
  log("info", "Refreshing Copilot API token...");
  
  const response = await fetch(GITHUB_COPILOT_TOKEN_URL, {
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${config.github_oauth_token}`,
      ...COPILOT_HEADERS,
    },
  });

  if (!response.ok) {
    const text = await response.text();
    log("error", `Copilot token refresh failed: ${response.status} ${text}`);
    
    if (response.status === 401) {
      // OAuth token is invalid, clear it
      log("warn", "OAuth token appears invalid, clearing...");
      config.github_oauth_token = undefined;
      saveConfig(config);
    }
    
    throw new Error(`Copilot token refresh failed: ${response.status}`);
  }

  const tokenData = await response.json() as { 
    token: string; 
    expires_at: number;
    endpoints?: { api?: string };
  };
  
  // Extract API base from response, fall back to default
  const apiBase = tokenData.endpoints?.api || COPILOT_API_BASE_DEFAULT;
  
  // Cache with 5 minute buffer before expiry
  copilotTokenCache = {
    token: tokenData.token,
    expires: tokenData.expires_at * 1000 - 5 * 60 * 1000,
    apiBase,
  };

  log("info", `Copilot token refreshed, expires at ${new Date(copilotTokenCache.expires).toISOString()}, API: ${apiBase}`);
  return { token: copilotTokenCache.token, apiBase };
}

// Start device code flow
async function startDeviceCodeFlow(): Promise<{ user_code: string; verification_uri: string; flow_id: string }> {
  const response = await fetch(GITHUB_DEVICE_CODE_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "User-Agent": "GitHubCopilotChat/0.35.0",
    },
    body: JSON.stringify({
      client_id: COPILOT_CLIENT_ID,
      scope: "read:user",
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Device code request failed: ${response.status} ${text}`);
  }

  const data = await response.json() as {
    device_code: string;
    user_code: string;
    verification_uri: string;
    expires_in: number;
    interval: number;
  };

  const flow_id = crypto.randomUUID();
  
  pendingDeviceFlows.set(flow_id, {
    device_code: data.device_code,
    user_code: data.user_code,
    verification_uri: data.verification_uri,
    expires_at: Date.now() + data.expires_in * 1000,
    interval: data.interval,
  });

  // Clean up expired flows
  for (const [id, flow] of pendingDeviceFlows) {
    if (flow.expires_at < Date.now()) {
      pendingDeviceFlows.delete(id);
    }
  }

  return {
    user_code: data.user_code,
    verification_uri: data.verification_uri,
    flow_id,
  };
}

// Poll for device code completion
async function pollDeviceCodeFlow(flow_id: string): Promise<{ status: "pending" | "success" | "expired" | "error"; message?: string }> {
  const flow = pendingDeviceFlows.get(flow_id);
  
  if (!flow) {
    return { status: "error", message: "Flow not found or expired" };
  }
  
  if (flow.expires_at < Date.now()) {
    pendingDeviceFlows.delete(flow_id);
    return { status: "expired", message: "Device code expired" };
  }

  const response = await fetch(GITHUB_ACCESS_TOKEN_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "User-Agent": "GitHubCopilotChat/0.35.0",
    },
    body: JSON.stringify({
      client_id: COPILOT_CLIENT_ID,
      device_code: flow.device_code,
      grant_type: "urn:ietf:params:oauth:grant-type:device_code",
    }),
  });

  if (!response.ok) {
    return { status: "error", message: `Token request failed: ${response.status}` };
  }

  const data = await response.json() as { 
    access_token?: string; 
    error?: string;
    error_description?: string;
  };

  if (data.access_token) {
    // Success! Save the token
    config.github_oauth_token = data.access_token;
    saveConfig(config);
    
    pendingDeviceFlows.delete(flow_id);
    copilotTokenCache = null; // Force refresh on next request
    
    log("info", "GitHub OAuth token saved successfully");
    return { status: "success", message: "Authentication successful" };
  }

  if (data.error === "authorization_pending") {
    return { status: "pending", message: "Waiting for user authorization..." };
  }

  if (data.error === "slow_down") {
    return { status: "pending", message: "Please wait..." };
  }

  return { status: "error", message: data.error_description || data.error || "Unknown error" };
}

// Allowed API paths for Copilot
const ALLOWED_PATHS = [
  "/v1/chat/completions",
  "/v1/completions",
  "/v1/models",
  "/chat/completions",  // Some clients use this
];

// Request tracking for monitoring
let requestCount = 0;
let premiumRequestsUsed = 0;

// Model multipliers from GitHub docs
// Note: Deprecated models excluded (gemini-2.5-pro, claude-sonnet-4, claude-opus-4/4.1)
const MODEL_MULTIPLIERS: Record<string, number> = {
  // Free (0x multiplier) - included in all paid plans
  "gpt-5-mini": 0,
  "gpt-4.1": 0,
  "gpt-4o": 0,
  
  // Very cheap (0.25-0.33x)
  "claude-haiku-4.5": 0.33,
  "grok-code-fast-1": 0.25,
  "gemini-3-flash-preview": 0.33,
  "gpt-5.1-codex-mini": 0.33,
  
  // Standard (1x)
  "claude-sonnet-4.5": 1,
  "gpt-5": 1,
  "gpt-5.1": 1,
  "gpt-5.2": 1,
  "gpt-5-codex": 1,
  "gpt-5.1-codex": 1,
  "gpt-5.1-codex-max": 1,
  "gemini-3-pro-preview": 1,
  "o3": 1,
  "o3-mini": 1,
  "o4-mini": 1,
  
  // Premium (3x)
  "claude-opus-4.5": 3,
  
  // Note: claude-opus-4 and claude-opus-41 (10x) are excluded
  // claude-opus-4.5 (3x) is cheaper AND better - always use that instead
};

function getModelMultiplier(model: string): number {
  // Strip github-copilot/ prefix if present
  const modelName = model.replace(/^github-copilot\//, "");
  return MODEL_MULTIPLIERS[modelName] ?? 1;
}

// Data capture types and functions
interface CapturedSession {
  id: string
  timestamp: string
  endpoint: string
  method: string
  request: unknown
  response: unknown
  status: number
  latency_ms: number
  model: string
  multiplier: number
  stream: boolean
}

let captureCount = 0

// Ensure data directory exists
function ensureDataDir() {
  const dataDir = dirname(DATA_CAPTURE_PATH)
  if (!existsSync(dataDir)) {
    mkdirSync(dataDir, { recursive: true })
    log("info", `Created data capture directory: ${dataDir}`)
  }
}

// Capture a request/response pair
async function captureSession(session: CapturedSession): Promise<void> {
  if (!DATA_CAPTURE_ENABLED) return

  const jsonLine = JSON.stringify(session) + "\n"
  captureCount++

  // Save locally if path is configured
  if (DATA_CAPTURE_PATH) {
    try {
      ensureDataDir()
      appendFileSync(DATA_CAPTURE_PATH, jsonLine)
      log("debug", `Captured session ${session.id} to ${DATA_CAPTURE_PATH}`)
    } catch (err) {
      log("error", `Failed to save capture locally: ${err}`)
    }
  }

  // Forward via tunnel if URL is configured
  if (DATA_CAPTURE_FORWARD_URL) {
    try {
      const res = await fetch(DATA_CAPTURE_FORWARD_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(session),
      })
      if (!res.ok) {
        log("warn", `Forward capture failed: ${res.status} ${res.statusText}`)
      } else {
        log("debug", `Forwarded session ${session.id} to ${DATA_CAPTURE_FORWARD_URL}`)
      }
    } catch (err) {
      log("warn", `Failed to forward capture: ${err}`)
    }
  }
}

// Collect streaming response chunks into full response body
async function collectStreamingResponse(response: Response): Promise<{ body: string; clonedResponse: Response }> {
  const chunks: Uint8Array[] = []
  const reader = response.body?.getReader()
  
  if (!reader) {
    return { body: "", clonedResponse: response }
  }

  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    if (value) chunks.push(value)
  }

  const fullBody = new TextDecoder().decode(
    chunks.reduce((acc, chunk) => {
      const combined = new Uint8Array(acc.length + chunk.length)
      combined.set(acc)
      combined.set(chunk, acc.length)
      return combined
    }, new Uint8Array())
  )

  // Create a new response with the same body for returning to client
  const clonedResponse = new Response(fullBody, {
    status: response.status,
    statusText: response.statusText,
    headers: response.headers,
  })

  return { body: fullBody, clonedResponse }
}

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

    // CORS headers for web clients
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check endpoint
    if (path === "/health" || path === "/") {
      return new Response(
        JSON.stringify({
          status: "ok",
          relay: "sovereign-agent-copilot",
          authenticated: hasGitHubAuth(),
          requests: requestCount,
          premium_requests_used: premiumRequestsUsed,
        }),
        {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Stats endpoint
    if (path === "/stats") {
      return new Response(
        JSON.stringify({
          requests: requestCount,
          premium_requests_used: premiumRequestsUsed,
          authenticated: hasGitHubAuth(),
          uptime: process.uptime(),
          data_capture: {
            enabled: DATA_CAPTURE_ENABLED,
            captures: captureCount,
            local_path: DATA_CAPTURE_PATH || null,
            forward_url: DATA_CAPTURE_FORWARD_URL || null,
          },
        }),
        {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Data capture endpoints
    if (path === "/data/stats") {
      let fileSize = 0;
      let lineCount = 0;
      
      if (DATA_CAPTURE_PATH && existsSync(DATA_CAPTURE_PATH)) {
        try {
          const content = readFileSync(DATA_CAPTURE_PATH, "utf-8");
          fileSize = Buffer.byteLength(content, "utf-8");
          lineCount = content.split("\n").filter(line => line.trim()).length;
        } catch {
          // Ignore read errors
        }
      }
      
      return new Response(
        JSON.stringify({
          enabled: DATA_CAPTURE_ENABLED,
          captures: captureCount,
          local_path: DATA_CAPTURE_PATH || null,
          forward_url: DATA_CAPTURE_FORWARD_URL || null,
          file_size_bytes: fileSize,
          file_lines: lineCount,
        }),
        {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Download captured data as JSONL
    if (path === "/data/export") {
      if (!DATA_CAPTURE_PATH || !existsSync(DATA_CAPTURE_PATH)) {
        return new Response(
          JSON.stringify({ error: "No capture file found", path: DATA_CAPTURE_PATH }),
          {
            status: 404,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      try {
        const content = readFileSync(DATA_CAPTURE_PATH, "utf-8");
        return new Response(content, {
          headers: {
            "Content-Type": "application/x-ndjson",
            "Content-Disposition": `attachment; filename=captures-${new Date().toISOString().split("T")[0]}.jsonl`,
            ...corsHeaders,
          },
        });
      } catch (err) {
        return new Response(
          JSON.stringify({ error: "Failed to read capture file", details: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // View recent captures (last N)
    if (path === "/data/recent") {
      const limit = parseInt(url.searchParams.get("limit") || "10", 10);
      
      if (!DATA_CAPTURE_PATH || !existsSync(DATA_CAPTURE_PATH)) {
        return new Response(
          JSON.stringify({ captures: [], total: 0 }),
          {
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      try {
        const content = readFileSync(DATA_CAPTURE_PATH, "utf-8");
        const lines = content.split("\n").filter(line => line.trim());
        const recent = lines.slice(-limit).reverse().map(line => {
          try {
            return JSON.parse(line);
          } catch {
            return { raw: line };
          }
        });
        
        return new Response(
          JSON.stringify({ captures: recent, total: lines.length }),
          {
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      } catch (err) {
        return new Response(
          JSON.stringify({ error: "Failed to read captures", details: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // Ingest endpoint - receives forwarded captures from other relays
    if (path === "/data/ingest" && method === "POST") {
      if (!DATA_CAPTURE_ENABLED) {
        return new Response(
          JSON.stringify({ error: "Data capture not enabled on this relay" }),
          {
            status: 400,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      try {
        const session = await req.json() as CapturedSession;
        
        // Save locally
        ensureDataDir();
        appendFileSync(DATA_CAPTURE_PATH, JSON.stringify(session) + "\n");
        captureCount++;
        
        log("info", `Ingested session ${session.id} from remote`);
        
        return new Response(
          JSON.stringify({ success: true, id: session.id }),
          {
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      } catch (err) {
        log("error", `Ingest failed: ${err}`);
        return new Response(
          JSON.stringify({ error: "Ingest failed", details: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // Auth status endpoint
    if (path === "/auth/status") {
      return new Response(
        JSON.stringify({
          authenticated: hasGitHubAuth(),
          message: hasGitHubAuth() 
            ? "GitHub Copilot authenticated" 
            : "Not authenticated. Use /auth/device to start authentication.",
        }),
        {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        }
      );
    }

    // Start device code flow
    if (path === "/auth/device" && method === "POST") {
      try {
        const result = await startDeviceCodeFlow();
        return new Response(
          JSON.stringify({
            success: true,
            user_code: result.user_code,
            verification_uri: result.verification_uri,
            flow_id: result.flow_id,
            message: `Go to ${result.verification_uri} and enter code: ${result.user_code}`,
          }),
          {
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      } catch (err) {
        log("error", `Device code flow failed: ${err}`);
        return new Response(
          JSON.stringify({ success: false, error: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // Poll device code flow
    if (path === "/auth/poll" && method === "POST") {
      try {
        const body = await req.json() as { flow_id: string };
        const result = await pollDeviceCodeFlow(body.flow_id);
        return new Response(
          JSON.stringify(result),
          {
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      } catch (err) {
        log("error", `Poll failed: ${err}`);
        return new Response(
          JSON.stringify({ status: "error", message: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // Interactive auth page (for browser)
    if (path === "/auth/device" && method === "GET") {
      const html = `<!DOCTYPE html>
<html>
<head>
  <title>Sovereign Agent - GitHub Copilot Auth</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
    .code { font-size: 2em; font-weight: bold; letter-spacing: 0.2em; padding: 20px; background: #f0f0f0; border-radius: 8px; text-align: center; margin: 20px 0; }
    .status { padding: 15px; border-radius: 8px; margin: 20px 0; }
    .pending { background: #fff3cd; }
    .success { background: #d4edda; }
    .error { background: #f8d7da; }
    button { padding: 10px 20px; font-size: 1em; cursor: pointer; }
    a { color: #0066cc; }
  </style>
</head>
<body>
  <h1>GitHub Copilot Authentication</h1>
  <div id="content">
    <p>Click the button below to start authentication:</p>
    <button onclick="startAuth()">Start Authentication</button>
  </div>
  
  <script>
    let flowId = null;
    let pollInterval = null;
    
    async function startAuth() {
      const content = document.getElementById('content');
      content.innerHTML = '<p>Starting authentication...</p>';
      
      try {
        const res = await fetch('/auth/device', { method: 'POST' });
        const data = await res.json();
        
        if (data.success) {
          flowId = data.flow_id;
          content.innerHTML = \`
            <p>Go to <a href="\${data.verification_uri}" target="_blank">\${data.verification_uri}</a> and enter this code:</p>
            <div class="code">\${data.user_code}</div>
            <div id="status" class="status pending">Waiting for authorization...</div>
          \`;
          pollInterval = setInterval(pollStatus, 5000);
        } else {
          content.innerHTML = \`<div class="status error">Error: \${data.error}</div>\`;
        }
      } catch (err) {
        content.innerHTML = \`<div class="status error">Error: \${err.message}</div>\`;
      }
    }
    
    async function pollStatus() {
      if (!flowId) return;
      
      try {
        const res = await fetch('/auth/poll', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ flow_id: flowId })
        });
        const data = await res.json();
        
        const statusEl = document.getElementById('status');
        if (data.status === 'success') {
          clearInterval(pollInterval);
          statusEl.className = 'status success';
          statusEl.textContent = 'Authentication successful! You can close this page.';
        } else if (data.status === 'expired' || data.status === 'error') {
          clearInterval(pollInterval);
          statusEl.className = 'status error';
          statusEl.textContent = data.message;
        }
      } catch (err) {
        console.error('Poll error:', err);
      }
    }
  </script>
</body>
</html>`;
      return new Response(html, {
        headers: { "Content-Type": "text/html", ...corsHeaders },
      });
    }

    // Setup script endpoint - serves a script that downloads bundle via tunnel
    // Supports tier parameter: /setup?tier=free|frugal|premium (default: premium)
    if (path === "/setup") {
      // Parse tier from query string
      const tier = url.searchParams.get("tier") || "premium";
      const validTiers = ["free", "frugal", "premium"];
      const selectedTier = validTiers.includes(tier) ? tier : "premium";
      
      log("info", `Setup requested with tier: ${selectedTier}`);
      
      const setupScript = `#!/bin/bash
# Sovereign Agent Client Setup (GitHub Copilot Edition)
# This script downloads everything through the tunnel - no direct internet access needed.
# Tier: ${selectedTier}

set -uo pipefail

# Configuration
TIER="${selectedTier}"
RELAY_PORT="\${RELAY_PORT:-${RELAY_PORT}}"
INSTALL_DIR="\${INSTALL_DIR:-\$PWD/sovereign-agent}"

echo "=== Sovereign Agent Client Setup (GitHub Copilot) ==="
echo "Tier: \$TIER"
echo ""

# Check the tunnel is working
if ! curl -sf "http://localhost:\$RELAY_PORT/health" >/dev/null 2>&1; then
    echo "Error: Cannot reach relay at localhost:\$RELAY_PORT"
    echo "Make sure the reverse tunnel is running on your laptop."
    exit 1
fi

# Check if relay is authenticated
AUTH_STATUS=\$(curl -sf "http://localhost:\$RELAY_PORT/auth/status" | grep -o '"authenticated":[^,]*' | cut -d: -f2)
if [[ "\$AUTH_STATUS" != "true" ]]; then
    echo "Error: Relay is not authenticated with GitHub Copilot"
    echo ""
    echo "On your relay server, run:"
    echo "  curl -X POST http://localhost:\$RELAY_PORT/auth/device"
    echo ""
    echo "Or open in browser:"
    echo "  http://localhost:\$RELAY_PORT/auth/device"
    echo ""
    exit 1
fi

echo "Relay connection OK (GitHub Copilot authenticated)"
echo ""

# Handle existing OpenCode installations
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)

# ~/.config/opencode - main config directory
OPENCODE_CONFIG_DIR="\$HOME/.config/opencode"
if [[ -d "\$OPENCODE_CONFIG_DIR" ]]; then
    BACKUP_DIR="\$HOME/.config/opencode.backup.\$TIMESTAMP"
    echo "Existing OpenCode config found at \$OPENCODE_CONFIG_DIR"
    echo "Backing up to \$BACKUP_DIR..."
    mv "\$OPENCODE_CONFIG_DIR" "\$BACKUP_DIR"
    echo ""
fi

# Check for required tools and install if missing
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
            GOARCH=""
            ;;
    esac
    if [[ -n "\$GOARCH" ]]; then
        mkdir -p "\$HOME/.local"
        if curl -fsSL "https://go.dev/dl/go\${GO_VERSION}.linux-\${GOARCH}.tar.gz" | tar -C "\$HOME/.local" -xzf -; then
            export PATH="\$GO_INSTALL_DIR/bin:\$PATH"
            echo "export PATH=\"\$GO_INSTALL_DIR/bin:\\\$PATH\"" >> "\$HOME/.bashrc"
        fi
    fi
fi

# Install jq if missing
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y jq 2>/dev/null || true
    elif command -v apk &>/dev/null; then
        sudo apk add jq 2>/dev/null || true
    fi
fi

echo ""

# Download and extract the bundle
echo "Downloading sovereign-agent bundle..."
mkdir -p "\$INSTALL_DIR"
cd "\$INSTALL_DIR"

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
    exit 1
fi
rm -f "\$BUNDLE_TMP"

# Verify bundle was extracted correctly
if [[ ! -f install.sh ]]; then
    echo "Error: Bundle extraction failed - install.sh not found"
    exit 1
fi

# Create client config for relay mode
echo "Creating relay client config..."

cat > config.json <<CONFIGEOF
{
  "site_url": "https://github.com/lachlan-jones5/sovereign-agent",
  "site_name": "SovereignAgent",

  "relay": {
    "enabled": true,
    "mode": "client",
    "port": \$RELAY_PORT
  }
}
CONFIGEOF

# Setup OpenCode configuration directory
echo "Setting up OpenCode configuration (\$TIER tier)..."
mkdir -p "\$HOME/.config/opencode"

# Copy the appropriate tier config file
CONFIG_FILE="configs/opencode.\${TIER}.jsonc"
if [[ -f "\$CONFIG_FILE" ]]; then
    # Replace the RELAY_PORT placeholder in the config
    sed "s/\\\${RELAY_PORT}/\$RELAY_PORT/g" "\$CONFIG_FILE" > "\$HOME/.config/opencode/opencode.jsonc"
    echo "Installed \$TIER tier configuration"
else
    echo "Warning: Config file \$CONFIG_FILE not found, using default"
    # Fallback to premium if specific tier not found
    if [[ -f "configs/opencode.premium.jsonc" ]]; then
        sed "s/\\\${RELAY_PORT}/\$RELAY_PORT/g" "configs/opencode.premium.jsonc" > "\$HOME/.config/opencode/opencode.jsonc"
    fi
fi

# Copy OpenAgents agent definitions
echo "Installing OpenAgents agents and subagents..."
OPENAGENTS_DIR="vendor/OpenAgents/.opencode"

if [[ -d "\$OPENAGENTS_DIR/agent" ]]; then
    # Copy agent directory (primary agents and subagents)
    cp -r "\$OPENAGENTS_DIR/agent" "\$HOME/.config/opencode/"
    echo "  Copied agents from OpenAgents"
fi

if [[ -d "\$OPENAGENTS_DIR/context" ]]; then
    # Copy context directory (context files for agents)
    cp -r "\$OPENAGENTS_DIR/context" "\$HOME/.config/opencode/"
    echo "  Copied context from OpenAgents"
fi

if [[ -d "\$OPENAGENTS_DIR/command" ]]; then
    # Copy command directory (slash commands)
    cp -r "\$OPENAGENTS_DIR/command" "\$HOME/.config/opencode/"
    echo "  Copied commands from OpenAgents"
fi

# Count installed agents
AGENT_COUNT=0
SUBAGENT_COUNT=0
if [[ -d "\$HOME/.config/opencode/agent" ]]; then
    AGENT_COUNT=\$(find "\$HOME/.config/opencode/agent" -maxdepth 2 -name "*.md" ! -path "*/subagents/*" 2>/dev/null | wc -l)
    SUBAGENT_COUNT=\$(find "\$HOME/.config/opencode/agent/subagents" -name "*.md" 2>/dev/null | wc -l)
fi
echo "  Installed \$AGENT_COUNT primary agents, \$SUBAGENT_COUNT subagents"

# Run install
echo ""
echo "Running install.sh..."
chmod +x install.sh
if ! ./install.sh; then
    echo ""
    echo "=== Setup FAILED ==="
    exit 1
fi

echo ""
echo "=== Setup Complete (\$TIER tier) ==="
echo ""
echo "Start a new shell session to pick up PATH changes:"
echo "  exec \\\$SHELL"
echo ""
echo "Then run OpenCode:"
echo "  opencode"
echo ""

# Tier-specific message
case "\$TIER" in
    free)
        echo "FREE TIER: Using only 0x multiplier models (unlimited use)"
        echo "  Primary agents: gpt-4.1, gpt-4o"
        echo "  Subagents: gpt-5-mini, gpt-4o"
        echo ""
        echo "To upgrade: curl -fsSL http://localhost:\$RELAY_PORT/setup?tier=frugal | bash"
        ;;
    frugal)
        echo "FRUGAL TIER: Balanced cost/quality"
        echo "  Primary agents: claude-sonnet-4.5 (1x)"
        echo "  Subagents: claude-haiku-4.5 (0.33x)"
        echo "  Critical tasks: claude-sonnet-4.5 (security, planning)"
        echo ""
        echo "To upgrade: curl -fsSL http://localhost:\$RELAY_PORT/setup?tier=premium | bash"
        ;;
    premium)
        echo "PREMIUM TIER: Maximum quality"
        echo "  Primary agents: claude-opus-4.5 (3x), claude-sonnet-4.5 (1x)"
        echo "  Subagents: claude-sonnet-4.5 (1x), claude-haiku-4.5 (0.33x)"
        echo "  Best models for critical decisions"
        ;;
esac

echo ""
echo "Available agents:"
echo "  Primary: openagent, opencoder, codebase-agent, backend-specialist,"
echo "           frontend-specialist, devops-specialist, system-builder"
echo "  Subagents: tester, reviewer, coder-agent, build-agent, task-manager,"
echo "             documentation, context-retriever, and more"
echo ""
echo "Use '@agent-name' to invoke a specific agent"
echo ""
`;
      return new Response(setupScript, {
        headers: { 
          "Content-Type": "text/x-shellscript",
          "Content-Disposition": "attachment; filename=setup.sh",
          ...corsHeaders,
        },
      });
    }

    // Bundle endpoint - creates fresh tarball of repo on demand (streamed)
    if (path === "/bundle.tar.gz") {
      log("info", "Generating fresh bundle (streaming)...");
      
      try {
        // Pull latest (ignore failures)
        await exec("git pull --quiet 2>/dev/null || true", REPO_PATH);
        
        // Update submodules
        await exec("git submodule update --init --recursive --depth 1 2>&1 || true", REPO_PATH);
        
        // Get approximate size
        const sizeResult = await exec(
          `tar -czf - --exclude='.git' --exclude='config.json' --exclude='node_modules' --exclude='.env' --exclude='*.log' --exclude='tests' . 2>/dev/null | wc -c`,
          REPO_PATH
        );
        const estimatedSize = parseInt(sizeResult.stdout.trim()) || 0;
        log("info", `Estimated bundle size: ${(estimatedSize / 1024 / 1024).toFixed(2)} MB`);
        
        // Stream tarball
        const tarStream = execStream(
          `tar -czf - --exclude='.git' --exclude='config.json' --exclude='node_modules' --exclude='.env' --exclude='*.log' --exclude='tests' .`,
          REPO_PATH
        );
        
        const headers: Record<string, string> = {
          "Content-Type": "application/gzip",
          "Content-Disposition": "attachment; filename=sovereign-agent.tar.gz",
          ...corsHeaders,
        };
        
        if (estimatedSize > 0) {
          headers["Content-Length"] = String(estimatedSize);
        }
        
        return new Response(tarStream, { headers });
      } catch (err) {
        log("error", `Failed to create bundle: ${err}`);
        return new Response(
          JSON.stringify({ error: "Failed to create bundle", details: String(err) }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // API proxy to GitHub Copilot
    const isApiPath = ALLOWED_PATHS.some(
      (allowed) => path === allowed || path.startsWith(allowed + "/") || path.startsWith("/v1/")
    );

    if (isApiPath) {
      // Check authentication
      if (!hasGitHubAuth()) {
        return new Response(
          JSON.stringify({ 
            error: "Not authenticated",
            message: "GitHub Copilot not authenticated. Visit /auth/device to authenticate.",
          }),
          {
            status: 401,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }

      try {
        // Get Copilot token (refreshes if needed)
        const { token: copilotToken, apiBase } = await getCopilotToken();
        
        // Build target URL - strip /v1 prefix as Copilot API doesn't use it
        const apiPath = path.startsWith("/v1/") ? path.slice(3) : path;
        const targetUrl = `${apiBase}${apiPath}${url.search}`;

        // Parse request body to extract model for tracking
        let requestBody: string | null = null;
        let requestParsed: unknown = null;
        let model = "unknown";
        let isStreaming = false;
        
        if (req.body && method === "POST") {
          requestBody = await req.text();
          try {
            requestParsed = JSON.parse(requestBody);
            model = (requestParsed as { model?: string }).model || "unknown";
            isStreaming = (requestParsed as { stream?: boolean }).stream === true;
          } catch {
            // Ignore parse errors
          }
        }

        // Build headers
        const headers = new Headers();
        headers.set("Authorization", `Bearer ${copilotToken}`);
        headers.set("Content-Type", "application/json");
        
        // Add Copilot-specific headers
        for (const [key, value] of Object.entries(COPILOT_HEADERS)) {
          headers.set(key, value);
        }
        
        // Add intent headers
        headers.set("Openai-Intent", "conversation-edits");
        headers.set("X-Initiator", "user");

        requestCount++;
        const multiplier = getModelMultiplier(model);
        premiumRequestsUsed += multiplier;
        
        const startTime = Date.now();
        log("info", `Forwarding: ${method} ${path} -> ${apiBase} (model: ${model}, multiplier: ${multiplier}x, stream: ${isStreaming})`);

        // Forward the request
        const response = await fetch(targetUrl, {
          method: req.method,
          headers,
          body: requestBody,
        });

        const latency = Date.now() - startTime;
        log("info", `Response: ${response.status} ${response.statusText} (${latency}ms)`);

        // Build response headers
        const responseHeaders = new Headers(response.headers);
        for (const [key, value] of Object.entries(corsHeaders)) {
          responseHeaders.set(key, value);
        }

        // Data capture: collect response body and capture session
        if (DATA_CAPTURE_ENABLED) {
          const sessionId = crypto.randomUUID();
          
          // For streaming responses, we need to collect all chunks
          const { body: responseBody, clonedResponse } = await collectStreamingResponse(response);
          
          // Parse response if possible
          let responseParsed: unknown = responseBody;
          try {
            // For streaming, the body is SSE format - keep as string
            if (!isStreaming) {
              responseParsed = JSON.parse(responseBody);
            }
          } catch {
            // Keep as string if not valid JSON
          }

          // Capture asynchronously (don't block response)
          captureSession({
            id: sessionId,
            timestamp: new Date().toISOString(),
            endpoint: path,
            method,
            request: requestParsed || requestBody,
            response: responseParsed,
            status: response.status,
            latency_ms: latency,
            model,
            multiplier,
            stream: isStreaming,
          }).catch(err => log("error", `Capture failed: ${err}`));

          return new Response(clonedResponse.body, {
            status: clonedResponse.status,
            statusText: clonedResponse.statusText,
            headers: responseHeaders,
          });
        }

        // No capture - return response as-is (streaming works automatically)
        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: responseHeaders,
        });
      } catch (err) {
        log("error", `Request failed: ${err}`);
        return new Response(
          JSON.stringify({ error: "Relay request failed", details: String(err) }),
          {
            status: 502,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          }
        );
      }
    }

    // Unknown path
    return new Response(
      JSON.stringify({ error: "Not found", path }),
      {
        status: 404,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      }
    );
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
log("info", `Backend: GitHub Copilot API (dynamic endpoint from token)`);
log("info", `Authenticated: ${hasGitHubAuth()}`);
if (!hasGitHubAuth()) {
  log("info", `To authenticate, visit: http://${RELAY_HOST}:${RELAY_PORT}/auth/device`);
}
log("info", `Client setup available at /setup and /bundle.tar.gz`);

// Data capture status
if (DATA_CAPTURE_ENABLED) {
  log("info", `Data capture: ENABLED`);
  if (DATA_CAPTURE_PATH) {
    log("info", `  Local storage: ${DATA_CAPTURE_PATH}`);
  }
  if (DATA_CAPTURE_FORWARD_URL) {
    log("info", `  Forward URL: ${DATA_CAPTURE_FORWARD_URL}`);
  }
  log("info", `  Endpoints: /data/stats, /data/recent, /data/export, /data/ingest`);
} else {
  log("info", `Data capture: disabled (set DATA_CAPTURE_ENABLED=true to enable)`);
}
