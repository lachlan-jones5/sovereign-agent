#!/usr/bin/env bash
# test-relay.sh - Tests for SSH relay functionality
#
# Tests GitHub Copilot-based relay functionality

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

echo
echo "========================================="
echo "Relay Script Tests"
echo "========================================="
echo

# Test 11: ssh-relay.sh shows help
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "SSH Tunnel for Sovereign Agent"; then
    pass "ssh-relay.sh shows help"
else
    fail "ssh-relay.sh shows help"
fi

# Test 12: ssh-relay.sh has start command
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "start <ssh-host>"; then
    pass "ssh-relay.sh has start command"
else
    fail "ssh-relay.sh has start command"
fi

# Test 13: ssh-relay.sh has stop command
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "stop"; then
    pass "ssh-relay.sh has stop command"
else
    fail "ssh-relay.sh has stop command"
fi

# Test 14: ssh-relay.sh has status command
if "$PROJECT_DIR/lib/ssh-relay.sh" help 2>&1 | grep -q "status"; then
    pass "ssh-relay.sh has status command"
else
    fail "ssh-relay.sh has status command"
fi

# Test 15: start-relay.sh shows help
if "$PROJECT_DIR/relay/start-relay.sh" help 2>&1 | grep -q "Sovereign Agent API Relay"; then
    pass "start-relay.sh shows help"
else
    fail "start-relay.sh shows help"
fi

# Test 16: start-relay.sh has daemon command
if "$PROJECT_DIR/relay/start-relay.sh" help 2>&1 | grep -q "daemon"; then
    pass "start-relay.sh has daemon command"
else
    fail "start-relay.sh has daemon command"
fi

# Test 17: start-relay.sh exports RELAY_HOST env var
if grep -q 'export RELAY_HOST=' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh exports RELAY_HOST env var"
else
    fail "start-relay.sh exports RELAY_HOST env var"
fi

# Test 18: start-relay.sh exports RELAY_PORT env var
if grep -q 'export RELAY_PORT=' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh exports RELAY_PORT env var"
else
    fail "start-relay.sh exports RELAY_PORT env var"
fi

# Test 19: start-relay.sh has default RELAY_HOST of 127.0.0.1
if grep -q 'RELAY_HOST:-127.0.0.1\|RELAY_HOST.*:-.*127.0.0.1' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh has default RELAY_HOST 127.0.0.1"
else
    fail "start-relay.sh has default RELAY_HOST 127.0.0.1"
fi

# Test 20: start-relay.sh has default RELAY_PORT of 8080
if grep -q 'RELAY_PORT:-8080\|RELAY_PORT.*:-.*8080' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh has default RELAY_PORT 8080"
else
    fail "start-relay.sh has default RELAY_PORT 8080"
fi

# Test 21: start-relay.sh documents RELAY_HOST in help
if "$PROJECT_DIR/relay/start-relay.sh" help 2>&1 | grep -q "RELAY_HOST"; then
    pass "start-relay.sh documents RELAY_HOST in help"
else
    fail "start-relay.sh documents RELAY_HOST in help"
fi

# Test 22: start-relay.sh logs the host it binds to
if grep -q 'Starting relay on http://\$RELAY_HOST:\$RELAY_PORT\|RELAY_HOST.*RELAY_PORT' "$PROJECT_DIR/relay/start-relay.sh"; then
    pass "start-relay.sh logs the host it binds to"
else
    fail "start-relay.sh logs the host it binds to"
fi

echo
echo "========================================="
echo "Relay TypeScript Tests - Core"
echo "========================================="
echo

# Test 23: main.ts imports required modules
if grep -q 'import.*from "fs"' "$PROJECT_DIR/relay/main.ts" || grep -q 'import.*from "bun"' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts imports required modules"
else
    fail "main.ts imports required modules"
fi

# Test 24: main.ts has health endpoint
if grep -q '/health' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has health endpoint"
else
    fail "main.ts has health endpoint"
