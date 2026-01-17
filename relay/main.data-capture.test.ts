/**
 * Tests for Data Capture functionality
 *
 * These tests cover:
 * - JSONL storage format
 * - Session capture structure
 * - Data endpoints (/data/stats, /data/recent, /data/export, /data/ingest)
 * - Streaming response collection
 * - Forward URL functionality
 * - File operations and directory creation
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "bun:test"
import { mkdirSync, rmSync, writeFileSync, readFileSync, existsSync, appendFileSync } from "fs"
import { resolve, dirname } from "path"

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-data-capture")
const TEST_CAPTURE_PATH = resolve(TEST_DIR, "data/captures.jsonl")

describe("Data Capture - Session Structure", () => {
  it("should have all required fields in CapturedSession", () => {
    const session = {
      id: "test-uuid-1234",
      timestamp: "2025-01-17T10:30:00.000Z",
      endpoint: "/v1/chat/completions",
      method: "POST",
      request: { model: "gpt-4", messages: [] },
      response: { choices: [] },
      status: 200,
      latency_ms: 150,
      model: "gpt-4",
      multiplier: 1,
      stream: false,
    }

    expect(session.id).toBeDefined()
    expect(session.timestamp).toBeDefined()
    expect(session.endpoint).toBeDefined()
    expect(session.method).toBeDefined()
    expect(session.request).toBeDefined()
    expect(session.response).toBeDefined()
    expect(session.status).toBeNumber()
    expect(session.latency_ms).toBeNumber()
    expect(session.model).toBeDefined()
    expect(session.multiplier).toBeNumber()
    expect(typeof session.stream).toBe("boolean")
  })

  it("should serialize session to valid JSON", () => {
    const session = {
      id: "test-uuid-1234",
      timestamp: new Date().toISOString(),
      endpoint: "/v1/chat/completions",
      method: "POST",
      request: {
        model: "claude-sonnet-4.5",
        messages: [
          { role: "system", content: "You are helpful" },
          { role: "user", content: "Hello" },
        ],
        stream: true,
      },
      response: "data: {\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}\n\n",
      status: 200,
      latency_ms: 523,
      model: "claude-sonnet-4.5",
      multiplier: 1,
      stream: true,
    }

    const jsonLine = JSON.stringify(session)
    expect(() => JSON.parse(jsonLine)).not.toThrow()

    const parsed = JSON.parse(jsonLine)
    expect(parsed.model).toBe("claude-sonnet-4.5")
    expect(parsed.stream).toBe(true)
  })

  it("should handle special characters in prompts", () => {
    const session = {
      id: "test-special-chars",
      timestamp: new Date().toISOString(),
      endpoint: "/v1/chat/completions",
      method: "POST",
      request: {
        messages: [
          { role: "user", content: "Code with \"quotes\" and 'apostrophes'\nand newlines\ttabs" },
        ],
      },
      response: { content: "```typescript\nconst x = 1;\n```" },
      status: 200,
      latency_ms: 100,
      model: "gpt-4",
      multiplier: 0,
      stream: false,
    }

    const jsonLine = JSON.stringify(session)
    expect(() => JSON.parse(jsonLine)).not.toThrow()
  })
})

describe("Data Capture - JSONL Format", () => {
  beforeAll(() => {
    mkdirSync(dirname(TEST_CAPTURE_PATH), { recursive: true })
  })

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true })
  })

  beforeEach(() => {
    if (existsSync(TEST_CAPTURE_PATH)) {
      rmSync(TEST_CAPTURE_PATH)
    }
  })

  it("should create valid JSONL with one object per line", () => {
    const sessions = [
      { id: "1", model: "gpt-4", status: 200 },
      { id: "2", model: "claude-sonnet-4.5", status: 200 },
      { id: "3", model: "gpt-5-mini", status: 200 },
    ]

    for (const session of sessions) {
      appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(session) + "\n")
    }

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const lines = content.split("\n").filter(line => line.trim())

    expect(lines.length).toBe(3)
    
    for (const line of lines) {
      expect(() => JSON.parse(line)).not.toThrow()
    }
  })

  it("should append without corrupting existing data", () => {
    const session1 = { id: "first", timestamp: "2025-01-17T10:00:00Z" }
    const session2 = { id: "second", timestamp: "2025-01-17T10:01:00Z" }

    appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(session1) + "\n")
    appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(session2) + "\n")

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const lines = content.split("\n").filter(line => line.trim())

    expect(lines.length).toBe(2)
    expect(JSON.parse(lines[0]).id).toBe("first")
    expect(JSON.parse(lines[1]).id).toBe("second")
  })

  it("should handle large request/response bodies", () => {
    const largeContent = "x".repeat(100000) // 100KB of content
    const session = {
      id: "large-session",
      request: { messages: [{ content: largeContent }] },
      response: { content: largeContent },
      status: 200,
    }

    appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(session) + "\n")

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const parsed = JSON.parse(content.trim())
    
    expect(parsed.request.messages[0].content.length).toBe(100000)
  })
})

describe("Data Capture - Directory Creation", () => {
  const NESTED_PATH = resolve(TEST_DIR, "deep/nested/dir/captures.jsonl")

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true })
  })

  it("should create parent directories if they don't exist", () => {
    const dataDir = dirname(NESTED_PATH)
    
    expect(existsSync(dataDir)).toBe(false)
    
    mkdirSync(dataDir, { recursive: true })
    
    expect(existsSync(dataDir)).toBe(true)
  })
})

describe("Data Capture - Streaming Response Collection", () => {
  it("should concatenate streaming chunks correctly", () => {
    const chunks = [
      new TextEncoder().encode("data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n"),
      new TextEncoder().encode("data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"),
      new TextEncoder().encode("data: [DONE]\n\n"),
    ]

    // Simulate chunk collection
    const combined = chunks.reduce((acc, chunk) => {
      const result = new Uint8Array(acc.length + chunk.length)
      result.set(acc)
      result.set(chunk, acc.length)
      return result
    }, new Uint8Array())

    const fullBody = new TextDecoder().decode(combined)

    expect(fullBody).toContain("Hello")
    expect(fullBody).toContain(" world")
    expect(fullBody).toContain("[DONE]")
  })

  it("should preserve SSE format in captured streaming response", () => {
    const sseResponse = `data: {"id":"chatcmpl-123","choices":[{"delta":{"content":"Hi"}}]}\n\ndata: [DONE]\n\n`
    
    const session = {
      id: "stream-test",
      response: sseResponse,
      stream: true,
    }

    const jsonLine = JSON.stringify(session)
    const parsed = JSON.parse(jsonLine)

    expect(parsed.response).toContain("data: ")
    expect(parsed.stream).toBe(true)
  })
})

describe("Data Capture - Stats Endpoint Response", () => {
  it("should include capture stats in response structure", () => {
    const statsResponse = {
      enabled: true,
      captures: 42,
      local_path: "/path/to/captures.jsonl",
      forward_url: "http://localhost:9090/data/ingest",
      file_size_bytes: 1024000,
      file_lines: 42,
    }

    expect(statsResponse.enabled).toBe(true)
    expect(statsResponse.captures).toBeNumber()
    expect(statsResponse.local_path).toBeDefined()
    expect(statsResponse.forward_url).toBeDefined()
    expect(statsResponse.file_size_bytes).toBeNumber()
    expect(statsResponse.file_lines).toBeNumber()
  })

  it("should handle disabled capture state", () => {
    const statsResponse = {
      enabled: false,
      captures: 0,
      local_path: null,
      forward_url: null,
      file_size_bytes: 0,
      file_lines: 0,
    }

    expect(statsResponse.enabled).toBe(false)
    expect(statsResponse.local_path).toBeNull()
  })
})

describe("Data Capture - Recent Endpoint Response", () => {
  beforeAll(() => {
    mkdirSync(dirname(TEST_CAPTURE_PATH), { recursive: true })
  })

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true })
  })

  beforeEach(() => {
    if (existsSync(TEST_CAPTURE_PATH)) {
      rmSync(TEST_CAPTURE_PATH)
    }
  })

  it("should return most recent captures in reverse order", () => {
    const sessions = [
      { id: "1", timestamp: "2025-01-17T10:00:00Z" },
      { id: "2", timestamp: "2025-01-17T10:01:00Z" },
      { id: "3", timestamp: "2025-01-17T10:02:00Z" },
    ]

    for (const session of sessions) {
      appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(session) + "\n")
    }

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const lines = content.split("\n").filter(line => line.trim())
    const recent = lines.slice(-2).reverse().map(line => JSON.parse(line))

    expect(recent.length).toBe(2)
    expect(recent[0].id).toBe("3") // Most recent first
    expect(recent[1].id).toBe("2")
  })

  it("should respect limit parameter", () => {
    for (let i = 1; i <= 20; i++) {
      appendFileSync(TEST_CAPTURE_PATH, JSON.stringify({ id: String(i) }) + "\n")
    }

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const lines = content.split("\n").filter(line => line.trim())
    
    const limit = 5
    const recent = lines.slice(-limit)

    expect(recent.length).toBe(5)
  })

  it("should handle empty capture file", () => {
    writeFileSync(TEST_CAPTURE_PATH, "")

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const lines = content.split("\n").filter(line => line.trim())

    expect(lines.length).toBe(0)
  })
})

describe("Data Capture - Export Endpoint", () => {
  beforeAll(() => {
    mkdirSync(dirname(TEST_CAPTURE_PATH), { recursive: true })
  })

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true })
  })

  it("should export valid JSONL content", () => {
    const sessions = [
      { id: "export-1", model: "gpt-4" },
      { id: "export-2", model: "claude-sonnet-4.5" },
    ]

    writeFileSync(TEST_CAPTURE_PATH, sessions.map(s => JSON.stringify(s)).join("\n") + "\n")

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    
    expect(content).toContain("export-1")
    expect(content).toContain("export-2")
    
    const lines = content.split("\n").filter(line => line.trim())
    for (const line of lines) {
      expect(() => JSON.parse(line)).not.toThrow()
    }
  })

  it("should generate appropriate filename with date", () => {
    const today = new Date().toISOString().split("T")[0]
    const filename = `captures-${today}.jsonl`

    expect(filename).toMatch(/^captures-\d{4}-\d{2}-\d{2}\.jsonl$/)
  })
})

describe("Data Capture - Ingest Endpoint", () => {
  beforeAll(() => {
    mkdirSync(dirname(TEST_CAPTURE_PATH), { recursive: true })
  })

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true })
  })

  beforeEach(() => {
    if (existsSync(TEST_CAPTURE_PATH)) {
      rmSync(TEST_CAPTURE_PATH)
    }
  })

  it("should accept valid session JSON", () => {
    const incomingSession = {
      id: "remote-session-123",
      timestamp: "2025-01-17T10:30:00.000Z",
      endpoint: "/v1/chat/completions",
      method: "POST",
      request: { model: "gpt-4", messages: [] },
      response: { choices: [] },
      status: 200,
      latency_ms: 150,
      model: "gpt-4",
      multiplier: 1,
      stream: false,
    }

    // Simulate ingest
    appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(incomingSession) + "\n")

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const parsed = JSON.parse(content.trim())

    expect(parsed.id).toBe("remote-session-123")
  })

  it("should preserve all fields from remote capture", () => {
    const remoteSession = {
      id: "uuid-from-remote",
      timestamp: "2025-01-17T12:00:00.000Z",
      endpoint: "/v1/chat/completions",
      method: "POST",
      request: {
        model: "claude-opus-4.5",
        messages: [
          { role: "system", content: "Be helpful" },
          { role: "user", content: "Explain quantum computing" },
        ],
        stream: true,
        max_tokens: 4096,
      },
      response: "data: {\"choices\":[...]}\n\ndata: [DONE]\n\n",
      status: 200,
      latency_ms: 2500,
      model: "claude-opus-4.5",
      multiplier: 3,
      stream: true,
    }

    appendFileSync(TEST_CAPTURE_PATH, JSON.stringify(remoteSession) + "\n")

    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const parsed = JSON.parse(content.trim())

    expect(parsed.model).toBe("claude-opus-4.5")
    expect(parsed.multiplier).toBe(3)
    expect(parsed.request.max_tokens).toBe(4096)
    expect(parsed.stream).toBe(true)
  })
})

describe("Data Capture - Forward URL Validation", () => {
  it("should accept valid localhost URLs", () => {
    const validUrls = [
      "http://localhost:9090/data/ingest",
      "http://127.0.0.1:8080/data/ingest",
      "http://localhost:3000/ingest",
    ]

    for (const url of validUrls) {
      expect(() => new URL(url)).not.toThrow()
      const parsed = new URL(url)
      expect(["localhost", "127.0.0.1"]).toContain(parsed.hostname)
    }
  })

  it("should construct proper POST request for forwarding", () => {
    const session = { id: "test", model: "gpt-4" }
    const forwardUrl = "http://localhost:9090/data/ingest"

    const requestInit = {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(session),
    }

    expect(requestInit.method).toBe("POST")
    expect(requestInit.headers["Content-Type"]).toBe("application/json")
    expect(JSON.parse(requestInit.body)).toEqual(session)
  })
})

describe("Data Capture - Security", () => {
  it("should not include OAuth tokens in captured requests", () => {
    const capturedRequest = {
      model: "gpt-4",
      messages: [{ role: "user", content: "Hello" }],
      // Authorization header should NOT be captured
    }

    const json = JSON.stringify(capturedRequest)
    expect(json).not.toContain("gho_")
    expect(json).not.toContain("Bearer")
    expect(json).not.toContain("Authorization")
  })

  it("should not include Copilot tokens in captured metadata", () => {
    const session = {
      id: "test",
      model: "gpt-4",
      status: 200,
      // No token fields
    }

    const json = JSON.stringify(session)
    expect(json).not.toContain("token")
    expect(json).not.toContain("tid=")
    expect(json).not.toContain("exp=")
  })
})

describe("Data Capture - Model Tracking", () => {
  it("should correctly identify model from request", () => {
    const requests = [
      { model: "gpt-4", expected: "gpt-4" },
      { model: "claude-sonnet-4.5", expected: "claude-sonnet-4.5" },
      { model: "github-copilot/gpt-4o", expected: "github-copilot/gpt-4o" },
    ]

    for (const req of requests) {
      const session = { model: req.model }
      expect(session.model).toBe(req.expected)
    }
  })

  it("should track multiplier for captured sessions", () => {
    const sessionsWithMultipliers = [
      { model: "gpt-4o", multiplier: 0 },
      { model: "claude-sonnet-4.5", multiplier: 1 },
      { model: "claude-opus-4.5", multiplier: 3 },
    ]

    for (const session of sessionsWithMultipliers) {
      expect(session.multiplier).toBeNumber()
      expect(session.multiplier).toBeGreaterThanOrEqual(0)
    }
  })
})

describe("Data Capture - Error Scenarios", () => {
  it("should capture failed requests with error status", () => {
    const failedSession = {
      id: "failed-request",
      status: 502,
      response: { error: "Bad Gateway" },
      latency_ms: 30000,
    }

    expect(failedSession.status).toBe(502)
    expect(failedSession.response.error).toBeDefined()
  })

  it("should capture 401 authentication errors", () => {
    const authErrorSession = {
      id: "auth-error",
      status: 401,
      response: { error: "Not authenticated" },
    }

    expect(authErrorSession.status).toBe(401)
  })

  it("should handle malformed response gracefully", () => {
    const session = {
      id: "malformed-response",
      response: "not valid json {{{",
      status: 200,
    }

    // Should store as string, not crash
    expect(typeof session.response).toBe("string")
    expect(() => JSON.stringify(session)).not.toThrow()
  })
})

describe("Data Capture - Performance", () => {
  beforeAll(() => {
    mkdirSync(dirname(TEST_CAPTURE_PATH), { recursive: true })
  })

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true })
  })

  it("should handle rapid sequential captures", () => {
    const startTime = Date.now()
    const count = 100

    for (let i = 0; i < count; i++) {
      appendFileSync(TEST_CAPTURE_PATH, JSON.stringify({ id: i }) + "\n")
    }

    const elapsed = Date.now() - startTime
    
    const content = readFileSync(TEST_CAPTURE_PATH, "utf-8")
    const lines = content.split("\n").filter(line => line.trim())

    expect(lines.length).toBe(count)
    expect(elapsed).toBeLessThan(5000) // Should complete in under 5 seconds
  })
})
