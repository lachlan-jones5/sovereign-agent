# Relay Server Setup

Detailed guide for setting up the relay server on your trusted machine.

## Prerequisites

- A trusted machine (Raspberry Pi, home server, VPS)
- Network access to the machine from your laptop
- Docker (recommended) or Bun runtime

## Quick Setup (One-liner)

```bash
# Interactive - prompts for API key
curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash

# Non-interactive
OPENROUTER_API_KEY=sk-or-v1-... \
RELAY_PORT=8081 \
curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash
```

## Manual Setup

### 1. Clone the Repository

```bash
git clone https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent
```

Note: Server setup doesn't need submodules (fast, ~100KB clone).

### 2. Create Configuration

```bash
cp config.json.example config.json
```

Edit `config.json`:

```json
{
  "openrouter_api_key": "sk-or-v1-your-key-here",
  "site_url": "https://github.com/yourusername/sovereign-agent",
  "site_name": "SovereignAgent",

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

### 3. Start the Relay

**With Docker (recommended):**

```bash
RELAY_HOST=0.0.0.0 RELAY_PORT=8081 docker compose -f docker-compose.relay.yml up -d
```

**Native (requires Bun):**

```bash
cd relay
RELAY_HOST=0.0.0.0 RELAY_PORT=8081 ./start-relay.sh daemon
```

### 4. Verify

```bash
curl http://localhost:8081/health
# {"status":"ok"}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RELAY_HOST` | `127.0.0.1` | Bind address (`0.0.0.0` for external access) |
| `RELAY_PORT` | `8080` | Port to listen on |
| `CONFIG_PATH` | `../config.json` | Path to config file |
| `LOG_LEVEL` | `info` | Log level: debug, info, warn, error |
| `OPENROUTER_API_KEY` | - | API key (alternative to config.json) |

## Docker Configuration

The `docker-compose.relay.yml` file:

```yaml
services:
  relay:
    build:
      context: .
      dockerfile: Dockerfile.relay
    container_name: sovereign-relay
    restart: unless-stopped
    ports:
      - "${RELAY_HOST:-127.0.0.1}:${RELAY_PORT:-8081}:${RELAY_PORT:-8081}"
    volumes:
      - ./config.json:/app/config.json:ro
    environment:
      - RELAY_PORT=${RELAY_PORT:-8081}
      - RELAY_HOST=0.0.0.0
      - LOG_LEVEL=info
```

### Docker Commands

```bash
# Start
docker compose -f docker-compose.relay.yml up -d

# View logs
docker compose -f docker-compose.relay.yml logs -f

# Restart
docker compose -f docker-compose.relay.yml restart

# Stop
docker compose -f docker-compose.relay.yml down

# Rebuild (after updates)
git pull
docker compose -f docker-compose.relay.yml build --no-cache
docker compose -f docker-compose.relay.yml up -d
```

## Native Setup

### Install Bun

```bash
curl -fsSL https://bun.sh/install | bash
```

### Start Commands

```bash
cd relay

# Foreground (for testing)
./start-relay.sh

# Background daemon
./start-relay.sh daemon

# Check status
./start-relay.sh status

# View logs
tail -f /tmp/sovereign-relay.log

# Stop
./start-relay.sh stop
```

## Firewall Configuration

If you have a firewall, allow the relay port:

**nftables:**
```bash
nft add rule inet filter input tcp dport 8081 accept
```

**ufw:**
```bash
ufw allow 8081/tcp
```

**iptables:**
```bash
iptables -A INPUT -p tcp --dport 8081 -j ACCEPT
```

## Security Considerations

1. **Bind to 0.0.0.0 only if needed** - Use `127.0.0.1` if clients connect via SSH tunnel to localhost
2. **Use SSH tunnels** - Even on trusted networks, SSH adds encryption
3. **Keep API key in config.json** - Don't commit to git (it's in .gitignore)
4. **Restrict network access** - Firewall the port to known IPs if possible

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Returns `{"status":"ok"}` |
| `/stats` | GET | Request stats, uptime, version |
| `/setup` | GET | Bash script for client setup |
| `/bundle.tar.gz` | GET | Streamed tarball of repo |
| `/api/v1/*` | ALL | Proxied to OpenRouter |

## Monitoring

Check relay status:

```bash
# Health
curl http://localhost:8081/health

# Stats
curl http://localhost:8081/stats | jq
```

Example stats output:
```json
{
  "uptime": 3600,
  "requests": {
    "total": 150,
    "success": 148,
    "error": 2
  },
  "version": "1.0.0"
}
```

## Troubleshooting

### Port already in use

```bash
# Find what's using the port
ss -tlnp | grep 8081

# Kill existing relay
docker stop sovereign-relay
# or
pkill -f 'bun.*main.ts'
```

### Container won't start

```bash
# Check logs
docker logs sovereign-relay

# Verify config.json is valid JSON
jq . config.json
```

### Can't connect from laptop

1. Check firewall allows port 8081
2. Verify `RELAY_HOST=0.0.0.0` is set
3. Test locally first: `curl http://localhost:8081/health`

## See Also

- [Architecture](ARCHITECTURE.md) - System overview
- [Alternative Setups](ALTERNATIVE-SETUPS.md) - Other deployment patterns
