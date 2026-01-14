# Architecture

Sovereign Agent uses a relay server architecture to keep API keys secure while allowing OpenCode to run on any machine.

## Overview

```
┌──────────────────┐                      ┌──────────────┐         ┌────────────────┐
│   Work VM        │◀── reverse tunnel ──│   Laptop     │────────▶│   Pi/VPS       │
│   (container)    │     (from laptop)   │   (bridge)   │  SSH    │   (relay)      │
│                  │                     │              │         │                │
│  ┌────────────┐  │                     │              │         │ ┌────────────┐ │
│  │ OpenCode   │──┼──▶ :8081 ───────────┼──────────────┼────────▶│ │  Relay     │ │
│  └────────────┘  │                     │              │         │ │  Server    │ │
│       ▲          │                     │              │         │ └─────┬──────┘ │
│       │          │                     │              │         │       │        │
│  ┌────┴───────┐  │                     │              │         │       │ HTTPS  │
│  │ SSH tunnel │  │                     │              │         │       │ ZDR    │
│  │ to host    │  │                     │              │         │       ▼        │
│  └────────────┘  │                     │              │         │ ┌────────────┐ │
└──────────────────┘                     └──────────────┘         │ │ OpenRouter │ │
                                                                  │ └────────────┘ │
                                                                  └────────────────┘
```

## Components

### Relay Server (Pi/VPS)

The relay server runs on a trusted machine you control. It:

- Holds your OpenRouter API key securely
- Forwards authenticated requests to OpenRouter with ZDR headers
- Serves the client installation bundle
- Provides health/stats endpoints for monitoring

**Endpoints:**
| Path | Description |
|------|-------------|
| `/health` | Health check - returns `{"status":"ok"}` |
| `/stats` | Request statistics and uptime |
| `/setup` | Client setup script (bash) |
| `/bundle.tar.gz` | Streamed tarball of sovereign-agent |
| `/api/v1/*` | Proxied to OpenRouter with auth |

### Laptop (Bridge)

Your laptop bridges the Work VM and relay server using SSH tunnels:

1. **Forward tunnel to Pi**: Connects to relay server
2. **Reverse tunnel to Work VM**: Exposes relay to Work VM's localhost

This allows the Work VM to reach the relay without direct network access.

### Work VM (Client)

The Work VM runs OpenCode in client mode:

- No API key needed locally (relay handles auth)
- All requests go to `localhost:8081` (tunneled to relay)
- Can run inside a Docker container with additional tunnel to host

## Data Flow

1. **OpenCode** makes API request to `localhost:8081`
2. Request travels through **container→host SSH tunnel** (if containerized)
3. Request travels through **reverse tunnel** to laptop
4. Laptop forwards through **SSH tunnel** to Pi relay
5. **Relay server** adds API key and ZDR headers
6. Request sent to **OpenRouter** over HTTPS
7. Response travels back through the same path

## Security Model

| Layer | Protection |
|-------|------------|
| API Key | Never leaves relay server |
| Transport | SSH tunnels (encrypted) |
| API Calls | OpenRouter ZDR mode (no data retention) |
| Client Auth | Tunnel access only (no credentials stored) |

## Port Conventions

| Port | Location | Purpose |
|------|----------|---------|
| 8081 | Relay server | Relay listens here |
| 8081 | Work VM host | Reverse tunnel endpoint |
| 8081 | Container | SSH tunnel to host |

All ports configurable via `RELAY_PORT` environment variable.

## Configuration Files

### Server Config (`config.json`)

```json
{
  "openrouter_api_key": "sk-or-v1-...",
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8081
  }
}
```

### Client Config (`config.json`)

```json
{
  "openrouter_api_key": "",
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8081
  }
}
```

Note: Client doesn't need API key - relay injects it.

## See Also

- [Relay Setup](RELAY-SETUP.md) - Detailed relay server configuration
- [Alternative Setups](ALTERNATIVE-SETUPS.md) - Other deployment patterns
- [Configuration Reference](CONFIGURATION.md) - All config options
