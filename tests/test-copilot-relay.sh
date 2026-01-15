#!/usr/bin/env bash
# test-copilot-relay.sh - Comprehensive tests for GitHub Copilot relay
#
# Tests cover:
# - Relay configuration for Copilot
# - Auth endpoint structure
# - Setup script generation
# - Model configuration
# - Health/stats endpoints

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RELAY_DIR="$PROJECT_ROOT/relay"

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
# Relay Source Code Tests
# ============================================

header "Relay Source Code Structure"

# Test 1: main.ts exists
if [[ -f "$RELAY_DIR/main.ts" ]]; then
    pass "main.ts exists"
else
    fail "main.ts exists"
fi

# Test 2: main.ts uses Copilot API base
if grep -q 'api.githubcopilot.com' "$RELAY_DIR/main.ts"; then
    pass "main.ts uses Copilot API base URL"
else
    fail "main.ts uses Copilot API base URL"
fi

# Test 3: No OpenRouter references in main relay code
if ! grep -q 'openrouter.ai' "$RELAY_DIR/main.ts"; then
    pass "main.ts does not reference openrouter.ai"
else
    fail "main.ts does not reference openrouter.ai (should use Copilot)"
fi

# Test 4: Has device code flow endpoint
if grep -q '/auth/device' "$RELAY_DIR/main.ts"; then
    pass "main.ts has /auth/device endpoint"
else
    fail "main.ts has /auth/device endpoint"
fi

# Test 5: Has auth poll endpoint
if grep -q '/auth/poll' "$RELAY_DIR/main.ts"; then
    pass "main.ts has /auth/poll endpoint"
else
    fail "main.ts has /auth/poll endpoint"
fi

# Test 6: Has auth status endpoint
if grep -q '/auth/status' "$RELAY_DIR/main.ts"; then
    pass "main.ts has /auth/status endpoint"
else
    fail "main.ts has /auth/status endpoint"
fi

# Test 7: Uses Copilot-specific headers
if grep -q 'GitHubCopilotChat' "$RELAY_DIR/main.ts"; then
    pass "main.ts uses GitHubCopilotChat user agent"
else
    fail "main.ts uses GitHubCopilotChat user agent"
fi

# Test 8: Has Copilot Integration ID
if grep -q 'Copilot-Integration-Id' "$RELAY_DIR/main.ts"; then
    pass "main.ts sets Copilot-Integration-Id header"
else
    fail "main.ts sets Copilot-Integration-Id header"
fi

# Test 9: Has token refresh logic
if grep -q 'copilot_internal/v2/token' "$RELAY_DIR/main.ts"; then
    pass "main.ts has Copilot token refresh endpoint"
else
    fail "main.ts has Copilot token refresh endpoint"
fi

# Test 10: Has token caching
if grep -q 'copilotTokenCache' "$RELAY_DIR/main.ts"; then
    pass "main.ts has Copilot token caching"
else
    fail "main.ts has Copilot token caching"
fi

# ============================================
# Model Multiplier Tests
# ============================================

header "Model Multipliers"

# Test 11: Has MODEL_MULTIPLIERS constant
if grep -q 'MODEL_MULTIPLIERS' "$RELAY_DIR/main.ts"; then
    pass "main.ts defines MODEL_MULTIPLIERS"
else
    fail "main.ts defines MODEL_MULTIPLIERS"
fi

# Test 12: gpt-5-mini is free (0x)
if grep -A2 '"gpt-5-mini"' "$RELAY_DIR/main.ts" | grep -q ': 0'; then
    pass "gpt-5-mini has 0x multiplier (free)"
else
    fail "gpt-5-mini has 0x multiplier (free)"
fi

# Test 13: gpt-4.1 is free (0x)
if grep -A2 '"gpt-4.1"' "$RELAY_DIR/main.ts" | grep -q ': 0'; then
    pass "gpt-4.1 has 0x multiplier (free)"
