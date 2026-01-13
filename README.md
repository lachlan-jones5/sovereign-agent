# Sovereign Agent

Privacy-compliant agentic software engineering environment combining [OpenCode](https://github.com/sst/opencode), [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode), and [opencode-dcp](https://github.com/tarquinen/opencode-dcp) with OpenRouter's Zero Data Retention (ZDR) mode.

## Features

- **Single Configuration**: One `config.json` file for all secrets and model assignments
- **Privacy-First**: All models route through OpenRouter with ZDR enabled
- **Role-Based Models**: Assign different models to orchestrator, planner, librarian, and fallback roles
- **DCP Awareness**: Agents understand context pruning constraints for optimal performance
- **Upstream Sync**: Easy rebasing on upstream repositories while preserving modifications

## Quick Start

### Option A: Docker (Recommended)

The easiest way to get started:

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# Create config with your API key
cp config.json.example config.json
# Edit config.json with your OpenRouter API key

# Build and run
docker compose run --rm agent
```

See [Docker Usage](#docker-usage) for more options.

### Option B: Native Installation

#### 1. Clone with submodules

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent
```

#### 2. Create your configuration

```bash
cp config.json.example config.json
```

Edit `config.json` with your OpenRouter API key and model preferences:

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

  "preferences": {
    "ultrawork_max_iterations": 50,
    "dcp_turn_protection": 2,
    "dcp_error_retention_turns": 4,
    "dcp_nudge_frequency": 10
  }
}
```

#### 3. Run the installer

```bash
./install.sh
```

#### 4. Start coding

```bash
cd /path/to/your/project
opencode
```

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

## Installer Options

```bash
./install.sh [OPTIONS]

Options:
  -c, --config FILE    Path to config.json (default: ./config.json)
  -d, --dest DIR       OpenCode config directory (default: ~/.config/opencode)
  -s, --skip-deps      Skip dependency installation
  -h, --help           Show help message
```

## Generated Files

The installer generates three configuration files in `~/.config/opencode/`:

| File | Purpose |
|------|---------|
| `opencode.json` | Main OpenCode configuration with provider settings |
| `dcp.jsonc` | Dynamic Context Pruning settings |
| `oh-my-opencode.json` | Agent orchestration configuration |

## Commands

Once installed, use these commands in OpenCode:

| Command | Description |
|---------|-------------|
| `/ulw <task>` | Start ultrawork mode for complex tasks |
| `/init-deep` | Initialize deep context for the project |

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

After syncing, push to your forks:

```bash
cd vendor/opencode && git push origin main --force-with-lease
cd ../oh-my-opencode && git push origin dev --force-with-lease
```

## Privacy

All API calls route through OpenRouter with Zero Data Retention (ZDR) enabled:

- Your prompts and completions are not stored by OpenRouter
- Your data is not used for training
- Compliance with enterprise data policies

The `site_url` and `site_name` fields are sent to OpenRouter for attribution but contain no sensitive data.

## SSH Relay Mode

For environments where you want to route API traffic through a trusted server (e.g., to avoid network monitoring), sovereign-agent supports a client-server relay architecture.

### Architecture

```
Work VM (client)      Laptop (jump)       Pi (server)         OpenRouter
     │                    │                   │                   │
     │─── SSH tunnel ────▶│                   │                   │
     │                    │─── SSH tunnel ───▶│                   │
     │                    │                   │─── HTTPS ────────▶│
```

- **Server (Pi)**: Has config.json with API key, runs relay service
- **Client (Work VM)**: Runs OpenCode, connects via SSH tunnel
- **Jump Host (Laptop)**: Optional SSH proxy for routing

### Quick Setup

#### On Server (Pi)

```bash
# Setup sovereign-agent with your API key
cp config.json.example config.json
# Edit config.json: set openrouter_api_key, relay.enabled=true, relay.mode=server