fi

# Test 25: main.ts has allowed paths security
if grep -q 'ALLOWED_PATHS' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has allowed paths security"
else
    fail "main.ts has allowed paths security"
fi

# Test 26: main.ts adds Authorization header
if grep -q 'Authorization' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts adds Authorization header"
else
    fail "main.ts adds Authorization header"
fi

# Test 27: main.ts has stats endpoint
if grep -q '/stats' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has stats endpoint"
else
    fail "main.ts has stats endpoint"
fi

# Test 28: main.ts has setup endpoint
if grep -q '/setup' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has setup endpoint"
else
    fail "main.ts has setup endpoint"
fi

# Test 29: main.ts has bundle endpoint
if grep -q '/bundle.tar.gz' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has bundle endpoint"
else
    fail "main.ts has bundle endpoint"
fi

# Test 30: setup endpoint returns shell script content type
if grep -q 'text/x-shellscript' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup endpoint returns shell script content type"
else
    fail "setup endpoint returns shell script content type"
fi

# Test 31: bundle endpoint returns gzip content type
if grep -q 'application/gzip' "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle endpoint returns gzip content type"
else
    fail "bundle endpoint returns gzip content type"
fi

# Test 32: bundle excludes config.json (contains API key)
if grep -q "exclude.*config.json\|--exclude='config.json'" "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle excludes config.json"
else
    fail "bundle excludes config.json"
fi

# Test 33: bundle excludes .git directories
if grep -q "exclude.*\.git\|--exclude='.git'" "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle excludes .git directories"
else
    fail "bundle excludes .git directories"
fi

# Test 34: bundle excludes .env files
if grep -q "exclude.*\.env\|--exclude='.env'" "$PROJECT_DIR/relay/main.ts"; then
    pass "bundle excludes .env files"
else
    fail "bundle excludes .env files"
fi

# Test 35: setup script checks relay health
if grep -q 'localhost.*RELAY_PORT.*health\|localhost:\$RELAY_PORT/health' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script checks relay health"
else
    fail "setup script checks relay health"
fi

# Test 36: setup script downloads bundle
if grep -q 'bundle.tar.gz' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script downloads bundle"
else
    fail "setup script downloads bundle"
fi

# Test 37: main.ts reads RELAY_HOST from environment
if grep -q 'process.env.RELAY_HOST\|RELAY_HOST.*process.env' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts reads RELAY_HOST from environment"
else
    fail "main.ts reads RELAY_HOST from environment"
fi

# Test 38: main.ts reads RELAY_PORT from environment
if grep -q 'process.env.RELAY_PORT\|RELAY_PORT.*process.env' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts reads RELAY_PORT from environment"
else
    fail "main.ts reads RELAY_PORT from environment"
fi

# Test 39: main.ts uses RELAY_HOST in Bun.serve hostname
if grep -q 'hostname: RELAY_HOST\|hostname:.*RELAY_HOST' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts uses RELAY_HOST in Bun.serve hostname"
else
    fail "main.ts uses RELAY_HOST in Bun.serve hostname"
fi

# Test 40: main.ts uses RELAY_PORT in Bun.serve port
if grep -q 'port: RELAY_PORT\|port:.*RELAY_PORT' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts uses RELAY_PORT in Bun.serve port"
else
    fail "main.ts uses RELAY_PORT in Bun.serve port"
fi

# Test 41: main.ts logs the host and port at startup
if grep -q 'Relay listening on http://\${RELAY_HOST}:\${RELAY_PORT}\|RELAY_HOST.*RELAY_PORT' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts logs the host and port at startup"
else
    fail "main.ts logs the host and port at startup"
fi

# Test 42: setup script injects actual RELAY_PORT into client script
if grep -q '\${RELAY_PORT}' "$PROJECT_DIR/relay/main.ts" && grep -q 'RELAY_PORT:-\${RELAY_PORT}' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup endpoint injects actual RELAY_PORT into client script"
else
    fail "setup endpoint should inject actual RELAY_PORT into client script"
