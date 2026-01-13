# Sovereign Agent

Privacy-compliant agentic software engineering environment combining [OpenCode](https://github.com/sst/opencode), [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode), and [opencode-dcp](https://github.com/tarquinen/opencode-dcp) with OpenRouter's Zero Data Retention (ZDR) mode.

## Overview

Sovereign Agent uses a **relay server** to keep your API keys secure on a trusted machine while running OpenCode on any workstation (like a work VM). This is ideal for:

- **Remote work**: Run AI coding on a work VM while keeping keys on your personal device
- **Network isolation**: Route API traffic through a trusted server to avoid monitoring
- **Team deployments**: Centralized API key management with per-user access control

```
┌──────────────┐                      ┌──────────────┐         ┌────────────┐
│   Work VM    │◀── reverse tunnel ──│   Laptop     │────────▶│   Pi/VPS   │
│   OpenCode   │     (from laptop)   │   (bridge)   │  SSH    │   relay    │
│   :8080      │                     │              │         │   :8080    │
└──────────────┘                     └──────────────┘         └────────────┘
                                                                    │
                                                               HTTPS│ZDR
                                                                    ▼
                                                              ┌────────────┐
                                                              │ OpenRouter │
                                                              │    API     │
                                                              └────────────┘
```

**Key insight**: Your laptop can SSH to both machines, so it acts as a bridge using a **reverse tunnel**. The Work VM downloads everything through the tunnel - no direct internet access to GitHub needed.

## Quick Start

### Step 1: Set Up the Relay Server

On your trusted machine (Pi, home server, VPS):

```bash
# One-liner setup (prompts for API key)
curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash
```

Or manually:

```bash
git clone https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent
cp config.json.example config.json
# Edit config.json: add your openrouter_api_key

# Start the relay
docker compose -f docker-compose.relay.yml up -d   # Docker
# OR: cd relay && ./start-relay.sh daemon          # Native (requires Bun)
```

Verify it's running:
```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

### Step 2: Create a Reverse Tunnel from Your Laptop

Your laptop bridges the Work VM and the relay server. Run this **on your laptop**:

```bash
# Using the helper script (if you have the repo cloned)
./scripts/tunnel.sh workvm pi-hostname

# Or directly
ssh -R 8080:pi-hostname:8080 workvm -N
```

Replace:
- `pi-hostname` - hostname/IP of your relay server (as reachable from your laptop)
- `workvm` - your Work VM's SSH host

**What this does:**
- Makes port 8080 on the Work VM forward through your laptop to the relay
- `-N` - Just create the tunnel, don't open a shell

### Step 3: Set Up the Work VM (via tunnel)

With the tunnel running, the Work VM can download everything through `localhost:8080` - no direct internet access to GitHub needed.

On the Work VM:

```bash
# Download and run setup through the tunnel
curl -fsSL http://localhost:8080/setup | bash
```

This downloads the sovereign-agent bundle from your relay server, installs OpenCode, and configures everything.

**What happens:**
1. `curl localhost:8080/setup` - Gets setup script from relay (through tunnel)
2. Script calls `curl localhost:8080/bundle.tar.gz` - Downloads fresh repo bundle
3. Runs `install.sh` - Installs OpenCode with agents, plugins, etc.
```

### Step 4: Run OpenCode

With the reverse tunnel running (Step 2), just run OpenCode on the Work VM:

```bash
opencode
```

All API requests go through `localhost:8080` → your laptop → relay server → OpenRouter.

---

## Persistent Tunnel Setup

Instead of manually running the SSH command, create a script or use autossh:

**On your laptop**, create `~/bin/relay-tunnel.sh`:

```bash
#!/bin/bash
# Tunnel Work VM :8080 to Pi relay :8080
autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
    -R 8080:pi-hostname:8080 workvm -N
```

Or add to your laptop's `~/.ssh/config`:

```ssh-config
Host workvm-relay
    HostName workvm-ip-or-hostname
    User youruser
    RemoteForward 8080 pi-hostname:8080
    ServerAliveInterval 30
```

Then just: `ssh workvm-relay -N`

---

## Server Setup (Detailed)

The **relay server** holds your API keys and forwards authenticated requests to OpenRouter. Run this on a trusted machine.

> **Note**: The server only needs the core repo - no submodules required. Clone with `git clone https://github.com/lachlan-jones5/sovereign-agent.git` (fast, ~100KB).

### Server Configuration

Create `config.json` with your API key and relay settings:

```json
{
  "openrouter_api_key": "sk-or-v1-your-api-key-here",
  "site_url": "https://github.com/lachlan-jones5/sovereign-agent",
  "site_name": "SovereignAgent",

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

The **client** (Work VM) runs OpenCode and connects to the relay via a reverse tunnel from your laptop.

### What You Need on the Work VM

With the reverse tunnel approach, the Work VM only needs:
1. OpenCode installed
2. OpenCode configured to use `localhost:8080` as the API endpoint

**That's it.** No SSH keys to the relay, no sovereign-agent repo (unless you want the installer).

### Installing OpenCode

**Option A: Use sovereign-agent's installer** (recommended)

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent
cp config.client.example config.json
./install.sh
```

**Option B: Install OpenCode directly**

Follow the [OpenCode installation guide](https://github.com/sst/opencode#installation), then configure it to use the relay:

Edit `~/.config/opencode/config.json`:
```json
{
  "provider": {
    "openrouter": {
      "baseURL": "http://localhost:8080/api/v1"
    }
  }
}
```

### Running OpenCode

1. Make sure the reverse tunnel is running (from your laptop - see Quick Start Step 2)
2. Verify the tunnel works:
   ```bash
   curl http://localhost:8080/health
   # Should return: {"status":"ok"}
   ```
3. Run OpenCode:
   ```bash
   opencode
   ```

---

## Alternative: Direct SSH Tunnel (Advanced)

If the Work VM can directly SSH to the relay server (has network access and SSH keys), you can skip the reverse tunnel and use a direct tunnel instead.

**On the Work VM**, add to `~/.ssh/config`:

```ssh-config
Host relay
    HostName pi.local
    User pi
    IdentityFile ~/.ssh/pi_key
```

Then use the included tunnel script:

```bash
./lib/ssh-relay.sh run relay
```

This creates a forward tunnel (`-L`) from the Work VM to the relay.

---

## Standalone Mode (No Relay)

If you don't need the relay architecture, you can run sovereign-agent directly with the API key on the same machine.

### Docker

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create config with API key
cp config.json.example config.json
# Edit config.json: add openrouter_api_key, set relay.enabled=false

# Build and run
docker compose run --rm agent
```

### Native

```bash
git clone --recurse-submodules --shallow-submodules https://github.com/lachlan-jones5/sovereign-agent.git
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

### Port Already in Use

**Symptom**: `Bind for 127.0.0.1:8080 failed: port is already allocated`

Something else is using port 8080. First, find what's using it:

```bash
sudo lsof -i :8080
# or
sudo ss -tlnp | grep 8080
```

Then either stop the conflicting service, or use a different port:

```bash
# Stop and remove any existing relay container
docker compose -f docker-compose.relay.yml down

# Start with a different port (e.g., 8081)
RELAY_PORT=8081 docker compose -f docker-compose.relay.yml up -d

# Verify it's running
curl http://localhost:8081/health
```

Remember to use the new port when connecting from the client:

```bash
# On client, forward to the new port
ssh -L 8081:localhost:8081 pi-relay
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
