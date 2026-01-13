#!/usr/bin/env bash
# network-firewall.sh - Network egress restrictions for Sovereign Agent
#
# Implements the "Iron Box" network isolation from the red team analysis:
# - Blocks private LAN ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
# - Only allows traffic to OpenRouter API and essential package registries
# - Prevents SSRF attacks against local infrastructure
#
# Usage:
#   ./lib/network-firewall.sh apply    # Apply firewall rules
#   ./lib/network-firewall.sh status   # Show current rules
#   ./lib/network-firewall.sh reset    # Reset to default (allow all)
#   ./lib/network-firewall.sh test     # Test connectivity to allowed hosts

set -e

# Allowed hosts (DNS names and IPs)
ALLOWED_HOSTS=(
    # OpenRouter API
    "openrouter.ai"
    
    # Package registries
    "registry.npmjs.org"
    "registry.yarnpkg.com"
    "pypi.org"
    "files.pythonhosted.org"
    
    # Container registries (for pulling images)
    "registry-1.docker.io"
    "auth.docker.io"
    "production.cloudflare.docker.com"
    "ghcr.io"
    
    # GitHub (for git operations and submodules)
    "github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    
    # Bun registry
    "bun.sh"
    "registry.bun.sh"
)

# Blocked private IP ranges (SSRF protection)
BLOCKED_RANGES=(
    "10.0.0.0/8"        # Class A private
    "172.16.0.0/12"     # Class B private (excludes Docker's 172.28.0.0/16)
    "192.168.0.0/16"    # Class C private
    "169.254.0.0/16"    # Link-local
    "127.0.0.0/8"       # Loopback (except localhost)
    "0.0.0.0/8"         # Invalid
    "224.0.0.0/4"       # Multicast
    "240.0.0.0/4"       # Reserved
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root (required for iptables)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (for iptables access)"
        log_info "Try: sudo $0 $*"
        exit 1
    fi
}

# Check if iptables is available
check_iptables() {
    if ! command -v iptables &> /dev/null; then
        log_error "iptables not found. Please install iptables."
        exit 1
    fi
}

# Resolve hostname to IP addresses
resolve_host() {
    local host="$1"
    # Use getent for reliable DNS resolution, fallback to dig
    if command -v getent &> /dev/null; then
        getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u | grep -E '^[0-9]+\.' || true
    elif command -v dig &> /dev/null; then
        dig +short "$host" 2>/dev/null | grep -E '^[0-9]+\.' || true
    elif command -v host &> /dev/null; then
        host "$host" 2>/dev/null | awk '/has address/ {print $4}' || true
    else
        log_warn "No DNS resolution tool found (getent/dig/host)"
        return 1
    fi
}

# Apply firewall rules
apply_rules() {
    check_root
    check_iptables
    
    log_info "Applying network firewall rules..."
    
    # Create a new chain for sovereign-agent rules
    iptables -N SOVEREIGN_AGENT 2>/dev/null || iptables -F SOVEREIGN_AGENT
    
    # Allow established connections
    iptables -A SOVEREIGN_AGENT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow DNS (required for hostname resolution)
    iptables -A SOVEREIGN_AGENT -p udp --dport 53 -j ACCEPT
    iptables -A SOVEREIGN_AGENT -p tcp --dport 53 -j ACCEPT
    
    # Block private IP ranges (SSRF protection)
    log_info "Blocking private IP ranges..."
    for range in "${BLOCKED_RANGES[@]}"; do
        iptables -A SOVEREIGN_AGENT -d "$range" -j DROP
        log_info "  Blocked: $range"
    done
    
    # Allow traffic to approved hosts
    log_info "Allowing traffic to approved hosts..."
    for host in "${ALLOWED_HOSTS[@]}"; do
        local ips
        ips=$(resolve_host "$host")
        if [[ -n "$ips" ]]; then
            while IFS= read -r ip; do
                if [[ -n "$ip" ]]; then
                    iptables -A SOVEREIGN_AGENT -d "$ip" -j ACCEPT
                    log_info "  Allowed: $host -> $ip"
                fi
            done <<< "$ips"
        else
            log_warn "  Could not resolve: $host"
        fi
    done
    
    # Allow HTTPS and HTTP to any allowed destination
    iptables -A SOVEREIGN_AGENT -p tcp --dport 443 -j ACCEPT
    iptables -A SOVEREIGN_AGENT -p tcp --dport 80 -j ACCEPT
    
    # Log and drop everything else
    iptables -A SOVEREIGN_AGENT -j LOG --log-prefix "SOVEREIGN_BLOCKED: " --log-level 4
    iptables -A SOVEREIGN_AGENT -j DROP
    
    # Insert the chain into OUTPUT
    if ! iptables -C OUTPUT -j SOVEREIGN_AGENT 2>/dev/null; then
        iptables -I OUTPUT -j SOVEREIGN_AGENT
    fi
    
    log_info "Firewall rules applied successfully"
    echo
    log_warn "Note: DNS is allowed for resolution. Traffic is restricted to:"
    for host in "${ALLOWED_HOSTS[@]}"; do
        echo "  - $host"
    done
}