fi

# Test 43: setup script does not hardcode port 8080 as only default
# The default should come from the server's RELAY_PORT, not hardcoded 8080
if grep -A5 'path === "/setup"' "$PROJECT_DIR/relay/main.ts" | grep -q 'RELAY_PORT:-8080'; then
    fail "setup endpoint should not hardcode 8080 - should use server's RELAY_PORT"
else
    pass "setup endpoint uses dynamic RELAY_PORT default"
fi

# Test 44: setup script auto-installs Bun
if grep -q 'Installing Bun\|bun.sh/install' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script auto-installs Bun"
else
    fail "setup script should auto-install Bun"
fi

# Test 45: setup script auto-installs Go
if grep -q 'Installing Go\|go.dev/dl' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script auto-installs Go"
else
    fail "setup script should auto-install Go"
fi

# Test 46: setup script auto-installs jq
if grep -q 'Installing jq\|apt-get.*jq\|apk add jq' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script auto-installs jq"
else
    fail "setup script should auto-install jq"
fi

# Test 47: setup script verifies bundle extraction
if grep -q 'install.sh not found\|Bundle extraction failed' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script verifies bundle extraction"
else
    fail "setup script should verify bundle extraction succeeded"
fi

# Test 48: setup script makes install.sh executable
if grep -q 'chmod.*install.sh' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script makes install.sh executable"
else
    fail "setup script should chmod +x install.sh"
fi

echo
echo "========================================="
echo "GitHub Copilot Integration Tests"
echo "========================================="
echo

# Test 49: main.ts uses api.githubcopilot.com
if grep -q 'api.githubcopilot.com' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts uses api.githubcopilot.com"
else
    fail "main.ts should use api.githubcopilot.com"
fi

# Test 50: main.ts does NOT reference openrouter.ai
if ! grep -q 'openrouter.ai' "$PROJECT_DIR/relay/main.ts" || grep -q '# Legacy OpenRouter' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts does not reference openrouter.ai (or only in legacy comments)"
else
    fail "main.ts should not reference openrouter.ai"
fi

# Test 51: main.ts has /auth/device endpoint
if grep -q '/auth/device' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has /auth/device endpoint"
else
    fail "main.ts should have /auth/device endpoint"
fi

# Test 52: main.ts has /auth/status endpoint
if grep -q '/auth/status' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has /auth/status endpoint"
else
    fail "main.ts should have /auth/status endpoint"
fi

# Test 53: main.ts has /auth/poll endpoint
if grep -q '/auth/poll' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has /auth/poll endpoint"
else
    fail "main.ts should have /auth/poll endpoint"
fi

# Test 54: main.ts has device code flow implementation
if grep -q 'startDeviceCodeFlow\|device_code' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts implements device code flow"
else
    fail "main.ts should implement device code flow"
fi

# Test 55: main.ts has GitHub OAuth token support
if grep -q 'github_oauth_token\|GITHUB.*TOKEN' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has GitHub OAuth token support"
else
    fail "main.ts should have GitHub OAuth token support"
fi

# Test 56: main.ts has Copilot token refresh logic
if grep -q 'getCopilotToken\|copilotTokenCache\|COPILOT.*TOKEN' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has Copilot token refresh logic"
else
    fail "main.ts should have Copilot token refresh logic"
fi

