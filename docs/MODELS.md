# GitHub Copilot Model Guide

This document describes the models available through GitHub Copilot API and their premium request multipliers.

## Cost Model

GitHub Copilot uses a **premium request** system instead of per-token billing:

| Plan | Monthly Cost | Premium Requests |
|------|--------------|------------------|
| **Copilot Pro** | $10/month | 300/month |
| **Copilot Pro+** | $39/month | 1,500/month |

Premium requests are consumed based on model multipliers. Free models (0x) don't consume any premium requests.

## Available Models

### Free Models (0x multiplier)

These models are unlimited and don't consume premium requests:

| Model | Context | Best For |
|-------|---------|----------|
| `gpt-5-mini` | 200k | General coding, fast responses |
| `gpt-4.1` | 1M | Large context tasks |
| `gpt-4o` | 128k | Balanced performance |

### Budget Models (0.25-0.33x multiplier)

Very cost-effective for most tasks:

| Model | Multiplier | Context | Best For |
|-------|------------|---------|----------|
| `claude-haiku-4.5` | 0.25x | 200k | Fast, cheap Claude |
| `grok-code-fast-1` | 0.25x | 128k | Code-focused tasks |
| `gemini-3-flash-preview` | 0.33x | 1M | Large context, multimodal |

### Standard Models (1x multiplier)

One premium request per API call:

| Model | Context | Best For |
|-------|---------|----------|
| `claude-sonnet-4.5` | 1M | Primary coding agent |
| `gpt-5` | 200k | OpenAI flagship |
| `gpt-5.1` | 200k | Latest GPT iteration |
| `gpt-5.2` | 200k | Newest GPT model |
| `o3` | 200k | OpenAI reasoning |
| `o3-mini` | 200k | Efficient reasoning |
| `o4-mini` | 200k | Latest reasoning |
| `gemini-3-pro-preview` | 1M | Google flagship |
| `grok-3` | 131k | xAI flagship |

### Premium Models (3x multiplier)

Best quality, highest cost:

| Model | Multiplier | Context | Best For |
|-------|------------|---------|----------|
| `claude-opus-4.5` | 3x | 200k | Complex problems, escape hatch |

## Deprecated Models

The following models are **deprecated** and excluded from the relay:

- `claude-sonnet-4` - Use `claude-sonnet-4.5` instead
- `claude-opus-4` - Use `claude-opus-4.5` instead
- `claude-opus-41` - Use `claude-opus-4.5` instead
- `gemini-2.5-pro` - Use `gemini-3-pro-preview` instead

## Cost Comparison

### Pro Plan ($10/month, 300 requests)

| Usage Pattern | Requests/day | Premium Exhaustion |
|---------------|--------------|-------------------|
| Heavy (claude-opus-4.5) | 3-4 | ~1 week |
| Moderate (claude-sonnet-4.5) | 10 | 30 days |
| Light (free models) | Unlimited | Never |

### Pro+ Plan ($39/month, 1,500 requests)

| Usage Pattern | Requests/day | Premium Exhaustion |
|---------------|--------------|-------------------|
| Heavy (claude-opus-4.5) | 15-20 | 30 days |
| Moderate (claude-sonnet-4.5) | 50 | 30 days |
| Light (free models) | Unlimited | Never |

## Recommended Configurations

### Budget Setup (Maximize Free Models)

Use free models for most work, save premium for complex tasks:

```
Primary: gpt-5-mini (0x)
Backup: claude-haiku-4.5 (0.25x)
Escape: claude-sonnet-4.5 (1x)
```

**Premium usage:** ~50-100/month

### Balanced Setup

Mix of quality and cost:

```
Primary: claude-sonnet-4.5 (1x)
Fast: gpt-5-mini (0x)
Large context: gpt-4.1 (0x)
Escape: claude-opus-4.5 (3x)
```

**Premium usage:** ~300-500/month (Pro+ recommended)

### Quality Setup

Best models for all tasks:

```
Primary: claude-sonnet-4.5 (1x)
Reasoning: o3 (1x)
Escape: claude-opus-4.5 (3x)
```

**Premium usage:** ~500-1000/month (Pro+ required)

## Comparison: Copilot vs OpenRouter

| Feature | GitHub Copilot | OpenRouter |
|---------|----------------|------------|
| **Pricing** | $10-39/month flat | Per-token |
| **Free models** | Yes (gpt-5-mini, gpt-4.1) | Limited |
| **Claude access** | All versions | All versions |
| **Premium billing** | Request-based | Token-based |
| **Best for** | Heavy users | Light/sporadic use |

### Break-even Analysis

Copilot Pro ($10/month) is cheaper than OpenRouter if you use:
- More than ~$10/month on OpenRouter
- Or more than ~500k tokens/month of Claude Sonnet

Copilot Pro+ ($39/month) is cheaper if you use:
- More than ~$39/month on OpenRouter
- Or heavy premium model usage (1000+ requests/month)

## Monitoring Usage

Check your premium request usage:

```bash
curl http://localhost:8080/stats | jq
```

Response:
```json
{
  "uptime": 3600,
  "requests": {
    "total": 150,
    "success": 148,
    "error": 2
  },
  "premiumRequests": {
    "used": 87.5,
    "limit": 300
  }
}
```

## See Also

- [Architecture](ARCHITECTURE.md) - System overview
- [Relay Setup](RELAY-SETUP.md) - Relay configuration
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
