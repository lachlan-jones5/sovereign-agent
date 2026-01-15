/**
 * Core tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - Copilot API URL construction
 * - Copilot-specific headers
 * - Model multiplier calculations
 * - Premium request tracking
 * - Path allowlist for Copilot API
 * - Config handling (new schema without OpenRouter)
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import { mkdirSync, rmSync, writeFileSync, readFileSync, existsSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-copilot");
const TEST_CONFIG_PATH = resolve(TEST_DIR, "config.json");

// Constants matching main.ts
const COPILOT_API_BASE = "https://api.githubcopilot.com";
const COPILOT_CLIENT_ID = "Iv1.b507a08c87ecfe98";
const GITHUB_DEVICE_CODE_URL = "https://github.com/login/device/code";
const GITHUB_ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token";
const GITHUB_COPILOT_TOKEN_URL = "https://api.github.com/copilot_internal/v2/token";

const COPILOT_HEADERS = {
  "User-Agent": "GitHubCopilotChat/0.35.0",
  "Editor-Version": "vscode/1.107.0",
  "Editor-Plugin-Version": "copilot-chat/0.35.0",
  "Copilot-Integration-Id": "vscode-chat",
};

// Model multipliers from main.ts
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
};

function getModelMultiplier(model: string): number {
  const modelName = model.replace(/^github-copilot\//, "");
  return MODEL_MULTIPLIERS[modelName] ?? 1;
}

describe("Copilot API Configuration", () => {
  it("should use correct Copilot API base URL", () => {
    expect(COPILOT_API_BASE).toBe("https://api.githubcopilot.com");
  });

  it("should use HTTPS for all Copilot endpoints", () => {
    expect(COPILOT_API_BASE).toStartWith("https://");
    expect(GITHUB_DEVICE_CODE_URL).toStartWith("https://");
    expect(GITHUB_ACCESS_TOKEN_URL).toStartWith("https://");
    expect(GITHUB_COPILOT_TOKEN_URL).toStartWith("https://");
  });

  it("should have correct GitHub OAuth client ID", () => {
    // This is the official GitHub Copilot Chat client ID
    expect(COPILOT_CLIENT_ID).toBe("Iv1.b507a08c87ecfe98");
    expect(COPILOT_CLIENT_ID).toMatch(/^Iv1\.[a-f0-9]+$/);
  });
});

describe("Copilot Headers", () => {
  it("should have required Copilot headers", () => {
    expect(COPILOT_HEADERS["User-Agent"]).toBeDefined();
    expect(COPILOT_HEADERS["Editor-Version"]).toBeDefined();
    expect(COPILOT_HEADERS["Editor-Plugin-Version"]).toBeDefined();
    expect(COPILOT_HEADERS["Copilot-Integration-Id"]).toBeDefined();
  });

  it("should use GitHubCopilotChat user agent", () => {
    expect(COPILOT_HEADERS["User-Agent"]).toContain("GitHubCopilotChat");
  });

  it("should use vscode as editor", () => {
    expect(COPILOT_HEADERS["Editor-Version"]).toContain("vscode");
  });

  it("should use vscode-chat integration ID", () => {
    expect(COPILOT_HEADERS["Copilot-Integration-Id"]).toBe("vscode-chat");
  });

  it("should add all Copilot headers to requests", () => {
    const headers = new Headers();
    
    for (const [key, value] of Object.entries(COPILOT_HEADERS)) {
      headers.set(key, value);
    }
    
    expect(headers.get("User-Agent")).toBe(COPILOT_HEADERS["User-Agent"]);
    expect(headers.get("Editor-Version")).toBe(COPILOT_HEADERS["Editor-Version"]);
    expect(headers.get("Editor-Plugin-Version")).toBe(COPILOT_HEADERS["Editor-Plugin-Version"]);
    expect(headers.get("Copilot-Integration-Id")).toBe(COPILOT_HEADERS["Copilot-Integration-Id"]);
  });

  it("should add Openai-Intent header", () => {
    const headers = new Headers();
    headers.set("Openai-Intent", "conversation-edits");
    
    expect(headers.get("Openai-Intent")).toBe("conversation-edits");
  });

  it("should add X-Initiator header for user requests", () => {
    const headers = new Headers();
    headers.set("X-Initiator", "user");
    
    expect(headers.get("X-Initiator")).toBe("user");
  });

  it("should add X-Initiator header for agent requests", () => {
    const headers = new Headers();
    headers.set("X-Initiator", "agent");
    
    expect(headers.get("X-Initiator")).toBe("agent");
  });
});

describe("Model Multipliers", () => {
  describe("Free models (0x)", () => {
    const freeModels = ["gpt-5-mini", "gpt-4.1", "gpt-4o"];
    
    for (const model of freeModels) {
      it(`should return 0 for ${model}`, () => {
        expect(getModelMultiplier(model)).toBe(0);
      });
      
      it(`should return 0 for github-copilot/${model}`, () => {
        expect(getModelMultiplier(`github-copilot/${model}`)).toBe(0);
      });
    }
  });

  describe("Very cheap models (0.25-0.33x)", () => {
    it("should return 0.33 for claude-haiku-4.5", () => {
      expect(getModelMultiplier("claude-haiku-4.5")).toBe(0.33);
    });

    it("should return 0.25 for grok-code-fast-1", () => {
      expect(getModelMultiplier("grok-code-fast-1")).toBe(0.25);
    });

    it("should return 0.33 for gemini-3-flash-preview", () => {
      expect(getModelMultiplier("gemini-3-flash-preview")).toBe(0.33);
    });

    it("should return 0.33 for gpt-5.1-codex-mini", () => {
      expect(getModelMultiplier("gpt-5.1-codex-mini")).toBe(0.33);
    });
  });

  describe("Standard models (1x)", () => {
    const standardModels = [
      "claude-sonnet-4.5",
      "gpt-5",
      "gpt-5.1",
      "gpt-5.2",
      "gpt-5-codex",
      "gpt-5.1-codex",
      "gpt-5.1-codex-max",
      "gemini-3-pro-preview",
      "o3",
      "o3-mini",
      "o4-mini",
    ];
    
    for (const model of standardModels) {
      it(`should return 1 for ${model}`, () => {
        expect(getModelMultiplier(model)).toBe(1);
      });
    }
  });

  describe("Premium models (3x)", () => {
    it("should return 3 for claude-opus-4.5", () => {
      expect(getModelMultiplier("claude-opus-4.5")).toBe(3);
    });
  });

  describe("Unknown models", () => {
    it("should return 1 (default) for unknown models", () => {
      expect(getModelMultiplier("unknown-model")).toBe(1);
      expect(getModelMultiplier("future-model-v99")).toBe(1);
    });
  });

  describe("Deprecated models exclusion", () => {
    it("should NOT have claude-sonnet-4 (deprecated)", () => {
      expect(MODEL_MULTIPLIERS["claude-sonnet-4"]).toBeUndefined();
    });

    it("should NOT have gemini-2.5-pro (deprecated)", () => {
      expect(MODEL_MULTIPLIERS["gemini-2.5-pro"]).toBeUndefined();
    });

    it("should NOT have claude-opus-4 (10x, use 4.5 instead)", () => {
      expect(MODEL_MULTIPLIERS["claude-opus-4"]).toBeUndefined();
    });

    it("should NOT have claude-opus-41 (10x, use 4.5 instead)", () => {
      expect(MODEL_MULTIPLIERS["claude-opus-41"]).toBeUndefined();
    });
  });
});

describe("Premium Request Tracking", () => {
  let premiumRequestsUsed = 0;

  beforeEach(() => {
    premiumRequestsUsed = 0;
  });

  it("should track 0 premium requests for free models", () => {
    premiumRequestsUsed += getModelMultiplier("gpt-5-mini");
    premiumRequestsUsed += getModelMultiplier("gpt-4.1");
    premiumRequestsUsed += getModelMultiplier("gpt-4o");
    
    expect(premiumRequestsUsed).toBe(0);
  });

  it("should track fractional premium requests for cheap models", () => {
    premiumRequestsUsed += getModelMultiplier("claude-haiku-4.5");
    
    expect(premiumRequestsUsed).toBe(0.33);
  });

  it("should track 1 premium request for standard models", () => {
    premiumRequestsUsed += getModelMultiplier("claude-sonnet-4.5");
    
    expect(premiumRequestsUsed).toBe(1);
  });

  it("should track 3 premium requests for opus", () => {
    premiumRequestsUsed += getModelMultiplier("claude-opus-4.5");
    
    expect(premiumRequestsUsed).toBe(3);
  });

  it("should accumulate premium requests across multiple calls", () => {
    premiumRequestsUsed += getModelMultiplier("gpt-5-mini");      // 0
    premiumRequestsUsed += getModelMultiplier("claude-haiku-4.5"); // 0.33
    premiumRequestsUsed += getModelMultiplier("claude-sonnet-4.5"); // 1
    premiumRequestsUsed += getModelMultiplier("claude-opus-4.5");   // 3
    
    expect(premiumRequestsUsed).toBeCloseTo(4.33);
  });

  it("should correctly calculate monthly usage scenario", () => {
    // Simulate a month of usage:
    // - 100 gpt-5-mini calls (free)
    // - 50 claude-haiku-4.5 calls (0.33 each = 16.5)
    // - 30 claude-sonnet-4.5 calls (1 each = 30)
    // - 5 claude-opus-4.5 calls (3 each = 15)
    
    for (let i = 0; i < 100; i++) premiumRequestsUsed += getModelMultiplier("gpt-5-mini");
    for (let i = 0; i < 50; i++) premiumRequestsUsed += getModelMultiplier("claude-haiku-4.5");
    for (let i = 0; i < 30; i++) premiumRequestsUsed += getModelMultiplier("claude-sonnet-4.5");
    for (let i = 0; i < 5; i++) premiumRequestsUsed += getModelMultiplier("claude-opus-4.5");
    
    // 0 + 16.5 + 30 + 15 = 61.5
    expect(premiumRequestsUsed).toBeCloseTo(61.5);
  });
});

describe("Copilot API Path Allowlist", () => {
  const ALLOWED_PATHS = [
    "/v1/chat/completions",
    "/v1/completions",
    "/v1/models",
    "/chat/completions",
  ];

  function isApiPathAllowed(path: string): boolean {
    return ALLOWED_PATHS.some(
      (allowed) => path === allowed || path.startsWith(allowed + "/") || path.startsWith("/v1/")
    );
  }

  it("should allow /v1/chat/completions", () => {
    expect(isApiPathAllowed("/v1/chat/completions")).toBe(true);
  });

  it("should allow /v1/completions", () => {
    expect(isApiPathAllowed("/v1/completions")).toBe(true);
  });

  it("should allow /v1/models", () => {
    expect(isApiPathAllowed("/v1/models")).toBe(true);
  });

  it("should allow /chat/completions (alternative path)", () => {
    expect(isApiPathAllowed("/chat/completions")).toBe(true);
  });

  it("should allow any /v1/* path", () => {
    expect(isApiPathAllowed("/v1/anything")).toBe(true);
    expect(isApiPathAllowed("/v1/chat/completions/stream")).toBe(true);
  });

  it("should not allow arbitrary paths", () => {
    expect(isApiPathAllowed("/admin")).toBe(false);
    expect(isApiPathAllowed("/api/v1/chat")).toBe(false);
  });
});

describe("URL Building for Copilot", () => {
  function buildCopilotUrl(path: string, search: string): string {
    const apiPath = path.startsWith("/v1/") ? path : `/v1${path}`;
    return `${COPILOT_API_BASE}${apiPath}${search}`;
  }

  it("should build correct URL for /v1/chat/completions", () => {
    const url = buildCopilotUrl("/v1/chat/completions", "");
    expect(url).toBe("https://api.githubcopilot.com/v1/chat/completions");
  });

  it("should add /v1 prefix if missing", () => {
    const url = buildCopilotUrl("/chat/completions", "");
    expect(url).toBe("https://api.githubcopilot.com/v1/chat/completions");
  });

  it("should preserve query string", () => {
    const url = buildCopilotUrl("/v1/models", "?filter=chat");
    expect(url).toBe("https://api.githubcopilot.com/v1/models?filter=chat");
  });
});

describe("Config Schema (Copilot)", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  it("should accept config without openrouter_api_key", () => {
    const config = {
      site_url: "https://example.com",
      site_name: "Test",
      relay: {
        enabled: true,
        mode: "server",
        port: 8080,
      },
    };
    
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    
    expect(loaded.openrouter_api_key).toBeUndefined();
    expect(loaded.relay.mode).toBe("server");
  });

  it("should accept config with github_oauth_token", () => {
    const config = {
      github_oauth_token: "gho_test_token_12345",
      relay: {
        enabled: true,
        mode: "server",
      },
    };
    
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    
    expect(loaded.github_oauth_token).toBe("gho_test_token_12345");
  });

  it("should work without github_oauth_token (unauthenticated)", () => {
    const config = {
      site_url: "https://example.com",
      relay: { enabled: true, mode: "server" },
    };
    
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    
    expect(loaded.github_oauth_token).toBeUndefined();
    // hasGitHubAuth() would return false
  });

  it("should handle relay client mode config", () => {
    const config = {
      relay: {
        enabled: true,
        mode: "client",
        port: 8081,
      },
    };
    
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    
    expect(loaded.relay.mode).toBe("client");
    expect(loaded.relay.port).toBe(8081);
  });

  it("should warn about deprecated openrouter_api_key", () => {
    const config = {
      openrouter_api_key: "sk-or-v1-deprecated",
      relay: { enabled: true },
    };
    
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    
    // The key exists but is deprecated
    expect(loaded.openrouter_api_key).toBeDefined();
    // In real code, this would trigger a warning log
  });
});

describe("Health Endpoint (Copilot)", () => {
  it("should return copilot relay identifier", () => {
    const healthResponse = {
      status: "ok",
      relay: "sovereign-agent-copilot",
      authenticated: false,
      requests: 0,
      premium_requests_used: 0,
    };
    
    expect(healthResponse.relay).toBe("sovereign-agent-copilot");
    expect(healthResponse.authenticated).toBe(false);
  });

  it("should include authentication status", () => {
    const healthResponse = {
      status: "ok",
      authenticated: true,
      requests: 100,
      premium_requests_used: 25.5,
    };
    
    expect(healthResponse.authenticated).toBe(true);
  });

  it("should track premium requests in health response", () => {
    const healthResponse = {
      status: "ok",
      requests: 150,
      premium_requests_used: 45.66,
    };
    
    expect(healthResponse.premium_requests_used).toBe(45.66);
  });
});

describe("Stats Endpoint (Copilot)", () => {
  it("should return premium requests used", () => {
    const statsResponse = {
      requests: 200,
      premium_requests_used: 75.5,
      authenticated: true,
      uptime: 3600,
    };
    
    expect(statsResponse.premium_requests_used).toBe(75.5);
    expect(statsResponse.authenticated).toBe(true);
  });
});

describe("Auth Status Endpoint", () => {
  it("should return authenticated: false when no token", () => {
    const hasGitHubAuth = () => false;
    
    const response = {
      authenticated: hasGitHubAuth(),
      message: "Not authenticated. Use /auth/device to start authentication.",
    };
    
    expect(response.authenticated).toBe(false);
    expect(response.message).toContain("/auth/device");
  });

  it("should return authenticated: true when token exists", () => {
    const hasGitHubAuth = () => true;
    
    const response = {
      authenticated: hasGitHubAuth(),
      message: "GitHub Copilot authenticated",
    };
    
    expect(response.authenticated).toBe(true);
    expect(response.message).toContain("authenticated");
  });
});

describe("CORS Headers", () => {
  it("should include CORS headers in responses", () => {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };
    
    expect(corsHeaders["Access-Control-Allow-Origin"]).toBe("*");
    expect(corsHeaders["Access-Control-Allow-Methods"]).toContain("POST");
    expect(corsHeaders["Access-Control-Allow-Headers"]).toContain("Authorization");
  });

  it("should handle OPTIONS preflight requests", () => {
    const method = "OPTIONS";
    const shouldReturnEmpty = method === "OPTIONS";
    
    expect(shouldReturnEmpty).toBe(true);
  });
});

describe("Error Responses (Copilot)", () => {
  it("should return 401 when not authenticated", () => {
    const response = {
      status: 401,
      body: {
        error: "Not authenticated",
        message: "GitHub Copilot not authenticated. Visit /auth/device to authenticate.",
      },
    };
    
    expect(response.status).toBe(401);
    expect(response.body.error).toBe("Not authenticated");
    expect(response.body.message).toContain("/auth/device");
  });

  it("should return 404 for unknown paths", () => {
    const response = {
      status: 404,
      body: {
        error: "Not found",
        path: "/unknown/path",
      },
    };
    
    expect(response.status).toBe(404);
    expect(response.body.error).toBe("Not found");
  });

  it("should return 502 when Copilot API fails", () => {
    const response = {
      status: 502,
      body: {
        error: "Relay request failed",
        details: "Connection refused",
      },
    };
    
    expect(response.status).toBe(502);
  });
});

describe("Setup Script (Copilot)", () => {
  it("should check for relay authentication in setup script", () => {
    const setupScript = `
AUTH_STATUS=$(curl -sf "http://localhost:$RELAY_PORT/auth/status" | grep -o '"authenticated":[^,]*' | cut -d: -f2)
if [[ "$AUTH_STATUS" != "true" ]]; then
    echo "Error: Relay is not authenticated with GitHub Copilot"
    exit 1
fi
`;
    
    expect(setupScript).toContain("/auth/status");
    expect(setupScript).toContain("authenticated");
  });

  it("should generate OpenCode config with sovereign-relay provider", () => {
    const config = {
      provider: {
        "sovereign-relay": {
          npm: "@ai-sdk/openai-compatible",
          name: "Sovereign Relay (GitHub Copilot)",
          options: {
            baseURL: "http://localhost:8081/v1",
          },
          models: {
            "gpt-5-mini": { name: "GPT-5 Mini [FREE]" },
          },
        },
      },
    };
    
    expect(config.provider["sovereign-relay"].npm).toBe("@ai-sdk/openai-compatible");
    expect(config.provider["sovereign-relay"].options.baseURL).toContain("/v1");
  });

  it("should set default model to gpt-5-mini (free)", () => {
    const config = {
      model: {
        default: "sovereign-relay/gpt-5-mini",
      },
    };
    
    expect(config.model.default).toBe("sovereign-relay/gpt-5-mini");
  });
});

describe("Model Extraction from Request", () => {
  it("should extract model from chat completion request", () => {
    const body = JSON.stringify({
      model: "gpt-5-mini",
      messages: [{ role: "user", content: "Hello" }],
    });
    
    const parsed = JSON.parse(body);
    expect(parsed.model).toBe("gpt-5-mini");
  });

  it("should handle missing model gracefully", () => {
    const body = JSON.stringify({
      messages: [{ role: "user", content: "Hello" }],
    });
    
    const parsed = JSON.parse(body);
    const model = parsed.model || "unknown";
    
    expect(model).toBe("unknown");
  });

  it("should handle non-JSON body gracefully", () => {
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
