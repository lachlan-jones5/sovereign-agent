#!/bin/bash
# setup-relay.sh - Quick relay server setup
#
# Usage (download and run):
#   bash <(curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh)
#
# Or with API key (non-interactive):
#   OPENROUTER_API_KEY=sk-or-... bash <(curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh)
#
# Or with custom port:
#   RELAY_PORT=8081 OPENROUTER_API_KEY=sk-or-... bash <(curl -fsSL ...)
#
# Or with custom host binding (0.0.0.0 for external access):
#   RELAY_HOST=0.0.0.0 RELAY_PORT=8081 OPENROUTER_API_KEY=sk-or-... bash <(curl -fsSL ...)
#
# This script:
#   1. Clones the repo into current directory (no submodules - fast)
#   2. Prompts for your OpenRouter API key (or uses env var)
#   3. Creates config.json
#   4. Starts the relay

set -euo pipefail

RELAY_PORT="${RELAY_PORT:-8080}"
RELAY_HOST="${RELAY_HOST:-127.0.0.1}"
INSTALL_DIR="${INSTALL_DIR:-$PWD/sovereign-agent}"
API_KEY="${OPENROUTER_API_KEY:-}"

echo "=== Sovereign Agent Relay Setup ==="
echo ""
echo "Installing to: $INSTALL_DIR"
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
    git pull --quiet || true
else
    echo "Cloning sovereign-agent..."
    git clone --quiet https://github.com/lachlan-jones5/sovereign-agent.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Initialize submodules (required for bundle endpoint to work)
echo "Initializing submodules..."
git submodule update --init --recursive --depth 1 || {
    echo ""
    echo "Warning: Submodule initialization failed."
    echo "The bundle endpoint will not work until submodules are initialized."
    echo "Try running: git submodule update --init --recursive"
    echo ""
}

# Get API key
if [[ -f config.json ]] && grep -q '"openrouter_api_key"' config.json; then
    echo "config.json already exists"
else
    # If no API key provided, try to read from terminal
    if [[ -z "$API_KEY" ]]; then
        echo ""
        echo "Enter your OpenRouter API key (from https://openrouter.ai/keys):"
        # Read from /dev/tty to work even when script is piped or in process substitution
        if ! read -r API_KEY </dev/tty 2>/dev/null; then
            echo ""
            echo "Error: Cannot read API key interactively."
            echo "Provide it via environment variable instead:"
            echo ""
            echo "  OPENROUTER_API_KEY=sk-or-... bash <(curl -fsSL ...)"
            exit 1
        fi
    fi
    
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

# Kill any existing relay process to free the port
# Check both localhost and 0.0.0.0, and also check if port is in use
if curl -s "http://localhost:$RELAY_PORT/health" &>/dev/null || \
   curl -s "http://127.0.0.1:$RELAY_PORT/health" &>/dev/null || \
   ss -tlnp 2>/dev/null | grep -q ":$RELAY_PORT " || \
   netstat -tlnp 2>/dev/null | grep -q ":$RELAY_PORT "; then
    echo "Port $RELAY_PORT in use - stopping existing processes..."
    # Try without sudo first, then with sudo if available
    pkill -f 'bun.*main.ts' 2>/dev/null || sudo pkill -f 'bun.*main.ts' 2>/dev/null || true
    docker stop sovereign-relay 2>/dev/null || true
    docker rm sovereign-relay 2>/dev/null || true
    sleep 2
    
    # Verify port is free
    if ss -tlnp 2>/dev/null | grep -q ":$RELAY_PORT " || \
       netstat -tlnp 2>/dev/null | grep -q ":$RELAY_PORT "; then
        echo "ERROR: Port $RELAY_PORT still in use. Please manually stop the process:"
        echo "  sudo lsof -i :$RELAY_PORT"
        echo "  sudo kill <PID>"
        exit 1
    fi
fi

if $HAS_DOCKER; then
    echo "Using Docker..."
    RELAY_HOST=$RELAY_HOST RELAY_PORT=$RELAY_PORT docker compose -f docker-compose.relay.yml up -d
    echo ""
    echo "Relay started! Check status:"
    echo "  docker logs sovereign-relay"
    echo "  curl http://localhost:$RELAY_PORT/health"
elif $HAS_BUN; then
    echo "Using Bun..."
    cd relay
    
    RELAY_HOST=$RELAY_HOST RELAY_PORT=$RELAY_PORT ./start-relay.sh daemon
    sleep 2
    
    echo ""
    echo "Relay started! Check status:"
    echo "  curl http://localhost:$RELAY_PORT/health"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next step: On your laptop, create a reverse tunnel to your Client VM:"
echo ""
echo "  ssh -R 8080:$(hostname):$RELAY_PORT devvm -N"
echo ""
echo "Replace 'devvm' with your Client VM's SSH host."
