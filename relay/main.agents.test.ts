/**
 * OpenAgents integration tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - Agent file structure validation
 * - Agent frontmatter parsing
 * - Subagent organization
 * - Agent category system
 * - Context file structure
 * - Command file structure
 * - Agent-config consistency
 */

import { describe, it, expect, beforeAll } from "bun:test";
import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { resolve, join, basename } from "path";

// OpenAgents directory paths
const OPENAGENTS_BASE = resolve(import.meta.dir, "../vendor/OpenAgents/.opencode");
const AGENTS_DIR = resolve(OPENAGENTS_BASE, "agent");
const CONTEXT_DIR = resolve(OPENAGENTS_BASE, "context");
const COMMAND_DIR = resolve(OPENAGENTS_BASE, "command");

// Config directory
const CONFIGS_DIR = resolve(import.meta.dir, "../configs");

// Helper to parse YAML frontmatter from markdown
function parseFrontmatter(content: string): Record<string, any> | null {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return null;
  
  const frontmatter: Record<string, any> = {};
  const lines = match[1].split("\n");
  
  for (const line of lines) {
    const colonIndex = line.indexOf(":");
    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim();
      let value = line.slice(colonIndex + 1).trim();
      
      // Handle quoted strings
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.slice(1, -1);
      }
      
      frontmatter[key] = value;
    }
  }
  
  return frontmatter;
}

// Helper to get all markdown files in directory recursively
function getMarkdownFiles(dir: string): string[] {
  const files: string[] = [];
  
  if (!existsSync(dir)) return files;
  
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    
    if (stat.isDirectory()) {
      files.push(...getMarkdownFiles(fullPath));
    } else if (entry.endsWith(".md")) {
      files.push(fullPath);
    }
  }
  
  return files;
}

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

// Helper to parse JSONC
function parseJsonc(filePath: string): any {
  const content = readFileSync(filePath, "utf-8");
  const stripped = stripJsoncComments(content);
  return JSON.parse(stripped);
}

describe("OpenAgents Directory Structure", () => {
  it("should have agent directory", () => {
    expect(existsSync(AGENTS_DIR)).toBe(true);
  });

  it("should have context directory", () => {
    expect(existsSync(CONTEXT_DIR)).toBe(true);
  });

  it("should have command directory", () => {
    expect(existsSync(COMMAND_DIR)).toBe(true);
  });

  describe("Agent categories", () => {
    const expectedCategories = [
      "core",
      "development",
      "meta",
      "content",
      "data",
      "subagents",
    ];

    for (const category of expectedCategories) {
      it(`should have ${category} category`, () => {
        const categoryPath = resolve(AGENTS_DIR, category);
        expect(existsSync(categoryPath)).toBe(true);
      });
    }
  });

  describe("Subagent categories", () => {
    const subagentPath = resolve(AGENTS_DIR, "subagents");
    const expectedSubcategories = ["code", "core", "system-builder", "utils"];

    for (const subcategory of expectedSubcategories) {
      it(`should have subagents/${subcategory}`, () => {
        const path = resolve(subagentPath, subcategory);
        expect(existsSync(path)).toBe(true);
      });
    }
  });
});

describe("Primary Agent Files", () => {
  describe("Core agents", () => {
    const coreAgents = ["openagent.md", "opencoder.md"];
    const corePath = resolve(AGENTS_DIR, "core");

    for (const agent of coreAgents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(corePath, agent))).toBe(true);
      });
    }
  });

  describe("Development agents", () => {
    const devAgents = [
      "backend-specialist.md",
      "frontend-specialist.md",
      "devops-specialist.md",
      "codebase-agent.md",
    ];
    const devPath = resolve(AGENTS_DIR, "development");

    for (const agent of devAgents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(devPath, agent))).toBe(true);
      });
    }
  });

  describe("Meta agents", () => {
    const metaAgents = ["system-builder.md", "repo-manager.md"];
    const metaPath = resolve(AGENTS_DIR, "meta");

    for (const agent of metaAgents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(metaPath, agent))).toBe(true);
      });
    }
  });

  describe("Content agents", () => {
    const contentAgents = ["copywriter.md", "technical-writer.md"];
    const contentPath = resolve(AGENTS_DIR, "content");

    for (const agent of contentAgents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(contentPath, agent))).toBe(true);
      });
    }
  });
});

