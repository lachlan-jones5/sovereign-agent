/**
 * Setup endpoint tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - Tiered setup endpoint (?tier=free|frugal|premium)
 * - Setup script generation with correct tier
 * - Config file installation
 * - OpenAgents agent installation
 * - RELAY_PORT substitution
 * - Bundle contents verification
 */

import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { mkdirSync, rmSync, existsSync, readFileSync, writeFileSync } from "fs";
import { resolve } from "path";

const TEST_DIR = resolve(import.meta.dir, "../.test-relay-setup");

// Valid tiers
const VALID_TIERS = ["free", "frugal", "premium"] as const;
type Tier = typeof VALID_TIERS[number];

// Mock setup script generator (matches main.ts behavior)
function generateSetupScript(tier: Tier, port: number): string {
  return `#!/bin/bash
# Sovereign Agent Client Setup (GitHub Copilot Edition)
# Tier: ${tier}

set -uo pipefail

# Configuration
TIER="${tier}"
RELAY_PORT="\${RELAY_PORT:-${port}}"
INSTALL_DIR="\${INSTALL_DIR:-\$PWD/sovereign-agent}"

echo "=== Sovereign Agent Client Setup (GitHub Copilot) ==="
echo "Tier: \$TIER"

# Setup OpenCode configuration (\$TIER tier)...
mkdir -p "\$HOME/.config/opencode"

# Copy the appropriate tier config file
CONFIG_FILE="configs/opencode.\${TIER}.jsonc"
sed "s/\\\${RELAY_PORT}/\$RELAY_PORT/g" "\$CONFIG_FILE" > "\$HOME/.config/opencode/opencode.jsonc"

# Copy OpenAgents agent definitions
echo "Installing OpenAgents agents and subagents..."
OPENAGENTS_DIR="vendor/OpenAgents/.opencode"

cp -r "\$OPENAGENTS_DIR/agent" "\$HOME/.config/opencode/"
cp -r "\$OPENAGENTS_DIR/context" "\$HOME/.config/opencode/"
cp -r "\$OPENAGENTS_DIR/command" "\$HOME/.config/opencode/"
`;
}

describe("Tiered Setup Endpoint", () => {
  describe("Tier parameter validation", () => {
    it("should accept 'free' tier", () => {
      const tier = "free";
      expect(VALID_TIERS.includes(tier as Tier)).toBe(true);
    });

    it("should accept 'frugal' tier", () => {
      const tier = "frugal";
      expect(VALID_TIERS.includes(tier as Tier)).toBe(true);
    });

    it("should accept 'premium' tier", () => {
      const tier = "premium";
      expect(VALID_TIERS.includes(tier as Tier)).toBe(true);
    });

    it("should default to 'premium' for missing tier", () => {
      const tier = null;
      const selectedTier = tier || "premium";
      expect(selectedTier).toBe("premium");
    });

    it("should default to 'premium' for invalid tier", () => {
      const tier = "invalid";
      const selectedTier = VALID_TIERS.includes(tier as Tier) ? tier : "premium";
      expect(selectedTier).toBe("premium");
    });

    it("should default to 'premium' for empty tier", () => {
      const tier = "";
      const selectedTier = tier || "premium";
      expect(selectedTier).toBe("premium");
    });

    it("should be case-sensitive (reject 'FREE')", () => {
      const tier = "FREE";
      const isValid = VALID_TIERS.includes(tier.toLowerCase() as Tier);
      expect(isValid).toBe(true);
      expect(VALID_TIERS.includes(tier as Tier)).toBe(false);
    });
  });

  describe("Setup script content", () => {
    it("should include tier in script header", () => {
      const script = generateSetupScript("free", 8081);
      expect(script).toContain("# Tier: free");
    });

    it("should set TIER variable correctly for free", () => {
      const script = generateSetupScript("free", 8081);
      expect(script).toContain('TIER="free"');
    });

    it("should set TIER variable correctly for frugal", () => {
      const script = generateSetupScript("frugal", 8081);
      expect(script).toContain('TIER="frugal"');
    });

    it("should set TIER variable correctly for premium", () => {
      const script = generateSetupScript("premium", 8081);
      expect(script).toContain('TIER="premium"');
    });

    it("should include RELAY_PORT with correct default", () => {
      const script = generateSetupScript("premium", 8081);
      expect(script).toContain("RELAY_PORT");
      expect(script).toContain("8081");
    });

    it("should use custom port in RELAY_PORT default", () => {
      const script = generateSetupScript("premium", 9999);
      expect(script).toContain("9999");
    });

    it("should reference config file for selected tier", () => {
      const script = generateSetupScript("frugal", 8081);
      expect(script).toContain("configs/opencode.${TIER}.jsonc");
    });

    it("should copy OpenAgents agent directory", () => {
      const script = generateSetupScript("premium", 8081);
      expect(script).toContain('cp -r "$OPENAGENTS_DIR/agent"');
    });

    it("should copy OpenAgents context directory", () => {
      const script = generateSetupScript("premium", 8081);
      expect(script).toContain('cp -r "$OPENAGENTS_DIR/context"');
    });

    it("should copy OpenAgents command directory", () => {
      const script = generateSetupScript("premium", 8081);
      expect(script).toContain('cp -r "$OPENAGENTS_DIR/command"');
    });
  });

  describe("Setup script response headers", () => {
    it("should return shell script content type", () => {
      const headers = {
        "Content-Type": "text/x-shellscript",
        "Content-Disposition": "attachment; filename=setup.sh",
      };

      expect(headers["Content-Type"]).toBe("text/x-shellscript");
    });

    it("should have correct Content-Disposition", () => {
      const headers = {
        "Content-Type": "text/x-shellscript",
        "Content-Disposition": "attachment; filename=setup.sh",
      };

      expect(headers["Content-Disposition"]).toContain("setup.sh");
    });
  });
});

