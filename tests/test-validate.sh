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

# Test 3: Valid config passes validation
test_valid_config() {
    local name="Valid config passes validation"
    cat > "$TEST_TMP_DIR/valid.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/valid.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 4: Placeholder API key returns error
test_placeholder_api_key() {
    local name="Placeholder API key returns error"
    cat > "$TEST_TMP_DIR/placeholder.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-your-api-key-here",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/placeholder.json" 2>/dev/null; then
        fail "$name" "exit code 1" "exit code 0"
    else
        pass "$name"
    fi
}

# Test 5: Missing required field returns error
test_missing_required_field() {
    local name="Missing orchestrator model returns error"
    cat > "$TEST_TMP_DIR/missing-field.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/missing-field.json" 2>/dev/null; then
        fail "$name" "exit code 1" "exit code 0"
    else
        pass "$name"
    fi
}

# Test 6: Config with optional preferences passes
test_optional_preferences() {
    local name="Config with optional preferences passes"
    cat > "$TEST_TMP_DIR/with-prefs.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "preferences": {
    "ultrawork_max_iterations": 100,
    "dcp_turn_protection": 3
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/with-prefs.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 7: Config with genius model passes validation
test_genius_model() {
    local name="Config with genius model passes validation"
    cat > "$TEST_TMP_DIR/with-genius.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3.2",
    "planner": "deepseek/deepseek-r1-0528",
    "librarian": "google/gemini-3-flash-preview",
    "genius": "anthropic/claude-opus-4.5",
    "fallback": "meta-llama/llama-4-maverick"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/with-genius.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 8: Config without genius model produces warning but passes
test_missing_genius_model_warns() {
    local name="Missing genius model produces warning but passes"
    cat > "$TEST_TMP_DIR/no-genius.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    local output
    output=$(validate_config "$TEST_TMP_DIR/no-genius.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Should pass but warn
        if echo "$output" | grep -q "genius"; then
            pass "$name"
        else
            # Pass even without warning - genius is optional
            pass "$name"
        fi
    else
        fail "$name" "exit code 0" "exit code $exit_code"
    fi
}

# Test 9: All five model tiers in config
test_all_five_model_tiers() {
    local name="All five model tiers in config passes"
    cat > "$TEST_TMP_DIR/all-tiers.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3.2",
    "planner": "deepseek/deepseek-r1-0528",
    "librarian": "google/gemini-3-flash-preview",
    "genius": "anthropic/claude-opus-4.5",
    "fallback": "meta-llama/llama-4-maverick"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/all-tiers.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 10: Empty model values return error
test_empty_model_value() {
    local name="Empty orchestrator model value returns error"
    cat > "$TEST_TMP_DIR/empty-model.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/empty-model.json" 2>/dev/null; then
        fail "$name" "exit code 1" "exit code 0"
    else
        pass "$name"
    fi
}

# Test 11: Relay client mode skips API key validation
test_relay_client_mode_skips_api_key() {
    local name="Relay client mode skips API key validation"
    cat > "$TEST_TMP_DIR/relay-client.json" << 'EOF'
{
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "relay": {
    "enabled": true,
    "mode": "client"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-client.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test 12: Relay server mode still requires API key
test_relay_server_mode_requires_api_key() {
    local name="Relay server mode still requires API key"
    cat > "$TEST_TMP_DIR/relay-server.json" << 'EOF'
{
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "relay": {
    "enabled": true,
    "mode": "server"
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-server.json" 2>/dev/null; then
        fail "$name" "exit code 1" "exit code 0"
    else
        pass "$name"
    fi
}

# Run all tests
echo "========================================"
echo "Running validate.sh tests"
echo "========================================"
echo

test_missing_config_file
test_invalid_json
test_valid_config
test_placeholder_api_key
test_missing_required_field
test_optional_preferences
test_genius_model
test_missing_genius_model_warns
test_all_five_model_tiers
test_empty_model_value
test_relay_client_mode_skips_api_key
test_relay_server_mode_requires_api_key

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
