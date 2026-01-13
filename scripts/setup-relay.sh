#!/bin/bash
# setup-relay.sh - Quick relay server setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash
#
# Or with custom port:
#   curl -fsSL ... | RELAY_PORT=8081 bash
#
# This script:
#   1. Clones the repo (no submodules - fast)
#   2. Prompts for your OpenRouter API key
#   3. Creates config.json
#   4. Starts the relay

set -euo pipefail

RELAY_PORT="${RELAY_PORT:-8080}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/sovereign-agent}"

echo "=== Sovereign Agent Relay Setup ==="
echo ""

# Check for required tools
if ! command -v git &>/dev/null; then
    echo "Error: git is required"
    exit 1
fi

# Check for Bun or Docker
HAS_BUN=false
HAS_DOCKER=false
if command -v bun &>/dev/null; then
    HAS_BUN=true
fi
if command -v docker &>/dev/null; then
    HAS_DOCKER=true
fi

if ! $HAS_BUN && ! $HAS_DOCKER; then
    echo "Error: Either 'bun' or 'docker' is required"
    echo ""
    echo "Install Bun:   curl -fsSL https://bun.sh/install | bash"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Clone repo if not already present
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Directory $INSTALL_DIR already exists"
    cd "$INSTALL_DIR"
    git pull --quiet
else
    echo "Cloning sovereign-agent..."
    git clone --quiet https://github.com/lachlan-jones5/sovereign-agent.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Get API key
if [[ -f config.json ]] && grep -q '"openrouter_api_key"' config.json; then
    echo "config.json already exists"
else
    echo ""
    echo "Enter your OpenRouter API key (from https://openrouter.ai/keys):"
    read -r -s API_KEY
    
    if [[ -z "$API_KEY" ]]; then
        echo "Error: API key is required"
        exit 1
    fi
    
    # Create minimal config
    cat > config.json <<EOF
{
  "openrouter_api_key": "$API_KEY",
  "site_url": "https://github.com/lachlan-jones5/sovereign-agent",
  "site_name": "SovereignAgent",
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": $RELAY_PORT
  }
}
EOF
    echo "Created config.json"
fi

# Start relay
echo ""
echo "Starting relay on port $RELAY_PORT..."

if $HAS_DOCKER; then
    echo "Using Docker..."
    RELAY_PORT=$RELAY_PORT docker compose -f docker-compose.relay.yml up -d
    echo ""
    echo "Relay started! Check status:"
    echo "  docker logs sovereign-relay"
    echo "  curl http://localhost:$RELAY_PORT/health"
elif $HAS_BUN; then
    echo "Using Bun..."
    cd relay
    
    # Check if already running
    if curl -s "http://localhost:$RELAY_PORT/health" &>/dev/null; then
        echo "Relay already running on port $RELAY_PORT"
    else
        ./start-relay.sh daemon
        sleep 2
    fi
    
    echo ""
    echo "Relay started! Check status:"
    echo "  curl http://localhost:$RELAY_PORT/health"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next step: On your laptop, create a reverse tunnel to your Work VM:"
echo ""
echo "  ssh -R 8080:$(hostname):$RELAY_PORT workvm -N"
echo ""
echo "Replace 'workvm' with your Work VM's SSH host."