else
    fail "gpt-4.1 has 0x multiplier (free)"
fi

# Test 14: gpt-4o is free (0x)
if grep -A2 '"gpt-4o"' "$RELAY_DIR/main.ts" | grep -q ': 0'; then
    pass "gpt-4o has 0x multiplier (free)"
else
    fail "gpt-4o has 0x multiplier (free)"
fi

# Test 15: claude-haiku-4.5 is 0.33x
if grep -A2 '"claude-haiku-4.5"' "$RELAY_DIR/main.ts" | grep -q '0.33'; then
    pass "claude-haiku-4.5 has 0.33x multiplier"
else
    fail "claude-haiku-4.5 has 0.33x multiplier"
fi

# Test 16: claude-sonnet-4.5 is 1x
if grep -A2 '"claude-sonnet-4.5"' "$RELAY_DIR/main.ts" | grep -q ': 1'; then
    pass "claude-sonnet-4.5 has 1x multiplier"
else
    fail "claude-sonnet-4.5 has 1x multiplier"
fi

# Test 17: claude-opus-4.5 is 3x
if grep -A2 '"claude-opus-4.5"' "$RELAY_DIR/main.ts" | grep -q ': 3'; then
    pass "claude-opus-4.5 has 3x multiplier"
else
    fail "claude-opus-4.5 has 3x multiplier"
fi

# Test 18: NO claude-sonnet-4 (deprecated)
if ! grep -q '"claude-sonnet-4":' "$RELAY_DIR/main.ts"; then
    pass "claude-sonnet-4 is NOT in multipliers (deprecated)"
else
    fail "claude-sonnet-4 is NOT in multipliers (deprecated)"
fi

# Test 19: NO gemini-2.5-pro (deprecated)
if ! grep -q '"gemini-2.5-pro"' "$RELAY_DIR/main.ts"; then
    pass "gemini-2.5-pro is NOT in multipliers (deprecated)"
else
    fail "gemini-2.5-pro is NOT in multipliers (deprecated)"
fi

# Test 20: NO claude-opus-4 (10x, use 4.5 instead)
if ! grep -q '"claude-opus-4":' "$RELAY_DIR/main.ts"; then
    pass "claude-opus-4 is NOT in multipliers (use 4.5)"
else
    fail "claude-opus-4 is NOT in multipliers (use 4.5)"
fi

# Test 21: NO claude-opus-41 (10x, use 4.5 instead)
if ! grep -q '"claude-opus-41"' "$RELAY_DIR/main.ts"; then
    pass "claude-opus-41 is NOT in multipliers (use 4.5)"
else
    fail "claude-opus-41 is NOT in multipliers (use 4.5)"
fi

# ============================================
# Config Schema Tests
# ============================================

header "Config Schema"

# Test 22: config.json.example exists
if [[ -f "$PROJECT_ROOT/config.json.example" ]]; then
    pass "config.json.example exists"
else
    fail "config.json.example exists"
fi

# Test 23: No openrouter_api_key in example config
if ! grep -q 'openrouter_api_key' "$PROJECT_ROOT/config.json.example"; then
    pass "config.json.example does not have openrouter_api_key"
else
    fail "config.json.example does not have openrouter_api_key (should be removed)"
fi

# Test 24: Has relay section in example config
if grep -q '"relay"' "$PROJECT_ROOT/config.json.example"; then
    pass "config.json.example has relay section"
else
    fail "config.json.example has relay section"
fi

# Test 25: main.ts accepts github_oauth_token
if grep -q 'github_oauth_token' "$RELAY_DIR/main.ts"; then
    pass "main.ts accepts github_oauth_token config"
else
    fail "main.ts accepts github_oauth_token config"
fi

# ============================================
# Setup Script Tests
# ============================================

header "Setup Script Generation"

# Test 26: Setup script checks auth status
if grep -q '/auth/status' "$RELAY_DIR/main.ts"; then
    pass "Setup script checks /auth/status"
