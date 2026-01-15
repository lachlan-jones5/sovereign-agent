# Sovereign Agent

Privacy-compliant AI coding environment. Keep your GitHub Copilot credentials secure on a trusted machine while running [OpenCode](https://github.com/sst/opencode) anywhere.

```
┌──────────────┐                     ┌──────────────┐         ┌────────────┐
│   Client VM  │◀── reverse tunnel ──│   Laptop     │────────▶│  Pi/VPS    │
│   OpenCode   │     (from laptop)   │   (bridge)   │  SSH    │  (relay)   │
└──────────────┘                     └──────────────┘         └────────────┘
                                                                    │
                                                               HTTPS│
                                                                    ▼
                                                              ┌────────────┐
                                                              │  GitHub    │
                                                              │  Copilot   │
                                                              └────────────┘
```

## Why GitHub Copilot?

| Plan | Cost | What You Get |
|------|------|--------------|
| **Pro** | $10/month | Unlimited GPT-5 mini, GPT-4.1, GPT-4o + 300 premium requests |
| **Pro+** | $39/month | Everything in Pro + 1,500 premium requests |

**Premium requests** give you access to Claude Sonnet 4.5, Claude Opus 4.5, Gemini 3 Pro, o3, and more. Most models cost 1 premium request, with free models (GPT-5 mini, etc.) costing 0.

## Quick Start

### 1. Set up the relay server (Pi/VPS)

**One-liner:**
```bash
curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash
```

**Or manually:**
```bash
git clone https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent
cp config.json.example config.json
cd relay && bun run main.ts
```

### 2. Authenticate with GitHub Copilot

Open your browser and go to: `http://localhost:8080/auth/device`

This will guide you through GitHub's device code flow. The OAuth token is stored securely on your relay server.

### 3. Create tunnels (laptop)

```bash
# Tunnel laptop → Pi (forward)
ssh -L 8081:127.0.0.1:8080 pi@your-relay.example.com -N &

# Tunnel laptop → Client VM (reverse)
ssh -R 8081:localhost:8081 devvm -N &
```

### 4. Install client (Client VM)

```bash
curl -fsSL http://localhost:8081/setup | bash
```

### 5. Run OpenCode

```bash
exec $SHELL  # Pick up PATH changes
opencode /path/to/your-project
```

## Available Models

Use `/models` in OpenCode to switch between models.

### Free (0x multiplier - unlimited)
- `gpt-5-mini` - Fast, good for most tasks (default)
- `gpt-4.1` - Good reasoning
- `gpt-4o` - Multimodal

### Very Cheap (0.25-0.33x multiplier)
- `claude-haiku-4.5` - Fast Claude
- `grok-code-fast-1` - Fast coding
- `gemini-3-flash-preview` - 1M context window
- `gpt-5.1-codex-mini` - Optimized for code

### Standard (1x multiplier)
- `claude-sonnet-4.5` - Best balance of speed/quality
- `gpt-5`, `gpt-5.1`, `gpt-5.2` - Latest GPT models
- `gemini-3-pro-preview` - 1M context, great for large codebases
- `o3`, `o3-mini`, `o4-mini` - OpenAI reasoning models

### Premium (3x multiplier)
- `claude-opus-4.5` - Best quality for complex tasks

## How It Works

Your laptop bridges two SSH tunnels:
- **Forward tunnel** to the relay server (Pi/VPS)
- **Reverse tunnel** to your Client VM

The Client VM sees `localhost:8081` which routes through your laptop to the relay. The relay handles GitHub Copilot authentication and forwards requests to the Copilot API.

**Key benefit:** OAuth tokens never touch the Client VM.

## Relay Endpoints

| Endpoint | Description |
|----------|-------------|
| `/health` | Health check, shows auth status |
| `/stats` | Usage statistics, premium requests used |
| `/auth/device` | Start GitHub device code flow (browser) |
| `/auth/status` | Check authentication status |
| `/setup` | Client setup script |
| `/bundle.tar.gz` | Download client bundle |
| `/v1/*` | Proxy to GitHub Copilot API |

## If Client VM Runs Docker

If your dev environment is inside a container:

```bash
# Inside container: find host IP
HOST_IP=$(ip route | grep default | awk '{print $3}')

# Create tunnel to host
ssh -L 8081:127.0.0.1:8081 youruser@$HOST_IP -N &

# Then install
curl -fsSL http://localhost:8081/setup | bash
```

Or use `--network host` when starting the container.

## Documentation

| Doc | Description |
|-----|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System design and data flow |
| [Relay Setup](docs/RELAY-SETUP.md) | Detailed relay server configuration |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and fixes |

## Privacy

- OAuth tokens are stored only on your trusted relay server
- API requests go through GitHub Copilot's infrastructure
- Your code context is handled per GitHub's Copilot privacy policy
- No credentials ever touch the untrusted Client VM

## Cost Estimation

With GitHub Copilot Pro ($10/month):
- **Unlimited** GPT-5 mini, GPT-4.1, GPT-4o usage
- 300 premium requests per month
- Most developers won't exceed this for normal use

With Pro+ ($39/month):
- Same unlimited base models
- 1,500 premium requests per month
- Better for heavy Claude Opus usage

## Related Projects

- [OpenCode](https://github.com/sst/opencode) - AI coding assistant
- [GitHub Copilot](https://github.com/features/copilot) - AI pair programmer

## License

MIT
