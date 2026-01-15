#!/usr/bin/env bash
# test-security-features.sh - Test security hardening features
# Usage: ./tests/test-security-features.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_DIR/templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# =============================================================================
# .opencodeignore Tests
# =============================================================================

test_opencodeignore_template_exists() {
    local name=".opencodeignore template exists"
    
    if [[ -f "$TEMPLATES_DIR/opencodeignore.tmpl" ]]; then
        pass "$name"
    else
        fail "$name" "file exists" "file not found"
    fi
}

test_opencodeignore_blocks_env() {
    local name=".opencodeignore blocks .env files"
    
    if grep -q "^\.env$" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" ".env in ignore list" "not found"
    fi
}

test_opencodeignore_blocks_pem() {
    local name=".opencodeignore blocks .pem files"
    
    if grep -q "\*\.pem" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "*.pem in ignore list" "not found"
    fi
}

test_opencodeignore_blocks_ssh_keys() {
    local name=".opencodeignore blocks SSH keys"
    
    if grep -q "id_rsa" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "id_rsa in ignore list" "not found"
    fi
}

test_opencodeignore_blocks_config_json() {
    local name=".opencodeignore blocks config.json (contains OAuth token)"
    
    if grep -q "^config\.json$" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "config.json in ignore list" "not found"
    fi
}

# Run all tests
echo "========================================"
echo "Running Security Features Tests"
echo "========================================"
echo

echo "--- .opencodeignore Template ---"
test_opencodeignore_template_exists
test_opencodeignore_blocks_env
test_opencodeignore_blocks_pem
test_opencodeignore_blocks_ssh_keys
test_opencodeignore_blocks_config_json

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