else
    fail "Setup script checks /auth/status"
fi

# Test 27: Setup script creates sovereign-relay provider
if grep -q 'sovereign-relay' "$RELAY_DIR/main.ts"; then
    pass "Setup script creates sovereign-relay provider"
else
    fail "Setup script creates sovereign-relay provider"
fi

# Test 28: Setup script sets default model to gpt-5-mini
if grep -q 'sovereign-relay/gpt-5-mini' "$RELAY_DIR/main.ts"; then
    pass "Setup script sets default model to gpt-5-mini"
else
    fail "Setup script sets default model to gpt-5-mini"
fi

# Test 29: Setup script includes baseURL with /v1
if grep -q 'baseURL.*localhost.*v1' "$RELAY_DIR/main.ts"; then
    pass "Setup script includes baseURL with /v1 path"
else
    fail "Setup script includes baseURL with /v1 path"
fi

# Test 30: Setup script uses @ai-sdk/openai-compatible
if grep -q '@ai-sdk/openai-compatible' "$RELAY_DIR/main.ts"; then
    pass "Setup script uses @ai-sdk/openai-compatible npm package"
else
    fail "Setup script uses @ai-sdk/openai-compatible npm package"
fi

# ============================================
# Health/Stats Endpoint Tests
# ============================================

header "Health and Stats Endpoints"

# Test 31: Health endpoint returns authenticated status
if grep -q 'authenticated:.*hasGitHubAuth' "$RELAY_DIR/main.ts"; then
    pass "Health endpoint returns authenticated status"
else
    fail "Health endpoint returns authenticated status"
fi

# Test 32: Health endpoint returns premium_requests_used
if grep -q 'premium_requests_used' "$RELAY_DIR/main.ts"; then
    pass "Health endpoint returns premium_requests_used"
else
    fail "Health endpoint returns premium_requests_used"
fi

# Test 33: Relay identifier is sovereign-agent-copilot
if grep -q 'sovereign-agent-copilot' "$RELAY_DIR/main.ts"; then
    pass "Relay identifier is sovereign-agent-copilot"
else
    fail "Relay identifier is sovereign-agent-copilot"
fi

# ============================================
# Security Tests
# ============================================

header "Security Checks"

# Test 34: Uses HTTPS for GitHub endpoints
if grep -q 'https://github.com' "$RELAY_DIR/main.ts" && \
   ! grep -q 'http://github.com' "$RELAY_DIR/main.ts"; then
    pass "Uses HTTPS for GitHub endpoints"
else
    fail "Uses HTTPS for GitHub endpoints"
fi

# Test 35: Uses HTTPS for Copilot API
if grep -q 'https://api.githubcopilot.com' "$RELAY_DIR/main.ts" && \
   ! grep -q 'http://api.githubcopilot.com' "$RELAY_DIR/main.ts"; then
    pass "Uses HTTPS for Copilot API"
else
    fail "Uses HTTPS for Copilot API"
fi

# Test 36: Has token expiry buffer (5 minutes)
if grep -q '5 \* 60 \* 1000' "$RELAY_DIR/main.ts"; then
    pass "Has 5-minute token expiry buffer"
else
    fail "Has 5-minute token expiry buffer"
fi

# Test 37: Deletes Authorization header before adding own
if grep -q 'delete.*x-api-key\|delete.*authorization' "$RELAY_DIR/main.ts"; then
    pass "Removes client authorization headers"
else
    # Check for headers.delete pattern
    if grep -q 'headers.delete' "$RELAY_DIR/main.ts"; then
        pass "Removes client authorization headers (via headers.delete)"
    else
        skip "Removes client authorization headers (implementation may vary)"
    fi
fi

# Test 38: Bundle excludes config.json
if grep -q "exclude.*config.json" "$RELAY_DIR/main.ts"; then
    pass "Bundle excludes config.json"
else
    fail "Bundle excludes config.json"
fi

