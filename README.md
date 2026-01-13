# Sovereign Agent

Privacy-compliant agentic software engineering environment combining [OpenCode](https://github.com/sst/opencode), [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode), and [opencode-dcp](https://github.com/tarquinen/opencode-dcp) with OpenRouter's Zero Data Retention (ZDR) mode.

## Overview

Sovereign Agent uses a **client-server relay architecture** to keep your API keys secure on a trusted machine while running OpenCode on any workstation. This is ideal for:

- **Remote work**: Run AI coding on a work VM while keeping keys on your personal device
- **Network isolation**: Route API traffic through a trusted server to avoid monitoring
- **Team deployments**: Centralized API key management with per-user access control

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌────────────┐
│   Work VM       │     │   Laptop     │     │   Pi/Server     │     │ OpenRouter │
│   (client)      │────▶│   (jump)     │────▶│   (relay)       │────▶│   API      │
│   OpenCode      │ SSH │   optional   │ SSH │   API keys here │HTTPS│   ZDR mode │
└─────────────────┘     └──────────────┘     └─────────────────┘     └────────────┘
```

## Quick Start

### Step 1: Set Up the Relay Server

Choose **one** of these methods on your trusted machine (Pi, home server, or laptop):

#### Option A: Docker (Recommended)

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create server config with your API key
cp config.json.example config.json
# Edit config.json: add your openrouter_api_key, set relay.enabled=true, relay.mode=server

# Start the relay server
docker compose -f docker-compose.relay.yml up -d
```

#### Option B: Native (Bun)

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create server config
cp config.json.example config.json
# Edit config.json: add your openrouter_api_key, set relay.enabled=true, relay.mode=server

# Start the relay
cd relay
./start-relay.sh daemon
```

### Step 2: Set Up the Client

Choose **one** of these methods on your workstation:

#### Option A: Docker

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create client config (no API key needed)
cp config.client.example config.json

# Start SSH tunnel + OpenCode
docker compose run --rm agent ./lib/ssh-relay.sh run pi-relay
```

#### Option B: Native

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create client config and install
cp config.client.example config.json
./install.sh

# Connect via SSH tunnel and run OpenCode
./lib/ssh-relay.sh run pi-relay
```

### Step 3: Configure SSH (Required for Remote Relay)

Add your relay server to `~/.ssh/config` on the client machine:

```ssh-config
Host pi-relay
    HostName your-pi.local
    User pi
    IdentityFile ~/.ssh/pi_key
    ServerAliveInterval 30
```

For multi-hop setups (e.g., through a laptop):

```ssh-config
Host laptop
    HostName laptop.local
    User youruser

Host pi-relay
    HostName pi.local
    User pi
    ProxyJump laptop
```

---

## Server Setup (Detailed)

The **relay server** holds your API keys and forwards authenticated requests to OpenRouter. Run this on a trusted machine.

### Server Configuration

Create `config.json` with your API key and relay settings:

```json
{
  "openrouter_api_key": "sk-or-v1-your-api-key-here",
  "site_url": "https://mycompany.internal",
  "site_name": "MyCompany",

  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },

  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080,
    "allowed_paths": [
      "/api/v1/chat/completions",
      "/api/v1/completions",
      "/api/v1/models",
      "/api/v1/auth/key"
    ]
  }
}
```

### Running the Server with Docker

**docker-compose.relay.yml**:

```yaml
services:
  relay:
    build:
      context: .
      dockerfile: Dockerfile.relay
    image: sovereign-relay:latest
    container_name: sovereign-relay
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"  # Only bind to localhost for SSH tunnel
    volumes:
      - ./config.json:/app/config.json:ro
    environment:
      - RELAY_PORT=8080
      - RELAY_HOST=0.0.0.0
      - LOG_LEVEL=info
```

Start the server:

```bash
# Build and start
docker compose -f docker-compose.relay.yml up -d

# Check logs
docker compose -f docker-compose.relay.yml logs -f

# Check status
curl http://localhost:8080/health
```

### Running the Server Natively

Prerequisites: [Bun](https://bun.sh) runtime

```bash
# Start in foreground (for testing)
cd relay
./start-relay.sh

# Start as daemon (for production)
./start-relay.sh daemon

# Check status
./start-relay.sh status

# View logs
tail -f /tmp/sovereign-relay.log

