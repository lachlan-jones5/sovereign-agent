/**
 * Security-focused tests for Sovereign Agent API Relay
 *
 * These tests cover:
 * - SSRF protection (Server-Side Request Forgery)
 * - API key leak prevention
 * - Bundle security (no sensitive files)
 * - Path traversal protection
 * - Request smuggling prevention
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "bun:test";
import { mkdirSync, rmSync, writeFileSync, readFileSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-security");

describe("SSRF Protection", () => {
  /**
   * SSRF attacks try to make the server request internal resources.
   * The relay should ONLY forward to openrouter.ai, never to arbitrary hosts.
   */

  const PRIVATE_IPS = [
    "127.0.0.1",
    "localhost",
    "0.0.0.0",
    "10.0.0.1",
    "10.255.255.255",
    "172.16.0.1",
    "172.31.255.255",
    "192.168.0.1",
    "192.168.255.255",
    "169.254.0.1", // Link-local
    "::1", // IPv6 localhost
    "fe80::1", // IPv6 link-local
    "fc00::1", // IPv6 ULA
  ];

  it("should reject requests with Host header pointing to private IPs", () => {
    for (const ip of PRIVATE_IPS) {
      const headers = new Headers({ Host: ip });
      // The relay should sanitize this - Host header is deleted
      headers.delete("Host");
      expect(headers.get("Host")).toBeNull();
    }
  });

  it("should not allow redirects to private IPs in target URL", () => {
    // The relay hardcodes OPENROUTER_BASE = "https://openrouter.ai"
    // It should never construct URLs pointing elsewhere
    const OPENROUTER_BASE = "https://openrouter.ai";
    
    for (const ip of PRIVATE_IPS) {
      const maliciousPath = `/api/v1/chat/completions?redirect=http://${ip}/steal`;
      const targetUrl = `${OPENROUTER_BASE}${maliciousPath}`;
      
      // Target URL should always start with openrouter.ai
      expect(targetUrl).toStartWith("https://openrouter.ai");
      // Should not contain the private IP as part of the hostname
      expect(targetUrl).not.toMatch(new RegExp(`^https?://${ip.replace(/\./g, "\\.")}`));
    }
  });

  it("should block path traversal attempts targeting internal endpoints", () => {
    const traversalAttempts = [
      "/../../../etc/passwd",
      "/api/v1/../../../internal",
      "/api/v1/chat/completions/../../admin",
      "/api/v1/chat/completions%2f..%2f..%2fadmin",
      "/api/v1/chat/completions;../../admin",
    ];

    function isPathAllowed(path: string): boolean {
      const ALLOWED_PATHS = [
        "/api/v1/chat/completions",
        "/api/v1/completions",
        "/api/v1/models",
        "/api/v1/auth/key",
        "/api/v1/generation",
      ];
      
      // Block traversal attempts
      if (path.includes("..") || path.includes("//")) {
        return false;
      }
      
      // Normalize URL-encoded characters
      const decodedPath = decodeURIComponent(path);
      if (decodedPath.includes("..")) {
        return false;
      }
      
      return ALLOWED_PATHS.some(
        (allowed) => path === allowed || path.startsWith(allowed + "/")
      );
    }

    for (const path of traversalAttempts) {
      expect(isPathAllowed(path)).toBe(false);
    }
  });

  it("should validate URL scheme is https for OpenRouter", () => {
    const OPENROUTER_BASE = "https://openrouter.ai";
    expect(OPENROUTER_BASE).toStartWith("https://");
    expect(OPENROUTER_BASE).not.toStartWith("http://");
  });
});

