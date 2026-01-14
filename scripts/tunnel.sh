#!/bin/bash
# tunnel.sh - Create reverse tunnel from laptop to Client VM
#
# Usage:
#   ./scripts/tunnel.sh <devvm-ssh-host> [relay-host] [port]
#
# Examples:
#   ./scripts/tunnel.sh devvm                    # Relay on localhost:8080
#   ./scripts/tunnel.sh devvm pi.local           # Relay on pi.local:8080
#   ./scripts/tunnel.sh devvm pi.local 8081      # Relay on pi.local:8081
#
# This creates a reverse tunnel so the Client VM's localhost:PORT
# connects to the relay server through your laptop.

set -euo pipefail

DEVVM="${1:-}"
RELAY_HOST="${2:-localhost}"
RELAY_PORT="${3:-8080}"

if [[ -z "$DEVVM" ]]; then
    echo "Usage: $0 <devvm-ssh-host> [relay-host] [port]"
    echo ""
    echo "Arguments:"
    echo "  devvm-ssh-host   SSH host for your Client VM (required)"
    echo "  relay-host       Hostname/IP of relay server (default: localhost)"
    echo "  port             Relay port (default: 8080)"
    echo ""
    echo "Examples:"
    echo "  $0 devvm                    # Relay on localhost:8080"
    echo "  $0 devvm pi.local           # Relay on pi.local:8080"
    echo "  $0 devvm pi.local 8081      # Relay on pi.local:8081"
    echo ""
    echo "This creates a reverse tunnel so Client VM's localhost:$RELAY_PORT"
    echo "forwards through your laptop to $RELAY_HOST:$RELAY_PORT"
    exit 1
fi

echo "=== Sovereign Agent Tunnel ==="
echo ""
echo "Creating reverse tunnel:"
echo "  Client VM ($DEVVM) :$RELAY_PORT  -->  Laptop  -->  Relay ($RELAY_HOST:$RELAY_PORT)"
echo ""
echo "Press Ctrl+C to stop the tunnel."
echo ""

# Check if we can reach the relay first
if curl -s --connect-timeout 2 "http://$RELAY_HOST:$RELAY_PORT/health" &>/dev/null; then
    echo "Relay is reachable at $RELAY_HOST:$RELAY_PORT"
else
    echo "Warning: Cannot reach relay at $RELAY_HOST:$RELAY_PORT"
    echo "Make sure the relay server is running."
    echo ""
fi

# Create the tunnel
# -R = remote/reverse tunnel
# -N = no command, just tunnel
# -o ServerAliveInterval = keep connection alive
# -o ExitOnForwardFailure = fail if port binding fails
exec ssh \
    -R "$RELAY_PORT:$RELAY_HOST:$RELAY_PORT" \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -N \
    "$DEVVM"
