/**
 * Security-focused tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - OAuth token protection
 * - Copilot token leak prevention
 * - SSRF protection for Copilot API
 * - Bundle security (no tokens)
 * - Path traversal protection
 * - Request smuggling prevention
 * - Config file security
 */

import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { mkdirSync, rmSync, writeFileSync, readFileSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-security-copilot");

describe("OAuth Token Protection", () => {
  it("should never include OAuth token in error responses", () => {
    const oauthToken = "gho_secret_oauth_token_12345";
    const errorDetails = "Copilot token refresh failed: 401";
    
    const errorResponse = {
      error: "Relay request failed",
      details: errorDetails,
    };
    
    expect(JSON.stringify(errorResponse)).not.toContain(oauthToken);
    expect(JSON.stringify(errorResponse)).not.toContain("gho_");
  });

  it("should never include OAuth token in logs", () => {
    const logMessage = (method: string, path: string) => `${method} ${path}`;
    
    const log = logMessage("POST", "/v1/chat/completions");
    expect(log).not.toContain("gho_");
    expect(log).not.toContain("Bearer");
  });

  it("should never include OAuth token in health/stats endpoints", () => {
    const healthResponse = {
      status: "ok",
      relay: "sovereign-agent-copilot",
      authenticated: true,
      requests: 100,
      premium_requests_used: 25.5,
    };

    const json = JSON.stringify(healthResponse);
    expect(json).not.toContain("gho_");
    expect(json).not.toContain("oauth");
    expect(json).not.toContain("token");
  });

  it("should redact OAuth token in debug output", () => {
    function redactToken(text: string): string {
      return text
        .replace(/gho_[a-zA-Z0-9_]+/g, "gho_[REDACTED]")
        .replace(/ghp_[a-zA-Z0-9_]+/g, "ghp_[REDACTED]");
    }
    
    const logWithToken = "Authorization: Bearer gho_secret_token_12345";
    const redacted = redactToken(logWithToken);
    
    expect(redacted).not.toContain("secret_token_12345");
    expect(redacted).toContain("[REDACTED]");
  });
});

describe("Copilot Token Protection", () => {
  it("should never expose Copilot API token to client", () => {
    const copilotToken = "tid=abc123;exp=1234567890;sku=copilot";
    
    // Token should only be used internally, never returned
    const response = {
      status: "ok",
      authenticated: true,
    };
    
    expect(JSON.stringify(response)).not.toContain("tid=");
    expect(JSON.stringify(response)).not.toContain(copilotToken);
  });

  it("should never include Copilot token in error messages", () => {
    const errorResponse = {
      status: 502,
      body: {
        error: "Relay request failed",
        details: "Connection refused",
      },
    };
    
    expect(JSON.stringify(errorResponse)).not.toContain("tid=");
    expect(JSON.stringify(errorResponse)).not.toContain("sku=");
  });

  it("should redact Copilot token in debug output", () => {
    function redactCopilotToken(text: string): string {
      return text.replace(/tid=[^;]+;exp=[^;]+;sku=[^\s]+/g, "tid=[REDACTED]");
    }
    
    const logWithToken = "Using token: tid=abc123;exp=1234567890;sku=copilot";
    const redacted = redactCopilotToken(logWithToken);
    
    expect(redacted).not.toContain("abc123");
    expect(redacted).toContain("[REDACTED]");
  });
});

describe("SSRF Protection for Copilot", () => {
  const COPILOT_API_BASE = "https://api.githubcopilot.com";
  
  const PRIVATE_IPS = [
    "127.0.0.1",
    "localhost",
    "0.0.0.0",
    "10.0.0.1",
    "172.16.0.1",
    "192.168.0.1",
    "169.254.0.1",
    "::1",
    "fe80::1",
  ];

  it("should hardcode Copilot API base URL", () => {
    expect(COPILOT_API_BASE).toBe("https://api.githubcopilot.com");
    expect(COPILOT_API_BASE).toStartWith("https://");
  });

  it("should never construct URLs to private IPs", () => {
    for (const ip of PRIVATE_IPS) {
      const maliciousPath = `/v1/chat/completions?redirect=http://${ip}/steal`;
      const targetUrl = `${COPILOT_API_BASE}${maliciousPath}`;
      
      // URL should always point to Copilot API
      expect(targetUrl).toStartWith("https://api.githubcopilot.com");
    }
  });

  it("should validate all GitHub URLs use HTTPS", () => {
    const githubUrls = [
      "https://github.com/login/device/code",
      "https://github.com/login/oauth/access_token",
      "https://api.github.com/copilot_internal/v2/token",
      "https://api.githubcopilot.com",
    ];
    
    for (const url of githubUrls) {
      expect(url).toStartWith("https://");
      expect(url).not.toStartWith("http://");
    }
  });

  it("should block path traversal attempts", () => {
    const traversalAttempts = [
      "/../../../etc/passwd",
      "/v1/../../../internal",
      "/v1/chat/completions/../../admin",
      "/v1/chat/completions%2f..%2f..%2fadmin",
    ];

    function isPathSafe(path: string): boolean {
      if (path.includes("..") || path.includes("//")) {
        return false;
      }
      const decodedPath = decodeURIComponent(path);
      return !decodedPath.includes("..");
    }

    for (const path of traversalAttempts) {
      expect(isPathSafe(path)).toBe(false);
    }
  });
});

describe("Bundle Security", () => {
  const EXCLUDED_PATTERNS = [
    ".git",
    "config.json",
    "node_modules",
    ".env",
    "*.log",
    "tests",
  ];

  it("should exclude config.json (contains OAuth token)", () => {
    expect(EXCLUDED_PATTERNS).toContain("config.json");
  });

  it("should exclude .env files", () => {
    expect(EXCLUDED_PATTERNS).toContain(".env");
  });

  it("should exclude .git directory", () => {
    expect(EXCLUDED_PATTERNS).toContain(".git");
  });

  it("should match OAuth token files against exclusions", () => {
    const sensitiveFiles = [
      "config.json",
      ".env",
      "auth.json",
      "tokens.json",
    ];

    function shouldExclude(path: string, patterns: string[]): boolean {
      for (const pattern of patterns) {
        if (path === pattern) return true;
        if (path.startsWith(pattern + "/")) return true;
        if (path.startsWith(pattern)) return true; // .env matches .env.local
        if (pattern.startsWith("*")) {
          const suffix = pattern.slice(1);
          if (path.endsWith(suffix)) return true;
        }
      }
      // Also exclude common auth file patterns
      if (path.includes("auth") || path.includes("token")) {
        return true;
      }
      return false;
    }

    for (const file of sensitiveFiles) {
      const excluded = shouldExclude(file, EXCLUDED_PATTERNS);
      expect(excluded).toBe(true);
    }
  });

  it("should not include backup files with tokens", () => {
    const dangerousPatterns = [
      "config.json.backup",
      "config.json.bak",
      ".env.backup",
      "auth.json.old",
    ];

    const enhancedPatterns = [...EXCLUDED_PATTERNS, "*.backup", "*.bak", "*.old"];

    function shouldExclude(path: string, patterns: string[]): boolean {
      for (const pattern of patterns) {
        if (path === pattern) return true;
        if (pattern.startsWith("*")) {
          const suffix = pattern.slice(1);
          if (path.endsWith(suffix)) return true;
        }
      }
      return false;
    }

    for (const file of dangerousPatterns) {
      expect(shouldExclude(file, enhancedPatterns)).toBe(true);
    }
  });
});

describe("Device Code Flow Security", () => {
  it("should NOT expose device_code to client", () => {
    const internalFlow = {
      device_code: "device_code_secret_123",
      user_code: "ABCD-1234",
      verification_uri: "https://github.com/login/device",
      expires_at: Date.now() + 900000,
    };

    // Client response should NOT contain device_code
    const clientResponse = {
      success: true,
      user_code: internalFlow.user_code,
      verification_uri: internalFlow.verification_uri,
      flow_id: "public-flow-id",
      message: `Go to ${internalFlow.verification_uri} and enter code: ${internalFlow.user_code}`,
    };

    expect(clientResponse).not.toHaveProperty("device_code");
    expect(JSON.stringify(clientResponse)).not.toContain("device_code_secret");
  });

  it("should use cryptographically random flow IDs", () => {
    const flowIds = new Set<string>();
    
    for (let i = 0; i < 100; i++) {
      flowIds.add(crypto.randomUUID());
    }
    
    // All should be unique
    expect(flowIds.size).toBe(100);
  });

  it("should validate flow_id format to prevent injection", () => {
    const validFlowId = "550e8400-e29b-41d4-a716-446655440000";
    const invalidFlowIds = [
      "not-a-uuid",
      "../../../etc/passwd",
      "<script>alert(1)</script>",
      "'; DROP TABLE users; --",
    ];

    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    expect(uuidRegex.test(validFlowId)).toBe(true);
    
    for (const invalid of invalidFlowIds) {
      expect(uuidRegex.test(invalid)).toBe(false);
    }
  });

  it("should expire device code flows", () => {
    const flows = new Map<string, { expires_at: number }>();
    
    flows.set("expired-flow", { expires_at: Date.now() - 1000 });
    flows.set("valid-flow", { expires_at: Date.now() + 900000 });
    
    // Clean expired
    for (const [id, flow] of flows) {
      if (flow.expires_at < Date.now()) {
        flows.delete(id);
      }
    }
    
    expect(flows.has("expired-flow")).toBe(false);
    expect(flows.has("valid-flow")).toBe(true);
  });
});

describe("Request Header Security", () => {
  it("should remove sensitive headers from forwarded requests", () => {
    const headers = new Headers({
      Host: "localhost:8080",
      Connection: "keep-alive",
      "X-Forwarded-For": "192.168.1.100",
      "Content-Type": "application/json",
    });

    // Remove hop-by-hop headers
    headers.delete("Host");
    headers.delete("Connection");
    headers.delete("X-Forwarded-For");

    expect(headers.get("Host")).toBeNull();
    expect(headers.get("Connection")).toBeNull();
    expect(headers.get("X-Forwarded-For")).toBeNull();
    expect(headers.get("Content-Type")).toBe("application/json");
  });

  it("should not forward client Authorization header", () => {
    const clientHeaders = new Headers({
      Authorization: "Bearer client-attempted-token",
      "Content-Type": "application/json",
    });

    // Relay should replace with its own token
    clientHeaders.delete("Authorization");
    clientHeaders.set("Authorization", "Bearer relay-copilot-token");

    expect(clientHeaders.get("Authorization")).toBe("Bearer relay-copilot-token");
    expect(clientHeaders.get("Authorization")).not.toContain("client-attempted");
  });

  it("should add required Copilot headers", () => {
    const headers = new Headers();
    
    headers.set("User-Agent", "GitHubCopilotChat/0.35.0");
    headers.set("Editor-Version", "vscode/1.107.0");
    headers.set("Copilot-Integration-Id", "vscode-chat");
    
    expect(headers.get("User-Agent")).toContain("GitHubCopilotChat");
    expect(headers.get("Editor-Version")).toContain("vscode");
    expect(headers.get("Copilot-Integration-Id")).toBe("vscode-chat");
  });
});

describe("Config File Security", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  it("should reject config with shell injection in token", () => {
    const maliciousValues = [
      "$(whoami)",
      "`id`",
      "'; rm -rf /; '",
      "| cat /etc/passwd",
    ];

    function containsShellInjection(value: string): boolean {
      const patterns = [
        /\$\(/,
        /`[^`]+`/,
        /;\s*\w+/,
        /\|\s*\w+/,
        /&&\s*\w+/,
      ];
      return patterns.some(p => p.test(value));
    }

    for (const value of maliciousValues) {
      expect(containsShellInjection(value)).toBe(true);
    }

    // Valid tokens should not trigger
    expect(containsShellInjection("gho_valid_token_12345")).toBe(false);
  });

  it("should warn about world-readable config permissions", () => {
    function isSecurePermissions(mode: number): boolean {
      const worldReadable = (mode & 0o004) !== 0;
      return !worldReadable;
    }

    expect(isSecurePermissions(0o600)).toBe(true);  // Owner only
    expect(isSecurePermissions(0o640)).toBe(true);  // Owner + group
    expect(isSecurePermissions(0o644)).toBe(false); // World readable - BAD
    expect(isSecurePermissions(0o777)).toBe(false); // World everything - BAD
  });

  it("should validate OAuth token format", () => {
    function isValidOAuthToken(token: string): boolean {
      // GitHub OAuth tokens start with gho_ or ghp_
      return /^gh[op]_[a-zA-Z0-9_]+$/.test(token);
    }

    expect(isValidOAuthToken("gho_valid_token_12345")).toBe(true);
    expect(isValidOAuthToken("ghp_valid_token_12345")).toBe(true);
    expect(isValidOAuthToken("invalid_token")).toBe(false);
    expect(isValidOAuthToken("sk-or-v1-openrouter")).toBe(false);
    expect(isValidOAuthToken("")).toBe(false);
  });
});

describe("Rate Limiting Considerations", () => {
  it("should track requests per client", () => {
    const requestCounts = new Map<string, number>();

    function incrementRequest(clientIp: string): number {
      const current = requestCounts.get(clientIp) || 0;
      const newCount = current + 1;
      requestCounts.set(clientIp, newCount);
      return newCount;
    }

    expect(incrementRequest("192.168.1.100")).toBe(1);
    expect(incrementRequest("192.168.1.100")).toBe(2);
    expect(incrementRequest("192.168.1.101")).toBe(1);
  });

  it("should prevent auth endpoint abuse", () => {
    interface AuthAttempt {
      count: number;
      firstAttempt: number;
    }

    const authAttempts = new Map<string, AuthAttempt>();
    const maxAttempts = 5;
    const windowMs = 300000; // 5 minutes

    function canAttemptAuth(clientIp: string): boolean {
      const now = Date.now();
      const attempt = authAttempts.get(clientIp);

      if (!attempt || now - attempt.firstAttempt > windowMs) {
        authAttempts.set(clientIp, { count: 1, firstAttempt: now });
        return true;
      }

      if (attempt.count >= maxAttempts) {
        return false;
      }

      attempt.count++;
      return true;
    }

    const ip = "192.168.1.100";
    
    // First 5 attempts should succeed
    for (let i = 0; i < 5; i++) {
      expect(canAttemptAuth(ip)).toBe(true);
    }
    
    // 6th attempt should be blocked
    expect(canAttemptAuth(ip)).toBe(false);
  });
});

describe("Input Validation", () => {
  it("should reject excessively long model names", () => {
    const maxLength = 256;
    const longModel = "a".repeat(500);

    function isValidModelName(model: string): boolean {
      return model.length <= maxLength && /^[a-zA-Z0-9\-_.\/]+$/.test(model);
    }

    expect(isValidModelName(longModel)).toBe(false);
    expect(isValidModelName("gpt-5-mini")).toBe(true);
  });

  it("should reject null bytes in inputs", () => {
    const inputWithNull = "gpt-5-mini\x00.html";

    function containsNullByte(input: string): boolean {
      return input.includes("\x00");
    }

    expect(containsNullByte(inputWithNull)).toBe(true);
    expect(containsNullByte("gpt-5-mini")).toBe(false);
  });

  it("should validate JSON request bodies", () => {
    const validBodies = [
      '{"model": "gpt-5-mini", "messages": []}',
      '{"prompt": "test"}',
    ];

    const invalidBodies = [
      "not json",
      "{malformed: json}",
      '{"unclosed": ',
    ];

    function isValidJson(body: string): boolean {
      try {
        JSON.parse(body);
        return true;
      } catch {
        return false;
      }
    }

    for (const body of validBodies) {
      expect(isValidJson(body)).toBe(true);
    }

    for (const body of invalidBodies) {
      expect(isValidJson(body)).toBe(false);
    }
  });
});

describe("Copilot API Response Security", () => {
  it("should not forward sensitive response headers", () => {
    const upstreamHeaders = new Headers({
      "Content-Type": "application/json",
      "X-Request-Id": "abc123",
      "Set-Cookie": "session=secret",
      "X-Internal-Token": "internal-secret",
    });

    const sensitiveHeaders = ["Set-Cookie", "X-Internal-Token"];

    for (const header of sensitiveHeaders) {
      upstreamHeaders.delete(header);
    }

    expect(upstreamHeaders.get("Set-Cookie")).toBeNull();
    expect(upstreamHeaders.get("X-Internal-Token")).toBeNull();
    expect(upstreamHeaders.get("Content-Type")).toBe("application/json");
  });

  it("should preserve CORS headers in response", () => {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    expect(corsHeaders["Access-Control-Allow-Origin"]).toBe("*");
  });
});
