/**
 * Tiered configuration tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - Config file structure validation
 * - Tier-specific model assignments
 * - Provider configuration
 * - Agent configuration per tier
 * - Model multiplier consistency
 * - JSONC parsing compatibility
 */

import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { existsSync, readFileSync } from "fs";
import { resolve } from "path";

// Config file paths
const CONFIGS_DIR = resolve(import.meta.dir, "../configs");
const FREE_CONFIG_PATH = resolve(CONFIGS_DIR, "opencode.free.jsonc");
const FRUGAL_CONFIG_PATH = resolve(CONFIGS_DIR, "opencode.frugal.jsonc");
const PREMIUM_CONFIG_PATH = resolve(CONFIGS_DIR, "opencode.premium.jsonc");

// Model multipliers for validation
const MODEL_MULTIPLIERS: Record<string, number> = {
  // Free (0x)
  "gpt-5-mini": 0,
  "gpt-4.1": 0,
  "gpt-4o": 0,
  
  // Very cheap (0.25-0.33x)
  "claude-haiku-4.5": 0.33,
  "grok-code-fast-1": 0.25,
  "gemini-3-flash-preview": 0.33,
  
  // Standard (1x)
  "claude-sonnet-4.5": 1,
  "gemini-3-pro-preview": 1,
  "gpt-5": 1,
  "o3": 1,
  "o3-mini": 1,
  "o4-mini": 1,
  
  // Premium (3x)
  "claude-opus-4.5": 3,
};

// Free tier models (0x multiplier)
const FREE_MODELS = ["gpt-5-mini", "gpt-4.1", "gpt-4o"];

// Helper to strip JSONC comments (properly handling strings)
function stripJsoncComments(content: string): string {
  let result = "";
  let inString = false;
  let inSingleLineComment = false;
  let inMultiLineComment = false;
  let i = 0;

  while (i < content.length) {
    const char = content[i];
    const nextChar = content[i + 1];

    // Handle string boundaries
    if (!inSingleLineComment && !inMultiLineComment) {
      if (char === '"' && (i === 0 || content[i - 1] !== "\\")) {
        inString = !inString;
        result += char;
        i++;
        continue;
      }
    }

    // Skip content inside strings
    if (inString) {
      result += char;
      i++;
      continue;
    }

    // Handle comment start
    if (!inSingleLineComment && !inMultiLineComment) {
      if (char === "/" && nextChar === "/") {
        inSingleLineComment = true;
        i += 2;
        continue;
      }
      if (char === "/" && nextChar === "*") {
        inMultiLineComment = true;
        i += 2;
        continue;
      }
    }

    // Handle comment end
    if (inSingleLineComment && char === "\n") {
      inSingleLineComment = false;
      result += char;
      i++;
      continue;
    }

    if (inMultiLineComment && char === "*" && nextChar === "/") {
      inMultiLineComment = false;
      i += 2;
      continue;
    }

    // Skip comment content
    if (inSingleLineComment || inMultiLineComment) {
      i++;
      continue;
    }

    result += char;
    i++;
  }

  return result;
}

// Helper to parse JSONC file
function parseJsonc(filePath: string): any {
  const content = readFileSync(filePath, "utf-8");
  const stripped = stripJsoncComments(content);
  return JSON.parse(stripped);
}

