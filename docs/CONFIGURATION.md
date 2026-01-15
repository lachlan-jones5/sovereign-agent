# Configuration Reference

Complete reference for all configuration options.

## config.json

The relay server uses a simple config.json file. Authentication is handled via GitHub OAuth, not API keys.

### Minimal Configuration

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
```

That's it! The `github_oauth_token` is automatically added when you authenticate via the device code flow.

### After Authentication

After running `./scripts/auth-relay.sh` or visiting `/auth/device`, your config will look like:

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  },
  "github_oauth_token": "gho_xxxxxxxxxxxx"
}
```

**Never commit or share the `github_oauth_token`!**

### All Relay Settings

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Enable relay mode |
| `mode` | `"server"` | Role: "server" for relay, "client" for consumer |
| `port` | `8080` | Port to listen on |

## Environment Variables

### Relay Server

| Variable | Default | Description |
|----------|---------|-------------|
| `RELAY_HOST` | `127.0.0.1` | Bind address (use `0.0.0.0` for external access) |
| `RELAY_PORT` | `8080` | Port to listen on |
| `CONFIG_PATH` | `../config.json` | Path to config file |
| `LOG_LEVEL` | `info` | Log level: debug, info, warn, error |

### Client

The client doesn't need much configuration. OpenCode is configured to point at the relay:

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_BASE_URL` | Set by /setup | Points to relay endpoint |

## Model Selection

Models are selected in OpenCode using `/models`. GitHub Copilot provides access to many models with a premium request quota system.

### Free Models (0x multiplier - unlimited)
- `gpt-5-mini` - Fast, default for most tasks
- `gpt-4.1` - Good reasoning
- `gpt-4o` - Multimodal

### Premium Models (use premium requests)
- `claude-sonnet-4.5` (1x) - Best balance
- `claude-opus-4.5` (3x) - Highest quality
- `o3`, `o3-mini` (1x) - OpenAI reasoning
- `gemini-3-pro-preview` (1x) - 1M context

See [MODELS.md](MODELS.md) for the complete list and pricing.

## Docker Volumes

When running in Docker:

| Mount | Purpose |
|-------|---------|
| `/workspace` | Your project directory |
| `/app/config.json` | Configuration file |
| `/root/.config/opencode` | OpenCode settings |
| `/root/.local/share/opencode` | Session history |
| `/root/.ssh` | SSH keys (optional) |
| `/root/.gitconfig` | Git config (optional) |

## Example Configurations

### Relay Server (Default)

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
```

### Relay Server with External Access

Use environment variables to bind to all interfaces:

```bash
RELAY_HOST=0.0.0.0 RELAY_PORT=8081 bun run main.ts
```

Or with the one-liner:

```bash
curl -fsSL .../scripts/setup-relay.sh | RELAY_HOST=0.0.0.0 RELAY_PORT=8081 bash
```

### Client (via /setup)

Clients are automatically configured when you run:

```bash
curl -fsSL http://localhost:8081/setup | bash
```

This creates the OpenCode configuration pointing to the relay.

## Migration from OpenRouter

If you have an old config with `openrouter_api_key`, you can safely remove it:

```json
{
  "openrouter_api_key": "sk-or-v1-...",  // ← Remove this
  "relay": { ... }
}
```

The relay now uses GitHub Copilot authentication instead.

## Security Notes

1. **OAuth tokens** are stored in `config.json` - keep this file secure
2. **Never commit** `config.json` to version control (it's in `.gitignore`)
3. **Tokens expire** - the relay automatically refreshes them
4. **Bind to localhost** by default - only expose via SSH tunnels

## See Also

- [Relay Setup](RELAY-SETUP.md) - Setting up the relay server
- [Models](MODELS.md) - Available models and pricing
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