# Start the relay
cd relay
./start-relay.sh daemon
```

#### On Client (Work VM)

```bash
# Setup with client config
cp config.client.example config.json
./install.sh

# Connect via SSH tunnel and run OpenCode
./lib/ssh-relay.sh run pi-relay
```

### Configuration

**Server mode** (`config.json` on Pi):
```json
{
  "openrouter_api_key": "sk-or-v1-your-key",
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
```

**Client mode** (`config.json` on Work VM):
```json
{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8080
  }
}
```

### SSH Configuration

Add to `~/.ssh/config` on Work VM:

```ssh-config
Host laptop
    HostName laptop.local
    User youruser
    IdentityFile ~/.ssh/laptop_key

Host pi-relay
    HostName pi.local               # Pi's address (from laptop's perspective)
    User pi
    ProxyJump laptop                # Route through laptop
    IdentityFile ~/.ssh/pi_key
    ServerAliveInterval 30
```

### Multi-Hop Configurations

SSH's `ProxyJump` supports chaining through multiple nodes. The relay architecture is SSH-agnostic - it only requires a tunnel to the relay service.

**Two-hop example** (Work VM → Laptop → Pi):
```ssh-config
Host pi-relay
    HostName pi.local
    ProxyJump laptop
```

**Three-hop example** (Work VM → Bastion → Laptop → Pi):
```ssh-config
Host pi-relay
    HostName pi.local
    ProxyJump bastion,laptop
```

**Direct connection** (Work VM → Pi, no jump host):
```ssh-config
Host pi-relay
    HostName your-pi.duckdns.org
    Port 22
```

The tunnel command remains the same regardless of hops:
```bash
./lib/ssh-relay.sh run pi-relay
```

### Relay Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `start-relay.sh` | Server (Pi) | Start/stop the API relay service |
| `ssh-relay.sh` | Client (Work VM) | Manage SSH tunnel and run OpenCode |

**Server commands:**
```bash
cd relay
./start-relay.sh daemon    # Start in background
./start-relay.sh status    # Check status
./start-relay.sh stop      # Stop relay
```

**Client commands:**
```bash
./lib/ssh-relay.sh run pi-relay      # Start tunnel + OpenCode
./lib/ssh-relay.sh start pi-relay    # Start tunnel only
./lib/ssh-relay.sh status            # Check tunnel status
./lib/ssh-relay.sh stop              # Stop tunnel
```

## Docker Usage

### Building the Image

```bash
docker build -t sovereign-agent .
```

Or with docker compose:

```bash
docker compose build
```

### Running with Docker Compose (Recommended)

```bash
# Interactive session in current directory
docker compose run --rm agent

# Work on a different project
docker compose run --rm -v /path/to/project:/workspace agent

# Shell access for debugging
docker compose run --rm agent bash

# Re-run installer after config changes
docker compose run --rm agent --install --skip-deps
```

### Running with Docker Directly

```bash
# Basic usage - mount project and config
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ./config.json:/app/config.json:ro \
  sovereign-agent

# With persistent configuration
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ./config.json:/app/config.json:ro \
  -v sovereign-config:/root/.config/opencode \
  -v sovereign-data:/root/.local/share/opencode \
  sovereign-agent

# Shell access
docker run -it --rm sovereign-agent bash
```

### Volume Mounts

| Mount | Purpose |
|-------|---------|
| `/workspace` | Your project directory (working directory) |
| `/app/config.json` | Your `config.json` with API key |
| `/root/.config/opencode` | Generated OpenCode configuration |
| `/root/.local/share/opencode` | Session history (SQLite) |
| `/root/.ssh` | SSH keys for git operations (optional) |
| `/root/.gitconfig` | Git configuration (optional) |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | API key (alternative to config.json) |
| `CONFIG_PATH` | Custom config.json location |

### Multi-Project Setup

For working on multiple projects:

```bash
# Create an alias
alias sa='docker compose -f /path/to/sovereign-agent/docker-compose.yml run --rm -v $(pwd):/workspace agent'

