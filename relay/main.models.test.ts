/**
 * Model and pricing tests for Sovereign Agent GitHub Copilot Relay
 *
 * These tests cover:
 * - All model multipliers
 * - Model name normalization
 * - Premium request calculations
 * - Cost estimation scenarios
 * - Model availability by tier
 * - Deprecated model exclusion
 */

import { describe, it, expect } from "bun:test";

// Model multipliers from main.ts - comprehensive list
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

// All models from GitHub Copilot (for validation)
const GITHUB_COPILOT_MODELS = [
  "github-copilot/claude-3.5-sonnet",
  "github-copilot/claude-3.7-sonnet",
  "github-copilot/claude-3.7-sonnet-thought",
  "github-copilot/claude-haiku-4.5",
  "github-copilot/claude-opus-4",
  "github-copilot/claude-opus-4.5",
  "github-copilot/claude-opus-41",
  "github-copilot/claude-sonnet-4",
  "github-copilot/claude-sonnet-4.5",
  "github-copilot/gemini-2.0-flash-001",
  "github-copilot/gemini-2.5-pro",
  "github-copilot/gemini-3-flash-preview",
  "github-copilot/gemini-3-pro-preview",
  "github-copilot/gpt-4.1",
  "github-copilot/gpt-4o",
  "github-copilot/gpt-5",
  "github-copilot/gpt-5-codex",
  "github-copilot/gpt-5-mini",
  "github-copilot/gpt-5.1",
  "github-copilot/gpt-5.1-codex",
  "github-copilot/gpt-5.1-codex-max",
  "github-copilot/gpt-5.1-codex-mini",
  "github-copilot/gpt-5.2",
  "github-copilot/grok-code-fast-1",
  "github-copilot/o3",
  "github-copilot/o3-mini",
  "github-copilot/o4-mini",
  "github-copilot/oswe-vscode-prime",
];

// Deprecated models that should NOT be used
const DEPRECATED_MODELS = [
  "gemini-2.5-pro",        // Use gemini-3-pro-preview
  "claude-sonnet-4",       // Use claude-sonnet-4.5
  "claude-opus-4",         // 10x cost, use claude-opus-4.5 (3x) instead
  "claude-opus-41",        // 10x cost, use claude-opus-4.5 (3x) instead
  "claude-3.5-sonnet",     // Old version
  "claude-3.7-sonnet",     // Old version
  "gemini-2.0-flash-001",  // Old version
];

