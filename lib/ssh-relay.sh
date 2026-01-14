#!/usr/bin/env bash
# ssh-relay.sh - SSH tunnel management for sovereign-agent relay
#
# This script manages SSH tunnels for the client-server relay architecture.
# Run on the WORK VM (client) to establish a tunnel to the PI (server).
#
# Usage:
#   ./lib/ssh-relay.sh start <ssh-host>    # Start tunnel via SSH config host
#   ./lib/ssh-relay.sh stop                # Stop tunnel
#   ./lib/ssh-relay.sh status              # Check tunnel status
#   ./lib/ssh-relay.sh run <ssh-host>      # Start tunnel and run opencode

set -e

RELAY_PORT="${SOVEREIGN_RELAY_PORT:-8080}"
PID_FILE="/tmp/sovereign-ssh-tunnel.pid"
SOCKET_FILE="/tmp/sovereign-ssh-tunnel.sock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

start_tunnel() {
    local ssh_host="$1"
    
    if [[ -z "$ssh_host" ]]; then
        log_error "SSH host required"
        echo "Usage: $0 start <ssh-host>"
        echo
        echo "The ssh-host can be:"
        echo "  - A host from ~/.ssh/config (recommended)"
        echo "  - user@hostname"
        echo "  - user@hostname with -J jump-host"
        exit 1
    fi
    
    # Check if already running
    if [[ -S "$SOCKET_FILE" ]]; then
        if ssh -S "$SOCKET_FILE" -O check placeholder 2>/dev/null; then
            log_warn "Tunnel already running"
            return 0
        else
            # Stale socket, clean up
            rm -f "$SOCKET_FILE" "$PID_FILE"
        fi
    fi
    
    log_info "Starting SSH tunnel to $ssh_host..."
    log_info "Local port $RELAY_PORT -> remote localhost:$RELAY_PORT"
    
    # Start SSH tunnel with:
    # -L: Local port forward (local:8080 -> remote:8080)
    # -f: Background after authentication
    # -N: No remote command
    # -M: Master mode for connection sharing
    # -S: Control socket path
    # -o: Options for keepalive and exit on failure
    ssh -L "$RELAY_PORT:localhost:$RELAY_PORT" \
        -f -N \
        -M -S "$SOCKET_FILE" \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o ControlPersist=yes \
        "$ssh_host"
    
    # Store the host for later reference
    echo "$ssh_host" > "$PID_FILE"
    
    log_info "Tunnel established"
    log_info "Relay available at http://localhost:$RELAY_PORT"
}

stop_tunnel() {
    if [[ -S "$SOCKET_FILE" ]]; then
        log_info "Stopping SSH tunnel..."
        ssh -S "$SOCKET_FILE" -O exit placeholder 2>/dev/null || true
        rm -f "$SOCKET_FILE"
        log_info "Tunnel stopped"
    else
        log_warn "No active tunnel found"
    fi
    
    rm -f "$PID_FILE"
}

check_status() {
    echo "=== Sovereign Agent SSH Tunnel Status ==="
    echo
    
    if [[ -S "$SOCKET_FILE" ]]; then
        if ssh -S "$SOCKET_FILE" -O check placeholder 2>/dev/null; then
            local host=""
            [[ -f "$PID_FILE" ]] && host=$(cat "$PID_FILE")
            echo -e "Status: ${GREEN}Connected${NC}"
            echo "Host: $host"
            echo "Port: $RELAY_PORT"
            echo
            
            # Test relay connectivity
            if curl -s --connect-timeout 2 "http://localhost:$RELAY_PORT/health" > /dev/null 2>&1; then
                echo "Relay health check:"
                curl -s "http://localhost:$RELAY_PORT/health" | jq . 2>/dev/null || \
                    curl -s "http://localhost:$RELAY_PORT/health"
            else
                echo -e "Relay: ${YELLOW}Not responding${NC} (is it running on the server?)"
            fi
            return 0
        fi
    fi
    
    echo -e "Status: ${YELLOW}Not connected${NC}"
    return 1
}

run_with_tunnel() {
    local ssh_host="$1"
    
    if [[ -z "$ssh_host" ]]; then
        log_error "SSH host required"
        echo "Usage: $0 run <ssh-host>"
        exit 1
    fi
    
    # Start tunnel if not running
    start_tunnel "$ssh_host"
    
    # Wait for relay to be ready
    log_info "Waiting for relay..."
    local attempts=0
    while ! curl -s --connect-timeout 1 "http://localhost:$RELAY_PORT/health" > /dev/null 2>&1; do
        ((attempts++))
        if [[ $attempts -gt 10 ]]; then
            log_error "Relay not responding after 10 seconds"
            log_error "Is the relay running on the server? Check with:"
            echo "  ssh $ssh_host 'cd ~/sovereign-agent/relay && ./start-relay.sh status'"
            exit 1
        fi
        sleep 1
    done
    
    log_info "Relay ready. Starting OpenCode..."
    echo
    
    # Run opencode (it should use config with relay.mode=client)
    opencode
    
    # Optionally stop tunnel when done
    # stop_tunnel
}

usage() {
    cat << EOF
SSH Tunnel for Sovereign Agent Relay

Usage: $0 <command> [options]

Commands:
    start <ssh-host>    Start SSH tunnel to server
    stop                Stop SSH tunnel
    status              Check tunnel and relay status
    run <ssh-host>      Start tunnel and run OpenCode

Environment Variables:
    SOVEREIGN_RELAY_PORT    Relay port (default: 8080)

SSH Configuration:
    The ssh-host should be configured in ~/.ssh/config with ProxyJump
    if needed. Example:

    # ~/.ssh/config
    Host pi-relay
        HostName your-pi.duckdns.org
        User pi
        ProxyJump laptop
        IdentityFile ~/.ssh/pi_key

Examples:
    # Start tunnel using SSH config host
    $0 start pi-relay

    # Start tunnel and run OpenCode
    $0 run pi-relay

    # Check status
    $0 status

    # Stop tunnel
    $0 stop

Architecture:
    Client VM ──SSH──> Laptop ──SSH──> Pi ──HTTPS──> OpenRouter
    (client)          (jump)          (server)

EOF
}

case "${1:-}" in
    start)
        start_tunnel "${2:-}"
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        check_status
        ;;
    run)
        run_with_tunnel "${2:-}"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