// Helper to extract model from full model ID
function extractModelName(fullModelId: string): string {
  return fullModelId.replace(/^github-copilot\//, "");
}

// Helper to get model multiplier
function getModelMultiplier(model: string): number {
  const modelName = extractModelName(model);
  return MODEL_MULTIPLIERS[modelName] ?? 1;
}

describe("Config Files Exist", () => {
  it("should have free tier config", () => {
    expect(existsSync(FREE_CONFIG_PATH)).toBe(true);
  });

  it("should have frugal tier config", () => {
    expect(existsSync(FRUGAL_CONFIG_PATH)).toBe(true);
  });

  it("should have premium tier config", () => {
    expect(existsSync(PREMIUM_CONFIG_PATH)).toBe(true);
  });
});

describe("Config Structure Validation", () => {
  describe("Common structure", () => {
    const configs = [
      { name: "free", path: FREE_CONFIG_PATH },
      { name: "frugal", path: FRUGAL_CONFIG_PATH },
      { name: "premium", path: PREMIUM_CONFIG_PATH },
    ];

    for (const { name, path } of configs) {
      describe(`${name} tier`, () => {
        let config: any;

        beforeAll(() => {
          if (existsSync(path)) {
            config = parseJsonc(path);
          }
        });

        it("should have $schema field", () => {
          expect(config.$schema).toBe("https://opencode.ai/config.json");
        });

        it("should have compaction settings", () => {
          expect(config.compaction).toBeDefined();
          expect(config.compaction.auto).toBe(false);
          expect(config.compaction.prune).toBe(true);
        });

        it("should have hybrid compaction enabled", () => {
          expect(config.compaction.hybrid?.enabled).toBe(true);
          expect(config.compaction.hybrid?.preserve_agent_context).toBe(true);
        });

        it("should have provider configuration", () => {
          expect(config.provider).toBeDefined();
          expect(config.provider["github-copilot"]).toBeDefined();
        });

        it("should have correct provider npm package", () => {
          expect(config.provider["github-copilot"].npm).toBe("@ai-sdk/openai-compatible");
        });

        it("should have provider baseURL with RELAY_PORT placeholder", () => {
          const baseURL = config.provider["github-copilot"].options?.baseURL;
          expect(baseURL).toContain("${RELAY_PORT}");
          expect(baseURL).toContain("/v1");
        });

        it("should have models defined", () => {
          const models = config.provider["github-copilot"].models;
          expect(models).toBeDefined();
          expect(Object.keys(models).length).toBeGreaterThan(0);
        });

        it("should have agent configuration", () => {
          expect(config.agent).toBeDefined();
          expect(Object.keys(config.agent).length).toBeGreaterThan(0);
        });

        it("should have default model set", () => {
          expect(config.model).toBeDefined();
          expect(typeof config.model).toBe("string");
        });
      });
    }
  });
});

describe("Free Tier Model Assignments", () => {
  let config: any;

  beforeAll(() => {
    if (existsSync(FREE_CONFIG_PATH)) {
      config = parseJsonc(FREE_CONFIG_PATH);
    }
  });

  describe("Primary agents", () => {
    const primaryAgents = [
      "openagent",
      "opencoder",
      "codebase-agent",
      "backend-specialist",
      "frontend-specialist",
      "devops-specialist",
      "system-builder",
    ];

    for (const agent of primaryAgents) {
      it(`should use free model for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        const multiplier = getModelMultiplier(modelName);
        
        expect(multiplier).toBe(0);
      });
    }
  });

  describe("Subagents", () => {
    const subagents = [
      "coder-agent",
      "reviewer",
      "tester",
      "build-agent",
      "task-manager",
      "documentation",
    ];

    for (const agent of subagents) {
      it(`should use free model for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        const multiplier = getModelMultiplier(modelName);
        
        expect(multiplier).toBe(0);
      });
    }
  });

  describe("Utility agents", () => {
    it("should use free model for title", () => {
      const modelName = extractModelName(config.agent.title.model);
      expect(getModelMultiplier(modelName)).toBe(0);
    });

    it("should use free model for summary", () => {
      const modelName = extractModelName(config.agent.summary.model);
      expect(getModelMultiplier(modelName)).toBe(0);
    });

    it("should use free model for compaction", () => {
      const modelName = extractModelName(config.agent.compaction.model);
      expect(getModelMultiplier(modelName)).toBe(0);
    });
  });

  it("should have default model as free tier", () => {
    const modelName = extractModelName(config.model);
    expect(getModelMultiplier(modelName)).toBe(0);
  });
});