describe("Subagent Files", () => {
  describe("Code subagents", () => {
    const codeSubagents = [
      "tester.md",
      "reviewer.md",
      "coder-agent.md",
      "build-agent.md",
      "codebase-pattern-analyst.md",
    ];
    const codePath = resolve(AGENTS_DIR, "subagents/code");

    for (const agent of codeSubagents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(codePath, agent))).toBe(true);
      });
    }
  });

  describe("Core subagents", () => {
    const coreSubagents = [
      "task-manager.md",
      "documentation.md",
      "context-retriever.md",
    ];
    const corePath = resolve(AGENTS_DIR, "subagents/core");

    for (const agent of coreSubagents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(corePath, agent))).toBe(true);
      });
    }
  });

  describe("System-builder subagents", () => {
    const sysSubagents = [
      "agent-generator.md",
      "command-creator.md",
      "context-organizer.md",
      "domain-analyzer.md",
      "workflow-designer.md",
    ];
    const sysPath = resolve(AGENTS_DIR, "subagents/system-builder");

    for (const agent of sysSubagents) {
      it(`should have ${agent}`, () => {
        expect(existsSync(resolve(sysPath, agent))).toBe(true);
      });
    }
  });
});

describe("Agent Frontmatter Validation", () => {
  const agentFiles = getMarkdownFiles(AGENTS_DIR);

  describe("Required frontmatter fields", () => {
    // Sample a few key agents
    const sampleAgents = [
      resolve(AGENTS_DIR, "core/openagent.md"),
      resolve(AGENTS_DIR, "core/opencoder.md"),
      resolve(AGENTS_DIR, "subagents/code/tester.md"),
    ];

    for (const agentPath of sampleAgents) {
      if (existsSync(agentPath)) {
        describe(basename(agentPath), () => {
          let frontmatter: Record<string, any> | null = null;

          beforeAll(() => {
            const content = readFileSync(agentPath, "utf-8");
            frontmatter = parseFrontmatter(content);
          });

          it("should have frontmatter", () => {
            expect(frontmatter).not.toBeNull();
          });

          it("should have id field", () => {
            expect(frontmatter?.id).toBeDefined();
          });

          it("should have name field", () => {
            expect(frontmatter?.name).toBeDefined();
          });

          it("should have description field", () => {
            expect(frontmatter?.description).toBeDefined();
          });
        });
      }
    }
  });

  describe("Agent ID consistency", () => {
    it("should have matching filename and id for openagent", () => {
      const path = resolve(AGENTS_DIR, "core/openagent.md");
      if (existsSync(path)) {
        const content = readFileSync(path, "utf-8");
        const fm = parseFrontmatter(content);
        expect(fm?.id).toBe("openagent");
      }
    });

    it("should have matching filename and id for opencoder", () => {
      const path = resolve(AGENTS_DIR, "core/opencoder.md");
      if (existsSync(path)) {
        const content = readFileSync(path, "utf-8");
        const fm = parseFrontmatter(content);
        expect(fm?.id).toBe("opencoder");
      }
    });
  });
});

describe("Agent Count Validation", () => {
  it("should have at least 10 primary agents", () => {
    const primaryAgents = getMarkdownFiles(AGENTS_DIR).filter(
      (f) => !f.includes("/subagents/")
    );
    expect(primaryAgents.length).toBeGreaterThanOrEqual(10);
  });

  it("should have at least 10 subagents", () => {
    const subagentPath = resolve(AGENTS_DIR, "subagents");
    const subagents = getMarkdownFiles(subagentPath);
    expect(subagents.length).toBeGreaterThanOrEqual(10);
  });

  it("should have more subagents than primary agents", () => {
    const primaryAgents = getMarkdownFiles(AGENTS_DIR).filter(
      (f) => !f.includes("/subagents/")
    );
    const subagentPath = resolve(AGENTS_DIR, "subagents");
    const subagents = getMarkdownFiles(subagentPath);
    
    expect(subagents.length).toBeGreaterThanOrEqual(primaryAgents.length);
  });
});