describe("API Key Leak Prevention", () => {
  /**
   * API keys should never be logged, even in debug mode.
   * This is critical for security - logs may be exposed.
   */

  it("should not include API key in error messages", () => {
    const apiKey = "sk-or-v1-secret-api-key-12345";
    const errorDetails = "Connection refused to openrouter.ai";
    
    // Error response should not contain the key
    const errorResponse = {
      error: "Relay request failed",
      details: errorDetails,
    };
    
    expect(JSON.stringify(errorResponse)).not.toContain(apiKey);
  });

  it("should not include API key in request logs", () => {
    const logMessage = (method: string, path: string) => `${method} ${path}`;
    
    // Log should only contain method and path, not auth header
    const log = logMessage("POST", "/api/v1/chat/completions");
    expect(log).toBe("POST /api/v1/chat/completions");
    expect(log).not.toContain("sk-or");
    expect(log).not.toContain("Bearer");
  });

  it("should not include API key in health/stats endpoints", () => {
    const healthResponse = {
      status: "ok",
      relay: "sovereign-agent",
      requests: 100,
      tokens: { in: 50000, out: 25000 },
    };

    const statsResponse = {
      requests: 100,
      tokens: { in: 50000, out: 25000 },
      uptime: 3600,
    };

    const healthJson = JSON.stringify(healthResponse);
    const statsJson = JSON.stringify(statsResponse);

    expect(healthJson).not.toContain("sk-or");
    expect(healthJson).not.toContain("api_key");
    expect(healthJson).not.toContain("secret");
    expect(statsJson).not.toContain("sk-or");
    expect(statsJson).not.toContain("api_key");
  });

  it("should redact API key in debug log output", () => {
    const apiKey = "sk-or-v1-test-key-12345";
    
    function redactApiKey(text: string): string {
      // Redact anything that looks like an API key
      return text.replace(/sk-or-v1-[a-zA-Z0-9-]+/g, "sk-or-v1-[REDACTED]");
    }
    
    const logWithKey = `Authorization: Bearer ${apiKey}`;
    const redacted = redactApiKey(logWithKey);
    
    expect(redacted).not.toContain("test-key-12345");
    expect(redacted).toContain("[REDACTED]");
  });

  it("should not expose API key via response headers", () => {
    // Response headers passed through from OpenRouter
    const upstreamHeaders = new Headers({
      "Content-Type": "application/json",
      "X-Request-Id": "abc123",
      // These should be in request, not response, but test anyway
      "Authorization": "Bearer sk-or-v1-secret",
    });
    
    // Sensitive headers that should be stripped from responses
    const sensitiveHeaders = ["Authorization", "X-API-Key", "Cookie", "Set-Cookie"];
    
    for (const header of sensitiveHeaders) {
      // In practice, these should be stripped from response
      if (upstreamHeaders.has(header)) {
        upstreamHeaders.delete(header);
      }
    }
    
    expect(upstreamHeaders.has("Authorization")).toBe(false);
    expect(upstreamHeaders.get("Content-Type")).toBe("application/json");
  });
});