describe("Frugal Tier Model Assignments", () => {
  let config: any;

  beforeAll(() => {
    if (existsSync(FRUGAL_CONFIG_PATH)) {
      config = parseJsonc(FRUGAL_CONFIG_PATH);
    }
  });

  describe("Primary agents use Sonnet (1x)", () => {
    const primaryAgents = [
      "openagent",
      "opencoder",
      "codebase-agent",
      "backend-specialist",
      "frontend-specialist",
    ];

    for (const agent of primaryAgents) {
      it(`should use 1x model for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        const multiplier = getModelMultiplier(modelName);
        
        expect(multiplier).toBeLessThanOrEqual(1);
      });
    }
  });

  describe("Subagents use Haiku (0.33x) or cheaper", () => {
    const cheapSubagents = [
      "coder-agent",
      "tester",
      "build-agent",
      "documentation",
      "context-retriever",
    ];

    for (const agent of cheapSubagents) {
      it(`should use cheap model for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        const multiplier = getModelMultiplier(modelName);
        
        // Haiku (0.33x) or cheaper
        expect(multiplier).toBeLessThanOrEqual(0.33);
      });
    }
  });

  describe("Critical subagents use Sonnet (1x)", () => {
    it("should use 1x model for reviewer (security)", () => {
      const modelName = extractModelName(config.agent.reviewer.model);
      expect(getModelMultiplier(modelName)).toBeLessThanOrEqual(1);
    });

    it("should use 1x model for task-manager (planning)", () => {
      const modelName = extractModelName(config.agent["task-manager"].model);
      expect(getModelMultiplier(modelName)).toBeLessThanOrEqual(1);
    });
  });

  describe("Utility agents use Haiku", () => {
    it("should use cheap model for title", () => {
      const modelName = extractModelName(config.agent.title.model);
      expect(getModelMultiplier(modelName)).toBeLessThanOrEqual(0.33);
    });

    it("should use cheap model for summary", () => {
      const modelName = extractModelName(config.agent.summary.model);
      expect(getModelMultiplier(modelName)).toBeLessThanOrEqual(0.33);
    });
  });
});

describe("Premium Tier Model Assignments", () => {
  let config: any;

  beforeAll(() => {
    if (existsSync(PREMIUM_CONFIG_PATH)) {
      config = parseJsonc(PREMIUM_CONFIG_PATH);
    }
  });

  describe("Core agents use Opus (3x)", () => {
    const opusAgents = ["openagent", "opencoder", "system-builder"];

    for (const agent of opusAgents) {
      it(`should use opus for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        expect(modelName).toBe("claude-opus-4.5");
      });
    }
  });

  describe("Critical subagents use Opus", () => {
    it("should use opus for reviewer (security)", () => {
      const modelName = extractModelName(config.agent.reviewer.model);
      expect(modelName).toBe("claude-opus-4.5");
    });

    it("should use opus for task-manager (planning)", () => {
      const modelName = extractModelName(config.agent["task-manager"].model);
      expect(modelName).toBe("claude-opus-4.5");
    });
  });

  describe("Standard subagents use Sonnet (1x)", () => {
    const sonnetSubagents = [
      "coder-agent",
      "tester",
      "documentation",
      "codebase-pattern-analyst",
    ];

    for (const agent of sonnetSubagents) {
      it(`should use sonnet for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        expect(modelName).toBe("claude-sonnet-4.5");
      });
    }
  });

  describe("Utility subagents use Haiku (0.33x)", () => {
    const haikuSubagents = [
      "build-agent",
      "context-retriever",
      "context-organizer",
      "command-creator",
    ];

    for (const agent of haikuSubagents) {
      it(`should use haiku for ${agent}`, () => {
        const agentConfig = config.agent[agent];
        expect(agentConfig).toBeDefined();
        
        const modelName = extractModelName(agentConfig.model);
        expect(modelName).toBe("claude-haiku-4.5");
      });
    }
  });
});