# Test 57: main.ts forwards to /v1/* endpoints
if grep -q '/v1/\*\|/v1/chat/completions\|v1.*path' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts forwards to /v1/* endpoints"
else
    fail "main.ts should forward to /v1/* endpoints"
fi

# Test 58: main.ts has Copilot-specific headers
if grep -q 'COPILOT_HEADERS\|GitHubCopilotChat\|Editor-Version' "$PROJECT_DIR/relay/main.ts"; then
    pass "main.ts has Copilot-specific headers"
else
    fail "main.ts should have Copilot-specific headers"
fi

# Test 59: setup script checks auth status
if grep -q 'auth/status\|authenticated.*true' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script checks auth status"
else
    fail "setup script should check auth status"
fi

# Test 60: setup script mentions GitHub Copilot
if grep -q 'GitHub Copilot' "$PROJECT_DIR/relay/main.ts"; then
    pass "setup script mentions GitHub Copilot"
else
    fail "setup script should mention GitHub Copilot"
fi

echo
echo "========================================="
echo "Dockerfile.relay Tests"
echo "========================================="
echo

# Test 61: Dockerfile.relay copies full repo for bundle endpoint
if grep -q 'COPY \. \.\|COPY \.\/' "$PROJECT_DIR/Dockerfile.relay"; then
    pass "Dockerfile.relay copies full repo for bundle endpoint"
else
    fail "Dockerfile.relay should copy full repo (COPY . .) for bundle endpoint"
fi

# Test 62: Dockerfile.relay sets REPO_PATH env var
if grep -q 'ENV REPO_PATH' "$PROJECT_DIR/Dockerfile.relay"; then
    pass "Dockerfile.relay sets REPO_PATH env var"
else
    fail "Dockerfile.relay should set REPO_PATH env var"
fi

# Test 63: Dockerfile.relay installs git for submodule updates
if grep -q 'apk.*git\|apt.*git' "$PROJECT_DIR/Dockerfile.relay"; then
    pass "Dockerfile.relay installs git"
else
    fail "Dockerfile.relay should install git for submodule updates"
fi

# Test 64: Bundle endpoint uses REPO_PATH
if grep -q 'REPO_PATH.*resolve\|exec.*REPO_PATH' "$PROJECT_DIR/relay/main.ts"; then
    pass "Bundle endpoint uses REPO_PATH for tar command"
else
    fail "Bundle endpoint should use REPO_PATH"
fi

# Test 65: Bundle endpoint excludes .git directories
if grep -q "exclude.*\.git\|--exclude='.git'" "$PROJECT_DIR/relay/main.ts"; then
    pass "Bundle endpoint excludes .git directories"
else
    fail "Bundle endpoint should exclude .git directories"
fi

# Test 66: Bundle endpoint excludes config.json (contains API key)
if grep -q "exclude.*config.json\|--exclude='config.json'" "$PROJECT_DIR/relay/main.ts"; then
    pass "Bundle endpoint excludes config.json"
else
    fail "Bundle endpoint should exclude config.json"
fi

# Test 67: Dockerfile.relay clones vendor submodules
if grep -q 'git clone.*opencode\|git clone.*OpenAgents' "$PROJECT_DIR/Dockerfile.relay"; then
    pass "Dockerfile.relay clones vendor submodules"
else
    fail "Dockerfile.relay should clone vendor submodules"
fi

# Test 68: Dockerfile.relay removes .git from cloned submodules
if grep -q 'rm -rf vendor.*\.git' "$PROJECT_DIR/Dockerfile.relay"; then
    pass "Dockerfile.relay removes .git from cloned submodules"
else
    fail "Dockerfile.relay should remove .git from cloned submodules"
fi

echo
echo "========================================="
echo "install.sh Tests"
echo "========================================="
echo

# Test 69: install.sh handles non-git repo installation
if grep -q 'Not a git repo\|not a git repo\|\.git.*skip' "$PROJECT_DIR/install.sh"; then
    pass "install.sh handles non-git repo installation"
else
    fail "install.sh should handle non-git repo installation (bundle installs)"
fi

# Test 70: install.sh checks vendor directories exist
if grep -q 'VENDOR_DIR.*opencode\|vendor.*opencode' "$PROJECT_DIR/install.sh"; then
    pass "install.sh checks vendor directories exist"
else
    fail "install.sh should check vendor directories exist"
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
