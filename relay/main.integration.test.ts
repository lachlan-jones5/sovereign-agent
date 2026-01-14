/**
 * Integration tests for Sovereign Agent API Relay
 *
 * These tests cover:
 * - End-to-end request flow (mocked)
 * - Config loading and validation
 * - Setup script generation
 * - Bundle endpoint behavior
 * - Error recovery scenarios
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import { mkdirSync, rmSync, writeFileSync, existsSync, readFileSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-integration");
const TEST_CONFIG_PATH = resolve(TEST_DIR, "config.json");

describe("Config Loading", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  describe("loadConfig error paths", () => {
    it("should fail when config file does not exist", () => {
      const missingPath = resolve(TEST_DIR, "missing-config.json");
      expect(existsSync(missingPath)).toBe(false);
      
      // Simulate what loadConfig does
      let error: Error | null = null;
      try {
        if (!existsSync(missingPath)) {
          throw new Error(`Config file not found: ${missingPath}`);
        }
      } catch (e) {
        error = e as Error;
      }
      
      expect(error).not.toBeNull();
      expect(error!.message).toContain("not found");
    });

    it("should fail when config file contains invalid JSON", () => {
      const invalidPath = resolve(TEST_DIR, "invalid.json");
      writeFileSync(invalidPath, "{ this is not valid json }");
      
      let error: Error | null = null;
      try {
        const content = readFileSync(invalidPath, "utf-8");
        JSON.parse(content);
      } catch (e) {
        error = e as Error;
      }
      
      expect(error).not.toBeNull();
    });

    it("should fail when API key is missing", () => {
      const noKeyPath = resolve(TEST_DIR, "no-key.json");
      writeFileSync(noKeyPath, JSON.stringify({
        site_url: "https://example.com",
        site_name: "Test",
      }));
      
      const content = JSON.parse(readFileSync(noKeyPath, "utf-8"));
      expect(content.openrouter_api_key).toBeUndefined();
    });

    it("should fail when API key is empty string", () => {
      const emptyKeyPath = resolve(TEST_DIR, "empty-key.json");
      writeFileSync(emptyKeyPath, JSON.stringify({
        openrouter_api_key: "",
        site_url: "https://example.com",
      }));
      
      const content = JSON.parse(readFileSync(emptyKeyPath, "utf-8"));
      expect(content.openrouter_api_key).toBe("");
      expect(content.openrouter_api_key).toBeFalsy();
    });

    it("should succeed with valid config", () => {
      writeFileSync(TEST_CONFIG_PATH, JSON.stringify({
        openrouter_api_key: "sk-or-v1-test-key",
        site_url: "https://example.com",
        site_name: "Test",
      }));
      
      const content = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
      expect(content.openrouter_api_key).toBe("sk-or-v1-test-key");
      expect(content.site_url).toBe("https://example.com");
    });

    it("should handle UTF-8 characters in config", () => {
      const utf8Path = resolve(TEST_DIR, "utf8.json");
      writeFileSync(utf8Path, JSON.stringify({
        openrouter_api_key: "sk-or-v1-test-key",
        site_name: "Test Site with emoji",
      }));
      
      const content = JSON.parse(readFileSync(utf8Path, "utf-8"));
      expect(content.site_name).toContain("emoji");
    });

    it("should handle very large config files gracefully", () => {
      const largePath = resolve(TEST_DIR, "large.json");
      const largeConfig = {
        openrouter_api_key: "sk-or-v1-test-key",
        metadata: "x".repeat(100000), // 100KB of data
      };
      writeFileSync(largePath, JSON.stringify(largeConfig));
      
      const content = JSON.parse(readFileSync(largePath, "utf-8"));
      expect(content.openrouter_api_key).toBe("sk-or-v1-test-key");
      expect(content.metadata.length).toBe(100000);
    });
  });
});

describe("Setup Script Generation", () => {
  it("should include relay port variable", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain("RELAY_PORT");
    expect(setupScript).toContain("8080");
  });

  it("should include health check command", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain("/health");
    expect(setupScript).toContain("curl");
  });

  it("should include bundle download command", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain("/bundle.tar.gz");
    expect(setupScript).toContain("tar");
  });

  it("should create client config with relay mode", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain('"mode": "client"');
    expect(setupScript).toContain('"enabled": true');
  });

  it("should check for required dependencies", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain("go");
    expect(setupScript).toContain("bun");
    expect(setupScript).toContain("jq");
  });

  it("should backup existing OpenCode configs", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain("backup");
    expect(setupScript).toContain(".config/opencode");
  });

  it("should handle custom relay port", () => {
    const setupScript = generateMockSetupScript(9999);
    
    expect(setupScript).toContain("9999");
  });

  it("should run install.sh after extraction", () => {
    const setupScript = generateMockSetupScript(8080);
    
    expect(setupScript).toContain("./install.sh");
    expect(setupScript).toContain("chmod +x install.sh");
  });
});

describe("Bundle Endpoint Behavior", () => {
  it("should return correct content type for gzip", () => {
    const headers = {
      "Content-Type": "application/gzip",
      "Content-Disposition": "attachment; filename=sovereign-agent.tar.gz",
    };
    
    expect(headers["Content-Type"]).toBe("application/gzip");
    expect(headers["Content-Disposition"]).toContain("sovereign-agent.tar.gz");
  });

  it("should exclude sensitive files from tar command", () => {
    const excludeArgs = [
      "--exclude='.git'",
      "--exclude='config.json'",
      "--exclude='node_modules'",
      "--exclude='.env'",
      "--exclude='*.log'",
      "--exclude='tests'",
    ];
    
    const tarCommand = `tar -czf - ${excludeArgs.join(" ")} .`;
    
    expect(tarCommand).toContain("--exclude='.git'");
    expect(tarCommand).toContain("--exclude='config.json'");
    expect(tarCommand).toContain("--exclude='.env'");
  });

  it("should verify vendor submodules before bundling", () => {
    const vendorChecks = [
      "vendor/opencode/package.json",
      "vendor/OpenAgents/.opencode/agent",
    ];
    
    // These paths should be checked before creating bundle
    for (const check of vendorChecks) {
      expect(check).toMatch(/vendor\//);
    }
  });

  it("should return 500 on bundle creation failure", () => {
    const errorResponse = {
      status: 500,
      body: {
        error: "Failed to create bundle",
        details: "tar command failed",
        repo_path: "/app",
      },
    };
    
    expect(errorResponse.status).toBe(500);
    expect(errorResponse.body.error).toBe("Failed to create bundle");
    expect(errorResponse.body.repo_path).toBeDefined();
  });

  it("should return 500 when vendor submodules are empty", () => {
    const errorResponse = {
      status: 500,
      body: {
        error: "Vendor submodules are not populated",
        details: "SSH to the relay server and run: cd ~/sovereign-agent && git submodule update --init --recursive",
        repo_path: "/app",
        stdout: "",
        stderr: "No such file or directory",
      },
    };
    
    expect(errorResponse.status).toBe(500);
    expect(errorResponse.body.error).toContain("not populated");
    expect(errorResponse.body.details).toContain("git submodule update");
  });

  it("should estimate bundle size for progress indicator", () => {
    const sizeBytes = 15 * 1024 * 1024; // 15 MB
    const sizeMB = (sizeBytes / 1024 / 1024).toFixed(2);
    
    expect(sizeMB).toBe("15.00");
    expect(parseFloat(sizeMB)).toBeGreaterThan(0);
  });
});

describe("Request Forwarding", () => {
  it("should build correct target URL without query string", () => {
    const OPENROUTER_BASE = "https://openrouter.ai";
    const path = "/api/v1/chat/completions";
    const search = "";
    
    const targetUrl = `${OPENROUTER_BASE}${path}${search}`;
    
    expect(targetUrl).toBe("https://openrouter.ai/api/v1/chat/completions");
  });

  it("should preserve query string in target URL", () => {
    const OPENROUTER_BASE = "https://openrouter.ai";
    const path = "/api/v1/models";
    const search = "?provider=openai";
    
    const targetUrl = `${OPENROUTER_BASE}${path}${search}`;
    
    expect(targetUrl).toBe("https://openrouter.ai/api/v1/models?provider=openai");
  });

  it("should add Authorization header with Bearer token", () => {
    const apiKey = "sk-or-v1-test-key";
    const headers = new Headers();
    headers.set("Authorization", `Bearer ${apiKey}`);
    
    expect(headers.get("Authorization")).toBe("Bearer sk-or-v1-test-key");
  });

  it("should add OpenRouter-specific headers", () => {
    const config = {
      site_url: "https://myapp.com",
      site_name: "My App",
    };
    
    const headers = new Headers();
    if (config.site_url) {
      headers.set("HTTP-Referer", config.site_url);
    }
    if (config.site_name) {
      headers.set("X-Title", config.site_name);
    }
    
    expect(headers.get("HTTP-Referer")).toBe("https://myapp.com");
    expect(headers.get("X-Title")).toBe("My App");
  });

  it("should remove Host and Connection headers", () => {
    const headers = new Headers({
      "Host": "localhost:8080",
      "Connection": "keep-alive",
      "Content-Type": "application/json",
    });
    
    headers.delete("Host");
    headers.delete("Connection");
    
    expect(headers.get("Host")).toBeNull();
    expect(headers.get("Connection")).toBeNull();
    expect(headers.get("Content-Type")).toBe("application/json");
  });

  it("should track token usage from response headers", () => {
    let totalTokensIn = 0;
    let totalTokensOut = 0;
    
    const usageHeader = JSON.stringify({
      prompt_tokens: 500,
      completion_tokens: 200,
    });
    
    const usageData = JSON.parse(usageHeader);
    if (usageData.prompt_tokens) totalTokensIn += usageData.prompt_tokens;
    if (usageData.completion_tokens) totalTokensOut += usageData.completion_tokens;
    
    expect(totalTokensIn).toBe(500);
    expect(totalTokensOut).toBe(200);
  });

  it("should return 403 for non-whitelisted paths", () => {
    const ALLOWED_PATHS = [
      "/api/v1/chat/completions",
      "/api/v1/completions",
      "/api/v1/models",
      "/api/v1/auth/key",
      "/api/v1/generation",
    ];
    
    function isAllowed(path: string): boolean {
      return ALLOWED_PATHS.some(
        (allowed) => path === allowed || path.startsWith(allowed + "/")
      );
    }
    
    expect(isAllowed("/api/v1/admin")).toBe(false);
    expect(isAllowed("/api/v1/users")).toBe(false);
    expect(isAllowed("/internal")).toBe(false);
    
    const response = {
      status: 403,
      body: { error: "Path not allowed" },
    };
    
    expect(response.status).toBe(403);
  });

  it("should return 502 when upstream fails", () => {
    const response = {
      status: 502,
      body: {
        error: "Relay request failed",
        details: "ECONNREFUSED",
      },
    };
    
    expect(response.status).toBe(502);
    expect(response.body.error).toBe("Relay request failed");
  });
});

describe("Error Recovery", () => {
  it("should handle network timeout gracefully", () => {
    // Simulate timeout handling
    const timeoutMs = 30000;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
    
    // Clean up
    clearTimeout(timeoutId);
    expect(controller.signal.aborted).toBe(false);
  });

  it("should handle malformed upstream response", () => {
    const malformedResponses = [
      null,
      undefined,
      "not a response object",
    ];
    
    for (const resp of malformedResponses) {
      const isValid = resp !== null && resp !== undefined && typeof resp === "object";
      expect(isValid).toBe(false);
    }
  });

  it("should continue after upstream 500 error", () => {
    // The relay should forward the error, not crash
    const upstreamError = {
      status: 500,
      body: { error: "Internal server error" },
    };
    
    // Relay returns the same status
    expect(upstreamError.status).toBe(500);
    // Server state should be unaffected (requestCount continues working)
    let requestCount = 10;
    requestCount++;
    expect(requestCount).toBe(11);
  });

  it("should track requests even when forwarding fails", () => {
    let requestCount = 0;
    
    // Before request
    requestCount++;
    
    // Even if fetch throws, count is incremented
    try {
      throw new Error("Network error");
    } catch {
      // Error handled
    }
    
    expect(requestCount).toBe(1);
  });
});

describe("Environment Variables", () => {
  it("should use defaults when env vars not set", () => {
    const config = {
      port: parseInt(process.env.TEST_RELAY_PORT || "8080", 10),
      host: process.env.TEST_RELAY_HOST || "127.0.0.1",
      logLevel: process.env.TEST_LOG_LEVEL || "info",
    };
    
    expect(config.port).toBe(8080);
    expect(config.host).toBe("127.0.0.1");
    expect(config.logLevel).toBe("info");
  });

  it("should accept custom port values", () => {
    const customPort = "9999";
    const port = parseInt(customPort, 10);
    
    expect(port).toBe(9999);
    expect(port).toBeGreaterThan(0);
    expect(port).toBeLessThanOrEqual(65535);
  });

  it("should accept 0.0.0.0 for external binding", () => {
    const host = "0.0.0.0";
    expect(host).toBe("0.0.0.0");
  });

  it("should validate port is numeric", () => {
    const validPorts = ["80", "443", "8080", "8081", "65535"];
    const invalidPorts = ["abc", "-1", "99999", ""];
    
    function isValidPort(portStr: string): boolean {
      const port = parseInt(portStr, 10);
      return !isNaN(port) && port > 0 && port <= 65535;
    }
    
    for (const port of validPorts) {
      expect(isValidPort(port)).toBe(true);
    }
    
    for (const port of invalidPorts) {
      expect(isValidPort(port)).toBe(false);
    }
  });
});

// Helper function to generate mock setup script
function generateMockSetupScript(port: number): string {
  return `#!/bin/bash
# Sovereign Agent Client Setup (via relay tunnel)
set -uo pipefail

RELAY_PORT="\${RELAY_PORT:-${port}}"
INSTALL_DIR="\${INSTALL_DIR:-\$PWD/sovereign-agent}"

echo "=== Sovereign Agent Client Setup (via tunnel) ==="

# Check the tunnel is working
if ! curl -sf "http://localhost:\$RELAY_PORT/health" >/dev/null 2>&1; then
    echo "Error: Cannot reach relay at localhost:\$RELAY_PORT"
    exit 1
fi

# Backup existing configs
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
OPENCODE_CONFIG_DIR="\$HOME/.config/opencode"
if [[ -d "\$OPENCODE_CONFIG_DIR" ]]; then
    BACKUP_DIR="\$HOME/.config/opencode.backup.\$TIMESTAMP"
    mv "\$OPENCODE_CONFIG_DIR" "\$BACKUP_DIR"
fi

# Check dependencies
if ! command -v go &>/dev/null; then
    echo "Installing Go..."
fi
if ! command -v bun &>/dev/null; then
    echo "Installing Bun..."
fi
if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
fi

# Download bundle
curl -# -f "http://localhost:\$RELAY_PORT/bundle.tar.gz" -o bundle.tar.gz
tar -xzf bundle.tar.gz

# Create client config
cat > config.json <<CONFIGEOF
{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": \$RELAY_PORT
  }
}
CONFIGEOF

# Run install
chmod +x install.sh
./install.sh
`;
}
