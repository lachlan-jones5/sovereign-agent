# Architecture

Sovereign Agent uses a relay server architecture to keep API credentials secure while allowing OpenCode to run on any machine. The relay authenticates via GitHub Copilot OAuth.

## Overview

```
┌──────────────────┐                      ┌──────────────┐         ┌────────────────┐
│   Client VM      │◀── reverse tunnel ──│   Laptop     │────────▶│   Pi/VPS       │
│   (container)    │     (from laptop)   │   (bridge)   │  SSH    │   (relay)      │
│                  │                     │              │         │                │
│  ┌────────────┐  │                     │              │         │ ┌────────────┐ │
│  │ OpenCode   │──┼──▶ :8080 ───────────┼──────────────┼────────▶│ │  Relay     │ │
│  └────────────┘  │                     │              │         │ │  Server    │ │
│       ▲          │                     │              │         │ └─────┬──────┘ │
│       │          │                     │              │         │       │        │
│  ┌────┴───────┐  │                     │              │         │       │ HTTPS  │
│  │ SSH tunnel │  │                     │              │         │       │        │
│  │ to host    │  │                     │              │         │       ▼        │
│  └────────────┘  │                     │              │         │ ┌────────────┐ │
└──────────────────┘                     └──────────────┘         │ │  GitHub    │ │
                                                                  │ │  Copilot   │ │
                                                                  │ └────────────┘ │
                                                                  └────────────────┘
```

## Components

### Relay Server (Pi/VPS)

The relay server runs on a trusted machine you control. It:

- Handles GitHub OAuth via device code flow
- Caches and auto-refreshes Copilot API tokens (30-minute expiry)
- Forwards authenticated requests to GitHub Copilot API
- Serves the client installation bundle
- Tracks premium request usage with model multipliers

**Endpoints:**
| Path | Description |
|------|-------------|
| `/health` | Health check - returns `{"status":"ok"}` |
| `/stats` | Request statistics, uptime, premium usage |
| `/auth/device` | Start GitHub device code flow |
| `/auth/poll` | Poll for device code completion |
| `/auth/status` | Check authentication status |
| `/setup` | Client setup script (bash) |
| `/bundle.tar.gz` | Streamed tarball of sovereign-agent |
| `/v1/*` | Proxied to GitHub Copilot API |

### Laptop (Bridge)

Your laptop bridges the Client VM and relay server using SSH tunnels:

1. **Forward tunnel to Pi**: Connects to relay server
2. **Reverse tunnel to Client VM**: Exposes relay to Client VM's localhost

This allows the Client VM to reach the relay without direct network access.

### Client VM (Client)

The Client VM runs OpenCode in client mode:

- No API credentials needed locally (relay handles auth)
- All requests go to `localhost:8080` (tunneled to relay)
- Can run inside a Docker container with additional tunnel to host

## Data Flow

1. **OpenCode** makes API request to `localhost:8080`
2. Request travels through **container→host SSH tunnel** (if containerized)
3. Request travels through **reverse tunnel** to laptop
4. Laptop forwards through **SSH tunnel** to Pi relay
5. **Relay server** adds Copilot API token
6. Request sent to **GitHub Copilot API** over HTTPS
7. Response travels back through the same path

## Security Model

| Layer | Protection |
|-------|------------|
| OAuth Token | Never leaves relay server |
| Copilot Token | Cached in memory only, never written to disk |
| Transport | SSH tunnels (encrypted) |
| Client Auth | Tunnel access only (no credentials stored) |

## Port Conventions

| Port | Location | Purpose |
|------|----------|---------|
| 8080 | Relay server | Relay listens here |
| 8080 | Client VM host | Reverse tunnel endpoint |
| 8080 | Container | SSH tunnel to host |

All ports configurable via `RELAY_PORT` environment variable.

## Configuration Files

### Server Config (`config.json`)

```json
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
```

After OAuth authentication, the relay stores `github_oauth_token` in config.json automatically.

### Client Config

Clients don't need a config file - the relay generates OpenCode config via the `/setup` endpoint.

## GitHub Copilot Authentication

The relay uses GitHub's device code OAuth flow:

1. Visit `/auth/device` on the relay server
2. You get a user code and link to `github.com/login/device`
3. Enter the code in your browser and authorize
4. Relay stores OAuth token and exchanges it for Copilot API token
5. Copilot token is cached (30min expiry) with auto-refresh

## Premium Request Tracking

GitHub Copilot uses a premium request multiplier system:

| Model | Multiplier | Cost per request |
|-------|------------|------------------|
| gpt-5-mini, gpt-4.1, gpt-4o | 0x | Free |
| claude-haiku-4.5 | 0.25x | 1/4 premium |
| claude-sonnet-4.5 | 1x | 1 premium |
| claude-opus-4.5 | 3x | 3 premium |

Check `/stats` endpoint to monitor premium request usage.

## See Also

- [Relay Setup](RELAY-SETUP.md) - Detailed relay server configuration
- [Models](MODELS.md) - Available models and multipliers
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