# Show current rules
show_status() {
    check_root
    check_iptables
    
    echo -e "${BLUE}=== Sovereign Agent Firewall Status ===${NC}"
    echo
    
    if iptables -L SOVEREIGN_AGENT -n 2>/dev/null; then
        echo
        log_info "Chain SOVEREIGN_AGENT is active"
    else
        log_warn "Chain SOVEREIGN_AGENT does not exist (firewall not applied)"
    fi
}

# Reset to default (allow all)
reset_rules() {
    check_root
    check_iptables
    
    log_info "Resetting firewall rules..."
    
    # Remove the chain from OUTPUT
    iptables -D OUTPUT -j SOVEREIGN_AGENT 2>/dev/null || true
    
    # Flush and delete the chain
    iptables -F SOVEREIGN_AGENT 2>/dev/null || true
    iptables -X SOVEREIGN_AGENT 2>/dev/null || true
    
    log_info "Firewall rules reset to default (all traffic allowed)"
}

# Test connectivity to allowed hosts
test_connectivity() {
    log_info "Testing connectivity to allowed hosts..."
    echo
    
    local failed=0
    
    for host in "${ALLOWED_HOSTS[@]}"; do
        if curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "https://$host" | grep -qE '^[23]'; then
            echo -e "  ${GREEN}OK${NC}: $host"
        elif ping -c 1 -W 3 "$host" &>/dev/null; then
            echo -e "  ${GREEN}OK${NC}: $host (ping)"
        else
            echo -e "  ${RED}FAIL${NC}: $host"
            ((failed++))
        fi
    done
    
    echo
    if [[ $failed -eq 0 ]]; then
        log_info "All hosts reachable"
    else
        log_warn "$failed host(s) unreachable"
    fi
    
    # Test that blocked ranges are blocked
    echo
    log_info "Testing SSRF protection (should fail)..."
    
    for range in "10.0.0.1" "172.16.0.1" "192.168.1.1"; do
        if ! ping -c 1 -W 1 "$range" &>/dev/null; then
            echo -e "  ${GREEN}BLOCKED${NC}: $range"
        else
            echo -e "  ${YELLOW}REACHABLE${NC}: $range (may indicate firewall not applied)"
        fi
    done
}

# Generate iptables rules file (for use without root)
generate_rules_file() {
    local output_file="${1:-/tmp/sovereign-agent-iptables.rules}"
    
    log_info "Generating iptables rules file: $output_file"
    
    cat > "$output_file" << 'RULES_HEADER'
# Sovereign Agent Network Firewall Rules
# Generated by network-firewall.sh
# Apply with: iptables-restore < this-file

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:SOVEREIGN_AGENT - [0:0]

# Jump to SOVEREIGN_AGENT chain
-A OUTPUT -j SOVEREIGN_AGENT

# Allow established connections
-A SOVEREIGN_AGENT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS
-A SOVEREIGN_AGENT -p udp --dport 53 -j ACCEPT
-A SOVEREIGN_AGENT -p tcp --dport 53 -j ACCEPT

# Block private IP ranges (SSRF protection)
RULES_HEADER

    for range in "${BLOCKED_RANGES[@]}"; do
        echo "-A SOVEREIGN_AGENT -d $range -j DROP" >> "$output_file"
    done
    
    cat >> "$output_file" << 'RULES_FOOTER'

# Allow HTTPS and HTTP
-A SOVEREIGN_AGENT -p tcp --dport 443 -j ACCEPT
-A SOVEREIGN_AGENT -p tcp --dport 80 -j ACCEPT

# Log and drop everything else
-A SOVEREIGN_AGENT -j LOG --log-prefix "SOVEREIGN_BLOCKED: "
-A SOVEREIGN_AGENT -j DROP

COMMIT
RULES_FOOTER

    log_info "Rules file generated. Apply with:"
    echo "  sudo iptables-restore < $output_file"
}

# Print usage
usage() {
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  apply       Apply firewall rules (requires root)"
    echo "  status      Show current firewall status"
    echo "  reset       Reset to default (allow all traffic)"
    echo "  test        Test connectivity to allowed hosts"
    echo "  generate    Generate iptables rules file"
    echo
    echo "Allowed hosts:"
    for host in "${ALLOWED_HOSTS[@]}"; do
        echo "  - $host"
    done
    echo
    echo "Blocked ranges (SSRF protection):"
    for range in "${BLOCKED_RANGES[@]}"; do
        echo "  - $range"
    done
}

# Main
case "${1:-}" in
    apply)
        apply_rules
        ;;
    status)
        show_status
        ;;
    reset)
        reset_rules
        ;;
    test)
        test_connectivity
        ;;
    generate)
        generate_rules_file "${2:-}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