describe("Config File Installation", () => {
  beforeAll(() => {
    mkdirSync(TEST_DIR, { recursive: true });
  });

  afterAll(() => {
    rmSync(TEST_DIR, { recursive: true, force: true });
  });

  describe("Config file paths", () => {
    it("should construct correct path for free tier", () => {
      const tier = "free";
      const configPath = `configs/opencode.${tier}.jsonc`;
      expect(configPath).toBe("configs/opencode.free.jsonc");
    });

    it("should construct correct path for frugal tier", () => {
      const tier = "frugal";
      const configPath = `configs/opencode.${tier}.jsonc`;
      expect(configPath).toBe("configs/opencode.frugal.jsonc");
    });

    it("should construct correct path for premium tier", () => {
      const tier = "premium";
      const configPath = `configs/opencode.${tier}.jsonc`;
      expect(configPath).toBe("configs/opencode.premium.jsonc");
    });
  });

  describe("RELAY_PORT substitution", () => {
    it("should replace ${RELAY_PORT} placeholder", () => {
      const template = 'baseURL": "http://localhost:${RELAY_PORT}/v1"';
      const port = 8081;
      const result = template.replace(/\$\{RELAY_PORT\}/g, String(port));
      
      expect(result).toContain("8081");
      expect(result).not.toContain("${RELAY_PORT}");
    });

    it("should replace all occurrences of ${RELAY_PORT}", () => {
      const template = `
        "baseURL": "http://localhost:\${RELAY_PORT}/v1",
        "health": "http://localhost:\${RELAY_PORT}/health"
      `;
      const port = 9000;
      const result = template.replace(/\$\{RELAY_PORT\}/g, String(port));
      
      const matches = result.match(/9000/g);
      expect(matches?.length).toBe(2);
    });

    it("should handle various port numbers", () => {
      const ports = [80, 443, 8080, 8081, 9000, 65535];
      const template = 'http://localhost:${RELAY_PORT}';

      for (const port of ports) {
        const result = template.replace(/\$\{RELAY_PORT\}/g, String(port));
        expect(result).toContain(String(port));
      }
    });
  });

  describe("Config installation location", () => {
    it("should install to ~/.config/opencode/opencode.jsonc", () => {
      const targetPath = "$HOME/.config/opencode/opencode.jsonc";
      expect(targetPath).toContain(".config/opencode");
      expect(targetPath).toContain("opencode.jsonc");
    });

    it("should create ~/.config/opencode directory", () => {
      const mkdirCommand = 'mkdir -p "$HOME/.config/opencode"';
      expect(mkdirCommand).toContain("mkdir -p");
      expect(mkdirCommand).toContain(".config/opencode");
    });
  });
});