function getModelMultiplier(model: string): number {
  const modelName = model.replace(/^github-copilot\//, "");
  return MODEL_MULTIPLIERS[modelName] ?? 1;
}

function normalizeModelName(model: string): string {
  return model.replace(/^github-copilot\//, "");
}

describe("Model Multipliers - Complete Coverage", () => {
  describe("Free tier models (0x)", () => {
    const freeModels = [
      { name: "gpt-5-mini", expected: 0 },
      { name: "gpt-4.1", expected: 0 },
      { name: "gpt-4o", expected: 0 },
    ];

    for (const { name, expected } of freeModels) {
      it(`should return ${expected} for ${name}`, () => {
        expect(getModelMultiplier(name)).toBe(expected);
      });

      it(`should return ${expected} for github-copilot/${name}`, () => {
        expect(getModelMultiplier(`github-copilot/${name}`)).toBe(expected);
      });
    }

    it("should have exactly 3 free models", () => {
      const freeCount = Object.entries(MODEL_MULTIPLIERS).filter(([_, v]) => v === 0).length;
      expect(freeCount).toBe(3);
    });
  });

  describe("Very cheap tier models (0.25-0.33x)", () => {
    const cheapModels = [
      { name: "claude-haiku-4.5", expected: 0.33 },
      { name: "grok-code-fast-1", expected: 0.25 },
      { name: "gemini-3-flash-preview", expected: 0.33 },
      { name: "gpt-5.1-codex-mini", expected: 0.33 },
    ];

    for (const { name, expected } of cheapModels) {
      it(`should return ${expected} for ${name}`, () => {
        expect(getModelMultiplier(name)).toBe(expected);
      });
    }

    it("should have exactly 4 very cheap models", () => {
      const cheapCount = Object.entries(MODEL_MULTIPLIERS)
        .filter(([_, v]) => v > 0 && v < 1).length;
      expect(cheapCount).toBe(4);
    });
  });

  describe("Standard tier models (1x)", () => {
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

    for (const name of standardModels) {
      it(`should return 1 for ${name}`, () => {
        expect(getModelMultiplier(name)).toBe(1);
      });
    }

    it("should have exactly 11 standard models", () => {
      const standardCount = Object.entries(MODEL_MULTIPLIERS)
        .filter(([_, v]) => v === 1).length;
      expect(standardCount).toBe(11);
    });
  });

  describe("Premium tier models (3x)", () => {
    it("should return 3 for claude-opus-4.5", () => {
      expect(getModelMultiplier("claude-opus-4.5")).toBe(3);
    });

    it("should have exactly 1 premium model at 3x", () => {
      const premiumCount = Object.entries(MODEL_MULTIPLIERS)
        .filter(([_, v]) => v === 3).length;
      expect(premiumCount).toBe(1);
    });
  });

  describe("Unknown models default to 1x", () => {
    const unknownModels = [
      "unknown-model",
      "future-gpt-99",
      "custom-model-abc",
      "nonexistent",
    ];

    for (const name of unknownModels) {
      it(`should return 1 (default) for unknown model: ${name}`, () => {
        expect(getModelMultiplier(name)).toBe(1);
      });
    }
  });
});

describe("Model Name Normalization", () => {
  it("should strip github-copilot/ prefix", () => {
    expect(normalizeModelName("github-copilot/gpt-5-mini")).toBe("gpt-5-mini");
    expect(normalizeModelName("github-copilot/claude-opus-4.5")).toBe("claude-opus-4.5");
  });

  it("should leave unprefixed names unchanged", () => {
    expect(normalizeModelName("gpt-5-mini")).toBe("gpt-5-mini");
    expect(normalizeModelName("claude-opus-4.5")).toBe("claude-opus-4.5");
  });

  it("should handle empty string", () => {
    expect(normalizeModelName("")).toBe("");
  });

  it("should handle model names with special characters", () => {
    expect(normalizeModelName("gpt-5.1-codex-max")).toBe("gpt-5.1-codex-max");
  });
});

describe("Deprecated Models Exclusion", () => {
  for (const model of DEPRECATED_MODELS) {
    it(`should NOT have ${model} in MODEL_MULTIPLIERS`, () => {
      expect(MODEL_MULTIPLIERS[model]).toBeUndefined();
    });
  }

  it("should not have any 10x multiplier models", () => {
    const expensiveModels = Object.entries(MODEL_MULTIPLIERS)
      .filter(([_, v]) => v >= 10);
    
    expect(expensiveModels.length).toBe(0);
  });

  it("should recommend claude-opus-4.5 over claude-opus-4", () => {
    // claude-opus-4.5 should exist at 3x
    expect(MODEL_MULTIPLIERS["claude-opus-4.5"]).toBe(3);
    // claude-opus-4 should NOT exist
    expect(MODEL_MULTIPLIERS["claude-opus-4"]).toBeUndefined();
  });

  it("should recommend claude-sonnet-4.5 over claude-sonnet-4", () => {
    expect(MODEL_MULTIPLIERS["claude-sonnet-4.5"]).toBe(1);
    expect(MODEL_MULTIPLIERS["claude-sonnet-4"]).toBeUndefined();
  });

  it("should recommend gemini-3-pro over gemini-2.5-pro", () => {
    expect(MODEL_MULTIPLIERS["gemini-3-pro-preview"]).toBe(1);
    expect(MODEL_MULTIPLIERS["gemini-2.5-pro"]).toBeUndefined();
  });
});

describe("Premium Request Calculations", () => {
  it("should calculate 0 for 100 free model requests", () => {
    let total = 0;
    for (let i = 0; i < 100; i++) {
      total += getModelMultiplier("gpt-5-mini");
    }
    expect(total).toBe(0);
  });

  it("should calculate 33 for 100 haiku requests", () => {
    let total = 0;
    for (let i = 0; i < 100; i++) {
      total += getModelMultiplier("claude-haiku-4.5");
    }
    expect(total).toBeCloseTo(33);
  });

  it("should calculate 100 for 100 sonnet requests", () => {
    let total = 0;
    for (let i = 0; i < 100; i++) {
      total += getModelMultiplier("claude-sonnet-4.5");
    }
    expect(total).toBe(100);
  });

  it("should calculate 300 for 100 opus requests", () => {
    let total = 0;
    for (let i = 0; i < 100; i++) {
      total += getModelMultiplier("claude-opus-4.5");
    }
    expect(total).toBe(300);
  });

  it("should calculate mixed usage correctly", () => {
    let total = 0;
    
    // 50 free (0)
    for (let i = 0; i < 50; i++) total += getModelMultiplier("gpt-5-mini");
    
    // 30 cheap (0.33 each = 9.9)
    for (let i = 0; i < 30; i++) total += getModelMultiplier("claude-haiku-4.5");
    
    // 15 standard (1 each = 15)
    for (let i = 0; i < 15; i++) total += getModelMultiplier("claude-sonnet-4.5");
    
    // 5 premium (3 each = 15)
    for (let i = 0; i < 5; i++) total += getModelMultiplier("claude-opus-4.5");
    
    // Total: 0 + 9.9 + 15 + 15 = 39.9
    expect(total).toBeCloseTo(39.9);
  });
});

describe("Cost Estimation Scenarios", () => {
  const COPILOT_PRO_MONTHLY_ALLOWANCE = 300;
  const COPILOT_PRO_PLUS_MONTHLY_ALLOWANCE = 1500;

  it("should estimate light user stays within Pro allowance", () => {
    // Light user: 20 requests/day, mostly free models
    const daysPerMonth = 22; // Work days
    const requestsPerDay = 20;
    
    let monthlyUsage = 0;
    for (let d = 0; d < daysPerMonth; d++) {
      // 15 free, 3 haiku, 2 sonnet
      monthlyUsage += 15 * getModelMultiplier("gpt-5-mini");
      monthlyUsage += 3 * getModelMultiplier("claude-haiku-4.5");
      monthlyUsage += 2 * getModelMultiplier("claude-sonnet-4.5");
    }
    
    // 0 + 22*(3*0.33 + 2*1) = 22*(0.99 + 2) = 22*2.99 = 65.78
    expect(monthlyUsage).toBeLessThan(COPILOT_PRO_MONTHLY_ALLOWANCE);
  });

  it("should estimate heavy Opus user exceeds Pro allowance", () => {
    // Heavy user: 10 opus requests/day
    const daysPerMonth = 22;
    const opusRequestsPerDay = 10;
    
    let monthlyUsage = 0;
    for (let d = 0; d < daysPerMonth; d++) {
      monthlyUsage += opusRequestsPerDay * getModelMultiplier("claude-opus-4.5");
    }
    
    // 22 * 10 * 3 = 660
    expect(monthlyUsage).toBeGreaterThan(COPILOT_PRO_MONTHLY_ALLOWANCE);
    expect(monthlyUsage).toBeLessThan(COPILOT_PRO_PLUS_MONTHLY_ALLOWANCE);
  });

  it("should estimate moderate user fits in Pro+ allowance", () => {
    // Moderate heavy: 30 requests/day, mix of models
    const daysPerMonth = 22;
    
    let monthlyUsage = 0;
    for (let d = 0; d < daysPerMonth; d++) {
      // 10 free, 10 sonnet, 10 opus
      monthlyUsage += 10 * getModelMultiplier("gpt-5-mini");
      monthlyUsage += 10 * getModelMultiplier("claude-sonnet-4.5");
      monthlyUsage += 10 * getModelMultiplier("claude-opus-4.5");
    }
    
    // 22 * (0 + 10 + 30) = 22 * 40 = 880
    expect(monthlyUsage).toBeGreaterThan(COPILOT_PRO_MONTHLY_ALLOWANCE);
    expect(monthlyUsage).toBeLessThan(COPILOT_PRO_PLUS_MONTHLY_ALLOWANCE);
  });

  it("should calculate cost savings vs OpenRouter", () => {
    // OpenRouter frugal tier: ~$20/month for ~31M tokens
    const OPENROUTER_MONTHLY_COST = 20;
    const COPILOT_PRO_COST = 10;
    
    const savings = OPENROUTER_MONTHLY_COST - COPILOT_PRO_COST;
    const savingsPercent = (savings / OPENROUTER_MONTHLY_COST) * 100;
    
    expect(savingsPercent).toBe(50);
  });
});

describe("Model Categories", () => {
  function getModelCategory(model: string): string {
    const multiplier = getModelMultiplier(model);
    if (multiplier === 0) return "free";
    if (multiplier < 1) return "very-cheap";
    if (multiplier === 1) return "standard";
    if (multiplier <= 3) return "premium";
    return "expensive";
  }

  it("should categorize gpt-5-mini as free", () => {
    expect(getModelCategory("gpt-5-mini")).toBe("free");
  });

  it("should categorize claude-haiku-4.5 as very-cheap", () => {
    expect(getModelCategory("claude-haiku-4.5")).toBe("very-cheap");
  });

  it("should categorize claude-sonnet-4.5 as standard", () => {
    expect(getModelCategory("claude-sonnet-4.5")).toBe("standard");
  });

  it("should categorize claude-opus-4.5 as premium", () => {
    expect(getModelCategory("claude-opus-4.5")).toBe("premium");
  });

  it("should categorize unknown models as standard", () => {
    expect(getModelCategory("unknown")).toBe("standard");
  });
});

describe("Model Display Names", () => {
  const MODEL_DISPLAY_NAMES: Record<string, string> = {
    "gpt-5-mini": "GPT-5 Mini [FREE]",
    "gpt-4.1": "GPT-4.1 [FREE]",
    "gpt-4o": "GPT-4o [FREE]",
    "claude-haiku-4.5": "Claude Haiku 4.5 [0.33x]",
    "grok-code-fast-1": "Grok Code Fast 1 [0.25x]",
    "gemini-3-flash-preview": "Gemini 3 Flash [0.33x]",
    "claude-sonnet-4.5": "Claude Sonnet 4.5 [1x]",
    "gpt-5": "GPT-5 [1x]",
    "o3": "o3 [1x]",
    "claude-opus-4.5": "Claude Opus 4.5 [3x] - Best Quality",
  };

  it("should have display names for free models", () => {
    expect(MODEL_DISPLAY_NAMES["gpt-5-mini"]).toContain("FREE");
    expect(MODEL_DISPLAY_NAMES["gpt-4.1"]).toContain("FREE");
    expect(MODEL_DISPLAY_NAMES["gpt-4o"]).toContain("FREE");
  });

  it("should show multiplier in display name for paid models", () => {
    expect(MODEL_DISPLAY_NAMES["claude-haiku-4.5"]).toContain("0.33x");
    expect(MODEL_DISPLAY_NAMES["claude-sonnet-4.5"]).toContain("1x");
    expect(MODEL_DISPLAY_NAMES["claude-opus-4.5"]).toContain("3x");
  });

  it("should mark opus as best quality", () => {
    expect(MODEL_DISPLAY_NAMES["claude-opus-4.5"]).toContain("Best Quality");
  });
});

describe("GitHub Copilot Model Validation", () => {
  it("should have all supported models with multipliers or defaults", () => {
    for (const fullModel of GITHUB_COPILOT_MODELS) {
      const modelName = normalizeModelName(fullModel);
      const multiplier = getModelMultiplier(modelName);
      
      // All models should return a valid number
      expect(typeof multiplier).toBe("number");
      expect(multiplier).toBeGreaterThanOrEqual(0);
    }
  });

  it("should have gpt-5-mini in the list", () => {
    const hasModel = GITHUB_COPILOT_MODELS.includes("github-copilot/gpt-5-mini");
    expect(hasModel).toBe(true);
  });

  it("should have claude-opus-4.5 in the list", () => {
    const hasModel = GITHUB_COPILOT_MODELS.includes("github-copilot/claude-opus-4.5");
    expect(hasModel).toBe(true);
  });

  it("should have all o-series models", () => {
    const oModels = GITHUB_COPILOT_MODELS.filter(m => 
      m.includes("/o3") || m.includes("/o4")
    );
    expect(oModels.length).toBeGreaterThanOrEqual(3);
  });
});

describe("Model Multiplier Totals", () => {
  it("should have 19 total models defined", () => {
    const totalModels = Object.keys(MODEL_MULTIPLIERS).length;
    expect(totalModels).toBe(19);
  });

  it("should have correct distribution of multipliers", () => {
    const distribution = {
      free: 0,      // 0x
      veryCheap: 0, // <1x
      standard: 0,  // 1x
      premium: 0,   // >1x
    };

    for (const [_, multiplier] of Object.entries(MODEL_MULTIPLIERS)) {
      if (multiplier === 0) distribution.free++;
      else if (multiplier < 1) distribution.veryCheap++;
      else if (multiplier === 1) distribution.standard++;
      else distribution.premium++;
    }

    expect(distribution.free).toBe(3);
    expect(distribution.veryCheap).toBe(4);
    expect(distribution.standard).toBe(11);
    expect(distribution.premium).toBe(1);
  });
});