# Stop daemon
./start-relay.sh stop
```

### Server Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_PATH` | `../config.json` | Path to config file |
| `RELAY_PORT` | `8080` | Port to listen on |
| `RELAY_HOST` | `127.0.0.1` | Host to bind (use `0.0.0.0` in Docker) |
| `LOG_LEVEL` | `info` | Log level: debug, info, warn, error |

### Security Considerations

1. **Bind to localhost**: The relay only accepts connections from `127.0.0.1` by default. Clients connect via SSH tunnel.
2. **Path whitelist**: Only `/api/v1/*` endpoints are forwarded. Other paths return 403.
3. **No API key exposure**: The API key never leaves the server; clients don't need it.

---

## Client Setup (Detailed)

The **client** runs OpenCode and connects to the relay server via SSH tunnel. No API key required.

### Client Configuration

Create `config.json` with relay client settings (note: `openrouter_api_key` is empty):

```json
{
  "openrouter_api_key": "",
  "site_url": "https://localhost",
  "site_name": "SovereignAgent-Client",

  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },

  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8080
  }
}
```

### Running the Client with Docker

```bash
# Interactive session with SSH tunnel
docker compose run --rm agent ./lib/ssh-relay.sh run pi-relay

# Or mount a specific project
docker compose run --rm \
  -v /path/to/project:/workspace \
  agent ./lib/ssh-relay.sh run pi-relay
```

For persistent tunnel (keep tunnel running between sessions):

```bash
# Terminal 1: Start tunnel
docker compose run --rm agent ./lib/ssh-relay.sh start pi-relay

# Terminal 2: Run OpenCode (multiple times)
docker compose run --rm agent opencode

# When done: Stop tunnel
docker compose run --rm agent ./lib/ssh-relay.sh stop
```

### Running the Client Natively

Prerequisites: Go 1.21+, Bun 1.0+, jq

```bash
# One-time setup
cp config.client.example config.json
./install.sh

# Daily usage: start tunnel and run OpenCode
./lib/ssh-relay.sh run pi-relay

# Or manage tunnel separately
./lib/ssh-relay.sh start pi-relay    # Start tunnel
opencode                              # Run OpenCode (multiple times)
./lib/ssh-relay.sh stop               # Stop tunnel when done
```

### Client Commands

```bash
# Start tunnel and run OpenCode
./lib/ssh-relay.sh run <ssh-host>

# Manage tunnel separately
./lib/ssh-relay.sh start <ssh-host>   # Start tunnel
./lib/ssh-relay.sh status             # Check tunnel + relay status
./lib/ssh-relay.sh stop               # Stop tunnel

# Check if relay is accessible
curl http://localhost:8080/health
```

### SSH Tunnel Configuration

The SSH host can be:
- A host defined in `~/.ssh/config` (recommended)
- Direct user@hostname connection
- Multi-hop via ProxyJump

**Direct connection** (client → server):
```ssh-config
Host pi-relay
    HostName your-pi.duckdns.org
    User pi
    Port 22
    IdentityFile ~/.ssh/pi_key
    ServerAliveInterval 30
```

**Two-hop** (client → laptop → server):
```ssh-config
Host laptop
    HostName laptop.local
    User youruser
    IdentityFile ~/.ssh/laptop_key

Host pi-relay
    HostName pi.local
    User pi
    ProxyJump laptop
    IdentityFile ~/.ssh/pi_key
```

**Three-hop** (client → bastion → laptop → server):
```ssh-config
Host pi-relay
    HostName pi.local
    User pi
    ProxyJump bastion,laptop
```

---

## Standalone Mode (No Relay)

If you don't need the relay architecture, you can run sovereign-agent directly with the API key on the same machine.

### Docker

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create config with API key
cp config.json.example config.json
# Edit config.json: add openrouter_api_key, set relay.enabled=false

# Build and run
docker compose run --rm agent
```

### Native

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

cp config.json.example config.json
# Edit config.json with your API key

./install.sh
cd /path/to/your/project
opencode
```

---

## Configuration Reference

### Models

| Role | Purpose | Default |
|------|---------|---------|
| `orchestrator` | Main coding agent, complex tasks | `deepseek/deepseek-v3` |
| `planner` | Task planning, architecture decisions | `anthropic/claude-opus-4.5` |
| `librarian` | Code search, documentation lookup | `google/gemini-3-flash` |
| `fallback` | Backup when primary models fail | `meta-llama/llama-3.3-70b-instruct` |

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

### Preferences

