#!/bin/bash
# setup-client.sh - Minimal OpenCode client setup for Work VM
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-client.sh | bash
#
# Or with custom port:
#   curl -fsSL ... | RELAY_PORT=8081 bash
#
# This script:
#   1. Installs OpenCode if not present
#   2. Configures it to use localhost:8080 (the relay tunnel)
#   3. That's it!

set -euo pipefail

RELAY_PORT="${RELAY_PORT:-8080}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

echo "=== Sovereign Agent Client Setup ==="
echo ""

# Check if OpenCode is installed
if command -v opencode &>/dev/null; then
    echo "OpenCode is already installed: $(which opencode)"
else
    echo "OpenCode not found. Installing..."
    
    # Check for Go
    if ! command -v go &>/dev/null; then
        echo "Error: Go is required to install OpenCode"
        echo "Install Go: https://go.dev/doc/install"
        exit 1
    fi
    
    echo "Installing OpenCode via 'go install'..."
    go install github.com/sst/opencode@latest
    
    # Check if it worked
    if ! command -v opencode &>/dev/null; then
        echo ""
        echo "OpenCode installed but not in PATH."
        echo "Add this to your shell config:"
        echo '  export PATH="$PATH:$(go env GOPATH)/bin"'
        echo ""
    fi
fi

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create or update config
CONFIG_FILE="$CONFIG_DIR/config.json"

if [[ -f "$CONFIG_FILE" ]]; then
    echo ""
    echo "Config already exists at $CONFIG_FILE"
    echo "Checking if relay is configured..."
    
    if grep -q "localhost:$RELAY_PORT" "$CONFIG_FILE"; then
        echo "Already configured for relay on port $RELAY_PORT"
    else
        echo ""
        echo "WARNING: Existing config may not be set up for relay."
        echo "Ensure your config has:"
        echo ""
        echo '  "provider": {'
        echo '    "openrouter": {'
        echo "      \"baseURL\": \"http://localhost:$RELAY_PORT/api/v1\""
        echo '    }'
        echo '  }'
    fi
else
    echo "Creating OpenCode config..."
    
    cat > "$CONFIG_FILE" <<EOF
{
  "provider": {
    "openrouter": {
      "baseURL": "http://localhost:$RELAY_PORT/api/v1"
    }
  }
}
EOF
    echo "Created $CONFIG_FILE"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Before running OpenCode, make sure the reverse tunnel is active."
echo "Test the connection:"
echo ""
echo "  curl http://localhost:$RELAY_PORT/health"
echo ""
echo "If that returns {\"status\":\"ok\"}, you're ready:"
echo ""
echo "  opencode"
echo ""