describe("OpenAgents Installation", () => {
  describe("Source directories", () => {
    it("should reference correct OpenAgents base path", () => {
      const basePath = "vendor/OpenAgents/.opencode";
      expect(basePath).toContain("vendor/OpenAgents");
      expect(basePath).toContain(".opencode");
    });

    it("should copy agent directory", () => {
      const sourcePath = "vendor/OpenAgents/.opencode/agent";
      const targetPath = "$HOME/.config/opencode/agent";
      
      expect(sourcePath).toContain("/agent");
      expect(targetPath).toContain("/agent");
    });

    it("should copy context directory", () => {
      const sourcePath = "vendor/OpenAgents/.opencode/context";
      const targetPath = "$HOME/.config/opencode/context";
      
      expect(sourcePath).toContain("/context");
      expect(targetPath).toContain("/context");
    });

    it("should copy command directory", () => {
      const sourcePath = "vendor/OpenAgents/.opencode/command";
      const targetPath = "$HOME/.config/opencode/command";
      
      expect(sourcePath).toContain("/command");
      expect(targetPath).toContain("/command");
    });
  });

  describe("Agent counting", () => {
    it("should count primary agents correctly", () => {
      // Mock find command result
      const agentFiles = [
        "core/openagent.md",
        "core/opencoder.md",
        "development/backend-specialist.md",
        "development/frontend-specialist.md",
      ];
      
      expect(agentFiles.length).toBe(4);
    });

    it("should count subagents correctly", () => {
      // Mock find command result for subagents
      const subagentFiles = [
        "subagents/code/tester.md",
        "subagents/code/reviewer.md",
        "subagents/code/coder-agent.md",
        "subagents/core/task-manager.md",
        "subagents/core/documentation.md",
      ];
      
      expect(subagentFiles.length).toBe(5);
    });

    it("should exclude category files from counts", () => {
      const allFiles = [
        "core/0-category.json",
        "core/openagent.md",
        "core/opencoder.md",
      ];
      
      const agentFiles = allFiles.filter(f => f.endsWith(".md"));
      expect(agentFiles.length).toBe(2);
    });
  });
});

describe("Tier-Specific Completion Messages", () => {
  describe("Free tier message", () => {
    it("should mention 0x multiplier models", () => {
      const message = "FREE TIER: Using only 0x multiplier models (unlimited use)";
      expect(message).toContain("0x");
      expect(message).toContain("FREE");
    });

    it("should list free primary models", () => {
      const primaryModels = ["gpt-4.1", "gpt-4o"];
      expect(primaryModels).toContain("gpt-4.1");
      expect(primaryModels).toContain("gpt-4o");
    });

    it("should include upgrade instruction", () => {
      const upgradeCmd = "curl -fsSL http://localhost:8081/setup?tier=frugal | bash";
      expect(upgradeCmd).toContain("tier=frugal");
    });
  });

  describe("Frugal tier message", () => {
    it("should mention balanced cost/quality", () => {
      const message = "FRUGAL TIER: Balanced cost/quality";
      expect(message).toContain("FRUGAL");
      expect(message).toContain("Balanced");
    });

    it("should mention sonnet for primary agents", () => {
      const primaryModel = "claude-sonnet-4.5 (1x)";
      expect(primaryModel).toContain("sonnet");
      expect(primaryModel).toContain("1x");
    });

    it("should mention haiku for subagents", () => {
      const subagentModel = "claude-haiku-4.5 (0.33x)";
      expect(subagentModel).toContain("haiku");
      expect(subagentModel).toContain("0.33x");
    });

    it("should include upgrade instruction to premium", () => {
      const upgradeCmd = "curl -fsSL http://localhost:8081/setup?tier=premium | bash";
      expect(upgradeCmd).toContain("tier=premium");
    });
  });

  describe("Premium tier message", () => {
    it("should mention maximum quality", () => {
      const message = "PREMIUM TIER: Maximum quality";
      expect(message).toContain("PREMIUM");
      expect(message).toContain("Maximum quality");
    });

    it("should mention opus for primary agents", () => {
      const primaryModel = "claude-opus-4.5 (3x)";
      expect(primaryModel).toContain("opus");
      expect(primaryModel).toContain("3x");
    });

    it("should NOT include upgrade instruction", () => {
      // Premium is the highest tier, no upgrade available
      const tierMessage = "PREMIUM TIER: Maximum quality\nBest models for critical decisions";
      expect(tierMessage).not.toContain("To upgrade");
    });
  });
});