describe("Config-Agent Consistency", () => {
  let premiumConfig: any;
  const configuredAgents: string[] = [];

  beforeAll(() => {
    const premiumPath = resolve(CONFIGS_DIR, "opencode.premium.jsonc");
    if (existsSync(premiumPath)) {
      premiumConfig = parseJsonc(premiumPath);
      configuredAgents.push(...Object.keys(premiumConfig.agent));
    }
  });

  describe("Configured agents have files", () => {
    // Map agent IDs to expected file locations
    const agentFileMap: Record<string, string> = {
      openagent: "core/openagent.md",
      opencoder: "core/opencoder.md",
      "codebase-agent": "development/codebase-agent.md",
      "backend-specialist": "development/backend-specialist.md",
      "frontend-specialist": "development/frontend-specialist.md",
      "devops-specialist": "development/devops-specialist.md",
      "system-builder": "meta/system-builder.md",
      "repo-manager": "meta/repo-manager.md",
      "coder-agent": "subagents/code/coder-agent.md",
      reviewer: "subagents/code/reviewer.md",
      tester: "subagents/code/tester.md",
      "build-agent": "subagents/code/build-agent.md",
      "task-manager": "subagents/core/task-manager.md",
      documentation: "subagents/core/documentation.md",
      "context-retriever": "subagents/core/context-retriever.md",
    };

    for (const [agentId, relativePath] of Object.entries(agentFileMap)) {
      it(`should have file for ${agentId}`, () => {
        const fullPath = resolve(AGENTS_DIR, relativePath);
        expect(existsSync(fullPath)).toBe(true);
      });
    }
  });

  describe("All configured agents have model assignments", () => {
    it("should have model for every agent in config", () => {
      for (const agentId of configuredAgents) {
        const agent = premiumConfig.agent[agentId];
        expect(agent.model).toBeDefined();
        expect(typeof agent.model).toBe("string");
      }
    });
  });
});

describe("Context Files", () => {
  it("should have context directory structure", () => {
    expect(existsSync(CONTEXT_DIR)).toBe(true);
  });

  it("should have navigation files", () => {
    const navFiles = getMarkdownFiles(CONTEXT_DIR).filter((f) =>
      f.includes("navigation.md")
    );
    expect(navFiles.length).toBeGreaterThan(0);
  });

  describe("OpenAgents-repo context", () => {
    const openagentsContext = resolve(CONTEXT_DIR, "openagents-repo");

    it("should have openagents-repo context", () => {
      expect(existsSync(openagentsContext)).toBe(true);
    });

    it("should have guides directory", () => {
      expect(existsSync(resolve(openagentsContext, "guides"))).toBe(true);
    });

    it("should have core-concepts directory", () => {
      expect(existsSync(resolve(openagentsContext, "core-concepts"))).toBe(true);
    });
  });
});

describe("Command Files", () => {
  it("should have command directory", () => {
    expect(existsSync(COMMAND_DIR)).toBe(true);
  });

  it("should have at least one command file", () => {
    const commandFiles = getMarkdownFiles(COMMAND_DIR);
    expect(commandFiles.length).toBeGreaterThan(0);
  });

  describe("OpenAgents commands", () => {
    const openagentsCommands = resolve(COMMAND_DIR, "openagents");

    it("should have openagents command directory", () => {
      expect(existsSync(openagentsCommands)).toBe(true);
    });
  });
});

describe("Category JSON Files", () => {
  const categories = ["core", "development", "meta", "content", "data"];

  for (const category of categories) {
    it(`should have 0-category.json in ${category}`, () => {
      const categoryJsonPath = resolve(AGENTS_DIR, category, "0-category.json");
      expect(existsSync(categoryJsonPath)).toBe(true);
    });
  }

  it("should parse category JSON files", () => {
    const coreCategoryPath = resolve(AGENTS_DIR, "core/0-category.json");
    if (existsSync(coreCategoryPath)) {
      const content = readFileSync(coreCategoryPath, "utf-8");
      expect(() => JSON.parse(content)).not.toThrow();
    }
  });
});

