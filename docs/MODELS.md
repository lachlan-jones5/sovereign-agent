# Model Selection Guide

This document provides a comprehensive analysis of available models on OpenRouter and recommendations for each agent role in Sovereign Agent.

## Current Default Models

| Role | Model | Price ($/1M tokens) | Context | Usage |
|------|-------|---------------------|---------|-------|
| **Orchestrator** | `deepseek/deepseek-v3.2` | $0.25 / $0.38 | 163k | Sisyphus, Frontend UI/UX |
| **Planner** | `deepseek/deepseek-r1-0528` | $0.45 / $2.15 | 131k | Oracle, Metis, Momus, Prometheus |
| **Librarian** | `google/gemini-3-flash-preview` | $0.50 / $3.00 | 1M | Explore, Document-Writer, Multimodal |
| **Genius** | `anthropic/claude-opus-4.5` | $5.00 / $25.00 | 200k | Escape hatch for hard problems |
| **Fallback** | `meta-llama/llama-4-maverick` | $0.15 / $0.60 | 1M | Unknown/unmapped agents |

## Orchestrator Role

Primary agents that coordinate work and can delegate to other agents.

**Agents:** Sisyphus, Frontend UI/UX Engineer

### Recommended Options

| Model | Price (in/out) | Context | Best For |
|-------|----------------|---------|----------|
| `deepseek/deepseek-v3.2` ⭐ | $0.25/$0.38 | 163k | Default - best value for coding |
| `mistralai/mistral-small-3.2-24b-instruct` | $0.06/$0.18 | 131k | Budget - 75% cheaper |
| `openai/gpt-4.1-nano` | $0.10/$0.40 | 1M | Large context - 1M tokens |
| `openai/gpt-4.1-mini` | $0.40/$1.60 | 1M | Quality + large context |
| `qwen/qwen3-32b` | $0.08/$0.24 | 40k | Ultra budget |

### Pros/Cons

**deepseek/deepseek-v3.2** (Default)
- ✅ Excellent coding ability
- ✅ Fast inference
- ✅ Good value
- ❌ No vision/multimodal

**mistralai/mistral-small-3.2-24b-instruct** (Budget)
- ✅ 75% cheaper than default
- ✅ Good general capability
- ❌ May struggle with complex orchestration

**openai/gpt-4.1-nano** (Large Context)
- ✅ 1M token context
- ✅ OpenAI quality
- ❌ 60% more expensive output

## Planner Role

Reasoning and advisory agents that analyze problems and create plans.

**Agents:** Oracle, Metis, Momus, Prometheus

### Recommended Options

| Model | Price (in/out) | Context | Best For |
|-------|----------------|---------|----------|
| `deepseek/deepseek-r1-0528` ⭐ | $0.45/$2.15 | 131k | Default - best reasoning |
| `deepseek/deepseek-r1-distill-llama-70b` | $0.03/$0.11 | 131k | Budget - 93% cheaper |
| `qwen/qwen3-235b-a22b-thinking-2507` | $0.11/$0.60 | 262k | Balance - larger context |
| `openai/o4-mini` | $1.10/$4.40 | 200k | Premium - OpenAI reasoning |
| `microsoft/phi-4-reasoning-plus` | $0.07/$0.35 | 32k | Ultra budget |

### Pros/Cons

**deepseek/deepseek-r1-0528** (Default)
- ✅ Best-in-class reasoning
- ✅ Extended thinking capability
- ❌ Output tokens expensive at $2.15/1M

**deepseek/deepseek-r1-distill-llama-70b** (Budget)
- ✅ 93% cheaper than full R1
- ✅ Retains most reasoning capability
- ❌ Distilled model, may miss edge cases

**openai/o4-mini** (Premium)
- ✅ Latest OpenAI reasoning
- ✅ Very strong on complex logic
- ❌ 2.5x more expensive than default

## Librarian Role

Research and exploration agents that gather information.

**Agents:** Explore, Document-Writer, Multimodal-Looker

### Recommended Options

| Model | Price (in/out) | Context | Best For |
|-------|----------------|---------|----------|
| `google/gemini-3-flash-preview` ⭐ | $0.50/$3.00 | 1M | Default - best multimodal |
| `google/gemini-2.5-flash-lite` | $0.10/$0.40 | 1M | Budget - 80% cheaper |
| `google/gemini-2.0-flash-lite-001` | $0.075/$0.30 | 1M | Ultra budget - 85% cheaper |
| `qwen/qwen-turbo` | $0.05/$0.20 | 1M | Cheapest 1M context |
| `openai/gpt-4.1-nano` | $0.10/$0.40 | 1M | OpenAI alternative |

### Pros/Cons

**google/gemini-3-flash-preview** (Default)
- ✅ Excellent multimodal (images, video)
- ✅ 1M token context
- ❌ Output expensive at $3.00/1M

**google/gemini-2.5-flash-lite** (Budget)
- ✅ 80% cheaper
- ✅ Same 1M context
- ❌ May be less capable for complex analysis

**qwen/qwen-turbo** (Ultra Budget)
- ✅ 90% cheaper than default
- ✅ 1M token context
- ❌ Less capable overall

## Genius Role

Escape hatch for hard problems - invoke with `@Genius`.

**Agents:** Genius

> **Note:** Claude Sonnet 4 has been deprecated in favor of Claude Sonnet 4.5. Both have identical pricing ($3.00/$15.00 per 1M tokens) and context (1M), but Sonnet 4.5 is the newer, more capable model. Always prefer `claude-sonnet-4.5` over `claude-sonnet-4`.

### Recommended Options