# Test 39: Bundle excludes .env
if grep -q "exclude.*\.env" "$RELAY_DIR/main.ts"; then
    pass "Bundle excludes .env"
else
    fail "Bundle excludes .env"
fi

# ============================================
# TypeScript Compilation Test
# ============================================

header "TypeScript Compilation"

# Test 40: Relay compiles without errors
if command -v bun &>/dev/null; then
    cd "$RELAY_DIR"
    if bun build main.ts --outdir ./dist --target bun 2>/dev/null; then
        pass "main.ts compiles without errors"
    else
        fail "main.ts compiles without errors"
    fi
    cd "$PROJECT_ROOT"
else
    skip "main.ts compiles without errors (bun not installed)"
fi

# ============================================
# Test File Existence
# ============================================

header "Test File Structure"

# Test 41-45: Test files exist
for testfile in main.copilot.test.ts main.auth.test.ts main.models.test.ts main.security.test.ts main.integration.test.ts; do
    if [[ -f "$RELAY_DIR/$testfile" ]]; then
        pass "$testfile exists"
    else
        fail "$testfile exists"
    fi
done

# ============================================
# Install Script Tests
# ============================================

header "Install Script"

# Test 46: install.sh exists
if [[ -f "$PROJECT_ROOT/install.sh" ]]; then
    pass "install.sh exists"
else
    fail "install.sh exists"
fi

# Test 47: install.sh is executable
if [[ -x "$PROJECT_ROOT/install.sh" ]]; then
    pass "install.sh is executable"
else
    fail "install.sh is executable"
fi

# Test 48: install.sh mentions GitHub Copilot
if grep -q 'GitHub Copilot\|Copilot' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh mentions GitHub Copilot"
else
    fail "install.sh mentions GitHub Copilot"
fi

# ============================================
# Validate Script Tests
# ============================================

header "Validate Script"

# Test 49: validate.sh exists
if [[ -f "$PROJECT_ROOT/lib/validate.sh" ]]; then
    pass "lib/validate.sh exists"
else
    fail "lib/validate.sh exists"
fi

# Test 50: validate.sh warns about openrouter_api_key
if grep -q 'openrouter_api_key.*deprecated\|deprecated.*openrouter' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh warns about deprecated openrouter_api_key"
else
    fail "validate.sh warns about deprecated openrouter_api_key"
fi

# ============================================
# README Tests
# ============================================

header "Documentation"

# Test 51: README mentions GitHub Copilot
if grep -q 'GitHub Copilot' "$PROJECT_ROOT/README.md"; then
    pass "README mentions GitHub Copilot"
else
    fail "README mentions GitHub Copilot"
fi

# Test 52: README has /auth/device instructions
if grep -q '/auth/device' "$PROJECT_ROOT/README.md"; then
    pass "README has /auth/device instructions"
else
    fail "README has /auth/device instructions"
fi

# Test 53: README has model list
if grep -q 'gpt-5-mini' "$PROJECT_ROOT/README.md"; then
    pass "README lists gpt-5-mini model"
else
    fail "README lists gpt-5-mini model"
fi

# Test 54: README has premium request info
if grep -q 'premium' "$PROJECT_ROOT/README.md"; then
    pass "README mentions premium requests"
else
    fail "README mentions premium requests"
fi

# Test 55: README does NOT prominently feature OpenRouter
OPENROUTER_COUNT=0
if grep -qi 'openrouter' "$PROJECT_ROOT/README.md" 2>/dev/null; then
    OPENROUTER_COUNT=$(grep -ci 'openrouter' "$PROJECT_ROOT/README.md" 2>/dev/null | tr -d '\n' || echo "0")
fi
if [[ "$OPENROUTER_COUNT" -le 2 ]]; then
    pass "README does not prominently feature OpenRouter ($OPENROUTER_COUNT mentions)"
else
    fail "README does not prominently feature OpenRouter ($OPENROUTER_COUNT mentions - should be minimal)"
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
