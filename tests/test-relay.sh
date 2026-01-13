#!/usr/bin/env bash
# test-relay.sh - Tests for SSH relay functionality
#
# Tests config generation for relay mode and script functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "========================================="
echo "Relay Configuration Tests"
echo "========================================="
echo

# Test 1: relay directory exists
if [[ -d "$PROJECT_DIR/relay" ]]; then
    pass "relay directory exists"
else
    fail "relay directory exists"
fi

# Test 2: relay/main.ts exists
if [[ -f "$PROJECT_DIR/relay/main.ts" ]]; then
    pass "relay/main.ts exists"
else
    fail "relay/main.ts exists"
fi

# Test 3: relay/start-relay.sh exists and is executable
if [[ -x "$PROJECT_DIR/relay/start-relay.sh" ]]; then
    pass "relay/start-relay.sh exists and is executable"
else
    fail "relay/start-relay.sh exists and is executable"
fi

# Test 4: lib/ssh-relay.sh exists and is executable
if [[ -x "$PROJECT_DIR/lib/ssh-relay.sh" ]]; then
    pass "lib/ssh-relay.sh exists and is executable"
else
    fail "lib/ssh-relay.sh exists and is executable"
fi

# Test 5: config.json.example has relay section
if jq -e '.relay' "$PROJECT_DIR/config.json.example" > /dev/null 2>&1; then
    pass "config.json.example has relay section"
else
    fail "config.json.example has relay section"
fi

# Test 6: config.json.example has relay.enabled field
# Note: jq -e treats false as falsy, so we check if the field exists with 'has' or type check
if jq -e '.relay | has("enabled")' "$PROJECT_DIR/config.json.example" > /dev/null 2>&1; then
    pass "config.json.example has relay.enabled field"
else
    fail "config.json.example has relay.enabled field"
fi

# Test 7: config.json.example has relay.mode field
if jq -e '.relay.mode' "$PROJECT_DIR/config.json.example" > /dev/null 2>&1; then
    pass "config.json.example has relay.mode field"
else
    fail "config.json.example has relay.mode field"
fi

# Test 8: config.client.example exists
if [[ -f "$PROJECT_DIR/config.client.example" ]]; then
    pass "config.client.example exists"
else
    fail "config.client.example exists"
fi

# Test 9: config.client.example has relay.mode=client
if [[ "$(jq -r '.relay.mode' "$PROJECT_DIR/config.client.example")" == "client" ]]; then
    pass "config.client.example has relay.mode=client"
else
    fail "config.client.example has relay.mode=client"
fi

# Test 10: config.client.example has relay.enabled=true
if [[ "$(jq -r '.relay.enabled' "$PROJECT_DIR/config.client.example")" == "true" ]]; then
    pass "config.client.example has relay.enabled=true"
else
    fail "config.client.example has relay.enabled=true"
fi

# Test 11: opencode.json.tmpl has RELAY_BASE_URL placeholder
if grep -q '{{RELAY_BASE_URL}}' "$PROJECT_DIR/templates/opencode.json.tmpl"; then
    pass "opencode.json.tmpl has RELAY_BASE_URL placeholder"
else
    fail "opencode.json.tmpl has RELAY_BASE_URL placeholder"
fi

# Test 12: generate-configs.sh handles relay settings
if grep -q 'relay_enabled' "$PROJECT_DIR/lib/generate-configs.sh"; then
    pass "generate-configs.sh handles relay settings"
else
    fail "generate-configs.sh handles relay settings"
fi

echo
echo "========================================="
echo "Relay Config Generation Tests"
echo "========================================="
echo

# Create test config for server mode (relay disabled)
cat > "$TEMP_DIR/config-server.json" << 'EOF'
{
  "openrouter_api_key": "sk-test-key",
  "site_url": "https://test.local",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/model-1",
    "planner": "test/model-2",
    "librarian": "test/model-3",
    "fallback": "test/model-4"
  },
  "relay": {
    "enabled": false,
    "mode": "server",
    "port": 8080
  }
}
EOF

# Create test config for client mode
cat > "$TEMP_DIR/config-client.json" << 'EOF'
{
  "openrouter_api_key": "",
  "site_url": "https://test.local",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/model-1",
    "planner": "test/model-2",
    "librarian": "test/model-3",
    "fallback": "test/model-4"
  },
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 9999
  }
}
EOF

# Source the generate-configs.sh
source "$PROJECT_DIR/lib/generate-configs.sh"

# Test 13: Server mode generates openrouter.ai baseURL
OUTPUT_DIR="$TEMP_DIR/output-server"
mkdir -p "$OUTPUT_DIR"
generate_from_template "$PROJECT_DIR/templates/opencode.json.tmpl" "$OUTPUT_DIR/opencode.json" "$TEMP_DIR/config-server.json" 2>/dev/null

if grep -q '"baseURL": "https://openrouter.ai"' "$OUTPUT_DIR/opencode.json"; then
    pass "Server mode generates openrouter.ai baseURL"