# Use anywhere
cd ~/projects/my-app
sa
```

---

# Developer Guide

## Project Structure

```
sovereign-agent/
├── install.sh                      # Main installer script
├── config.json.example             # User configuration template
├── README.md                       # This file
├── Dockerfile                      # Multi-stage Docker build
├── docker-compose.yml              # Docker Compose configuration
├── .dockerignore                   # Docker build exclusions
├── lib/
│   ├── check-deps.sh               # Dependency installer (curl, jq, Go, Bun)
│   ├── validate.sh                 # Configuration validator
│   └── generate-configs.sh         # Config file generator
├── templates/
│   ├── opencode.json.tmpl          # OpenCode config template
│   ├── dcp.jsonc.tmpl              # DCP config template
│   └── oh-my-opencode.json.tmpl    # oh-my-opencode config template
├── scripts/
│   └── sync-upstream.sh            # Upstream sync utility
├── tests/
│   ├── run-tests.sh                # Test runner
│   ├── test-validate.sh            # Validation tests
│   ├── test-generate-configs.sh    # Config generation tests
│   ├── test-check-deps.sh          # Dependency check tests
│   ├── test-install.sh             # Installer tests
│   └── test-sync-upstream.sh       # Sync script tests
└── vendor/
    ├── opencode/                   # Forked OpenCode submodule
    └── oh-my-opencode/             # Forked oh-my-opencode submodule
```

## Architecture

### Build Pipeline

```
config.json (user secrets)
       │
       ▼
   validate.sh (check required fields)
       │
       ▼
   check-deps.sh (install/build dependencies)
       │
       ├── curl, jq (system packages)
       ├── Go → builds vendor/opencode
       └── Bun → builds vendor/oh-my-opencode
       │
       ▼
   generate-configs.sh (template substitution)
       │
       ├── opencode.json.tmpl → ~/.config/opencode/opencode.json
       ├── dcp.jsonc.tmpl → ~/.config/opencode/dcp.jsonc
       └── oh-my-opencode.json.tmpl → ~/.config/opencode/oh-my-opencode.json
```

### oh-my-opencode Modifications

The forked oh-my-opencode includes sovereign-agent integration:

**New modules in `src/config/`:**

1. **`sovereign-config.ts`** - Unified config loader
   - Loads `config.json` from multiple locations
   - Maps agent names to model roles
   - Exports: `loadSovereignConfig()`, `getModelForAgent()`, `getModelForRole()`

2. **`dcp-prompts.ts`** - DCP awareness prompts
   - Provides context management instructions to agents
   - Role-specific variants (orchestrator, researcher, planner)
   - Exports: `getDCPPromptForAgent()`, `getDCPPromptForRole()`

**Modified agent files:**
- All 7 agents use `getModelForAgent()` instead of hardcoded models
- Orchestrator agents (Sisyphus, oracle) inject DCP awareness prompts

## Development Setup

### Prerequisites

- Git
- Bash 4.0+
- Go 1.21+ (for building OpenCode)
- Bun 1.0+ (for building oh-my-opencode)
- jq (for JSON processing)

### Clone and Initialize

```bash
git clone --recursive https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

# If submodules weren't cloned
git submodule update --init --recursive
```

### Configure Upstream Remotes

The submodules should already have upstream configured:

```bash
# Verify
cd vendor/opencode
git remote -v
# Should show:
#   origin    https://github.com/lachlan-jones5/opencode.git
#   upstream  https://github.com/sst/opencode.git

cd ../oh-my-opencode
git remote -v
# Should show:
#   origin    https://github.com/lachlan-jones5/oh-my-opencode.git
#   upstream  https://github.com/code-yeongyu/oh-my-opencode.git
```

## Testing

### Run All Tests

```bash
./tests/run-tests.sh
```

### Run Specific Test Suites

```bash
# Shell script tests
./tests/test-validate.sh
./tests/test-generate-configs.sh
./tests/test-check-deps.sh
./tests/test-install.sh
./tests/test-sync-upstream.sh

