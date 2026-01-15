#!/usr/bin/env bash
# setup-relay.sh - One-liner setup for Sovereign Agent relay server
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash
#
# With custom options:
#   curl -fsSL ... | RELAY_HOST=0.0.0.0 RELAY_PORT=8081 bash
#
# Environment variables:
#   RELAY_PORT  - Port to listen on (default: 8080)
#   RELAY_HOST  - Host to bind to (default: 127.0.0.1, use 0.0.0.0 for external)
#   INSTALL_DIR - Where to install (default: ~/sovereign-agent)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
INSTALL_DIR="${INSTALL_DIR:-$HOME/sovereign-agent}"
RELAY_PORT="${RELAY_PORT:-8080}"
RELAY_HOST="${RELAY_HOST:-127.0.0.1}"
REPO_URL="https://github.com/lachlan-jones5/sovereign-agent.git"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║       Sovereign Agent Relay Server Setup          ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for required tools
check_command() {
    if ! command -v "$1" &>/dev/null; then
        return 1
    fi
    return 0
}

# Install Bun if not present
install_bun() {
    if check_command bun; then
        log_info "Bun already installed: $(bun --version)"
        return 0
    fi
    
    log_info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    
    # Source the new PATH
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    if check_command bun; then
        log_info "Bun installed successfully: $(bun --version)"
    else
        log_error "Failed to install Bun"
        exit 1
    fi
}

# Install Git if not present
check_git() {
    if check_command git; then
        log_info "Git already installed: $(git --version)"
        return 0
    fi
    
    log_warn "Git not found. Please install git first:"
    echo "  Ubuntu/Debian: sudo apt-get install git"
    echo "  macOS: xcode-select --install"
    echo "  Alpine: apk add git"
    exit 1
}

# Clone or update repository
setup_repo() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull --ff-only
        git submodule update --init --recursive
    else
        log_info "Cloning repository to $INSTALL_DIR..."
        git clone --recurse-submodules "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
}

# Create config if not exists
setup_config() {
    if [[ -f "$INSTALL_DIR/config.json" ]]; then
        log_info "Config file already exists"
        return 0
    fi
    
    log_info "Creating config.json..."
    cat > "$INSTALL_DIR/config.json" << EOF
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": $RELAY_PORT
  }
}
EOF
    log_info "Created $INSTALL_DIR/config.json"
}

# Start the relay
start_relay() {
    cd "$INSTALL_DIR/relay"
    
    log_info "Starting relay server on http://$RELAY_HOST:$RELAY_PORT"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Relay server starting!${NC}"
    echo ""
    echo -e "  ${BLUE}Next steps:${NC}"
    echo "  1. Open http://localhost:$RELAY_PORT/auth/device in your browser"
    echo "  2. Follow the GitHub device code flow to authenticate"
    echo "  3. Set up SSH tunnels from your laptop"
    echo "  4. Install client on your VM with:"
    echo "     curl -fsSL http://localhost:$RELAY_PORT/setup | bash"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    export RELAY_HOST="$RELAY_HOST"
    export RELAY_PORT="$RELAY_PORT"
    exec bun run main.ts
}

# Main
main() {
    check_git
    install_bun
    setup_repo
    setup_config
    start_relay
}

main "$@"