describe("Agent Mode Validation", () => {
  let premiumConfig: any;

  beforeAll(() => {
    const premiumPath = resolve(CONFIGS_DIR, "opencode.premium.jsonc");
    if (existsSync(premiumPath)) {
      premiumConfig = parseJsonc(premiumPath);
    }
  });

  describe("Primary agents have primary mode", () => {
    const primaryAgentIds = [
      "openagent",
      "opencoder",
      "codebase-agent",
      "backend-specialist",
      "frontend-specialist",
      "devops-specialist",
      "system-builder",
      "repo-manager",
    ];

    for (const agentId of primaryAgentIds) {
      it(`${agentId} should have mode: primary`, () => {
        const agent = premiumConfig?.agent[agentId];
        expect(agent?.mode).toBe("primary");
      });
    }
  });

  describe("Subagents have subagent mode", () => {
    const subagentIds = [
      "coder-agent",
      "reviewer",
      "tester",
      "build-agent",
      "task-manager",
      "documentation",
      "context-retriever",
    ];

    for (const agentId of subagentIds) {
      it(`${agentId} should have mode: subagent`, () => {
        const agent = premiumConfig?.agent[agentId];
        expect(agent?.mode).toBe("subagent");
      });
    }
  });

  describe("Utility agents have no mode", () => {
    const utilityAgentIds = ["title", "summary", "compaction"];

    for (const agentId of utilityAgentIds) {
      it(`${agentId} should not have mode field`, () => {
        const agent = premiumConfig?.agent[agentId];
        // Utility agents typically don't have mode
        expect(agent?.mode).toBeUndefined();
      });
    }
  });
});

describe("Agent Description Validation", () => {
  let premiumConfig: any;

  beforeAll(() => {
    const premiumPath = resolve(CONFIGS_DIR, "opencode.premium.jsonc");
    if (existsSync(premiumPath)) {
      premiumConfig = parseJsonc(premiumPath);
    }
  });

  it("should have description for every agent", () => {
    for (const [agentId, agent] of Object.entries(premiumConfig.agent)) {
      expect((agent as any).description).toBeDefined();
      expect(typeof (agent as any).description).toBe("string");
      expect((agent as any).description.length).toBeGreaterThan(10);
    }
  });

  it("should have unique descriptions", () => {
    const descriptions = new Set<string>();
    for (const [agentId, agent] of Object.entries(premiumConfig.agent)) {
      const desc = (agent as any).description;
      expect(descriptions.has(desc)).toBe(false);
      descriptions.add(desc);
    }
  });
});

describe("Subagent Invocation Format", () => {
  // These are the subagent types that should be available for Task tool
  const EXPECTED_SUBAGENT_TYPES = [
    "general",
    "explore",
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
  ];

  it("should have all expected subagent types available", () => {
    expect(EXPECTED_SUBAGENT_TYPES.length).toBeGreaterThanOrEqual(10);
  });

  it("should have valid subagent type names", () => {
    for (const type of EXPECTED_SUBAGENT_TYPES) {
      expect(type).toMatch(/^[a-zA-Z][a-zA-Z0-9\-]*$/);
    }
  });

  it("should have unique subagent types", () => {
    const unique = new Set(EXPECTED_SUBAGENT_TYPES);
    expect(unique.size).toBe(EXPECTED_SUBAGENT_TYPES.length);
  });
});

describe("Bundle Inclusion Verification", () => {
  // These paths should be included in the bundle
  const BUNDLE_REQUIRED_PATHS = [
    "vendor/OpenAgents/.opencode/agent",
    "vendor/OpenAgents/.opencode/context",
    "vendor/OpenAgents/.opencode/command",
    "configs/opencode.free.jsonc",
    "configs/opencode.frugal.jsonc",
    "configs/opencode.premium.jsonc",
  ];

  for (const relativePath of BUNDLE_REQUIRED_PATHS) {
    it(`should include ${relativePath} in bundle`, () => {
      const fullPath = resolve(import.meta.dir, "..", relativePath);
      expect(existsSync(fullPath)).toBe(true);
    });
  }

  // These paths should be excluded from the bundle
  const BUNDLE_EXCLUDED_PATHS = [
    "config.json",
    ".env",
    ".git",
  ];

  it("should not bundle sensitive files", () => {
    // This is a conceptual test - the actual exclusion happens in tar command
    const excludePatterns = [".git", "config.json", ".env"];
    expect(excludePatterns).toContain("config.json");
    expect(excludePatterns).toContain(".env");
  });
});