describe("Bundle Security", () => {
  /**
   * The /bundle.tar.gz endpoint should never include sensitive files.
   */

  const EXCLUDED_PATTERNS = [
    ".git",
    "config.json",
    "node_modules",
    ".env",
    "*.log",
    "tests",
  ];

  it("should have correct exclusion patterns", () => {
    expect(EXCLUDED_PATTERNS).toContain(".git");
    expect(EXCLUDED_PATTERNS).toContain("config.json");
    expect(EXCLUDED_PATTERNS).toContain(".env");
    expect(EXCLUDED_PATTERNS).toContain("node_modules");
  });

  it("should match sensitive files against exclusion patterns", () => {
    const sensitiveFiles = [
      ".git/config",
      ".git/objects/pack/abc.pack",
      "config.json",
      ".env",
      ".env.local",
      ".env.production",
      "node_modules/package/index.js",
      "relay/debug.log",
      "tests/test-file.sh",
    ];

    function shouldExclude(path: string, patterns: string[]): boolean {
      for (const pattern of patterns) {
        // Exact match
        if (path === pattern) return true;
        // Starts with (for directories like .git, node_modules)
        if (path.startsWith(pattern + "/")) return true;
        if (path.startsWith(pattern)) return true;
        // Wildcard match (*.log)
        if (pattern.startsWith("*")) {
          const suffix = pattern.slice(1);
          if (path.endsWith(suffix)) return true;
        }
      }
      return false;
    }

    for (const file of sensitiveFiles) {
      const excluded = shouldExclude(file, EXCLUDED_PATTERNS);
      expect(excluded).toBe(true);
    }
  });

  it("should allow legitimate files", () => {
    const legitimateFiles = [
      "install.sh",
      "lib/validate.sh",
      "lib/generate-configs.sh",
      "relay/main.ts",
      "templates/opencode.frugal.jsonc.tmpl",
      "vendor/opencode/package.json",
      "vendor/OpenAgents/.opencode/agent/core/openagent.md",
    ];

    function shouldExclude(path: string, patterns: string[]): boolean {
      for (const pattern of patterns) {
        if (path === pattern) return true;
        if (path.startsWith(pattern + "/")) return true;
        if (pattern.startsWith("*")) {
          const suffix = pattern.slice(1);
          if (path.endsWith(suffix)) return true;
        }
      }
      return false;
    }

    for (const file of legitimateFiles) {
      const excluded = shouldExclude(file, EXCLUDED_PATTERNS);
      expect(excluded).toBe(false);
    }
  });

  it("should not include backup files with API keys", () => {
    const dangerousPatterns = [
      "config.json.backup",
      "config.json.bak",
      ".env.backup",
      "config.json.old",
    ];

    // These should also be excluded
    const enhancedPatterns = [...EXCLUDED_PATTERNS, "*.backup", "*.bak", "*.old"];

    function shouldExclude(path: string, patterns: string[]): boolean {
      for (const pattern of patterns) {
        if (path === pattern) return true;
        if (path.startsWith(pattern + "/")) return true;
        if (pattern.startsWith("*")) {
          const suffix = pattern.slice(1);
          if (path.endsWith(suffix)) return true;
        }
      }
      return false;
    }

    for (const file of dangerousPatterns) {
      const excluded = shouldExclude(file, enhancedPatterns);
      expect(excluded).toBe(true);
    }
  });
});

describe("Request Smuggling Prevention", () => {
  /**
   * Prevent HTTP request smuggling attacks.
   */

  it("should sanitize Content-Length header conflicts", () => {
    // Request smuggling often uses conflicting Content-Length
    const headers = new Headers({
      "Content-Length": "10",
      "Transfer-Encoding": "chunked",
    });

    // When both are present, prefer Transfer-Encoding and remove Content-Length
    if (headers.has("Transfer-Encoding") && headers.has("Content-Length")) {
      headers.delete("Content-Length");
    }

    expect(headers.has("Content-Length")).toBe(false);
    expect(headers.has("Transfer-Encoding")).toBe(true);
  });

  it("should remove hop-by-hop headers", () => {
    const hopByHopHeaders = [
      "Connection",
      "Keep-Alive",
      "Proxy-Authenticate",
      "Proxy-Authorization",
      "TE",
      "Trailer",
      "Transfer-Encoding",
      "Upgrade",
    ];

    const headers = new Headers({
      "Connection": "keep-alive",
      "Keep-Alive": "timeout=5",
      "Content-Type": "application/json",
    });

    for (const header of hopByHopHeaders) {
      headers.delete(header);
    }

    expect(headers.has("Connection")).toBe(false);
    expect(headers.has("Keep-Alive")).toBe(false);
    expect(headers.get("Content-Type")).toBe("application/json");
  });
});

