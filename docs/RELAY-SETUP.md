# Relay Server Setup

Detailed guide for setting up the relay server on your trusted machine with GitHub Copilot authentication.

## Prerequisites

- A trusted machine (Raspberry Pi, home server, VPS)
- Network access to the machine from your laptop
- Docker (recommended) or Bun runtime
- GitHub Copilot subscription (Pro or Pro+)

## Quick Setup

### 1. Clone and Start Relay

```bash
# Clone the repository
git clone https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create minimal config
cat > config.json << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
EOF

# Start relay (with Docker)
docker compose -f docker-compose.relay.yml up -d

# Or start natively (requires Bun)
cd relay && bun run main.ts
```

### 2. Authenticate with GitHub Copilot

**Option A: Headless (CLI) - for servers without a browser:**

```bash
./scripts/auth-relay.sh
```

This will display a user code and URL. Go to `https://github.com/login/device` on any device, enter the code, and authorize. The script polls for completion and saves the token automatically.

**Option B: Browser - if you have access to a browser:**

```
http://localhost:8080/auth/device
```

You'll see a page with:
- A **user code** (e.g., `ABCD-1234`)
- A link to `https://github.com/login/device`

1. Click the GitHub link or go to `https://github.com/login/device`
2. Enter the user code
3. Authorize "GitHub Copilot" access
4. Return to the relay page - it will show "Authentication successful"

The OAuth token is now saved in `config.json`.

### 3. Install Client on VM

From your Client VM (via SSH tunnel):

```bash
curl -fsSL http://localhost:8080/setup | bash
```

This downloads sovereign-agent, installs OpenCode, and configures it to use the relay.

## Manual Setup

### 1. Clone the Repository

```bash
git clone https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent
```

### 2. Create Configuration

```bash
cp config.json.example config.json
```

Edit `config.json`:

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
```

Note: `github_oauth_token` will be added automatically after device code auth.

### 3. Start the Relay

**With Docker (recommended):**

```bash
RELAY_HOST=0.0.0.0 RELAY_PORT=8080 docker compose -f docker-compose.relay.yml up -d
```

**Native (requires Bun):**

```bash
cd relay
RELAY_HOST=0.0.0.0 RELAY_PORT=8080 bun run main.ts
```

### 4. Verify

```bash
curl http://localhost:8080/health
# {"status":"ok","authenticated":false}
```

### 5. Authenticate

```bash
# Start device code flow
curl http://localhost:8080/auth/device

# Or visit in browser for a nicer UI
open http://localhost:8080/auth/device
```

After authentication:

```bash
curl http://localhost:8080/health
# {"status":"ok","authenticated":true}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RELAY_HOST` | `127.0.0.1` | Bind address (`0.0.0.0` for external access) |
| `RELAY_PORT` | `8080` | Port to listen on |
| `CONFIG_PATH` | `../config.json` | Path to config file |
| `LOG_LEVEL` | `info` | Log level: debug, info, warn, error |
| `DATA_CAPTURE_ENABLED` | `false` | Enable request/response capture for fine-tuning |
| `DATA_CAPTURE_PATH` | `../data/captures.jsonl` | Local JSONL file for captured sessions |
| `DATA_CAPTURE_FORWARD_URL` | (none) | URL to forward captures (e.g., `http://localhost:9090/data/ingest`) |

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
      - "${RELAY_HOST:-127.0.0.1}:${RELAY_PORT:-8080}:${RELAY_PORT:-8080}"
    volumes:
      - ./config.json:/app/config.json:rw
    environment:
      - RELAY_PORT=${RELAY_PORT:-8080}
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
bun run main.ts

# Background with start script
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
nft add rule inet filter input tcp dport 8080 accept
```

**ufw:**
```bash
ufw allow 8080/tcp
```

**iptables:**
```bash
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

## Security Considerations

1. **Bind to 0.0.0.0 only if needed** - Use `127.0.0.1` if clients connect via SSH tunnel to localhost
2. **Use SSH tunnels** - Even on trusted networks, SSH adds encryption
3. **OAuth token stays on relay** - Never leaves the server, never sent to clients
4. **Copilot token in memory only** - Not written to disk, auto-refreshed
5. **Restrict network access** - Firewall the port to known IPs if possible

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Returns `{"status":"ok","authenticated":bool}` |
| `/stats` | GET | Request stats, uptime, premium usage, data capture status |
| `/auth/device` | GET/POST | Start device code flow |
| `/auth/poll` | POST | Poll for auth completion |
| `/auth/status` | GET | Check auth status |
| `/setup` | GET | Bash script for client setup |
| `/bundle.tar.gz` | GET | Streamed tarball of repo |
| `/data/stats` | GET | Data capture statistics |
| `/data/recent` | GET | Recent captures (use `?limit=N`) |
| `/data/export` | GET | Download all captures as JSONL |
| `/data/ingest` | POST | Receive forwarded captures from remote relays |
| `/v1/*` | ALL | Proxied to GitHub Copilot API |

## Monitoring

Check relay status:

```bash
# Health
curl http://localhost:8080/health

# Stats (includes premium request usage)
curl http://localhost:8080/stats | jq
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
  "premiumRequests": {
    "used": 87.5,
    "limit": 300
  },
  "version": "2.0.0"
}
```

## Token Refresh

The relay automatically handles Copilot token management:

1. OAuth token stored in `config.json` (permanent until revoked)
2. Copilot API token exchanged on demand (30-minute expiry)
3. Token cached in memory, refreshed 5 minutes before expiry
4. If OAuth token revoked, re-authenticate via `/auth/device`

## Re-authentication

If you need to re-authenticate (e.g., token revoked):

```bash
# Check current status
curl http://localhost:8080/auth/status

# Start new device code flow
curl -X POST http://localhost:8080/auth/device

# Or visit in browser
open http://localhost:8080/auth/device
```

## See Also

- [Architecture](ARCHITECTURE.md) - System overview
- [Models](MODELS.md) - Available models and multipliers
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Data Capture](DATA-CAPTURE.md) - Collecting training data for fine-tuning
