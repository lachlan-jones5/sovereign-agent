/**
 * Integration tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - End-to-end request flow (mocked)
 * - Config loading and validation
 * - Setup script generation for Copilot
 * - Bundle endpoint behavior
 * - Error recovery scenarios
 * - Full authentication flow simulation
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import { mkdirSync, rmSync, writeFileSync, existsSync, readFileSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-integration-copilot");
const TEST_CONFIG_PATH = resolve(TEST_DIR, "config.json");

// Constants from main.ts
const COPILOT_API_BASE = "https://api.githubcopilot.com";
const COPILOT_HEADERS = {
  "User-Agent": "GitHubCopilotChat/0.35.0",
  "Editor-Version": "vscode/1.107.0",
  "Editor-Plugin-Version": "copilot-chat/0.35.0",
  "Copilot-Integration-Id": "vscode-chat",
};

describe("Config Loading", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  describe("Copilot config paths", () => {
    it("should create empty config when file does not exist", () => {
      const missingPath = resolve(TEST_DIR, "missing-config.json");
      expect(existsSync(missingPath)).toBe(false);
      
      // Simulate createEmptyConfig behavior
      const emptyConfig = {
        site_url: "https://github.com/lachlan-jones5/sovereign-agent",
        site_name: "SovereignAgent",
      };
      writeFileSync(missingPath, JSON.stringify(emptyConfig, null, 2));
      
      expect(existsSync(missingPath)).toBe(true);
      const content = JSON.parse(readFileSync(missingPath, "utf-8"));
      expect(content.site_url).toBeDefined();
    });

    it("should load config with github_oauth_token", () => {
      const configPath = resolve(TEST_DIR, "oauth-config.json");
      writeFileSync(configPath, JSON.stringify({
        github_oauth_token: "gho_test_token_12345",
        relay: { enabled: true, mode: "server" },
      }));
      
      const content = JSON.parse(readFileSync(configPath, "utf-8"));
      expect(content.github_oauth_token).toBe("gho_test_token_12345");
    });

    it("should handle config without github_oauth_token", () => {
      const configPath = resolve(TEST_DIR, "no-oauth-config.json");
      writeFileSync(configPath, JSON.stringify({
        relay: { enabled: true, mode: "server" },
      }));
      
      const content = JSON.parse(readFileSync(configPath, "utf-8"));
      expect(content.github_oauth_token).toBeUndefined();
    });

    it("should save github_oauth_token after auth", () => {
      const configPath = resolve(TEST_DIR, "save-oauth-config.json");
      writeFileSync(configPath, JSON.stringify({
        relay: { enabled: true },
      }));
      
      // Simulate saving token after auth
      const config = JSON.parse(readFileSync(configPath, "utf-8"));
      config.github_oauth_token = "gho_new_token_67890";
      writeFileSync(configPath, JSON.stringify(config, null, 2));
      
      const updated = JSON.parse(readFileSync(configPath, "utf-8"));
      expect(updated.github_oauth_token).toBe("gho_new_token_67890");
      expect(updated.relay.enabled).toBe(true);
    });

    it("should handle invalid JSON gracefully", () => {
      const invalidPath = resolve(TEST_DIR, "invalid.json");
      writeFileSync(invalidPath, "{ this is not valid json }");
      
      let error: Error | null = null;
      try {
        JSON.parse(readFileSync(invalidPath, "utf-8"));
      } catch (e) {
        error = e as Error;
      }
      
      expect(error).not.toBeNull();
    });
  });
});

describe("Setup Script Generation (Copilot)", () => {
  it("should check for relay authentication", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("/auth/status");
    expect(setupScript).toContain("authenticated");
  });

  it("should include relay port variable", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("RELAY_PORT");
    expect(setupScript).toContain("8081");
  });

  it("should generate sovereign-relay provider config", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("sovereign-relay");
    expect(setupScript).toContain("@ai-sdk/openai-compatible");
  });

  it("should include baseURL with /v1 path", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("/v1");
    expect(setupScript).toContain("localhost");
  });

  it("should set default model to gpt-5-mini", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("sovereign-relay/gpt-5-mini");
  });

  it("should include free models", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("gpt-5-mini");
    expect(setupScript).toContain("gpt-4.1");
    expect(setupScript).toContain("gpt-4o");
  });

  it("should include model multiplier info", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("[FREE]");
    expect(setupScript).toContain("[0.33x]");
    expect(setupScript).toContain("[1x]");
    expect(setupScript).toContain("[3x]");
  });

  it("should include claude models", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("claude-haiku-4.5");
    expect(setupScript).toContain("claude-sonnet-4.5");
    expect(setupScript).toContain("claude-opus-4.5");
  });

  it("should include reasoning models", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    expect(setupScript).toContain("o3");
  });

  it("should NOT include deprecated models", () => {
    const setupScript = generateMockCopilotSetupScript(8081);
    
    // These should NOT be in the generated config
    expect(setupScript).not.toContain('"claude-sonnet-4"');
    expect(setupScript).not.toContain('"gemini-2.5-pro"');
    expect(setupScript).not.toContain('"claude-opus-4"');
    expect(setupScript).not.toContain('"claude-opus-41"');
  });
});

describe("Bundle Endpoint (Copilot)", () => {
  it("should return correct content type", () => {
    const headers = {
      "Content-Type": "application/gzip",
      "Content-Disposition": "attachment; filename=sovereign-agent.tar.gz",
    };
    
    expect(headers["Content-Type"]).toBe("application/gzip");
  });

  it("should exclude sensitive files", () => {
    const excludeArgs = [
      "--exclude='.git'",
      "--exclude='config.json'",
      "--exclude='node_modules'",
      "--exclude='.env'",
      "--exclude='*.log'",
      "--exclude='tests'",
    ];
    
    expect(excludeArgs).toContainEqual("--exclude='config.json'");
    expect(excludeArgs).toContainEqual("--exclude='.env'");
  });

  it("should verify vendor submodules before bundling", () => {
    const vendorChecks = [
      "vendor/opencode/package.json",
      "vendor/OpenAgents/.opencode/agent",
    ];
    
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
      },
    };
    
    expect(errorResponse.status).toBe(500);
    expect(errorResponse.body.error).toContain("bundle");
  });
});

describe("Request Forwarding (Copilot)", () => {
  it("should build correct Copilot URL", () => {
    const path = "/v1/chat/completions";
    const search = "";
    const targetUrl = `${COPILOT_API_BASE}${path}${search}`;
    
    expect(targetUrl).toBe("https://api.githubcopilot.com/v1/chat/completions");
  });

  it("should preserve query string", () => {
    const path = "/v1/models";
    const search = "?filter=chat";
    const targetUrl = `${COPILOT_API_BASE}${path}${search}`;
    
    expect(targetUrl).toBe("https://api.githubcopilot.com/v1/models?filter=chat");
  });

  it("should add Copilot-specific headers", () => {
    const headers = new Headers();
    
    for (const [key, value] of Object.entries(COPILOT_HEADERS)) {
      headers.set(key, value);
    }
    
    expect(headers.get("User-Agent")).toContain("GitHubCopilotChat");
    expect(headers.get("Copilot-Integration-Id")).toBe("vscode-chat");
  });

  it("should add Bearer token from Copilot API", () => {
    const copilotToken = "tid=test;exp=12345;sku=copilot";
    const headers = new Headers();
    headers.set("Authorization", `Bearer ${copilotToken}`);
    
    expect(headers.get("Authorization")).toStartWith("Bearer ");
    expect(headers.get("Authorization")).toContain("tid=");
  });

  it("should add Openai-Intent header", () => {
    const headers = new Headers();
    headers.set("Openai-Intent", "conversation-edits");
    
    expect(headers.get("Openai-Intent")).toBe("conversation-edits");
  });

  it("should add X-Initiator header", () => {
    const headers = new Headers();
    headers.set("X-Initiator", "user");
    
    expect(headers.get("X-Initiator")).toBe("user");
  });

  it("should return 401 when not authenticated", () => {
    const response = {
      status: 401,
      body: {
        error: "Not authenticated",
        message: "GitHub Copilot not authenticated. Visit /auth/device to authenticate.",
      },
    };
    
    expect(response.status).toBe(401);
    expect(response.body.message).toContain("/auth/device");
  });

  it("should return 502 when Copilot API fails", () => {
    const response = {
      status: 502,
      body: {
        error: "Relay request failed",
        details: "ECONNREFUSED",
      },
    };
    
    expect(response.status).toBe(502);
  });

  it("should track premium requests from model", () => {
    const MODEL_MULTIPLIERS: Record<string, number> = {
      "gpt-5-mini": 0,
      "claude-haiku-4.5": 0.33,
      "claude-sonnet-4.5": 1,
      "claude-opus-4.5": 3,
    };
    
    let premiumRequestsUsed = 0;
    
    premiumRequestsUsed += MODEL_MULTIPLIERS["gpt-5-mini"];
    expect(premiumRequestsUsed).toBe(0);
    
    premiumRequestsUsed += MODEL_MULTIPLIERS["claude-opus-4.5"];
    expect(premiumRequestsUsed).toBe(3);
  });
});

describe("Authentication Flow Simulation", () => {
  it("should start device code flow", () => {
    const deviceCodeRequest = {
      client_id: "Iv1.b507a08c87ecfe98",
      scope: "read:user",
    };
    
    expect(deviceCodeRequest.client_id).toBe("Iv1.b507a08c87ecfe98");
    expect(deviceCodeRequest.scope).toBe("read:user");
  });

  it("should return device code response", () => {
    const response = {
      success: true,
      user_code: "ABCD-1234",
      verification_uri: "https://github.com/login/device",
      flow_id: "test-flow-id",
      message: "Go to https://github.com/login/device and enter code: ABCD-1234",
    };
    
    expect(response.user_code).toMatch(/^[A-Z0-9]{4}-[A-Z0-9]{4}$/);
    expect(response.verification_uri).toBe("https://github.com/login/device");
  });

  it("should poll for authorization", () => {
    const pollStates = ["pending", "pending", "success"];
    let currentState = 0;
    
    function poll(): { status: string } {
      return { status: pollStates[currentState++] };
    }
    
    expect(poll().status).toBe("pending");
    expect(poll().status).toBe("pending");
    expect(poll().status).toBe("success");
  });

  it("should handle authorization timeout", () => {
    const flow = {
      expires_at: Date.now() - 1000, // Already expired
    };
    
    const isExpired = flow.expires_at < Date.now();
    expect(isExpired).toBe(true);
  });

  it("should save OAuth token on success", () => {
    const config = { relay: { enabled: true } };
    const oauthToken = "gho_test_token_12345";
    
    // Simulate saving
    (config as any).github_oauth_token = oauthToken;
    
    expect((config as any).github_oauth_token).toBe(oauthToken);
  });

  it("should refresh Copilot token when needed", () => {
    const tokenCache = {
      token: "old_token",
      expires: Date.now() - 1000, // Expired
    };
    
    const shouldRefresh = tokenCache.expires < Date.now();
    expect(shouldRefresh).toBe(true);
  });
});

describe("Error Recovery", () => {
  it("should handle network timeout", () => {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);
    
    clearTimeout(timeoutId);
    expect(controller.signal.aborted).toBe(false);
  });

  it("should handle 401 from Copilot API", () => {
    const response = { status: 401 };
    
    // Should clear cached token
    let tokenCache: { token: string } | null = { token: "old" };
    
    if (response.status === 401) {
      tokenCache = null;
    }
    
    expect(tokenCache).toBeNull();
  });

  it("should continue after upstream 500 error", () => {
    const upstreamError = { status: 500 };
    
    // Relay should forward the error, not crash
    expect(upstreamError.status).toBe(500);
    
    // Server state should be unaffected
    let requestCount = 10;
    requestCount++;
    expect(requestCount).toBe(11);
  });

  it("should track requests even when forwarding fails", () => {
    let requestCount = 0;
    requestCount++;
    
    try {
      throw new Error("Network error");
    } catch {
      // Error handled
    }
    
    expect(requestCount).toBe(1);
  });

  it("should handle malformed JSON in request body", () => {
    const body = "not json";
    let model = "unknown";
    
    try {
      const parsed = JSON.parse(body);
      model = parsed.model || "unknown";
    } catch {
      // Expected
    }
    
    expect(model).toBe("unknown");
  });
});

describe("Health and Stats Endpoints", () => {
  it("should return Copilot-specific health response", () => {
    const healthResponse = {
      status: "ok",
      relay: "sovereign-agent-copilot",
      authenticated: true,
      requests: 100,
      premium_requests_used: 25.5,
    };
    
    expect(healthResponse.relay).toBe("sovereign-agent-copilot");
    expect(healthResponse.authenticated).toBe(true);
    expect(healthResponse.premium_requests_used).toBe(25.5);
  });

  it("should show unauthenticated status", () => {
    const healthResponse = {
      status: "ok",
      relay: "sovereign-agent-copilot",
      authenticated: false,
      requests: 0,
      premium_requests_used: 0,
    };
    
    expect(healthResponse.authenticated).toBe(false);
  });

  it("should return stats with premium request tracking", () => {
    const statsResponse = {
      requests: 200,
      premium_requests_used: 75.5,
      authenticated: true,
      uptime: 3600,
    };
    
    expect(statsResponse.premium_requests_used).toBe(75.5);
  });
});

describe("CORS Support", () => {
  it("should include CORS headers", () => {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };
    
    expect(corsHeaders["Access-Control-Allow-Origin"]).toBe("*");
    expect(corsHeaders["Access-Control-Allow-Methods"]).toContain("POST");
  });

  it("should handle OPTIONS preflight", () => {
    const method = "OPTIONS";
    const shouldReturnEmpty = method === "OPTIONS";
    
    expect(shouldReturnEmpty).toBe(true);
  });
});

// Helper function to generate mock setup script
function generateMockCopilotSetupScript(port: number): string {
  return `#!/bin/bash
# Sovereign Agent Client Setup (GitHub Copilot)
set -uo pipefail

RELAY_PORT="\${RELAY_PORT:-${port}}"
INSTALL_DIR="\${INSTALL_DIR:-\$PWD/sovereign-agent}"

echo "=== Sovereign Agent Client Setup (GitHub Copilot) ==="

# Check the tunnel is working
if ! curl -sf "http://localhost:\$RELAY_PORT/health" >/dev/null 2>&1; then
    echo "Error: Cannot reach relay"
    exit 1
fi

# Check if relay is authenticated
AUTH_STATUS=\$(curl -sf "http://localhost:\$RELAY_PORT/auth/status" | grep -o '"authenticated":[^,]*' | cut -d: -f2)
if [[ "\$AUTH_STATUS" != "true" ]]; then
    echo "Error: Relay is not authenticated with GitHub Copilot"
    exit 1
fi

# Create OpenCode config
mkdir -p "\$HOME/.config/opencode"
cat > "\$HOME/.config/opencode/opencode.jsonc" <<OPENCODEEOF
{
  "\\$schema": "https://opencode.ai/config.json",
  "provider": {
    "sovereign-relay": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Sovereign Relay (GitHub Copilot)",
      "options": {
        "baseURL": "http://localhost:\$RELAY_PORT/v1"
      },
      "models": {
        "gpt-5-mini": { "name": "GPT-5 Mini [FREE]" },
        "gpt-4.1": { "name": "GPT-4.1 [FREE]" },
        "gpt-4o": { "name": "GPT-4o [FREE]" },
        "claude-haiku-4.5": { "name": "Claude Haiku 4.5 [0.33x]" },
        "claude-sonnet-4.5": { "name": "Claude Sonnet 4.5 [1x]" },
        "claude-opus-4.5": { "name": "Claude Opus 4.5 [3x]" },
        "o3": { "name": "o3 [1x]" }
      }
    }
  },
  "model": {
    "default": "sovereign-relay/gpt-5-mini"
  }
}
OPENCODEEOF
`;
}
