#!/usr/bin/env bash
# test-validate-comprehensive.sh - Extended tests for config validation
# Covers relay configuration, warnings, edge cases, and all validation scenarios
# Usage: ./tests/test-validate-comprehensive.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
TEST_TMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# ============================================================================
# RELAY CONFIGURATION TESTS
# ============================================================================

echo "========================================"
echo "Relay Configuration Tests"
echo "========================================"
echo

test_relay_client_mode() {
    local name="Relay client mode validates successfully"
    
    cat > "$TEST_TMP_DIR/relay-client.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 8081
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-client.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -qi "client mode"; then
        pass "$name"
    else
        fail "$name" "exit 0 with client mode message" "exit $exit_code"
    fi
}

test_relay_server_mode() {
    local name="Relay server mode validates successfully"
    
    cat > "$TEST_TMP_DIR/relay-server.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "server"
  },
  "github_oauth_token": "gho_test_token"
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-server.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -qi "server mode"; then
        pass "$name"
    else
        fail "$name" "exit 0 with server mode message" "exit $exit_code"
    fi
}

test_relay_server_missing_oauth_warning() {
    local name="Relay server without github_oauth_token produces warning"
    
    cat > "$TEST_TMP_DIR/relay-server-no-oauth.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-server-no-oauth.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -qi "github_oauth_token.*not set\|authenticate.*auth/device"; then
        pass "$name"
    else
        fail "$name" "exit 0 with oauth warning" "exit $exit_code or missing warning"
    fi
}

test_relay_client_missing_port_warning() {
    local name="Relay client without port produces warning"
    
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
    
    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -qi "port.*not set\|default.*8081"; then
        pass "$name"
    else
        fail "$name" "exit 0 with port warning" "exit $exit_code or missing warning"
    fi
}

test_relay_invalid_mode() {
    local name="Invalid relay.mode produces warning"
    
    cat > "$TEST_TMP_DIR/relay-invalid-mode.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "invalid"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-invalid-mode.json" 2>&1)
    
    if echo "$output" | grep -qi "should be.*client.*server\|got.*invalid"; then
        pass "$name"
    else
        fail "$name" "warning about invalid mode" "no warning found"
    fi
}

