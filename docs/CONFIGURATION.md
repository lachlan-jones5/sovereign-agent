# Configuration Reference

Complete reference for all configuration options.

## Model Tiers

Sovereign Agent uses a tier-based model configuration system. Set the tier in `config.json`:

```json
{
  "tier": "frugal"
}
```

### Available Tiers

| Tier | Cost/Month | Description |
|------|------------|-------------|
| `free` | $0 | Uses only free models (DeepSeek R1:free, Devstral:free, etc.) |
| `frugal` | ~$20 | Balanced value with DeepSeek V3.2, GPT-4o-mini, Claude Haiku |
| `premium` | ~$100+ | Best quality with Claude Opus 4.5, Sonnet 4.5, o3 |

The tier determines which OpenCode configuration template is used. See [Model Selection Guide](MODELS.md) for detailed model assignments per tier.

### Selecting a Tier During Installation

```bash
# Via the relay setup script
curl -fsSL http://localhost:8081/setup | TIER=free bash

# Or set in config.json before running install.sh
echo '{"tier": "premium", ...}' > config.json
./install.sh
```

## config.json

### Required Fields

```json
{
  "openrouter_api_key": "sk-or-v1-...",
  "site_url": "https://github.com/yourusername/sovereign-agent",
  "site_name": "SovereignAgent",
  "models": {
    "orchestrator": "anthropic/claude-sonnet-4.5",
    "planner": "anthropic/claude-sonnet-4.5",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
```

Note: `openrouter_api_key` not required for relay client mode.

### Models

Models are configured automatically based on your selected tier. The tier templates define optimal model assignments for each agent role.

| Role | Purpose | Free Tier | Frugal Tier | Premium Tier |
|------|---------|-----------|-------------|--------------|
| Primary agents | User-facing work | DeepSeek R1:free | DeepSeek V3.2 | Claude Opus 4.5 |
| Coding agents | Code generation | Devstral:free | GPT-4o-mini | Claude Sonnet 4.5 |
| Review agents | Security analysis | Qwen3-Coder:free | Claude Haiku 4.5 | Claude Haiku 4.5 |
| Utility agents | Summaries, titles | Llama 3.3:free | Llama 3.3 | Llama 3.3 |

See [Model Selection Guide](MODELS.md) for complete model assignments and pricing.

### Relay Settings

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8081,
    "allowed_paths": [
      "/api/v1/chat/completions",
      "/api/v1/completions",
      "/api/v1/models",
      "/api/v1/auth/key"
    ]
  }
}
```

| Setting | Server | Client | Description |
|---------|--------|--------|-------------|
| `enabled` | true | true | Enable relay mode |
| `mode` | "server" | "client" | Role of this instance |
| `port` | 8081 | 8081 | Relay port |
| `allowed_paths` | [...] | - | API paths to forward (server only) |

### Preferences

```json
{
  "preferences": {
    "ultrawork_max_iterations": 50,
    "dcp_turn_protection": 2,
    "dcp_error_retention_turns": 4,
    "dcp_nudge_frequency": 10
  }
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `ultrawork_max_iterations` | 50 | Max iterations in ultrawork mode |
| `dcp_turn_protection` | 2 | Turns to protect content from pruning |
| `dcp_error_retention_turns` | 4 | Turns to retain error context |
| `dcp_nudge_frequency` | 10 | How often to remind about context limits |

## Environment Variables

### Relay Server

| Variable | Default | Description |
|----------|---------|-------------|
| `RELAY_HOST` | `127.0.0.1` | Bind address |
| `RELAY_PORT` | `8080` | Port to listen on |
| `CONFIG_PATH` | `../config.json` | Config file path |
| `LOG_LEVEL` | `info` | debug, info, warn, error |
| `OPENROUTER_API_KEY` | - | Override config file key |
| `REPO_PATH` | `/app` | Path to repo (for bundle) |

### Client

| Variable | Default | Description |
|----------|---------|-------------|
| `RELAY_PORT` | `8080` | Port to connect to |

## Docker Volumes

| Mount | Purpose |
|-------|---------|
| `/workspace` | Your project directory |
| `/app/config.json` | Configuration file |
| `/root/.config/opencode` | OpenCode settings |
| `/root/.local/share/opencode` | Session history |
| `/root/.ssh` | SSH keys (optional) |
| `/root/.gitconfig` | Git config (optional) |

## Example Configurations

### Minimal Server

```json
{
  "openrouter_api_key": "sk-or-v1-...",
  "site_url": "https://example.com",
  "site_name": "MyAgent",
  "models": {
    "orchestrator": "anthropic/claude-sonnet-4.5",
    "planner": "anthropic/claude-sonnet-4.5",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8081
  }
}
```

### Minimal Client

```json
{
  "openrouter_api_key": "",
  "site_url": "https://example.com",
  "site_name": "MyAgent",
  "models": {
    "orchestrator": "anthropic/claude-sonnet-4.5",
    "planner": "anthropic/claude-sonnet-4.5",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8081
  }
}
```

### Standalone (No Relay)

```json
{
  "openrouter_api_key": "sk-or-v1-...",
  "site_url": "https://example.com",
  "site_name": "MyAgent",
  "models": {
    "orchestrator": "anthropic/claude-sonnet-4.5",
    "planner": "anthropic/claude-sonnet-4.5",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "relay": {
    "enabled": false
  }
}
```
