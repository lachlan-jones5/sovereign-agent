#!/bin/bash
# setup-client.sh - Full client setup for Client VM
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-client.sh | bash
#
# Or with custom port:
#   curl -fsSL ... | RELAY_PORT=8081 bash
#
# This script:
#   1. Clones sovereign-agent with all submodules
#   2. Creates client config (points to localhost relay)
#   3. Runs install.sh to set up OpenCode with agents/plugins

set -euo pipefail

RELAY_PORT="${RELAY_PORT:-8080}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/sovereign-agent}"

echo "=== Sovereign Agent Client Setup ==="
echo ""

# Check for required tools
for cmd in git go jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed"
        exit 1
    fi
done

# Check for Bun (needed for oh-my-opencode)
if ! command -v bun &>/dev/null; then
    echo "Bun not found. Installing..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# Clone repo (remove existing directory for clean state)
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Removing existing $INSTALL_DIR for clean install..."
    rm -rf "$INSTALL_DIR"
fi
echo "Cloning sovereign-agent (this may take a minute)..."
git clone --recurse-submodules --shallow-submodules \
    https://github.com/lachlan-jones5/sovereign-agent.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Create client config if not exists
if [[ -f config.json ]]; then
    echo "config.json already exists"
else
    echo "Creating client config..."
    cat > config.json <<EOF
{
  "openrouter_api_key": "",
  "site_url": "https://github.com/lachlan-jones5/sovereign-agent",
  "site_name": "SovereignAgent",

  "models": {
    "orchestrator": "deepseek/deepseek-r1",
    "planner": "anthropic/claude-sonnet-4",
    "librarian": "google/gemini-2.5-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },

  "preferences": {
    "ultrawork_max_iterations": 50,
    "dcp_turn_protection": 2,
    "dcp_error_retention_turns": 4,
    "dcp_nudge_frequency": 10
  },

  "relay": {
    "enabled": true,
    "mode": "client",
    "port": $RELAY_PORT
  }
}
EOF
fi

# Run install
echo ""
echo "Running install.sh..."
./install.sh

echo ""
echo "=== Setup Complete ==="
echo ""
echo "1. Start a new shell session to pick up PATH changes:"
echo ""
echo "   exec \$SHELL"
echo ""
echo "2. Make sure the reverse tunnel is active. Test the connection:"
echo ""
echo "   curl http://localhost:$RELAY_PORT/health"
echo ""
echo "3. If that returns {\"status\":\"ok\"}, you're ready:"
echo ""
echo "   opencode"
echo ""
