#!/bin/bash
# test-setup-scripts.sh - Tests for setup-relay.sh, setup-client.sh, and tunnel.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    ((TESTS_RUN++))
}

echo "=== Setup Scripts Tests ==="
echo ""

# ============================================
# setup-relay.sh tests
# ============================================
echo "--- setup-relay.sh ---"

# Test: Script exists and is executable
if [[ -x "$PROJECT_ROOT/scripts/setup-relay.sh" ]]; then
    pass "setup-relay.sh exists and is executable"
else
    fail "setup-relay.sh not executable"
fi

# Test: Script has correct shebang
if head -1 "$PROJECT_ROOT/scripts/setup-relay.sh" | grep -q '^#!/bin/bash'; then
    pass "setup-relay.sh has bash shebang"
else
    fail "setup-relay.sh missing bash shebang"
fi

# Test: Script uses PWD for INSTALL_DIR by default
if grep -q 'INSTALL_DIR=.*\$PWD' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh uses PWD for INSTALL_DIR"
else
    fail "setup-relay.sh should use PWD for INSTALL_DIR, not HOME"
fi

# Test: Script reads OPENROUTER_API_KEY from env
if grep -q 'OPENROUTER_API_KEY' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh reads OPENROUTER_API_KEY env var"
else
    fail "setup-relay.sh should read OPENROUTER_API_KEY env var"
fi

# Test: Script reads RELAY_PORT from env
if grep -q 'RELAY_PORT' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh reads RELAY_PORT env var"
else
    fail "setup-relay.sh should read RELAY_PORT env var"
fi

# Test: Script reads RELAY_HOST from env
if grep -q 'RELAY_HOST' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh reads RELAY_HOST env var"
else
    fail "setup-relay.sh should read RELAY_HOST env var"
fi

# Test: Script has default RELAY_HOST of 127.0.0.1
if grep -q 'RELAY_HOST:-127.0.0.1\|RELAY_HOST.*127.0.0.1' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh has default RELAY_HOST 127.0.0.1"
else
    fail "setup-relay.sh should have default RELAY_HOST 127.0.0.1"
fi

# Test: Script passes RELAY_HOST to start-relay.sh
if grep -q 'RELAY_HOST=\$RELAY_HOST.*start-relay.sh\|RELAY_HOST=.*RELAY_HOST.*start-relay' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh passes RELAY_HOST to start-relay.sh"
else
    fail "setup-relay.sh should pass RELAY_HOST to start-relay.sh"
fi

# Test: Script reads from /dev/tty for interactive input
if grep -q '/dev/tty' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh reads from /dev/tty for interactive input"
else
    fail "setup-relay.sh should read from /dev/tty"
fi

# Test: Script checks for git
if grep -q 'command -v git' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh checks for git dependency"
else
    fail "setup-relay.sh should check for git"
fi

# Test: Script checks for bun or docker
if grep -q 'command -v bun' "$PROJECT_ROOT/scripts/setup-relay.sh" && \
   grep -q 'command -v docker' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh checks for bun or docker"
else
    fail "setup-relay.sh should check for bun or docker"
fi

# Test: Script creates config.json with API key
if grep -q 'openrouter_api_key' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh creates config with API key"
else
    fail "setup-relay.sh should create config with API key"
fi

# Test: Script has usage instructions mentioning bash <(curl)
if grep -q 'bash <(curl' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh usage shows bash <(curl) syntax"
else
    fail "setup-relay.sh usage should show bash <(curl) syntax"
fi

# Test: Dry run with missing dependencies (should fail gracefully)
# We just check the script logic statically - the error message exists
if grep -q "Either 'bun' or 'docker' is required" "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh has graceful error for missing bun/docker"
else
    fail "setup-relay.sh should fail gracefully without bun/docker"
fi

# ============================================
# setup-client.sh tests  
# ============================================
echo ""
echo "--- setup-client.sh ---"

# Test: Script exists and is executable
if [[ -x "$PROJECT_ROOT/scripts/setup-client.sh" ]]; then
    pass "setup-client.sh exists and is executable"
else
    fail "setup-client.sh not executable"
fi

# Test: Script has correct shebang
if head -1 "$PROJECT_ROOT/scripts/setup-client.sh" | grep -q '^#!/bin/bash'; then
    pass "setup-client.sh has bash shebang"
else
    fail "setup-client.sh missing bash shebang"
fi

# Test: Script reads RELAY_PORT from env
if grep -q 'RELAY_PORT' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh reads RELAY_PORT env var"
else
    fail "setup-client.sh should read RELAY_PORT env var"
fi

# Test: Script clones with submodules
if grep -q 'recurse-submodules' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh clones with submodules"
else
    fail "setup-client.sh should clone with submodules"
fi

# Test: Script runs install.sh
if grep -q './install.sh' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh runs install.sh"
else
    fail "setup-client.sh should run install.sh"
