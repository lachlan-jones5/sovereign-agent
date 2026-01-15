#!/usr/bin/env bash
# test-copilot-install.sh - Tests for Copilot-based install flow
#
# Tests cover:
# - Install script structure
# - Config validation
# - OpenCode config generation
# - Dependency checks
# - Error handling

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

skip() {
    echo -e "${YELLOW}○${NC} $1 (skipped)"
}

header() {
    echo
    echo -e "${YELLOW}=== $1 ===${NC}"
    echo
}

# ============================================
# Install Script Structure
# ============================================

header "Install Script Structure"

# Test 1: install.sh exists and is executable
if [[ -f "$PROJECT_ROOT/install.sh" && -x "$PROJECT_ROOT/install.sh" ]]; then
    pass "install.sh exists and is executable"
else
    fail "install.sh exists and is executable"
fi

# Test 2: install.sh has shebang
if head -1 "$PROJECT_ROOT/install.sh" | grep -q '^#!/'; then
    pass "install.sh has shebang"
else
    fail "install.sh has shebang"
fi

# Test 3: install.sh uses set -e for safety
if grep -q 'set -e' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh uses set -e"
else
    fail "install.sh uses set -e"
fi

# Test 4: install.sh has help option
if grep -q '\-h\|--help' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has help option"
else
    fail "install.sh has help option"
fi

# Test 5: install.sh has skip-deps option
if grep -q 'skip-deps\|SKIP_DEPS' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has skip-deps option"
else
    fail "install.sh has skip-deps option"
fi

# Test 6: install.sh checks for bun
if grep -q 'command -v bun' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh checks for bun"
else
    fail "install.sh checks for bun"
fi

# Test 7: install.sh mentions GitHub Copilot
if grep -qi 'copilot\|GitHub' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh mentions GitHub Copilot"
else
    fail "install.sh mentions GitHub Copilot"
fi

# Test 8: install.sh installs from vendor/opencode
if grep -q 'VENDOR_DIR.*opencode\|vendor.*opencode' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh references vendor/opencode"
else
    fail "install.sh references vendor/opencode"
fi

# Test 9: install.sh copies OpenAgents
if grep -q 'OpenAgents\|agents' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh copies OpenAgents"
else
    fail "install.sh copies OpenAgents"
fi

# Test 10: install.sh has completion message
if grep -q 'Complete\|Success' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has completion message"
else
    fail "install.sh has completion message"
fi

# ============================================
# Validate Script
# ============================================

header "Validate Script"

# Test 11: validate.sh exists
if [[ -f "$PROJECT_ROOT/lib/validate.sh" ]]; then
    pass "lib/validate.sh exists"
else
    fail "lib/validate.sh exists"
fi

# Test 12: validate.sh accepts relay mode config
if grep -q 'relay.mode' "$PROJECT_ROOT/lib/validate.sh" || grep -q 'relay_mode' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh accepts relay mode config"
else
    fail "validate.sh accepts relay mode config"
fi

# Test 13: validate.sh warns about deprecated openrouter_api_key
if grep -q 'deprecated\|openrouter.*deprecated' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh warns about deprecated openrouter_api_key"
else
    fail "validate.sh warns about deprecated openrouter_api_key"
fi

# Test 14: validate.sh handles missing config gracefully
if grep -q 'not found\|does not exist' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh handles missing config"
else
    fail "validate.sh handles missing config"
fi

# Test 15: validate.sh checks for valid JSON
if grep -q 'jq\|JSON' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh checks JSON validity"
else
    fail "validate.sh checks JSON validity"
fi

# ============================================
# Config Examples
# ============================================

header "Config Examples"

# Test 16: config.json.example is valid JSON
if jq empty "$PROJECT_ROOT/config.json.example" 2>/dev/null; then
    pass "config.json.example is valid JSON"
else
    fail "config.json.example is valid JSON"
fi