else
    fail "Server mode generates openrouter.ai baseURL"
    echo "  Generated content:"
    grep baseURL "$OUTPUT_DIR/opencode.json" || echo "  No baseURL found"
fi

# Test 14: Client mode generates localhost baseURL
OUTPUT_DIR="$TEMP_DIR/output-client"
mkdir -p "$OUTPUT_DIR"
generate_from_template "$PROJECT_DIR/templates/opencode.json.tmpl" "$OUTPUT_DIR/opencode.json" "$TEMP_DIR/config-client.json" 2>/dev/null

if grep -q '"baseURL": "http://localhost:9999"' "$OUTPUT_DIR/opencode.json"; then
    pass "Client mode generates localhost baseURL with custom port"
else
    fail "Client mode generates localhost baseURL with custom port"
    echo "  Generated content:"
    grep baseURL "$OUTPUT_DIR/opencode.json" || echo "  No baseURL found"
fi

echo
echo "========================================="
echo "Relay Script Tests"
echo "========================================="
echo

# Test 15: ssh-relay.sh shows help
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "SSH Tunnel for Sovereign Agent"; then
    pass "ssh-relay.sh shows help"
else
    fail "ssh-relay.sh shows help"
fi

# Test 16: ssh-relay.sh has start command
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "start <ssh-host>"; then
    pass "ssh-relay.sh has start command"
else
    fail "ssh-relay.sh has start command"
fi

# Test 17: ssh-relay.sh has stop command
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "stop"; then
    pass "ssh-relay.sh has stop command"
else
    fail "ssh-relay.sh has stop command"
fi

# Test 18: ssh-relay.sh has status command
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "status"; then
    pass "ssh-relay.sh has status command"
else
    fail "ssh-relay.sh has status command"
fi

# Test 19: start-relay.sh shows help
if "$PROJECT_DIR/relay/start-relay.sh" help 2>&1 | grep -q "Sovereign Agent API Relay"; then
    pass "start-relay.sh shows help"
else
    fail "start-relay.sh shows help"
fi

# Test 20: start-relay.sh has daemon command
if "$PROJECT_DIR/relay/start-relay.sh" help 2>&1 | grep -q "daemon"; then
    pass "start-relay.sh has daemon command"
else
    fail "start-relay.sh has daemon command"
fi

# Test 21: start-relay.sh exports RELAY_HOST env var
if grep -q 'export RELAY_HOST=' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh exports RELAY_HOST env var"
else
    fail "start-relay.sh exports RELAY_HOST env var"
fi

# Test 22: start-relay.sh exports RELAY_PORT env var
if grep -q 'export RELAY_PORT=' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh exports RELAY_PORT env var"
else
    fail "start-relay.sh exports RELAY_PORT env var"
fi

# Test 23: start-relay.sh has default RELAY_HOST of 127.0.0.1
if grep -q 'RELAY_HOST:-127.0.0.1\|RELAY_HOST.*:-.*127.0.0.1' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh has default RELAY_HOST 127.0.0.1"
else
    fail "start-relay.sh has default RELAY_HOST 127.0.0.1"
fi

# Test 24: start-relay.sh has default RELAY_PORT of 8080
if grep -q 'RELAY_PORT:-8080\|RELAY_PORT.*:-.*8080' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh has default RELAY_PORT 8080"
else
    fail "start-relay.sh has default RELAY_PORT 8080"
fi

# Test 25: start-relay.sh documents RELAY_HOST in help
if "$PROJECT_DIR/relay/start-relay.sh" help 2>&1 | grep -q "RELAY_HOST"; then
    pass "start-relay.sh documents RELAY_HOST in help"
else
    fail "start-relay.sh documents RELAY_HOST in help"
fi

# Test 26: start-relay.sh logs the host it binds to
if grep -q 'Starting relay on http://\$RELAY_HOST:\$RELAY_PORT\|RELAY_HOST.*RELAY_PORT' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh logs the host it binds to"
else
    fail "start-relay.sh logs the host it binds to"
fi

echo
echo "========================================="
echo "Relay TypeScript Tests"
echo "========================================="
echo

# Test 27: main.ts imports required modules
if grep -q 'import.*from "fs"' "$PROJECT_DIR/relay/main.ts" || grep -q 'import.*from "bun"' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts imports required modules"
else
    fail "main.ts imports required modules"
fi

# Test 28: main.ts has health endpoint
if grep -q '/health' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has health endpoint"
else
    fail "main.ts has health endpoint"
fi

# Test 29: main.ts has allowed paths security
if grep -q 'ALLOWED_PATHS' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has allowed paths security"
else
    fail "main.ts has allowed paths security"
fi

# Test 30: main.ts adds Authorization header
if grep -q 'Authorization' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts adds Authorization header"
else
    fail "main.ts adds Authorization header"
fi

# Test 31: main.ts forwards to openrouter.ai
if grep -q 'openrouter.ai' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts forwards to openrouter.ai"
else
    fail "main.ts forwards to openrouter.ai"
fi