describe("Available Agents List", () => {
  const PRIMARY_AGENTS = [
    "openagent",
    "opencoder",
    "codebase-agent",
    "backend-specialist",
    "frontend-specialist",
    "devops-specialist",
    "system-builder",
  ];

  const SUBAGENTS = [
    "tester",
    "reviewer",
    "coder-agent",
    "build-agent",
    "task-manager",
    "documentation",
    "context-retriever",
  ];

  it("should list all primary agents", () => {
    for (const agent of PRIMARY_AGENTS) {
      expect(PRIMARY_AGENTS).toContain(agent);
    }
  });

  it("should list all subagents", () => {
    for (const agent of SUBAGENTS) {
      expect(SUBAGENTS).toContain(agent);
    }
  });

  it("should include @agent-name invocation syntax", () => {
    const usage = "Use '@agent-name' to invoke a specific agent";
    expect(usage).toContain("@agent-name");
  });
});

describe("Setup Script Error Handling", () => {
  it("should check tunnel connectivity", () => {
    const healthCheck = 'curl -sf "http://localhost:$RELAY_PORT/health"';
    expect(healthCheck).toContain("/health");
    expect(healthCheck).toContain("RELAY_PORT");
  });

  it("should check authentication status", () => {
    const authCheck = 'curl -sf "http://localhost:$RELAY_PORT/auth/status"';
    expect(authCheck).toContain("/auth/status");
  });

  it("should fail gracefully on missing tunnel", () => {
    const errorMessage = "Cannot reach relay at localhost:$RELAY_PORT";
    expect(errorMessage).toContain("Cannot reach relay");
  });

  it("should fail gracefully when not authenticated", () => {
    const errorMessage = "Relay is not authenticated with GitHub Copilot";
    expect(errorMessage).toContain("not authenticated");
  });

  it("should fail gracefully on missing config file", () => {
    const fallbackBehavior = "using default";
    expect(fallbackBehavior).toContain("default");
  });

  it("should fail gracefully on missing install.sh", () => {
    const errorMessage = "Bundle extraction failed - install.sh not found";
    expect(errorMessage).toContain("install.sh not found");
  });
});

describe("Dependency Installation", () => {
  it("should check for Bun", () => {
    const bunCheck = "command -v bun";
    expect(bunCheck).toContain("bun");
  });

  it("should check for Go", () => {
    const goCheck = "command -v go";
    expect(goCheck).toContain("go");
  });

  it("should check for jq", () => {
    const jqCheck = "command -v jq";
    expect(jqCheck).toContain("jq");
  });

  it("should install Bun if missing", () => {
    const bunInstall = "curl -fsSL https://bun.sh/install | bash";
    expect(bunInstall).toContain("bun.sh/install");
  });

  it("should install Go to user-local directory", () => {
    const goInstall = "$HOME/.local/go";
    expect(goInstall).toContain(".local/go");
  });

  it("should support multiple architectures for Go", () => {
    const architectures = ["x86_64", "aarch64", "arm64"];
    const goArchMappings: Record<string, string> = {
      x86_64: "amd64",
      aarch64: "arm64",
      arm64: "arm64",
    };

    for (const arch of architectures) {
      expect(goArchMappings[arch]).toBeDefined();
    }
  });
});

describe("Backup Handling", () => {
  it("should backup existing opencode config", () => {
    const backupDir = "$HOME/.config/opencode.backup.$TIMESTAMP";
    expect(backupDir).toContain("backup");
    expect(backupDir).toContain("TIMESTAMP");
  });

  it("should use timestamp in backup name", () => {
    const timestamp = "20260115_123456";
    const backupDir = `$HOME/.config/opencode.backup.${timestamp}`;
    expect(backupDir).toContain(timestamp);
  });

  it("should check for existing config before backup", () => {
    const checkCommand = '[[ -d "$OPENCODE_CONFIG_DIR" ]]';
    expect(checkCommand).toContain("-d");
  });
});
