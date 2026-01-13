#!/usr/bin/env bash
# start-relay.sh - Start the Sovereign Agent API relay
#
# Usage:
#   ./start-relay.sh           # Start relay in foreground
#   ./start-relay.sh daemon    # Start relay in background
#   ./start-relay.sh stop      # Stop background relay
#   ./start-relay.sh status    # Check relay status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="/tmp/sovereign-relay.pid"
LOG_FILE="/tmp/sovereign-relay.log"

# Default configuration
export CONFIG_PATH="${CONFIG_PATH:-$PROJECT_DIR/config.json}"
export RELAY_PORT="${RELAY_PORT:-8080}"
export RELAY_HOST="${RELAY_HOST:-127.0.0.1}"
export LOG_LEVEL="${LOG_LEVEL:-info}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_bun() {
    if ! command -v bun &> /dev/null; then
        log_error "Bun is not installed. Install it with:"
        echo "  curl -fsSL https://bun.sh/install | bash"
        exit 1
    fi
}

check_config() {
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_error "Config file not found: $CONFIG_PATH"
        log_info "Copy config.json.example to config.json and add your API key"
        exit 1
    fi
    
    # Verify API key is set
    if ! jq -e '.openrouter_api_key' "$CONFIG_PATH" > /dev/null 2>&1; then
        log_error "Missing openrouter_api_key in config"
        exit 1
    fi
    
    local api_key
    api_key=$(jq -r '.openrouter_api_key' "$CONFIG_PATH")
    if [[ "$api_key" == "sk-or-v1-your-api-key-here" ]]; then
        log_error "Please set your actual OpenRouter API key in config.json"
        exit 1
    fi
}

start_foreground() {
    check_bun
    check_config
    
    log_info "Starting relay on http://$RELAY_HOST:$RELAY_PORT"
    log_info "Config: $CONFIG_PATH"
    log_info "Press Ctrl+C to stop"
    echo
    
    cd "$SCRIPT_DIR"
    exec bun run main.ts
}

start_daemon() {
    check_bun
    check_config
    
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_warn "Relay already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    
    log_info "Starting relay daemon..."
    
    cd "$SCRIPT_DIR"
    nohup bun run main.ts > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        log_info "Relay started (PID: $pid)"
        log_info "Log file: $LOG_FILE"
    else
        log_error "Relay failed to start. Check $LOG_FILE for errors"
        rm -f "$PID_FILE"
        exit 1
    fi
}

stop_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        log_warn "No PID file found. Relay may not be running."
        return 0
    fi
    
    local pid
    pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        log_info "Stopping relay (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        log_info "Relay stopped"
    else
        log_warn "Process $pid not running. Cleaning up PID file."
        rm -f "$PID_FILE"
    fi
}

show_status() {
    echo "=== Sovereign Agent Relay Status ==="
    echo
    
    # Check PID file
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "Status: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "Status: ${RED}Dead${NC} (stale PID file)"
        fi
    else
        echo -e "Status: ${YELLOW}Not running${NC}"
    fi
    
    echo
    echo "Config: $CONFIG_PATH"
    echo "Port: $RELAY_PORT"
    echo "Host: $RELAY_HOST"
    echo
    
    # Try to hit the health endpoint
    if curl -s "http://$RELAY_HOST:$RELAY_PORT/health" > /dev/null 2>&1; then
        echo "Health check:"
        curl -s "http://$RELAY_HOST:$RELAY_PORT/health" | jq .
    fi
}

usage() {
    cat << EOF
Sovereign Agent API Relay

Usage: $0 [command]

Commands:
    (none)      Start relay in foreground
    daemon      Start relay in background
    stop        Stop background relay
    status      Check relay status
    help        Show this help

Environment Variables:
    CONFIG_PATH   Path to config.json (default: ../config.json)
    RELAY_PORT    Port to listen on (default: 8080)
    RELAY_HOST    Host to bind to (default: 127.0.0.1)
    LOG_LEVEL     Logging level (default: info)

Examples:
    # Start in foreground
    $0

    # Start as daemon
    $0 daemon

    # Check status
    $0 status

    # Custom port
    RELAY_PORT=9000 $0

EOF
}

case "${1:-}" in
    "")
        start_foreground
        ;;
    daemon)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