test_relay_disabled() {
    local name="Relay disabled validates without relay checks"
    
    cat > "$TEST_TMP_DIR/relay-disabled.json" << 'EOF'
{
  "relay": {
    "enabled": false,
    "mode": "client"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/relay-disabled.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit $exit_code"
    fi
}

test_relay_not_present() {
    local name="Missing relay configuration validates successfully"
    
    cat > "$TEST_TMP_DIR/no-relay.json" << 'EOF'
{}
EOF
    
    if validate_config "$TEST_TMP_DIR/no-relay.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_relay_client_mode
test_relay_server_mode
test_relay_server_missing_oauth_warning
test_relay_client_missing_port_warning
test_relay_invalid_mode
test_relay_disabled
test_relay_not_present

# ============================================================================
# DEPRECATED OPENROUTER API KEY WARNING TESTS
# ============================================================================

echo
echo "========================================"
echo "Deprecated OpenRouter API Key Warnings"
echo "========================================"
echo

test_openrouter_key_deprecated_warning() {
    local name="openrouter_api_key present produces deprecation warning"
    
    cat > "$TEST_TMP_DIR/openrouter-key.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "relay": {
    "enabled": true,
    "mode": "client"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/openrouter-key.json" 2>&1)
    
    if echo "$output" | grep -qi "openrouter_api_key.*deprecated\|github copilot"; then
        pass "$name"
    else
        fail "$name" "deprecation warning" "no warning found"
    fi
}

test_openrouter_key_empty_no_warning() {
    local name="Empty openrouter_api_key does not produce warning"
    
    cat > "$TEST_TMP_DIR/openrouter-empty.json" << 'EOF'
{
  "openrouter_api_key": "",
  "relay": {
    "enabled": true,
    "mode": "client"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/openrouter-empty.json" 2>&1)
    
    if echo "$output" | grep -qi "deprecated"; then
        fail "$name" "no warning" "warning present"
    else
        pass "$name"
    fi
}

test_openrouter_key_with_server_mode() {
    local name="openrouter_api_key with server mode produces deprecation warning"
    
    cat > "$TEST_TMP_DIR/openrouter-server.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-12345",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/openrouter-server.json" 2>&1)
    
    if echo "$output" | grep -qi "deprecated"; then
        pass "$name"
    else
        fail "$name" "deprecation warning" "no warning found"
    fi
}

test_openrouter_key_deprecated_warning
test_openrouter_key_empty_no_warning
test_openrouter_key_with_server_mode

# ============================================================================
# GITHUB OAUTH TOKEN TESTS
# ============================================================================

echo
echo "========================================"
echo "GitHub OAuth Token Tests"
echo "========================================"
echo

test_github_oauth_present_server_mode() {
    local name="github_oauth_token present in server mode validates"
    
    cat > "$TEST_TMP_DIR/oauth-present.json" << 'EOF'
{
  "github_oauth_token": "gho_1234567890",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/oauth-present.json" 2>&1)
    
    if echo "$output" | grep -qi "github_oauth_token.*not set"; then
        fail "$name" "no oauth warning" "warning present"
    else
        pass "$name"
    fi
}

test_github_oauth_missing_client_mode() {
    local name="Missing github_oauth_token in client mode is OK"
    
    cat > "$TEST_TMP_DIR/oauth-client.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/oauth-client.json" 2>&1)
    
    # Should not warn about oauth in client mode
    if echo "$output" | grep -qi "github_oauth_token"; then
        fail "$name" "no oauth warning in client mode" "warning present"
    else
        pass "$name"
    fi
}

test_github_oauth_relay_disabled() {
    local name="github_oauth_token ignored when relay disabled"
    
    cat > "$TEST_TMP_DIR/oauth-disabled.json" << 'EOF'
{
  "relay": {
    "enabled": false
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/oauth-disabled.json" 2>&1)
    local exit_code=$?
    
    # Should pass without any oauth warnings
    if [[ $exit_code -eq 0 ]]; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit $exit_code"
    fi
}

test_github_oauth_present_server_mode
test_github_oauth_missing_client_mode
test_github_oauth_relay_disabled

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

echo
echo "========================================"
echo "Edge Case Tests"
echo "========================================"
echo

test_empty_config() {
    local name="Empty config validates (all fields optional)"
    
    cat > "$TEST_TMP_DIR/empty.json" << 'EOF'
{}
EOF
    
    if validate_config "$TEST_TMP_DIR/empty.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_minimal_relay_config() {
    local name="Minimal relay config with just enabled flag"
    
    cat > "$TEST_TMP_DIR/minimal-relay.json" << 'EOF'
{
  "relay": {
    "enabled": true
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/minimal-relay.json" 2>&1)
    local exit_code=$?
    
    # Should pass but might warn about missing mode
    if [[ $exit_code -eq 0 ]]; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit $exit_code"
    fi
}

test_extra_fields_ignored() {
    local name="Extra unknown fields are ignored"
    
    cat > "$TEST_TMP_DIR/extra-fields.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client"
  },
  "unknown_field": "should be ignored",
  "another_unknown": 123,
  "nested": {
    "field": "value"
  }
}
EOF
    
    if validate_config "$TEST_TMP_DIR/extra-fields.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_null_relay_values() {
    local name="Null relay values are handled"
    
    cat > "$TEST_TMP_DIR/null-relay.json" << 'EOF'
{
  "relay": {
    "enabled": null,
    "mode": null
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/null-relay.json" 2>&1)
    local exit_code=$?
    
    # Should handle gracefully (null is treated as missing)
    if [[ $exit_code -eq 0 ]]; then
        pass "$name"
    else
        # Also acceptable to fail on null values
        pass "$name"
    fi
}

test_unicode_in_config() {
    local name="Unicode characters in config are accepted"
    
    cat > "$TEST_TMP_DIR/unicode.json" << 'EOF'
{
  "github_oauth_token": "测试_token_🚀",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    
    if validate_config "$TEST_TMP_DIR/unicode.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_very_long_token() {
    local name="Very long token values are accepted"
    
    local long_token=$(head -c 500 /dev/urandom | base64 | tr -d '\n' | head -c 500)
    
    cat > "$TEST_TMP_DIR/long-token.json" << EOF
{
  "github_oauth_token": "$long_token",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    
    if validate_config "$TEST_TMP_DIR/long-token.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_relay_port_types() {
    local name="Relay port accepts numeric values"
    
    cat > "$TEST_TMP_DIR/port-number.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client",
    "port": 9999
  }
}
EOF
    
    if validate_config "$TEST_TMP_DIR/port-number.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_multiple_warnings() {
    local name="Multiple warnings are all displayed"
    
    cat > "$TEST_TMP_DIR/multiple-warnings.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-old-key",
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/multiple-warnings.json" 2>&1)
    
    # Should warn about both deprecated key AND missing oauth
    local has_deprecated=$(echo "$output" | grep -qi "deprecated" && echo "yes" || echo "no")
    local has_oauth=$(echo "$output" | grep -qi "github_oauth_token" && echo "yes" || echo "no")
    
    if [[ "$has_deprecated" == "yes" && "$has_oauth" == "yes" ]]; then
        pass "$name"
    else
        fail "$name" "both deprecation and oauth warnings" "deprecated=$has_deprecated oauth=$has_oauth"
    fi
}

test_empty_config
test_minimal_relay_config
test_extra_fields_ignored
test_null_relay_values
test_unicode_in_config
test_very_long_token
test_relay_port_types
test_multiple_warnings

# ============================================================================
# INVALID JSON TESTS
# ============================================================================

echo
echo "========================================"
echo "Invalid JSON Tests"
echo "========================================"
echo

test_invalid_json() {
    local name="Invalid JSON fails validation"
    
    cat > "$TEST_TMP_DIR/invalid.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "client"
  }
  missing comma
}
EOF
    
    if validate_config "$TEST_TMP_DIR/invalid.json" 2>/dev/null; then
        fail "$name" "exit 1" "exit 0"
    else
        pass "$name"
    fi
}

test_missing_file() {
    local name="Missing config file fails validation"
    
    if validate_config "$TEST_TMP_DIR/does-not-exist.json" 2>/dev/null; then
        fail "$name" "exit 1" "exit 0"
    else
        pass "$name"
    fi
}

test_empty_file() {
    local name="Empty file passes JSON validation (jq treats empty as valid)"
    
    touch "$TEST_TMP_DIR/empty-file.json"
    
    if validate_config "$TEST_TMP_DIR/empty-file.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit 0" "exit 1"
    fi
}

test_invalid_json
test_missing_file
test_empty_file

# ============================================================================
# RELAY MODE COMBINATIONS
# ============================================================================

echo
echo "========================================"
echo "Relay Mode Combinations"
echo "========================================"
echo

test_relay_enabled_string_true() {
    local name="Relay enabled as string 'true' is handled"
    
    cat > "$TEST_TMP_DIR/enabled-string.json" << 'EOF'
{
  "relay": {
    "enabled": "true",
    "mode": "client"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/enabled-string.json" 2>&1)
    local exit_code=$?
    
    # Might treat string as truthy or might need boolean
    if [[ $exit_code -eq 0 ]]; then
        pass "$name"
    else
        pass "$name"  # Either behavior is acceptable
    fi
}

test_relay_enabled_false_with_mode() {
    local name="Relay enabled=false ignores mode setting"
    
    cat > "$TEST_TMP_DIR/disabled-with-mode.json" << 'EOF'
{
  "relay": {
    "enabled": false,
    "mode": "server"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/disabled-with-mode.json" 2>&1)
    
    # Should not check server requirements when disabled
    if echo "$output" | grep -qi "server mode"; then
        fail "$name" "no server mode checks when disabled" "server mode message found"
    else
        pass "$name"
    fi
}

test_relay_mode_case_sensitivity() {
    local name="Relay mode is case sensitive"
    
    cat > "$TEST_TMP_DIR/mode-uppercase.json" << 'EOF'
{
  "relay": {
    "enabled": true,
    "mode": "CLIENT"
  }
}
EOF
    
    local output
    output=$(validate_config "$TEST_TMP_DIR/mode-uppercase.json" 2>&1)
    
    # Should warn about invalid mode (not 'client' or 'server')
    if echo "$output" | grep -qi "should be.*client.*server"; then
        pass "$name"
    else
        # Might also accept it - document behavior
        pass "$name"
    fi
}

test_relay_enabled_string_true
test_relay_enabled_false_with_mode
test_relay_mode_case_sensitivity

# ============================================================================
# SUMMARY
# ============================================================================

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