# Test 32: main.ts has stats endpoint
if grep -q '/stats' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has stats endpoint"
else
    fail "main.ts has stats endpoint"
fi

# Test 33: main.ts has setup endpoint
if grep -q '/setup' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has setup endpoint"
else
    fail "main.ts has setup endpoint"
fi

# Test 34: main.ts has bundle endpoint
if grep -q '/bundle.tar.gz' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has bundle endpoint"
else
    fail "main.ts has bundle endpoint"
fi

# Test 35: setup endpoint returns shell script content type
if grep -q 'text/x-shellscript' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup endpoint returns shell script content type"
else
    fail "setup endpoint returns shell script content type"
fi

# Test 36: bundle endpoint returns gzip content type
if grep -q 'application/gzip' "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle endpoint returns gzip content type"
else
    fail "bundle endpoint returns gzip content type"
fi

# Test 37: bundle excludes config.json (contains API key)
if grep -q "exclude.*config.json\|--exclude='config.json'" "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle excludes config.json"
else
    fail "bundle excludes config.json"
fi

# Test 38: bundle excludes .git directories
if grep -q "exclude.*\.git\|--exclude='.git'" "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle excludes .git directories"
else
    fail "bundle excludes .git directories"
fi

# Test 39: bundle excludes .env files
if grep -q "exclude.*\.env\|--exclude='.env'" "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle excludes .env files"
else
    fail "bundle excludes .env files"
fi

# Test 40: setup script checks relay health
if grep -q 'localhost.*RELAY_PORT.*health\|localhost:\$RELAY_PORT/health' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script checks relay health"
else
    fail "setup script checks relay health"
fi

# Test 41: setup script downloads bundle
if grep -q 'bundle.tar.gz' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script downloads bundle"
else
    fail "setup script downloads bundle"
fi

# Test 42: main.ts reads RELAY_HOST from environment
if grep -q 'process.env.RELAY_HOST\|RELAY_HOST.*process.env' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts reads RELAY_HOST from environment"
else
    fail "main.ts reads RELAY_HOST from environment"
fi

# Test 43: main.ts reads RELAY_PORT from environment
if grep -q 'process.env.RELAY_PORT\|RELAY_PORT.*process.env' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts reads RELAY_PORT from environment"
else
    fail "main.ts reads RELAY_PORT from environment"
fi

# Test 44: main.ts uses RELAY_HOST in Bun.serve hostname
if grep -q 'hostname: RELAY_HOST\|hostname:.*RELAY_HOST' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts uses RELAY_HOST in Bun.serve hostname"
else
    fail "main.ts uses RELAY_HOST in Bun.serve hostname"
fi

# Test 45: main.ts uses RELAY_PORT in Bun.serve port
if grep -q 'port: RELAY_PORT\|port:.*RELAY_PORT' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts uses RELAY_PORT in Bun.serve port"
else
    fail "main.ts uses RELAY_PORT in Bun.serve port"
fi

# Test 46: main.ts logs the host and port at startup
if grep -q 'Relay listening on http://\${RELAY_HOST}:\${RELAY_PORT}\|RELAY_HOST.*RELAY_PORT' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts logs the host and port at startup"
else
    fail "main.ts logs the host and port at startup"
fi

# Test 47: setup script injects actual RELAY_PORT into client script
if grep -q '\${RELAY_PORT}' "$PROJECT_DIR/relay/main.ts" && grep -q 'RELAY_PORT:-\${RELAY_PORT}' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup endpoint injects actual RELAY_PORT into client script"
else
    fail "setup endpoint should inject actual RELAY_PORT into client script"
fi

# Test 48: setup script does not hardcode port 8080 as only default
# The default should come from the server's RELAY_PORT, not hardcoded 8080
if grep -A5 'path === "/setup"' "$PROJECT_DIR/relay/main.ts" | grep -q 'RELAY_PORT:-8080'; then
    fail "setup endpoint should not hardcode 8080 - should use server's RELAY_PORT"
else
    pass "setup endpoint uses dynamic RELAY_PORT default"
fi

# Test 49: setup script auto-installs Bun
if grep -q 'Installing Bun\|bun.sh/install' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script auto-installs Bun"
else
    fail "setup script should auto-install Bun"
fi

# Test 50: setup script auto-installs Go
if grep -q 'Installing Go\|go.dev/dl' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script auto-installs Go"
else
    fail "setup script should auto-install Go"
fi

# Test 51: setup script auto-installs jq
if grep -q 'Installing jq\|apt-get.*jq\|apk add jq' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script auto-installs jq"
else
    fail "setup script should auto-install jq"
fi

# Test 52: setup script verifies bundle extraction
if grep -q 'install.sh not found\|Bundle extraction failed' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script verifies bundle extraction"
else
    fail "setup script should verify bundle extraction succeeded"
fi

# Test 53: setup script makes install.sh executable
if grep -q 'chmod.*install.sh' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script makes install.sh executable"
else
    fail "setup script should chmod +x install.sh"
fi

echo
echo "========================================="
echo "Relay Test Results"
echo "========================================="
echo "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