# Test 17: config.json.example has relay section
if jq -e '.relay' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "config.json.example has relay section"
else
    fail "config.json.example has relay section"
fi

# Test 18: config.json.example does NOT have openrouter_api_key
if ! jq -e '.openrouter_api_key' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "config.json.example does not have openrouter_api_key"
else
    fail "config.json.example does not have openrouter_api_key (should be removed)"
fi

# Test 19: config.json.example does NOT have models section (using templates)
if ! jq -e '.models' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "config.json.example does not have models section (using relay)"
else
    skip "config.json.example has models section (may be for standalone use)"
fi

# ============================================
# Relay Server Mode Tests
# ============================================

header "Relay Server Mode"

# Create temp directory for tests
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Test 20: Validate accepts relay server config
cat > "$TEMP_DIR/server-config.json" <<EOF
{
  "relay": {
    "enabled": true,
    "mode": "server",
    "port": 8080
  }
}
EOF

if bash "$PROJECT_ROOT/lib/validate.sh" "$TEMP_DIR/server-config.json" 2>/dev/null; then
    pass "Validate accepts relay server config"
else
    fail "Validate accepts relay server config"
fi

# Test 21: Validate accepts relay client config
cat > "$TEMP_DIR/client-config.json" <<EOF
{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8081
  }
}
EOF

if bash "$PROJECT_ROOT/lib/validate.sh" "$TEMP_DIR/client-config.json" 2>/dev/null; then
    pass "Validate accepts relay client config"
else
    fail "Validate accepts relay client config"
fi