fi

# Test: Script creates client config with relay mode
if grep -q '"mode": "client"' "$PROJECT_ROOT/scripts/setup-client.sh" || \
   grep -q "'mode': 'client'" "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh creates client config with relay mode"
else
    fail "setup-client.sh should create client config with relay mode"
fi

# ============================================
# tunnel.sh tests
# ============================================
echo ""
echo "--- tunnel.sh ---"

# Test: Script exists and is executable
if [[ -x "$PROJECT_ROOT/scripts/tunnel.sh" ]]; then
    pass "tunnel.sh exists and is executable"
else
    fail "tunnel.sh not executable"
fi

# Test: Script has correct shebang
if head -1 "$PROJECT_ROOT/scripts/tunnel.sh" | grep -q '^#!/bin/bash'; then
    pass "tunnel.sh has bash shebang"
else
    fail "tunnel.sh missing bash shebang"
fi

# Test: Script shows usage when no args
OUTPUT=$("$PROJECT_ROOT/scripts/tunnel.sh" 2>&1 || true)
if echo "$OUTPUT" | grep -q 'Usage'; then
    pass "tunnel.sh shows usage when no args"
else
    fail "tunnel.sh should show usage when no args"
fi

# Test: Script uses ssh -R for reverse tunnel
if grep -q '\-R.*RELAY_PORT' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh uses ssh -R for reverse tunnel"
else
    fail "tunnel.sh should use ssh -R"
fi

# Test: Script uses -N for no command
if grep -q '\-N' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh uses -N flag"
else
    fail "tunnel.sh should use -N flag"
fi

# Test: Script has ServerAliveInterval for keepalive
if grep -q 'ServerAliveInterval' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh has ServerAliveInterval for keepalive"
else
    fail "tunnel.sh should have ServerAliveInterval"
fi

# Test: Script has ExitOnForwardFailure for safety
if grep -q 'ExitOnForwardFailure' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh has ExitOnForwardFailure option"
else
    fail "tunnel.sh should have ExitOnForwardFailure"
fi

# Test: Script checks relay health before starting
if grep -q 'health\|curl.*RELAY' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh checks relay health"
else
    fail "tunnel.sh should check relay health"
fi

# ============================================
# Additional edge case tests
# ============================================
echo ""
echo "--- Additional Edge Cases ---"

# Test: setup-relay.sh uses set -e for error handling
if grep -q 'set -e\|set -.*e' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh uses set -e for error handling"
else
    fail "setup-relay.sh should use set -e"
fi

# Test: setup-client.sh uses set -e for error handling
if grep -q 'set -e\|set -.*e' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh uses set -e for error handling"
else
    fail "setup-client.sh should use set -e"
fi

# Test: tunnel.sh uses set -e for error handling
if grep -q 'set -e\|set -.*e' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh uses set -e for error handling"
else
    fail "tunnel.sh should use set -e"
fi

# Test: setup-relay.sh has default port 8080
if grep -q 'RELAY_PORT:-8080\|RELAY_PORT.*8080' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh has default port 8080"
else
    fail "setup-relay.sh should have default port 8080"
fi

# Test: setup-client.sh has default port 8080
if grep -q 'RELAY_PORT:-8080\|RELAY_PORT.*8080' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh has default port 8080"
else
    fail "setup-client.sh should have default port 8080"
fi

# Test: tunnel.sh has default port 8080
if grep -q 'RELAY_PORT:-8080\|RELAY_PORT.*8080' "$PROJECT_ROOT/scripts/tunnel.sh"; then
    pass "tunnel.sh has default port 8080"
else
    fail "tunnel.sh should have default port 8080"
fi

# Test: setup-client.sh uses shallow submodules for faster clone
if grep -q 'shallow-submodules' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh uses shallow submodules"
else
    fail "setup-client.sh should use shallow submodules"
fi

# Test: setup-relay.sh clones from correct repo URL
if grep -q 'github.com.*sovereign-agent\|lachlan-jones5/sovereign-agent' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh clones from correct repo URL"
else
    fail "setup-relay.sh should clone from sovereign-agent repo"
fi

# Test: setup-client.sh clones from correct repo URL
if grep -q 'github.com.*sovereign-agent\|lachlan-jones5/sovereign-agent' "$PROJECT_ROOT/scripts/setup-client.sh"; then
    pass "setup-client.sh clones from correct repo URL"
else
    fail "setup-client.sh should clone from sovereign-agent repo"
fi

# Test: setup-relay.sh validates API key is not empty
if grep -q 'API_KEY.*-z\|-z.*API_KEY\|if.*-z.*api_key\|api_key.*empty\|if \[\[ -z' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh validates API key is not empty"
else
    fail "setup-relay.sh should validate API key is not empty"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=== Results ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