| Model | Price (in/out) | Context | Best For |
|-------|----------------|---------|----------|
| `anthropic/claude-opus-4.5` ⭐ | $5.00/$25.00 | 200k | Default - best overall |
| `anthropic/claude-sonnet-4.5` | $3.00/$15.00 | 1M | Balanced - 40% cheaper |
| `google/gemini-2.5-pro` | $1.25/$10.00 | 1M | Value - 75% cheaper |
| `openai/gpt-5.1` | $1.25/$10.00 | 400k | OpenAI alternative |
| `openai/o3` | $2.00/$8.00 | 200k | Best reasoning |

### Pros/Cons

**anthropic/claude-opus-4.5** (Default)
- ✅ Best Anthropic model
- ✅ Exceptional at complex coding
- ✅ Excellent instruction following
- ❌ Most expensive option

**anthropic/claude-sonnet-4.5** (Balanced)
- ✅ 40% cheaper than Opus
- ✅ 1M token context (5x larger)
- ❌ Slightly less capable on edge cases

**google/gemini-2.5-pro** (Value)
- ✅ 75% cheaper than Opus
- ✅ 1M token context
- ❌ Different style, may need prompt adjustment

**openai/o3** (Reasoning)
- ✅ Best for complex logical problems
- ✅ 60% cheaper than Opus
- ❌ Overkill for simple tasks

## Fallback Role

Used for unknown or unmapped agents.

**Agents:** Any agent not in AGENT_ROLE_MAP

### Recommended Options

| Model | Price (in/out) | Context | Best For |
|-------|----------------|---------|----------|
| `meta-llama/llama-4-maverick` ⭐ | $0.15/$0.60 | 1M | Default - good all-around |
| `meta-llama/llama-4-scout` | $0.08/$0.30 | 327k | Budget - 47% cheaper |
| `meta-llama/llama-3.3-70b-instruct` | $0.10/$0.32 | 131k | Proven - stable |
| `mistralai/mistral-small-3.1-24b-instruct` | $0.03/$0.11 | 131k | Ultra budget - 80% cheaper |

## Model Presets

### Budget Preset (Maximum Savings)

```json
{
  "models": {
    "orchestrator": "mistralai/mistral-small-3.2-24b-instruct",
    "planner": "deepseek/deepseek-r1-distill-llama-70b",
    "librarian": "google/gemini-2.0-flash-lite-001",
    "genius": "google/gemini-2.5-pro",
    "fallback": "mistralai/mistral-small-3.1-24b-instruct"
  }
}
```

**Estimated monthly cost:** $5-15 (moderate usage)
**Savings vs default:** 75-85%

### Balanced Preset (Good Value)

```json
{
  "models": {
    "orchestrator": "deepseek/deepseek-v3.2",
    "planner": "deepseek/deepseek-r1-distill-llama-70b",
    "librarian": "google/gemini-2.5-flash-lite",
    "genius": "anthropic/claude-sonnet-4.5",
    "fallback": "meta-llama/llama-4-scout"
  }
}
```

**Estimated monthly cost:** $15-30 (moderate usage)
**Savings vs default:** 50-60%

### Premium Preset (Best Quality)

```json
{
  "models": {
    "orchestrator": "openai/gpt-4.1-mini",
    "planner": "openai/o4-mini",
    "librarian": "google/gemini-3-flash-preview",
    "genius": "anthropic/claude-opus-4.5",
    "fallback": "meta-llama/llama-4-maverick"
  }
}
```

**Estimated monthly cost:** $50-100 (moderate usage)

## Reasoning Models Comparison

For planning tasks that require extended thinking:

| Model | Price (in/out) | Context | Notes |
|-------|----------------|---------|-------|
| `deepseek/deepseek-r1-0528` | $0.45/$2.15 | 131k | Best value reasoning |
| `deepseek/deepseek-r1-distill-llama-70b` | $0.03/$0.11 | 131k | 93% cheaper, distilled |
| `openai/o3-mini` | $1.10/$4.40 | 200k | OpenAI reasoning |
| `openai/o4-mini` | $1.10/$4.40 | 200k | Latest OpenAI |
| `qwen/qwen3-235b-a22b-thinking-2507` | $0.11/$0.60 | 262k | Good value, large |
| `anthropic/claude-3.7-sonnet:thinking` | $3.00/$15.00 | 200k | Claude with thinking |

## Large Context Models (1M+ tokens)

For tasks requiring massive context:

| Model | Price (in/out) | Context | Notes |
|-------|----------------|---------|-------|
| `google/gemini-3-flash-preview` | $0.50/$3.00 | 1M | Multimodal |
| `google/gemini-2.5-flash-lite` | $0.10/$0.40 | 1M | Budget option |
| `openai/gpt-4.1-nano` | $0.10/$0.40 | 1M | OpenAI |
| `openai/gpt-4.1-mini` | $0.40/$1.60 | 1M | Better quality |
| `meta-llama/llama-4-maverick` | $0.15/$0.60 | 1M | Open source |
| `qwen/qwen-turbo` | $0.05/$0.20 | 1M | Cheapest |

## Configuration

Set models in `config.json`:

```json
{
  "models": {
    "orchestrator": "deepseek/deepseek-v3.2",
    "planner": "deepseek/deepseek-r1-0528",
    "librarian": "google/gemini-3-flash-preview",
    "genius": "anthropic/claude-opus-4.5",
    "fallback": "meta-llama/llama-4-maverick"
  }
}
```

## Updating This Document

To refresh model data from OpenRouter API:

```bash
# List all models with pricing
curl -s "https://openrouter.ai/api/v1/models" | jq -r '
.data | sort_by(.pricing.prompt | tonumber) | .[] |
"\(.id)|\(.context_length)|\(.pricing.prompt)|\(.pricing.completion)"
'
```

---

*Last updated: January 2026*
*Data source: OpenRouter API*