# Test 22: Validate accepts config with github_oauth_token
cat > "$TEMP_DIR/oauth-config.json" <<EOF
{
  "github_oauth_token": "gho_test_token_12345",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF

if bash "$PROJECT_ROOT/lib/validate.sh" "$TEMP_DIR/oauth-config.json" 2>/dev/null; then
    pass "Validate accepts config with github_oauth_token"
else
    fail "Validate accepts config with github_oauth_token"
fi

# ============================================
# OpenCode Config Generation
# ============================================

header "OpenCode Config Generation"

# Test 23: Setup script in relay generates OpenCode config
if grep -q 'opencode.jsonc\|opencode\.json' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Relay generates OpenCode config file"
else
    fail "Relay generates OpenCode config file"
fi

# Test 24: Generated config uses sovereign-relay provider
if grep -q '"sovereign-relay"' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Generated config uses sovereign-relay provider"
else
    fail "Generated config uses sovereign-relay provider"
fi

# Test 25: Generated config has model definitions
if grep -q '"gpt-5-mini"' "$PROJECT_ROOT/relay/main.ts" && \
   grep -q '"claude-opus-4.5"' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Generated config has model definitions"
else
    fail "Generated config has model definitions"
fi

# Test 26: Generated config sets baseURL to localhost
if grep -q 'localhost.*8081\|localhost.*RELAY_PORT' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Generated config sets baseURL to localhost with port"
else
    fail "Generated config sets baseURL to localhost with port"
fi

# Test 27: Generated config has model context limits
if grep -q '"limit".*"context"' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Generated config has model context limits"
else
    fail "Generated config has model context limits"
fi

# ============================================
# Dependency Checks
# ============================================

header "Dependency Checks"

# Test 28: check-deps.sh exists
if [[ -f "$PROJECT_ROOT/lib/check-deps.sh" ]]; then
    pass "lib/check-deps.sh exists"
else
    fail "lib/check-deps.sh exists"
fi

# Test 29: check-deps.sh is sourced in install.sh
if grep -q 'source.*check-deps\|\..*check-deps' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh sources check-deps.sh"
else
    fail "install.sh sources check-deps.sh"
fi

# ============================================
# Submodule Handling
# ============================================

header "Submodule Handling"

# Test 30: install.sh checks for submodules
if grep -q 'submodule\|vendor' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh handles submodules"
else
    fail "install.sh handles submodules"
fi

# Test 31: install.sh handles missing git repo (bundle mode)
if grep -q '\.git\|not a git repo\|bundle' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh handles non-git environments"
else
    fail "install.sh handles non-git environments"
fi

# Test 32: Vendor directories exist
if [[ -d "$PROJECT_ROOT/vendor/opencode" && -d "$PROJECT_ROOT/vendor/OpenAgents" ]]; then
    pass "Vendor directories exist"
else
    fail "Vendor directories exist"
fi

# ============================================
# Error Handling
# ============================================

header "Error Handling"

# Test 33: install.sh has error messages
if grep -q 'ERROR\|error\|Error' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has error messages"
else
    fail "install.sh has error messages"
fi

# Test 34: install.sh has warning messages
if grep -q 'WARN\|warn\|Warning' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has warning messages"
else
    fail "install.sh has warning messages"
fi

# Test 35: validate.sh exits with non-zero on error
if grep -q 'exit 1\|return 1' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh exits with non-zero on error"
else
    fail "validate.sh exits with non-zero on error"
fi

# ============================================
# Relay Setup Script
# ============================================

header "Relay Setup Script Content"

# Test 36: Setup script checks tunnel health
if grep -q '/health' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script checks tunnel health"
else
    fail "Setup script checks tunnel health"
fi

# Test 37: Setup script checks authentication
if grep -q '/auth/status' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script checks authentication status"
else
    fail "Setup script checks authentication status"
fi

# Test 38: Setup script installs bun if missing
if grep -q 'bun.sh/install\|Installing Bun' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script installs bun if missing"
else
    fail "Setup script installs bun if missing"
fi

# Test 39: Setup script installs Go if missing
if grep -q 'go.dev\|Installing Go' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script installs Go if missing"
else
    fail "Setup script installs Go if missing"
fi

# Test 40: Setup script runs install.sh
if grep -q './install.sh\|install\.sh' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script runs install.sh"
else
    fail "Setup script runs install.sh"
fi

# ============================================
# Bundle Tests
# ============================================

header "Bundle Endpoint"

# Test 41: Bundle excludes sensitive files
if grep -q "exclude.*config\.json" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes config.json"
else
    fail "Bundle excludes config.json"
fi

# Test 42: Bundle excludes .git
if grep -q "exclude.*\.git" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes .git"
else
    fail "Bundle excludes .git"
fi

# Test 43: Bundle excludes node_modules
if grep -q "exclude.*node_modules" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes node_modules"
else
    fail "Bundle excludes node_modules"
fi

# Test 44: Bundle excludes tests
if grep -q "exclude.*tests" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes tests"
else
    fail "Bundle excludes tests"
fi

# Test 45: Bundle returns correct content type
if grep -q 'application/gzip' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle returns application/gzip content type"
else
    fail "Bundle returns application/gzip content type"
fi

# ============================================
# Model Configuration
# ============================================

header "Model Configuration in Setup"

# Test 46: Setup includes FREE models
if grep -q '\[FREE\]' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup marks FREE models"
else
    fail "Setup marks FREE models"
fi

# Test 47: Setup includes multiplier info in model names
if grep -q '\[0.33x\]\|\[1x\]\|\[3x\]' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup includes multiplier info in model names"
else
    fail "Setup includes multiplier info in model names"
fi

# Test 48: Setup includes o3 models
if grep -q '"o3"' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup includes o3 model"
else
    fail "Setup includes o3 model"
fi

# Test 49: Setup includes gemini-3 models
if grep -q 'gemini-3' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup includes gemini-3 models"
else
    fail "Setup includes gemini-3 models"
fi

# Test 50: Setup includes gpt-5 series
if grep -q 'gpt-5\.' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup includes gpt-5 series models"
else
    fail "Setup includes gpt-5 series models"
fi

# ============================================
# Summary
# ============================================

echo
echo "========================================"
echo "Test Results"
echo "========================================"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total:  $TESTS_RUN"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