describe("Provider Model Definitions", () => {
  let config: any;

  beforeAll(() => {
    if (existsSync(PREMIUM_CONFIG_PATH)) {
      config = parseJsonc(PREMIUM_CONFIG_PATH);
    }
  });

  const expectedModels = [
    // Free
    { id: "gpt-5-mini", contextLimit: 128000 },
    { id: "gpt-4.1", contextLimit: 128000 },
    { id: "gpt-4o", contextLimit: 128000 },
    // Cheap
    { id: "claude-haiku-4.5", contextLimit: 200000 },
    { id: "gemini-3-flash-preview", contextLimit: 1000000 },
    // Standard
    { id: "claude-sonnet-4.5", contextLimit: 200000 },
    { id: "gemini-3-pro-preview", contextLimit: 1000000 },
    // Premium
    { id: "claude-opus-4.5", contextLimit: 200000 },
  ];

  describe("Model availability", () => {
    for (const { id } of expectedModels) {
      it(`should have ${id} defined`, () => {
        const models = config.provider["github-copilot"].models;
        expect(models[id]).toBeDefined();
      });
    }
  });

  describe("Model context limits", () => {
    for (const { id, contextLimit } of expectedModels) {
      it(`should have correct context limit for ${id}`, () => {
        const models = config.provider["github-copilot"].models;
        expect(models[id].limit?.context).toBe(contextLimit);
      });
    }
  });

  describe("Model display names", () => {
    it("should include [FREE] for free models", () => {
      const models = config.provider["github-copilot"].models;
      expect(models["gpt-5-mini"].name).toContain("[FREE]");
      expect(models["gpt-4.1"].name).toContain("[FREE]");
      expect(models["gpt-4o"].name).toContain("[FREE]");
    });

    it("should include multiplier for paid models", () => {
      const models = config.provider["github-copilot"].models;
      expect(models["claude-haiku-4.5"].name).toContain("[0.33x]");
      expect(models["claude-sonnet-4.5"].name).toContain("[1x]");
      expect(models["claude-opus-4.5"].name).toContain("[3x]");
    });
  });
});

describe("Agent Configuration Completeness", () => {
  const REQUIRED_AGENTS = [
    // Primary
    "openagent",
    "opencoder",
    "codebase-agent",
    "backend-specialist",
    "frontend-specialist",
    "devops-specialist",
    "system-builder",
    "repo-manager",
    "copywriter",
    "technical-writer",
    "data-analyst",
    // Subagents
    "coder-agent",
    "reviewer",
    "tester",
    "build-agent",
    "codebase-pattern-analyst",
    "task-manager",
    "documentation",
    "context-retriever",
    "domain-analyzer",
    "agent-generator",
    "context-organizer",
    "workflow-designer",
    "command-creator",
    "image-specialist",
    // Utility
    "title",
    "summary",
    "compaction",
  ];

  for (const tier of ["free", "frugal", "premium"]) {
    describe(`${tier} tier`, () => {
      let config: any;

      beforeAll(() => {
        const path = resolve(CONFIGS_DIR, `opencode.${tier}.jsonc`);
        if (existsSync(path)) {
          config = parseJsonc(path);
        }
      });

      for (const agent of REQUIRED_AGENTS) {
        it(`should have ${agent} configured`, () => {
          expect(config.agent[agent]).toBeDefined();
          expect(config.agent[agent].model).toBeDefined();
        });
      }
    });
  }
});

describe("Cost Estimation by Tier", () => {
  const configs: Record<string, any> = {};

  beforeAll(() => {
    if (existsSync(FREE_CONFIG_PATH)) {
      configs.free = parseJsonc(FREE_CONFIG_PATH);
    }
    if (existsSync(FRUGAL_CONFIG_PATH)) {
      configs.frugal = parseJsonc(FRUGAL_CONFIG_PATH);
    }
    if (existsSync(PREMIUM_CONFIG_PATH)) {
      configs.premium = parseJsonc(PREMIUM_CONFIG_PATH);
    }
  });

  function calculateTierCost(config: any, requestCount: number): number {
    let total = 0;
    const agents = Object.keys(config.agent);
    const requestsPerAgent = Math.ceil(requestCount / agents.length);

    for (const agentName of agents) {
      const agent = config.agent[agentName];
      const modelName = extractModelName(agent.model);
      const multiplier = getModelMultiplier(modelName);
      total += multiplier * requestsPerAgent;
    }

    return total;
  }

  it("should have zero cost for free tier", () => {
    const cost = calculateTierCost(configs.free, 100);
    expect(cost).toBe(0);
  });

  it("should have lower cost for frugal than premium", () => {
    const frugalCost = calculateTierCost(configs.frugal, 100);
    const premiumCost = calculateTierCost(configs.premium, 100);
    expect(frugalCost).toBeLessThan(premiumCost);
  });

  it("should have significant savings with frugal tier", () => {
    const frugalCost = calculateTierCost(configs.frugal, 100);
    const premiumCost = calculateTierCost(configs.premium, 100);
    
    // Frugal should be at least 30% cheaper than premium
    const savings = (premiumCost - frugalCost) / premiumCost;
    expect(savings).toBeGreaterThan(0.3);
  });
});

