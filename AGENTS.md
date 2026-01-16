# Sovereign Agent - Agent Guidelines

This document provides guidelines for AI coding agents operating in this repository.

## Project Overview

Sovereign Agent is a relay/proxy service for GitHub Copilot API that enables self-hosted AI coding workflows. It consists of:

- **Relay Server** (`relay/`): Bun-based HTTP proxy for Copilot API
- **OpenCode** (`vendor/opencode/`): AI-powered TUI application (git submodule)
- **OpenAgents** (`vendor/OpenAgents/`): Agent definitions (git submodule)
- **Scripts** (`scripts/`, `lib/`): Setup and utility bash scripts
- **Configs** (`configs/`): OpenCode tier configurations (JSONC format)

## Build/Test Commands

### Relay Server

```bash
# Run relay server
cd relay && bun run main.ts

# Run with custom port/host
RELAY_PORT=8080 RELAY_HOST=127.0.0.1 bun run main.ts

# Run all tests
cd relay && bun test

# Run single test file
cd relay && bun test main.test.ts
cd relay && bun test main.security.test.ts

# Run tests matching pattern
cd relay && bun test --grep "OAuth Token Protection"
```

### Vendor OpenCode

```bash
# Install dependencies
cd vendor/opencode && bun install

# Run in dev mode
cd vendor/opencode/packages/opencode && bun run dev

# Type checking
cd vendor/opencode && bun turbo typecheck

# Run tests
cd vendor/opencode/packages/opencode && bun test

# Single test file
cd vendor/opencode/packages/opencode && bun test test/tool/tool.test.ts
```

### Docker

```bash
# Build relay container
docker build -f Dockerfile.relay -t sovereign-relay .

# Run with docker-compose
docker-compose -f docker-compose.relay.yml up
```

## Code Style Guidelines

### General Formatting

- **No semicolons** at end of statements
- **2-space indentation**
- **120 character** max line width
- **Double quotes** for strings
- **ESM modules** - use `import`/`export`, not `require`

### TypeScript Patterns

```typescript
// Named imports from Node.js built-ins
import { existsSync, readFileSync, writeFileSync } from "fs"
import { resolve, dirname } from "path"

// Constants: SCREAMING_SNAKE_CASE
const RELAY_PORT = 8080
const ALLOWED_PATHS = ["/v1/chat/completions"]

// Functions: camelCase
function loadConfig(): Config { ... }
async function getCopilotToken(): Promise<string> { ... }

// Interfaces: PascalCase
interface Config {
  github_oauth_token?: string
  relay?: {
    enabled?: boolean
    port?: number
  }
}
```

### Error Handling

```typescript
// Try-catch with logging and graceful fallbacks
try {
  const content = readFileSync(CONFIG_PATH, "utf-8")
  const config = JSON.parse(content) as Config
  return config
} catch (err) {
  log("error", `Failed to load config: ${err}`)
  process.exit(1)
}

// Async error handling with user-friendly responses
try {
  const result = await startDeviceCodeFlow()
  return new Response(JSON.stringify({ success: true, ...result }))
} catch (err) {
  log("error", `Device code flow failed: ${err}`)
  return new Response(JSON.stringify({ success: false, error: String(err) }), { status: 500 })
}
```

### Logging Pattern

```typescript
const LOG_LEVELS: Record<string, number> = { debug: 0, info: 1, warn: 2, error: 3 }

function log(level: string, message: string, data?: unknown) {
  if (LOG_LEVELS[level] >= currentLogLevel) {
    const timestamp = new Date().toISOString()
    const prefix = `[${timestamp}] [${level.toUpperCase()}]`
    console.log(`${prefix} ${message}`, data)
  }
}
```

### HTTP Response Pattern

```typescript
// Always return JSON with appropriate headers
return new Response(
  JSON.stringify({ status: "ok", data }),
  {
    headers: { "Content-Type": "application/json", ...corsHeaders },
  }
)
```

### Test Structure

```typescript
import { describe, it, expect, beforeAll, afterAll } from "bun:test"

describe("Feature Name", () => {
  const TEST_DIR = resolve(import.meta.dir, "../.test-relay")

  beforeAll(() => { mkdirSync(TEST_DIR, { recursive: true }) })
  afterAll(() => { rmSync(TEST_DIR, { recursive: true, force: true }) })

  it("should do something", () => {
    expect(result).toBe(expected)
    expect(json).not.toContain("secret")
  })
})
```

Test file naming: `main.test.ts`, `main.security.test.ts`, `main.auth.test.ts`

### Bash Script Patterns

```bash
#!/usr/bin/env bash
set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Command existence check
command_exists() { command -v "$1" >/dev/null 2>&1; }
```

## Security Guidelines

- **Never log OAuth tokens** - redact in debug output
- **Never return tokens in responses** - only return success/failure
- **Validate all paths** - prevent path traversal attacks
- **Use whitelists** for API path filtering (`ALLOWED_PATHS`)
- **Add CORS headers** to all responses

## Directory Structure

```
sovereign-agent/
├── relay/                  # Relay server (main.ts + tests)
├── lib/                    # Library scripts (check-deps.sh, etc.)
├── scripts/                # User scripts (setup-relay.sh, etc.)
├── configs/                # OpenCode tier configs (JSONC)
├── templates/              # Template files
├── docs/                   # Documentation
├── vendor/                 # Git submodules
│   ├── opencode/           # OpenCode TUI
│   └── OpenAgents/         # Agent definitions
└── config.json             # Runtime config (gitignored secrets)
```

## Important Notes

1. **Runtime is Bun** - Use Bun APIs (`Bun.serve()`, `Bun.file()`) where appropriate
2. **No build step for relay** - TypeScript runs directly via Bun
3. **Submodules** - `vendor/` contains git submodules; update with `git submodule update`
4. **Config format** - Use JSONC (JSON with comments) for config files in `configs/`
5. **Docker base** - Alpine-based with `oven/bun:1.1-alpine` image

## Parallel Tool Usage

Always use parallel tool calls when operations are independent. This significantly improves performance.
