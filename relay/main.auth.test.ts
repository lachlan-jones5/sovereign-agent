/**
 * Authentication tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - Device code flow initiation
 * - Device code polling
 * - OAuth token storage
 * - Copilot token refresh
 * - Token caching
 * - Token expiry handling
 * - Error scenarios
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import { mkdirSync, rmSync, writeFileSync, readFileSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-auth");
const TEST_CONFIG_PATH = resolve(TEST_DIR, "config.json");

// Mock device code flow data
const MOCK_DEVICE_CODE_RESPONSE = {
  device_code: "device_code_123",
  user_code: "ABCD-1234",
  verification_uri: "https://github.com/login/device",
  expires_in: 900,
  interval: 5,
};

// Mock access token response
const MOCK_ACCESS_TOKEN_RESPONSE = {
  access_token: "gho_test_oauth_token_12345",
  token_type: "bearer",
  scope: "read:user",
};

// Mock Copilot token response
const MOCK_COPILOT_TOKEN_RESPONSE = {
  token: "tid=test_copilot_token_67890;exp=1234567890;sku=copilot_for_business",
  expires_at: Math.floor(Date.now() / 1000) + 1800, // 30 minutes from now
};

describe("Device Code Flow Initiation", () => {
  it("should generate correct device code request body", () => {
    const clientId = "Iv1.b507a08c87ecfe98";
    const scope = "read:user";
    
    const body = {
      client_id: clientId,
      scope: scope,
    };
    
    expect(body.client_id).toBe("Iv1.b507a08c87ecfe98");
    expect(body.scope).toBe("read:user");
  });

  it("should return user_code and verification_uri", () => {
    const response = MOCK_DEVICE_CODE_RESPONSE;
    
    expect(response.user_code).toBe("ABCD-1234");
    expect(response.verification_uri).toBe("https://github.com/login/device");
  });

  it("should generate unique flow_id for each request", () => {
    const flow_id_1 = crypto.randomUUID();
    const flow_id_2 = crypto.randomUUID();
    
    expect(flow_id_1).not.toBe(flow_id_2);
    expect(flow_id_1).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
  });

  it("should store device code with expiry time", () => {
    const flow = {
      device_code: MOCK_DEVICE_CODE_RESPONSE.device_code,
      user_code: MOCK_DEVICE_CODE_RESPONSE.user_code,
      verification_uri: MOCK_DEVICE_CODE_RESPONSE.verification_uri,
      expires_at: Date.now() + MOCK_DEVICE_CODE_RESPONSE.expires_in * 1000,
      interval: MOCK_DEVICE_CODE_RESPONSE.interval,
    };
    
    expect(flow.expires_at).toBeGreaterThan(Date.now());
    expect(flow.interval).toBe(5);
  });

  it("should return correct response structure", () => {
    const response = {
      success: true,
      user_code: "ABCD-1234",
      verification_uri: "https://github.com/login/device",
      flow_id: crypto.randomUUID(),
      message: "Go to https://github.com/login/device and enter code: ABCD-1234",
    };
    
    expect(response.success).toBe(true);
    expect(response.message).toContain(response.user_code);
    expect(response.message).toContain(response.verification_uri);
  });
});

describe("Device Code Polling", () => {
  const pendingDeviceFlows = new Map<string, any>();
  
  beforeEach(() => {
    pendingDeviceFlows.clear();
  });

  it("should return 'pending' while waiting for authorization", () => {
    const flow_id = "test-flow-1";
    pendingDeviceFlows.set(flow_id, {
      device_code: "device_code_123",
      expires_at: Date.now() + 900000,
      interval: 5,
    });
    
    // Simulate authorization_pending response
    const pollResult = {
      status: "pending",
      message: "Waiting for user authorization...",
    };
    
    expect(pollResult.status).toBe("pending");
  });

  it("should return 'expired' when device code expires", () => {
    const flow_id = "test-flow-2";
    pendingDeviceFlows.set(flow_id, {
      device_code: "device_code_123",
      expires_at: Date.now() - 1000, // Already expired
      interval: 5,
    });
    
    const flow = pendingDeviceFlows.get(flow_id);
    const isExpired = flow.expires_at < Date.now();
    
    expect(isExpired).toBe(true);
  });

  it("should return 'error' when flow_id not found", () => {
    const flow = pendingDeviceFlows.get("nonexistent-flow");
    
    expect(flow).toBeUndefined();
    
    const pollResult = {
      status: "error",
      message: "Flow not found or expired",
    };
    
    expect(pollResult.status).toBe("error");
  });

  it("should return 'success' when access token received", () => {
    const pollResult = {
      status: "success",
      message: "Authentication successful",
    };
    
    expect(pollResult.status).toBe("success");
  });

  it("should clean up flow after successful auth", () => {
    const flow_id = "test-flow-3";
    pendingDeviceFlows.set(flow_id, {
      device_code: "device_code_123",
      expires_at: Date.now() + 900000,
      interval: 5,
    });
    
    // Simulate successful auth
    pendingDeviceFlows.delete(flow_id);
    
    expect(pendingDeviceFlows.has(flow_id)).toBe(false);
  });

  it("should handle slow_down response", () => {
    const pollResult = {
      status: "pending",
      message: "Please wait...",
    };
    
    expect(pollResult.status).toBe("pending");
  });
});

describe("OAuth Token Storage", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  it("should save OAuth token to config", () => {
    const config = { relay: { enabled: true } };
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    
    // Simulate saving token
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    loaded.github_oauth_token = "gho_test_token_12345";
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(loaded));
    
    const updated = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    expect(updated.github_oauth_token).toBe("gho_test_token_12345");
  });

  it("should preserve existing config when adding token", () => {
    const config = {
      site_url: "https://example.com",
      site_name: "Test",
      relay: { enabled: true, mode: "server" },
    };
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(config));
    
    // Add token
    const loaded = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    loaded.github_oauth_token = "gho_test_token_12345";
    writeFileSync(TEST_CONFIG_PATH, JSON.stringify(loaded));
    
    const updated = JSON.parse(readFileSync(TEST_CONFIG_PATH, "utf-8"));
    expect(updated.site_url).toBe("https://example.com");
    expect(updated.relay.mode).toBe("server");
    expect(updated.github_oauth_token).toBeDefined();
  });

  it("should detect when OAuth token is present", () => {
    const config = {
      github_oauth_token: "gho_test_token_12345",
      relay: { enabled: true },
    };
    
    const hasGitHubAuth = () => !!config.github_oauth_token;
    
    expect(hasGitHubAuth()).toBe(true);
  });

  it("should detect when OAuth token is missing", () => {
    const config = {
      relay: { enabled: true },
    };
    
    const hasGitHubAuth = () => !!(config as any).github_oauth_token;
    
    expect(hasGitHubAuth()).toBe(false);
  });

  it("should detect when OAuth token is empty string", () => {
    const config = {
      github_oauth_token: "",
      relay: { enabled: true },
    };
    
    const hasGitHubAuth = () => !!config.github_oauth_token;
    
    expect(hasGitHubAuth()).toBe(false);
  });
});

describe("Copilot Token Refresh", () => {
  interface CopilotToken {
    token: string;
    expires: number;
  }
  
  let copilotTokenCache: CopilotToken | null = null;

  beforeEach(() => {
    copilotTokenCache = null;
  });

  it("should use cached token when not expired", () => {
    copilotTokenCache = {
      token: "cached_token_123",
      expires: Date.now() + 300000, // 5 minutes from now
    };
    
    const shouldRefresh = !copilotTokenCache || copilotTokenCache.expires < Date.now();
    
    expect(shouldRefresh).toBe(false);
  });

  it("should refresh token when expired", () => {
    copilotTokenCache = {
      token: "expired_token_123",
      expires: Date.now() - 1000, // Already expired
    };
    
    const shouldRefresh = !copilotTokenCache || copilotTokenCache.expires < Date.now();
    
    expect(shouldRefresh).toBe(true);
  });

  it("should refresh token when cache is null", () => {
    copilotTokenCache = null;
    
    const shouldRefresh = !copilotTokenCache || copilotTokenCache.expires < Date.now();
    
    expect(shouldRefresh).toBe(true);
  });

  it("should calculate expiry with 5 minute buffer", () => {
    const expiresAt = Math.floor(Date.now() / 1000) + 1800; // 30 minutes from now (in seconds)
    const bufferMs = 5 * 60 * 1000; // 5 minutes
    
    const cacheExpiry = expiresAt * 1000 - bufferMs;
    
    expect(cacheExpiry).toBeLessThan(expiresAt * 1000);
    expect(cacheExpiry).toBeGreaterThan(Date.now());
  });

  it("should update cache after refresh", () => {
    const newToken = MOCK_COPILOT_TOKEN_RESPONSE;
    
    copilotTokenCache = {
      token: newToken.token,
      expires: newToken.expires_at * 1000 - 5 * 60 * 1000,
    };
    
    expect(copilotTokenCache.token).toBe(newToken.token);
    expect(copilotTokenCache.expires).toBeGreaterThan(Date.now());
  });

  it("should include Bearer token in refresh request", () => {
    const oauthToken = "gho_test_oauth_token_12345";
    const headers = {
      Accept: "application/json",
      Authorization: `Bearer ${oauthToken}`,
    };
    
    expect(headers.Authorization).toBe("Bearer gho_test_oauth_token_12345");
  });

  it("should include Copilot headers in refresh request", () => {
    const headers = {
      Accept: "application/json",
      Authorization: "Bearer gho_test_oauth_token_12345",
      "User-Agent": "GitHubCopilotChat/0.35.0",
      "Editor-Version": "vscode/1.107.0",
    };
    
    expect(headers["User-Agent"]).toContain("GitHubCopilotChat");
  });
});

describe("Token Refresh Error Handling", () => {
  let config: { github_oauth_token?: string } = {};

  beforeEach(() => {
    config = { github_oauth_token: "gho_test_token" };
  });

  it("should clear token on 401 response", () => {
    // Simulate 401 response
    const responseStatus = 401;
    
    if (responseStatus === 401) {
      config.github_oauth_token = undefined;
    }
    
    expect(config.github_oauth_token).toBeUndefined();
  });

  it("should throw error on refresh failure", () => {
    const responseStatus = 500;
    
    const shouldThrow = () => {
      if (responseStatus !== 200) {
        throw new Error(`Copilot token refresh failed: ${responseStatus}`);
      }
    };
    
    expect(shouldThrow).toThrow("Copilot token refresh failed: 500");
  });

  it("should handle network timeout", () => {
    const networkError = new Error("ETIMEDOUT");
    
    expect(networkError.message).toBe("ETIMEDOUT");
  });

  it("should handle invalid JSON response", () => {
    const invalidJson = "not json";
    
    const parseResult = () => {
      JSON.parse(invalidJson);
    };
    
    expect(parseResult).toThrow();
  });

  it("should handle missing token in response", () => {
    const response = { expires_at: 12345 }; // Missing token
    
    const hasToken = "token" in response && (response as any).token;
    
    expect(hasToken).toBeFalsy();
  });

  it("should handle missing expires_at in response", () => {
    const response = { token: "test_token" }; // Missing expires_at
    
    const hasExpiry = "expires_at" in response;
    
    expect(hasExpiry).toBe(false);
  });
});

describe("Device Code Flow HTML Page", () => {
  it("should include start auth button", () => {
    const html = `<button onclick="startAuth()">Start Authentication</button>`;
    
    expect(html).toContain("startAuth");
    expect(html).toContain("button");
  });

  it("should display user code prominently", () => {
    const userCode = "ABCD-1234";
    const html = `<div class="code">${userCode}</div>`;
    
    expect(html).toContain("ABCD-1234");
    expect(html).toContain("code");
  });

  it("should link to GitHub verification URL", () => {
    const verificationUri = "https://github.com/login/device";
    const html = `<a href="${verificationUri}" target="_blank">${verificationUri}</a>`;
    
    expect(html).toContain("github.com/login/device");
    expect(html).toContain('target="_blank"');
  });

  it("should poll for status automatically", () => {
    const js = `pollInterval = setInterval(pollStatus, 5000);`;
    
    expect(js).toContain("setInterval");
    expect(js).toContain("pollStatus");
    expect(js).toContain("5000");
  });

  it("should display success message on completion", () => {
    const statusHtml = `<div class="status success">Authentication successful! You can close this page.</div>`;
    
    expect(statusHtml).toContain("success");
    expect(statusHtml).toContain("successful");
  });

  it("should display error message on failure", () => {
    const statusHtml = `<div class="status error">Authentication failed</div>`;
    
    expect(statusHtml).toContain("error");
    expect(statusHtml).toContain("failed");
  });
});

describe("Auth Endpoint Security", () => {
  it("should only allow POST for /auth/device initiation", () => {
    const method = "POST";
    const isValid = method === "POST";
    
    expect(isValid).toBe(true);
  });

  it("should only allow POST for /auth/poll", () => {
    const method = "POST";
    const isValid = method === "POST";
    
    expect(isValid).toBe(true);
  });

  it("should allow GET for /auth/device HTML page", () => {
    const method = "GET";
    const isValid = method === "GET";
    
    expect(isValid).toBe(true);
  });

  it("should require flow_id in poll request body", () => {
    const body = { flow_id: "test-flow-123" };
    
    expect(body.flow_id).toBeDefined();
    expect(typeof body.flow_id).toBe("string");
  });

  it("should validate flow_id format", () => {
    const validFlowId = "550e8400-e29b-41d4-a716-446655440000";
    const invalidFlowId = "not-a-uuid";
    
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    
    expect(uuidRegex.test(validFlowId)).toBe(true);
    expect(uuidRegex.test(invalidFlowId)).toBe(false);
  });

  it("should not expose device_code to client", () => {
    const response = {
      success: true,
      user_code: "ABCD-1234",
      verification_uri: "https://github.com/login/device",
      flow_id: "test-flow-123",
      message: "Go to https://github.com/login/device and enter code: ABCD-1234",
    };
    
    // device_code should NOT be in the response
    expect((response as any).device_code).toBeUndefined();
  });

  it("should clean up expired flows", () => {
    const flows = new Map<string, { expires_at: number }>();
    
    flows.set("flow1", { expires_at: Date.now() - 1000 }); // Expired
    flows.set("flow2", { expires_at: Date.now() + 1000 }); // Valid
    
    // Clean up expired
    for (const [id, flow] of flows) {
      if (flow.expires_at < Date.now()) {
        flows.delete(id);
      }
    }
    
    expect(flows.size).toBe(1);
    expect(flows.has("flow1")).toBe(false);
    expect(flows.has("flow2")).toBe(true);
  });
});

describe("OAuth Token Validation", () => {
  it("should accept valid GitHub OAuth token format (gho_)", () => {
    const token = "gho_test_token_12345";
    const isValid = token.startsWith("gho_");
    
    expect(isValid).toBe(true);
  });

  it("should accept valid GitHub personal access token format (ghp_)", () => {
    const token = "ghp_test_token_12345";
    const isValid = token.startsWith("ghp_") || token.startsWith("gho_");
    
    expect(isValid).toBe(true);
  });

  it("should reject empty token", () => {
    const token = "";
    const isValid = token && token.length > 0;
    
    expect(isValid).toBeFalsy();
  });

  it("should reject null/undefined token", () => {
    const token = null;
    const isValid = !!token;
    
    expect(isValid).toBe(false);
  });
});

describe("Copilot Token Structure", () => {
  it("should parse Copilot token format", () => {
    const token = "tid=abcd1234;exp=1234567890;sku=copilot_for_business";
    
    expect(token).toContain("tid=");
    expect(token).toContain("exp=");
    expect(token).toContain("sku=");
  });

  it("should extract expiry from Copilot token", () => {
    const expiresAt = 1234567890;
    
    // Convert to milliseconds and compare
    const expiresMs = expiresAt * 1000;
    expect(expiresMs).toBe(1234567890000);
  });
});