describe("JSONC Comment Handling", () => {
  it("should strip single-line comments", () => {
    const input = `{
      "key": "value" // This is a comment
    }`;
    const stripped = stripJsoncComments(input);
    expect(stripped).not.toContain("// This is a comment");
  });

  it("should strip multi-line comments", () => {
    const input = `{
      /* This is a
         multi-line comment */
      "key": "value"
    }`;
    const stripped = stripJsoncComments(input);
    expect(stripped).not.toContain("multi-line comment");
  });

  it("should parse config files with comments", () => {
    // All config files should parse without error
    expect(() => parseJsonc(FREE_CONFIG_PATH)).not.toThrow();
    expect(() => parseJsonc(FRUGAL_CONFIG_PATH)).not.toThrow();
    expect(() => parseJsonc(PREMIUM_CONFIG_PATH)).not.toThrow();
  });
});

describe("DCP Plugin Configuration", () => {
  const configs = [
    { name: "free", path: FREE_CONFIG_PATH },
    { name: "frugal", path: FRUGAL_CONFIG_PATH },
    { name: "premium", path: PREMIUM_CONFIG_PATH },
  ];

  for (const { name, path } of configs) {
    describe(`${name} tier`, () => {
      let config: any;

      beforeAll(() => {
        if (existsSync(path)) {
          config = parseJsonc(path);
        }
      });

      it("should have plugin array defined", () => {
        expect(config.plugin).toBeDefined();
        expect(Array.isArray(config.plugin)).toBe(true);
      });

      it("should include DCP plugin", () => {
        expect(config.plugin).toContain("@tarquinen/opencode-dcp@latest");
      });

      it("should use @latest version for auto-updates", () => {
        const dcpPlugin = config.plugin.find((p: string) => p.includes("opencode-dcp"));
        expect(dcpPlugin).toContain("@latest");
      });
    });
  }

  it("should have DCP plugin in all tiers", () => {
    const allConfigs = configs.map(({ path }) => parseJsonc(path));
    
    for (const config of allConfigs) {
      expect(config.plugin).toContain("@tarquinen/opencode-dcp@latest");
    }
  });

  it("should have consistent plugin configuration across tiers", () => {
    const allConfigs = configs.map(({ path }) => parseJsonc(path));
    
    // All tiers should have the same plugin array
    const freePlugins = JSON.stringify(allConfigs[0].plugin);
    const frugalPlugins = JSON.stringify(allConfigs[1].plugin);
    const premiumPlugins = JSON.stringify(allConfigs[2].plugin);
    
    expect(freePlugins).toBe(frugalPlugins);
    expect(frugalPlugins).toBe(premiumPlugins);
  });
});

describe("Model Consistency", () => {
  it("should not use deprecated models", () => {
    const deprecatedModels = [
      "claude-sonnet-4",
      "claude-opus-4",
      "claude-opus-41",
      "gemini-2.5-pro",
      "gemini-2.5-flash",
      "claude-3.5-sonnet",
    ];

    for (const tier of ["free", "frugal", "premium"]) {
      const path = resolve(CONFIGS_DIR, `opencode.${tier}.jsonc`);
      if (existsSync(path)) {
        const content = readFileSync(path, "utf-8");
        for (const model of deprecatedModels) {
          expect(content).not.toContain(`"${model}"`);
        }
      }
    }
  });

  it("should use consistent model naming across tiers", () => {
    const modelPattern = /github-copilot\/[a-z0-9\-\.]+/g;

    for (const tier of ["free", "frugal", "premium"]) {
      const path = resolve(CONFIGS_DIR, `opencode.${tier}.jsonc`);
      if (existsSync(path)) {
        const content = readFileSync(path, "utf-8");
        const matches = content.match(modelPattern) || [];
        
        // All model references should follow the pattern
        for (const match of matches) {
          expect(match).toMatch(/^github-copilot\/[a-z0-9\-\.]+$/);
        }
      }
    }
  });
});
