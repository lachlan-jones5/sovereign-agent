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

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
