# Sovereign Agent

Privacy-compliant AI coding environment. Keep your API keys secure on a trusted machine while running [OpenCode](https://github.com/sst/opencode) anywhere.

```
┌──────────────┐                     ┌──────────────┐         ┌────────────┐
│   Work VM    │◀── reverse tunnel ──│   Laptop     │────────▶│  Pi/VPS    │
│   OpenCode   │     (from laptop)   │   (bridge)   │  SSH    │  (relay)   │
└──────────────┘                     └──────────────┘         └────────────┘
                                                                    │
                                                               HTTPS│ZDR
                                                                    ▼
                                                              ┌────────────┐
                                                              │ OpenRouter │
                                                              └────────────┘
```

## Quick Start

### 1. Set up the relay server (Pi/VPS)

```bash
OPENROUTER_API_KEY=sk-or-v1-... bash <(curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh)
```

### 2. Create tunnels (laptop)

```bash
# Tunnel laptop → Pi (forward)
ssh -L 8081:127.0.0.1:8081 pi@your-relay.example.com -N &

# Tunnel laptop → Work VM (reverse)
ssh -R 8081:localhost:8081 workvm -N &
```

### 3. Install client (Work VM)

```bash
curl -fsSL http://localhost:8081/setup | bash
```

### 4. Run OpenCode

```bash
cd your-project
opencode
```

## How It Works

Your laptop bridges two SSH tunnels:
- **Forward tunnel** to the relay server (Pi/VPS)
- **Reverse tunnel** to your Work VM

The Work VM sees `localhost:8081` which routes through your laptop to the relay. The relay adds your API key and forwards to OpenRouter with ZDR (Zero Data Retention).

**Key benefit:** API keys never touch the Work VM.

## If Work VM Runs Docker

If your dev environment is inside a container, you need one more tunnel from the container to the host:

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
| [Configuration](docs/CONFIGURATION.md) | All config options |
| [Alternative Setups](docs/ALTERNATIVE-SETUPS.md) | Direct tunnel, standalone, VPS |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and fixes |

## One-liner Reference

| Task | Command |
|------|---------|
| Setup relay (interactive) | `bash <(curl -fsSL .../scripts/setup-relay.sh)` |
| Setup relay (with key) | `OPENROUTER_API_KEY=... bash <(curl -fsSL .../scripts/setup-relay.sh)` |
| Install client | `curl -fsSL http://localhost:8081/setup \| bash` |
| Check relay health | `curl http://localhost:8081/health` |
| View relay stats | `curl http://localhost:8081/stats` |

## Privacy

All API calls use OpenRouter's Zero Data Retention (ZDR) mode:
- Prompts and completions are not stored
- Your data is not used for training
- API keys never leave the relay server

## Related Projects

- [OpenCode](https://github.com/sst/opencode) - AI coding assistant
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) - Agent framework
- [opencode-dcp](https://github.com/tarquinen/opencode-dcp) - Context pruning
- [OpenRouter](https://openrouter.ai) - Multi-model API with ZDR

## License

MIT
