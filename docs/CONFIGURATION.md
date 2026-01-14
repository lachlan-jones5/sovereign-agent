# Configuration Reference

Complete reference for all configuration options.

## config.json

### Required Fields

```json
{
  "openrouter_api_key": "sk-or-v1-...",
  "site_url": "https://github.com/yourusername/sovereign-agent",
  "site_name": "SovereignAgent",
  "models": {
    "orchestrator": "anthropic/claude-sonnet-4",
    "planner": "anthropic/claude-sonnet-4",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
```

Note: `openrouter_api_key` not required for relay client mode.

### Models

| Role | Purpose | Recommended |
|------|---------|-------------|
| `orchestrator` | Main coding agent | claude-sonnet-4, deepseek-r1 |
| `planner` | Task planning | claude-sonnet-4 |
| `librarian` | Code search, docs | gemini-2.5-flash |
| `fallback` | Backup model | llama-3.3-70b-instruct |

### Agent-to-Role Mapping

| Agent | Role |
|-------|------|
| Sisyphus | orchestrator |
| oracle | planner |
| librarian | librarian |
| explore | librarian |
| frontend-ui-ux-engineer | orchestrator |
| document-writer | librarian |
| multimodal-looker | librarian |

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
    "orchestrator": "anthropic/claude-sonnet-4",
    "planner": "anthropic/claude-sonnet-4",
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
    "orchestrator": "anthropic/claude-sonnet-4",
    "planner": "anthropic/claude-sonnet-4",
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
    "orchestrator": "anthropic/claude-sonnet-4",
    "planner": "anthropic/claude-sonnet-4",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "relay": {
    "enabled": false
  }
}
```
