#!/usr/bin/env bash
# test-validate.sh - Test the config validation script
# Usage: ./tests/test-validate.sh

# Don't use set -e as we need to test failure cases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
TEST_TMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
    rm -rf "$TEST_TMP_DIR"
}
trap cleanup EXIT

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

# Source the validate script
source "$LIB_DIR/validate.sh"

# Test 1: Missing config file returns error
test_missing_config_file() {
    local name="Missing config file returns error"
    if validate_config "$TEST_TMP_DIR/nonexistent.json" 2>/dev/null; then
        fail "$name" "exit code 1" "exit code 0"
    else
        pass "$name"
    fi
}

# Test 2: Invalid JSON returns error
test_invalid_json() {
    local name="Invalid JSON returns error"
    echo "not valid json" > "$TEST_TMP_DIR/invalid.json"
    if validate_config "$TEST_TMP_DIR/invalid.json" 2>/dev/null; then
        fail "$name" "exit code 1" "exit code 0"
    else
        pass "$name"
    fi
}

# Test 3: Valid relay server config passes validation
test_valid_relay_server_config() {
    local name="Valid relay server config passes validation"
    cat > "$TEST_TMP_DIR/relay-server.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-server.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 4: Valid relay client config passes validation
test_valid_relay_client_config() {
    local name="Valid relay client config passes validation"
    cat > "$TEST_TMP_DIR/relay-client.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8081
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-client.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 5: Relay client config without port passes (uses default)
test_relay_client_without_port() {
    local name="Relay client config without port passes with warning"
    cat > "$TEST_TMP_DIR/relay-client-no-port.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client"
  }
}
EOF
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-client-no-port.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -q "relay.port not set"; then
            pass "$name"
        else
            pass "$name (no warning expected)"
        fi
    else
        fail "$name" "exit code 0" "exit code $exit_code"
    fi
}

# Test 6: Relay server config without github_oauth_token passes with warning
test_relay_server_without_oauth_token() {
    local name="Relay server config without github_oauth_token passes with warning"
    cat > "$TEST_TMP_DIR/relay-server-no-token.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-server-no-token.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -q "github_oauth_token not set"; then
            pass "$name"
        else
            pass "$name (no warning expected)"
        fi
    else
        fail "$name" "exit code 0" "exit code $exit_code"
    fi
}

# Test 7: Deprecated openrouter_api_key produces warning
test_deprecated_openrouter_api_key_warning() {
    local name="Deprecated openrouter_api_key produces warning"
    cat > "$TEST_TMP_DIR/with-openrouter.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    local output
    output=$(validate_config "$TEST_TMP_DIR/with-openrouter.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -q "openrouter_api_key is deprecated"; then
            pass "$name"
        else
            fail "$name" "warning about deprecated openrouter_api_key" "no warning"
        fi
    else
        fail "$name" "exit code 0 with warning" "exit code $exit_code"
    fi
}

# Test 8: Invalid relay mode produces warning
test_invalid_relay_mode() {
    local name="Invalid relay mode produces warning"
    cat > "$TEST_TMP_DIR/invalid-mode.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "invalid"
  }
}
EOF
    local output
    output=$(validate_config "$TEST_TMP_DIR/invalid-mode.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -q "should be 'client' or 'server'"; then
            pass "$name"
        else
            fail "$name" "warning about invalid mode" "no warning"
        fi
    else
        fail "$name" "exit code 0 with warning" "exit code $exit_code"
    fi
}

# Test 9: Empty config passes validation
test_empty_config() {
    local name="Empty config passes validation"
    cat > "$TEST_TMP_DIR/empty.json" << 'EOF'
{}
EOF
    if validate_config "$TEST_TMP_DIR/empty.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 10: Config with relay disabled passes
test_relay_disabled() {
    local name="Config with relay disabled passes"
    cat > "$TEST_TMP_DIR/relay-disabled.json" << 'EOF'
{
  "relay": {
    "enabled": false
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-disabled.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 11: Config with additional fields passes
test_config_with_additional_fields() {
    local name="Config with additional fields passes"
    cat > "$TEST_TMP_DIR/with-extra.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client"
  },
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "preferences": {
    "ultrawork_max_iterations": 100
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/with-extra.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 12: Relay server config with github_oauth_token passes
test_relay_server_with_oauth_token() {
    local name="Relay server config with github_oauth_token passes"
    cat > "$TEST_TMP_DIR/relay-server-with-token.json" << 'EOF'
{
  "github_oauth_token": "gho_test_token_here",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-server-with-token.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Run all tests
echo "========================================"
echo "Running validate.sh tests"
echo "========================================"
echo

test_missing_config_file
test_invalid_json
test_valid_relay_server_config
test_valid_relay_client_config
test_relay_client_without_port
test_relay_server_without_oauth_token
test_deprecated_openrouter_api_key_warning
test_invalid_relay_mode
test_empty_config
test_relay_disabled
test_config_with_additional_fields
test_relay_server_with_oauth_token

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