# oh-my-opencode TypeScript tests
cd vendor/oh-my-opencode
bun test

# Specific test file
bun test src/config/sovereign-config.test.ts
```

### Test Coverage

```bash
cd vendor/oh-my-opencode
bun test --coverage
```

### Current Test Stats

| Component | Tests | Status |
|-----------|-------|--------|
| Shell scripts | 49 | Passing |
| oh-my-opencode TypeScript | 873 | Passing |
| **Total** | **922** | **Passing** |

## Adding New Agents

To add a new agent that uses sovereign-agent configuration:

1. Create the agent file in `vendor/oh-my-opencode/src/agents/`:

```typescript
import { getModelForAgent } from "../config/sovereign-config";
import { getDCPPromptForAgent } from "../config/dcp-prompts";

// Get model from unified config
const MODEL = getModelForAgent("my-new-agent");

// For orchestrator-type agents, include DCP prompt
const systemPrompt = `${getDCPPromptForAgent("my-new-agent")}

Your agent-specific instructions here...`;
```

2. Add the agent mapping in `sovereign-config.ts`:

```typescript
const AGENT_ROLE_MAP: Record<string, ModelRole> = {
  // ... existing mappings
  "my-new-agent": "orchestrator", // or "planner", "librarian", "fallback"
};
```

3. Add tests in `src/agents/my-new-agent.test.ts`

4. Export from `src/agents/index.ts`

## Template Variables

Templates use `{{VARIABLE}}` syntax. Available variables:

| Variable | Source |
|----------|--------|
| `{{OPENROUTER_API_KEY}}` | `config.json` → `openrouter_api_key` |
| `{{SITE_URL}}` | `config.json` → `site_url` |
| `{{SITE_NAME}}` | `config.json` → `site_name` |
| `{{ORCHESTRATOR_MODEL}}` | `config.json` → `models.orchestrator` |
| `{{PLANNER_MODEL}}` | `config.json` → `models.planner` |
| `{{LIBRARIAN_MODEL}}` | `config.json` → `models.librarian` |
| `{{FALLBACK_MODEL}}` | `config.json` → `models.fallback` |
| `{{ULTRAWORK_MAX_ITERATIONS}}` | `config.json` → `preferences.ultrawork_max_iterations` |
| `{{DCP_TURN_PROTECTION}}` | `config.json` → `preferences.dcp_turn_protection` |
| `{{DCP_ERROR_RETENTION_TURNS}}` | `config.json` → `preferences.dcp_error_retention_turns` |
| `{{DCP_NUDGE_FREQUENCY}}` | `config.json` → `preferences.dcp_nudge_frequency` |

## Debugging

### Verbose Installation

```bash
bash -x ./install.sh
```

### Check Generated Configs

```bash
cat ~/.config/opencode/opencode.json | jq .
cat ~/.config/opencode/dcp.jsonc
cat ~/.config/opencode/oh-my-opencode.json | jq .
```

### Validate Config Manually

```bash
source lib/validate.sh
validate_config config.json
echo $?  # 0 = valid
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run `./tests/run-tests.sh` to verify
5. Submit a pull request

### Code Style

- Shell scripts: Use `shellcheck` for linting
- TypeScript: Follow existing patterns in oh-my-opencode
- Tests: Aim for >80% coverage on new code

## License

MIT License - See LICENSE file for details.

## Related Projects

- [OpenCode](https://github.com/sst/opencode) - The AI-powered coding assistant
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) - Agent orchestration framework
- [opencode-dcp](https://github.com/tarquinen/opencode-dcp) - Dynamic Context Pruning plugin
- [OpenRouter](https://openrouter.ai) - Multi-model API gateway with ZDR