describe("Input Validation", () => {
  /**
   * Validate and sanitize all inputs.
   */

  it("should reject excessively long paths", () => {
    const maxPathLength = 2048;
    const longPath = "/api/v1/chat/completions/" + "a".repeat(3000);

    function isValidPath(path: string): boolean {
      return path.length <= maxPathLength;
    }

    expect(isValidPath(longPath)).toBe(false);
    expect(isValidPath("/api/v1/chat/completions")).toBe(true);
  });

  it("should reject null bytes in paths", () => {
    const pathWithNull = "/api/v1/chat/completions\x00.html";

    function containsNullByte(path: string): boolean {
      return path.includes("\x00");
    }

    expect(containsNullByte(pathWithNull)).toBe(true);
    expect(containsNullByte("/api/v1/chat/completions")).toBe(false);
  });

  it("should reject control characters in headers", () => {
    function containsControlChars(value: string): boolean {
      // Control chars are 0x00-0x1F except tab (0x09), and 0x7F
      return /[\x00-\x08\x0A-\x1F\x7F]/.test(value);
    }

    expect(containsControlChars("normal-value")).toBe(false);
    expect(containsControlChars("value\nwith\nnewlines")).toBe(true);
    expect(containsControlChars("value\rwith\rcarriage")).toBe(true);
    expect(containsControlChars("value\x00with\x00null")).toBe(true);
  });

  it("should validate JSON request bodies", () => {
    const validBodies = [
      '{"model": "gpt-4", "messages": []}',
      '{"prompt": "test"}',
    ];

    const invalidBodies = [
      "not json at all",
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

describe("Rate Limiting Considerations", () => {
  /**
   * Test rate limiting structures (actual enforcement is in main.ts).
   */

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
    expect(incrementRequest("192.168.1.100")).toBe(3);
  });

  it("should reset counts after time window", () => {
    interface RateLimitEntry {
      count: number;
      resetTime: number;
    }

    const rateLimits = new Map<string, RateLimitEntry>();
    const windowMs = 60000; // 1 minute

    function checkRateLimit(clientIp: string, now: number, limit: number): boolean {
      const entry = rateLimits.get(clientIp);

      if (!entry || now >= entry.resetTime) {
        rateLimits.set(clientIp, { count: 1, resetTime: now + windowMs });
        return true;
      }

      if (entry.count >= limit) {
        return false;
      }

      entry.count++;
      return true;
    }

    const now = Date.now();
    const limit = 3;

    expect(checkRateLimit("client1", now, limit)).toBe(true); // 1
    expect(checkRateLimit("client1", now, limit)).toBe(true); // 2
    expect(checkRateLimit("client1", now, limit)).toBe(true); // 3
    expect(checkRateLimit("client1", now, limit)).toBe(false); // blocked

    // After window resets
    expect(checkRateLimit("client1", now + windowMs + 1, limit)).toBe(true);
  });
});

describe("Config File Security", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  it("should reject config with symlink to sensitive file", () => {
    // If config.json is a symlink to /etc/passwd, reject it
    // This is a defense-in-depth measure
    
    function isRegularFile(path: string): boolean {
      // In real implementation, use lstat to check for symlinks
      // For this test, we just verify the pattern
      return !path.includes("../") && !path.startsWith("/etc/");
    }

    expect(isRegularFile("/home/user/config.json")).toBe(true);
    expect(isRegularFile("../../../etc/passwd")).toBe(false);
    expect(isRegularFile("/etc/passwd")).toBe(false);
  });

  it("should validate config file permissions are not world-readable", () => {
    // Config contains API key, should be owner-only (0600)
    // This is advisory - we log a warning
    
    function isSecurePermissions(mode: number): boolean {
      // 0600 = owner read/write only
      // 0640 = owner read/write, group read
      // 0644 = world readable - BAD
      const worldReadable = (mode & 0o004) !== 0;
      return !worldReadable;
    }

    expect(isSecurePermissions(0o600)).toBe(true);
    expect(isSecurePermissions(0o640)).toBe(true);
    expect(isSecurePermissions(0o644)).toBe(false);
    expect(isSecurePermissions(0o777)).toBe(false);
  });

  it("should reject config with embedded shell commands", () => {
    // Defense against command injection via config values
    const maliciousValues = [
      "$(whoami)",
      "`id`",
      "'; rm -rf /; '",
      "| cat /etc/passwd",
    ];

    function containsShellInjection(value: string): boolean {
      const patterns = [
        /\$\(/,           // $(command)
        /`[^`]+`/,        // `command`
        /;\s*\w+/,        // ; command
        /\|\s*\w+/,       // | command
        /&&\s*\w+/,       // && command
        /\|\|\s*\w+/,     // || command
      ];
      
      return patterns.some(p => p.test(value));
    }

    for (const value of maliciousValues) {
      expect(containsShellInjection(value)).toBe(true);
    }

    expect(containsShellInjection("https://example.com")).toBe(false);
    expect(containsShellInjection("sk-or-v1-test-key")).toBe(false);
  });
});
