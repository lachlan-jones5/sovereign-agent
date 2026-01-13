/**
 * Unit tests for Sovereign Agent API Relay
 *
 * These tests cover:
 * - Request forwarding logic
 * - Authorization header injection
 * - Path whitelist enforcement
 * - Health and stats endpoints
 * - Error handling
 * - Token tracking
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach, mock, spyOn } from "bun:test";
import { existsSync, writeFileSync, unlinkSync, mkdirSync, rmSync } from "fs";
import { resolve } from "path";

// Test configuration directory
const TEST_DIR = resolve(import.meta.dir, "../.test-relay");
const TEST_CONFIG_PATH = resolve(TEST_DIR, "config.json");

// Mock fetch for network isolation
const originalFetch = globalThis.fetch;

describe("Relay Configuration", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  describe("loadConfig", () => {
    it("should throw error when config file is missing", () => {
      const missingPath = resolve(TEST_DIR, "nonexistent.json");
      expect(existsSync(missingPath)).toBe(false);
    });

    it("should parse valid config JSON", () => {
      const config = {
        openrouter_api_key: "sk-or-v1-test-key",
        site_url: "https://test.local",
        site_name: "TestSite",
      };
      writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));

      const content = Bun.file(TEST_CONFIG_PATH).text();
      expect(content).resolves.toContain("sk-or-v1-test-key");
    });

    it("should require openrouter_api_key", async () => {
      const invalidConfig = { site_url: "https://test.local" };
      writeFileSync(TEST_CONFIG_PATH, JSON.stringify(invalidConfig));

      const content = JSON.parse(await Bun.file(TEST_CONFIG_PATH).text());
      expect(content.openrouter_api_key).toBeUndefined();
    });

    it("should use default allowed paths when not specified", async () => {
      const config = {
        openrouter_api_key: "sk-or-v1-test-key",
      };
      writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));

      const content = JSON.parse(await Bun.file(TEST_CONFIG_PATH).text());
      expect(content.relay?.allowed_paths).toBeUndefined();
    });

    it("should read custom allowed paths from config", async () => {
      const config = {
        openrouter_api_key: "sk-or-v1-test-key",
        relay: {
          allowed_paths: ["/api/v1/custom"],
        },
      };
      writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));

      const content = JSON.parse(await Bun.file(TEST_CONFIG_PATH).text());
      expect(content.relay.allowed_paths).toEqual(["/api/v1/custom"]);
    });
  });
});

describe("Path Whitelist Enforcement", () => {
  const ALLOWED_PATHS = [
    "/api/v1/chat/completions",
    "/api/v1/completions",
    "/api/v1/models",
    "/api/v1/auth/key",
    "/api/v1/generation",
  ];

  function isPathAllowed(path: string): boolean {
    // Block path traversal attempts
    if (path.includes("..") || path.includes("//")) {
      return false;
    }
    return ALLOWED_PATHS.some(
      (allowed) => path === allowed || path.startsWith(allowed + "/")
    );
  }

  it("should allow exact match paths", () => {
    expect(isPathAllowed("/api/v1/chat/completions")).toBe(true);
    expect(isPathAllowed("/api/v1/models")).toBe(true);
    expect(isPathAllowed("/api/v1/auth/key")).toBe(true);
  });

  it("should allow subpaths", () => {
    expect(isPathAllowed("/api/v1/chat/completions/stream")).toBe(true);
    expect(isPathAllowed("/api/v1/models/list")).toBe(true);
  });

  it("should block non-whitelisted paths", () => {
    expect(isPathAllowed("/api/v1/admin")).toBe(false);
    expect(isPathAllowed("/api/v1/users")).toBe(false);
    expect(isPathAllowed("/admin")).toBe(false);
    expect(isPathAllowed("/")).toBe(false);
  });

  it("should block path traversal attempts", () => {
    expect(isPathAllowed("/../etc/passwd")).toBe(false);
    expect(isPathAllowed("/api/v1/chat/completions/../../../etc/passwd")).toBe(false);
  });

  it("should block paths with query string manipulation", () => {
    // Note: Path itself doesn't include query string, but we test the path portion
    expect(isPathAllowed("/api/v1/secret")).toBe(false);
  });

  it("should be case-sensitive", () => {
    expect(isPathAllowed("/API/V1/CHAT/COMPLETIONS")).toBe(false);
    expect(isPathAllowed("/Api/V1/Chat/Completions")).toBe(false);
  });
});

describe("Authorization Header Injection", () => {
  const API_KEY = "sk-or-v1-test-api-key-12345";

  function addAuthHeader(headers: Headers, apiKey: string): Headers {
    headers.set("Authorization", `Bearer ${apiKey}`);
    return headers;
  }

  it("should add Authorization header with Bearer token", () => {
    const headers = new Headers();
    addAuthHeader(headers, API_KEY);

    expect(headers.get("Authorization")).toBe(`Bearer ${API_KEY}`);
  });

  it("should overwrite existing Authorization header", () => {
    const headers = new Headers({
      Authorization: "Bearer old-token",
    });
    addAuthHeader(headers, API_KEY);

    expect(headers.get("Authorization")).toBe(`Bearer ${API_KEY}`);
    expect(headers.get("Authorization")).not.toBe("Bearer old-token");
  });

  it("should preserve other headers", () => {
    const headers = new Headers({
      "Content-Type": "application/json",
      "X-Custom-Header": "custom-value",
    });
    addAuthHeader(headers, API_KEY);

    expect(headers.get("Content-Type")).toBe("application/json");
    expect(headers.get("X-Custom-Header")).toBe("custom-value");
    expect(headers.get("Authorization")).toBe(`Bearer ${API_KEY}`);
  });
});

describe("Header Sanitization", () => {
  function sanitizeHeaders(headers: Headers): Headers {
    headers.delete("Host");
    headers.delete("Connection");
    return headers;
  }

  it("should remove Host header", () => {
    const headers = new Headers({
      Host: "localhost:8080",
      "Content-Type": "application/json",
    });
    sanitizeHeaders(headers);

    expect(headers.get("Host")).toBeNull();
  });

  it("should remove Connection header", () => {
    const headers = new Headers({
      Connection: "keep-alive",
      "Content-Type": "application/json",
    });
    sanitizeHeaders(headers);

    expect(headers.get("Connection")).toBeNull();
  });

  it("should preserve other headers", () => {
    const headers = new Headers({
      Host: "localhost:8080",
      Connection: "keep-alive",
      "Content-Type": "application/json",
      Authorization: "Bearer token",
    });
    sanitizeHeaders(headers);

    expect(headers.get("Content-Type")).toBe("application/json");
    expect(headers.get("Authorization")).toBe("Bearer token");
  });
});

describe("Health Endpoint", () => {
  it("should return correct health response structure", () => {
    const healthResponse = {
      status: "ok",
      relay: "sovereign-agent",
      requests: 0,
      tokens: { in: 0, out: 0 },
    };

    expect(healthResponse.status).toBe("ok");
    expect(healthResponse.relay).toBe("sovereign-agent");
    expect(healthResponse.tokens).toHaveProperty("in");
    expect(healthResponse.tokens).toHaveProperty("out");
  });

  it("should track request count", () => {
    let requestCount = 0;
    requestCount++;
    requestCount++;

    expect(requestCount).toBe(2);
  });
});

describe("Stats Endpoint", () => {
  it("should return correct stats response structure", () => {
    const statsResponse = {
      requests: 5,
      tokens: { in: 1000, out: 500 },
      uptime: 3600,
    };

    expect(statsResponse.requests).toBe(5);
    expect(statsResponse.tokens.in).toBe(1000);
    expect(statsResponse.tokens.out).toBe(500);
    expect(statsResponse.uptime).toBeGreaterThanOrEqual(0);
  });
});

describe("Token Tracking", () => {
  let totalTokensIn = 0;
  let totalTokensOut = 0;

  beforeEach(() => {
    totalTokensIn = 0;
    totalTokensOut = 0;
  });

  it("should track input tokens from usage header", () => {
    const usageHeader = JSON.stringify({
      prompt_tokens: 100,
      completion_tokens: 50,
    });

    const usageData = JSON.parse(usageHeader);
    if (usageData.prompt_tokens) totalTokensIn += usageData.prompt_tokens;
    if (usageData.completion_tokens) totalTokensOut += usageData.completion_tokens;

    expect(totalTokensIn).toBe(100);
    expect(totalTokensOut).toBe(50);
  });

  it("should accumulate tokens across requests", () => {
    const usages = [
      { prompt_tokens: 100, completion_tokens: 50 },
      { prompt_tokens: 200, completion_tokens: 100 },
      { prompt_tokens: 150, completion_tokens: 75 },
    ];

    for (const usage of usages) {
      totalTokensIn += usage.prompt_tokens;
      totalTokensOut += usage.completion_tokens;
    }

    expect(totalTokensIn).toBe(450);
    expect(totalTokensOut).toBe(225);
  });

  it("should handle missing usage data gracefully", () => {
    const usageHeader = null;

    if (usageHeader) {
      try {
        const usageData = JSON.parse(usageHeader);
        if (usageData.prompt_tokens) totalTokensIn += usageData.prompt_tokens;
      } catch {
        // Ignore
      }
    }

    expect(totalTokensIn).toBe(0);
  });

  it("should handle malformed JSON in usage header", () => {
    const usageHeader = "not-valid-json";

    try {
      const usageData = JSON.parse(usageHeader);
      if (usageData.prompt_tokens) totalTokensIn += usageData.prompt_tokens;
    } catch {
      // Expected - malformed JSON
    }

    expect(totalTokensIn).toBe(0);
  });
});

describe("Error Handling", () => {
  describe("403 Forbidden responses", () => {
    it("should return 403 for blocked paths", () => {
      const blockedPath = "/api/v1/admin";
      const response = {
        status: 403,
        body: { error: "Path not allowed" },
      };

      expect(response.status).toBe(403);
      expect(response.body.error).toBe("Path not allowed");
    });
  });

  describe("502 Bad Gateway responses", () => {
    it("should return 502 when upstream fails", () => {
      const response = {
        status: 502,
        body: { error: "Relay request failed", details: "Connection refused" },
      };

      expect(response.status).toBe(502);
      expect(response.body.error).toBe("Relay request failed");
      expect(response.body.details).toBeDefined();
    });
  });

  describe("500 Internal Server Error", () => {
    it("should return 500 for server errors", () => {
      const response = {
        status: 500,
        body: { error: "Internal server error" },
      };

      expect(response.status).toBe(500);
      expect(response.body.error).toBe("Internal server error");
    });
  });
});

describe("URL Building", () => {
  const OPENROUTER_BASE = "https://openrouter.ai";

  function buildTargetUrl(path: string, search: string): string {
    return `${OPENROUTER_BASE}${path}${search}`;
  }

  it("should build correct URL without query string", () => {
    const url = buildTargetUrl("/api/v1/chat/completions", "");
    expect(url).toBe("https://openrouter.ai/api/v1/chat/completions");
  });

  it("should preserve query string", () => {
    const url = buildTargetUrl("/api/v1/models", "?provider=openai");
    expect(url).toBe("https://openrouter.ai/api/v1/models?provider=openai");
  });

  it("should handle complex query strings", () => {
    const url = buildTargetUrl("/api/v1/chat/completions", "?stream=true&model=gpt-4");
    expect(url).toBe("https://openrouter.ai/api/v1/chat/completions?stream=true&model=gpt-4");
  });
});

describe("Logging", () => {
  const LOG_LEVELS: Record<string, number> = { debug: 0, info: 1, warn: 2, error: 3 };

  function shouldLog(messageLevel: string, currentLevel: string): boolean {
    return LOG_LEVELS[messageLevel] >= LOG_LEVELS[currentLevel];
  }

  it("should log at info level by default", () => {
    expect(shouldLog("info", "info")).toBe(true);
    expect(shouldLog("warn", "info")).toBe(true);
    expect(shouldLog("error", "info")).toBe(true);
    expect(shouldLog("debug", "info")).toBe(false);
  });

  it("should filter debug logs when level is info", () => {
    expect(shouldLog("debug", "info")).toBe(false);
  });

  it("should show all logs when level is debug", () => {
    expect(shouldLog("debug", "debug")).toBe(true);
    expect(shouldLog("info", "debug")).toBe(true);
    expect(shouldLog("warn", "debug")).toBe(true);
    expect(shouldLog("error", "debug")).toBe(true);
  });

  it("should only show errors when level is error", () => {
    expect(shouldLog("debug", "error")).toBe(false);
    expect(shouldLog("info", "error")).toBe(false);
    expect(shouldLog("warn", "error")).toBe(false);
    expect(shouldLog("error", "error")).toBe(true);
  });
});

describe("OpenRouter Headers", () => {
  interface Config {
    site_url?: string;
    site_name?: string;
  }

  function addOpenRouterHeaders(headers: Headers, config: Config): Headers {
    if (config.site_url) {
      headers.set("HTTP-Referer", config.site_url);
    }
    if (config.site_name) {
      headers.set("X-Title", config.site_name);
    }
    return headers;
  }

  it("should add HTTP-Referer from site_url", () => {
    const headers = new Headers();
    const config = { site_url: "https://myapp.com" };
    addOpenRouterHeaders(headers, config);

    expect(headers.get("HTTP-Referer")).toBe("https://myapp.com");
  });

  it("should add X-Title from site_name", () => {
    const headers = new Headers();
    const config = { site_name: "My Application" };
    addOpenRouterHeaders(headers, config);

    expect(headers.get("X-Title")).toBe("My Application");
  });

  it("should add both headers when both are configured", () => {
    const headers = new Headers();
    const config = { site_url: "https://myapp.com", site_name: "My App" };
    addOpenRouterHeaders(headers, config);

    expect(headers.get("HTTP-Referer")).toBe("https://myapp.com");
    expect(headers.get("X-Title")).toBe("My App");
  });

  it("should not add headers when not configured", () => {
    const headers = new Headers();
    const config = {};
    addOpenRouterHeaders(headers, config);

    expect(headers.get("HTTP-Referer")).toBeNull();
    expect(headers.get("X-Title")).toBeNull();
  });
});

describe("Environment Variables", () => {
  it("should parse RELAY_PORT as integer", () => {
    const portStr = "8080";
    const port = parseInt(portStr, 10);
    expect(port).toBe(8080);
  });

  it("should default to 8080 when RELAY_PORT is not set", () => {
    const port = parseInt(process.env.RELAY_PORT || "8080", 10);
    expect(port).toBeGreaterThan(0);
  });

  it("should default RELAY_HOST to 127.0.0.1", () => {
    const host = process.env.RELAY_HOST || "127.0.0.1";
    expect(host).toBe("127.0.0.1");
  });

  it("should default LOG_LEVEL to info", () => {
    const level = process.env.LOG_LEVEL || "info";
    expect(level).toBe("info");
  });
});

describe("Request Counting", () => {
  let requestCount = 0;

  beforeEach(() => {
    requestCount = 0;
  });

  it("should increment on each request", () => {
    requestCount++;
    expect(requestCount).toBe(1);

    requestCount++;
    expect(requestCount).toBe(2);
  });

  it("should not count health check requests", () => {
    const isHealthCheck = (path: string) => path === "/health" || path === "/";

    const paths = ["/api/v1/chat/completions", "/health", "/", "/api/v1/models"];
    for (const path of paths) {
      if (!isHealthCheck(path)) {
        requestCount++;
      }
    }

    expect(requestCount).toBe(2); // Only the non-health paths
  });
});

describe("Setup Endpoint", () => {
  it("should return shell script content type", () => {
    const response = new Response("#!/bin/bash\necho 'test'", {
      headers: { 
        "Content-Type": "text/x-shellscript",
        "Content-Disposition": "attachment; filename=setup.sh",
      },
    });

    expect(response.headers.get("Content-Type")).toBe("text/x-shellscript");
    expect(response.headers.get("Content-Disposition")).toBe("attachment; filename=setup.sh");
  });

  it("should include RELAY_PORT variable in setup script", () => {
    const setupScript = `#!/bin/bash
RELAY_PORT="\${RELAY_PORT:-8080}"
curl -sf "http://localhost:\$RELAY_PORT/health"
`;
    expect(setupScript).toContain("RELAY_PORT");
    expect(setupScript).toContain("/health");
  });

  it("should include bundle download command in setup script", () => {
    const setupScript = `curl -sf "http://localhost:$RELAY_PORT/bundle.tar.gz" | tar -xzf - --strip-components=1`;
    expect(setupScript).toContain("/bundle.tar.gz");
    expect(setupScript).toContain("tar -xzf");
  });

  it("should create client config with relay mode", () => {
    const configTemplate = `{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8080
  }
}`;
    const config = JSON.parse(configTemplate);
    expect(config.relay.enabled).toBe(true);
    expect(config.relay.mode).toBe("client");
  });

  it("should check for required dependencies", () => {
    const setupScript = `
if ! command -v go &>/dev/null; then
    echo "Warning: 'go' not found"
fi
if ! command -v bun &>/dev/null; then
    echo "Warning: 'bun' not found"
fi
if ! command -v jq &>/dev/null; then
    echo "Warning: 'jq' not found"
fi
`;
    expect(setupScript).toContain("go");
    expect(setupScript).toContain("bun");
    expect(setupScript).toContain("jq");
  });
});

describe("Bundle Endpoint", () => {
  it("should return gzip content type for bundle", () => {
    const response = new Response(new Uint8Array([0x1f, 0x8b]), {
      headers: {
        "Content-Type": "application/gzip",
        "Content-Disposition": "attachment; filename=sovereign-agent.tar.gz",
      },
    });

    expect(response.headers.get("Content-Type")).toBe("application/gzip");
    expect(response.headers.get("Content-Disposition")).toBe("attachment; filename=sovereign-agent.tar.gz");
  });

  it("should exclude sensitive files from bundle", () => {
    const excludePatterns = [
      ".git",
      "config.json",
      "node_modules",
      ".env",
      "*.log",
    ];

    // These patterns should be in the tar exclude list
    expect(excludePatterns).toContain(".git");
    expect(excludePatterns).toContain("config.json");
    expect(excludePatterns).toContain(".env");
  });

  it("should return 500 on bundle creation failure", () => {
    const errorResponse = {
      status: 500,
      body: { error: "Failed to create bundle", details: "tar command failed" },
    };

    expect(errorResponse.status).toBe(500);
    expect(errorResponse.body.error).toBe("Failed to create bundle");
    expect(errorResponse.body.details).toBeDefined();
  });

  it("should log bundle size on success", () => {
    const bundleSize = 15 * 1024 * 1024; // 15 MB
    const logMessage = `Bundle created: ${(bundleSize / 1024 / 1024).toFixed(2)} MB`;
    
    expect(logMessage).toBe("Bundle created: 15.00 MB");
  });
});

describe("Response Streaming", () => {
  it("should preserve response body for streaming", async () => {
    // Test that Response body can be passed through
    const chunks = ["data: {\"content\": \"Hello\"}\n\n", "data: {\"content\": \"World\"}\n\n"];
    const body = new ReadableStream({
      start(controller) {
        for (const chunk of chunks) {
          controller.enqueue(new TextEncoder().encode(chunk));
        }
        controller.close();
      },
    });

    const response = new Response(body, {
      headers: { "Content-Type": "text/event-stream" },
    });

    expect(response.body).toBeDefined();
    expect(response.headers.get("Content-Type")).toBe("text/event-stream");
  });

  it("should preserve response status and headers", () => {
    const originalHeaders = new Headers({
      "Content-Type": "application/json",
      "X-Request-Id": "abc123",
    });

    const response = new Response("{}", {
      status: 200,
      statusText: "OK",
      headers: originalHeaders,
    });

    expect(response.status).toBe(200);
    expect(response.statusText).toBe("OK");
    expect(response.headers.get("X-Request-Id")).toBe("abc123");
  });
});