| Setting | Description | Default |
|---------|-------------|---------|
| `ultrawork_max_iterations` | Max iterations in ultrawork mode | 50 |
| `dcp_turn_protection` | Turns to protect content from pruning | 2 |
| `dcp_error_retention_turns` | Turns to retain error context | 4 |
| `dcp_nudge_frequency` | How often to remind about context limits | 10 |

### Relay Settings

| Setting | Server | Client | Description |
|---------|--------|--------|-------------|
| `relay.enabled` | true | true | Enable relay mode |
| `relay.mode` | "server" | "client" | Role of this instance |
| `relay.port` | 8080 | 8080 | Port for relay service |
| `relay.allowed_paths` | [...] | - | API paths to forward (server only) |

---

## Docker Reference

### Volume Mounts

| Mount | Purpose |
|-------|---------|
| `/workspace` | Your project directory (working directory) |
| `/app/config.json` | Your `config.json` |
| `/root/.config/opencode` | Generated OpenCode configuration |
| `/root/.local/share/opencode` | Session history (SQLite) |
| `/root/.ssh` | SSH keys for tunnel/git (optional) |
| `/root/.gitconfig` | Git configuration (optional) |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | API key (alternative to config.json) |
| `CONFIG_PATH` | Custom config.json location |
| `RELAY_PORT` | Override relay port |
| `LOG_LEVEL` | Logging verbosity |

### Multi-Project Alias

```bash
# Add to ~/.bashrc or ~/.zshrc
alias sa='docker compose -f /path/to/sovereign-agent/docker-compose.yml run --rm -v $(pwd):/workspace agent'

# Use anywhere
cd ~/projects/my-app
sa
```

---

## Maintenance

### Check Submodule Status

```bash
./scripts/sync-upstream.sh status
```

### Sync with Upstream

```bash
# Sync all submodules
./scripts/sync-upstream.sh all

# Sync specific submodule
./scripts/sync-upstream.sh opencode
./scripts/sync-upstream.sh oh-my-opencode
```

### Relay Health Checks

```bash
# On server
curl http://localhost:8080/health
curl http://localhost:8080/stats

# On client (with tunnel active)
./lib/ssh-relay.sh status
```

---

## Privacy

All API calls route through OpenRouter with Zero Data Retention (ZDR) enabled:

- Your prompts and completions are not stored by OpenRouter
- Your data is not used for training
- Compliance with enterprise data policies

The relay architecture adds another layer of protection by keeping API keys off untrusted machines.

---

## Troubleshooting

### Relay Connection Issues

**Symptom**: `Relay not responding after 10 seconds`

1. Check if relay is running on server:
   ```bash
   ssh pi-relay 'cd ~/sovereign-agent/relay && ./start-relay.sh status'
   ```

2. Check SSH tunnel:
   ```bash
   ./lib/ssh-relay.sh status
   ```

3. Test relay directly on server:
   ```bash
   ssh pi-relay 'curl http://localhost:8080/health'
   ```

### SSH Tunnel Issues

**Symptom**: `SSH tunnel already running` but not working

```bash
# Force stop and restart
./lib/ssh-relay.sh stop
rm -f /tmp/sovereign-ssh-tunnel.*
./lib/ssh-relay.sh start pi-relay
```

### Docker Issues

**Symptom**: Container can't access SSH keys

```bash
# Mount SSH directory
docker compose run --rm -v ~/.ssh:/root/.ssh:ro agent ./lib/ssh-relay.sh run pi-relay
```

---

## Testing

### Run All Tests

```bash
./tests/run-tests.sh
```

### Run Specific Test Suites

```bash
# Shell script tests
./tests/test-validate.sh
./tests/test-relay.sh
./tests/test-ssh-relay.sh

# Relay TypeScript tests
cd relay && bun test

# oh-my-opencode tests
cd vendor/oh-my-opencode && bun test
```

### Current Test Stats

| Component | Tests | Status |
|-----------|-------|--------|
| Shell scripts | 401 | Passing |
| Relay TypeScript | 46 | Passing |
| oh-my-opencode | 1,016 | Passing |
| **Total** | **1,463** | **Passing** |

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run `./tests/run-tests.sh` to verify
5. Submit a pull request

---

## License

MIT License - See LICENSE file for details.

## Related Projects

- [OpenCode](https://github.com/sst/opencode) - The AI-powered coding assistant
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) - Agent orchestration framework
- [opencode-dcp](https://github.com/tarquinen/opencode-dcp) - Dynamic Context Pruning plugin
- [OpenRouter](https://openrouter.ai) - Multi-model API gateway with ZDR
