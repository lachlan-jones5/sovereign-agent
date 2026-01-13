#!/usr/bin/env bash
# test-install.sh - Test the main installer script
# Usage: ./tests/test-install.sh

# Don't use set -e as we test various scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
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

# Test 1: install.sh exists and is executable
test_install_exists() {
    local name="install.sh exists and is executable"
    if [[ -x "$PROJECT_DIR/install.sh" ]]; then
        pass "$name"
    else
        fail "$name" "executable script" "missing or not executable"
    fi
}

# Test 2: --help flag shows usage
test_help_flag() {
    local name="--help flag shows usage"
    local output
    output=$("$PROJECT_DIR/install.sh" --help 2>&1)
    
    if echo "$output" | grep -q "Usage:"; then
        pass "$name"
    else
        fail "$name" "Usage text" "no usage text"
    fi
}

# Test 3: -h flag shows usage
test_short_help_flag() {
    local name="-h flag shows usage"
    local output
    output=$("$PROJECT_DIR/install.sh" -h 2>&1)
    
    if echo "$output" | grep -q "Usage:"; then
        pass "$name"
    else
        fail "$name" "Usage text" "no usage text"
    fi
}

# Test 4: Invalid option shows error
test_invalid_option() {
    local name="Invalid option shows error"
    local output
    output=$("$PROJECT_DIR/install.sh" --invalid-option 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q -i "unknown"; then
        pass "$name"
    else
        fail "$name" "error for unknown option" "$output"
    fi
}

# Test 5: Missing config file shows error
test_missing_config() {
    local name="Missing config file shows error"
    local output
    output=$("$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/nonexistent.json" --skip-deps 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        pass "$name"
    else
        fail "$name" "non-zero exit code" "exit code 0"
    fi
}

# Test 6: --skip-deps flag is recognized
test_skip_deps_flag() {
    local name="--skip-deps flag is recognized"
    
    # Create a valid config
    cat > "$TEST_TMP_DIR/config.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/model",
    "planner": "test/model",
    "librarian": "test/model",
    "fallback": "test/model"
  }
}
EOF
    
    local output
    output=$("$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/config.json" --skip-deps --dest "$TEST_TMP_DIR/output" 2>&1)
    
    if echo "$output" | grep -q -i "skip"; then
        pass "$name"
    else
        fail "$name" "skip message" "$output"
    fi
}

# Test 7: --config flag accepts custom path
test_config_flag() {
    local name="--config flag accepts custom path"
    
    cat > "$TEST_TMP_DIR/custom-config.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-custom-key",
  "site_url": "https://custom.example.com",
  "site_name": "CustomSite",
  "models": {
    "orchestrator": "custom/model",
    "planner": "custom/model",
    "librarian": "custom/model",
    "fallback": "custom/model"
  }
}
EOF
    
    local output_dir="$TEST_TMP_DIR/output7"
    "$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/custom-config.json" --skip-deps --dest "$output_dir" >/dev/null 2>&1
    
    if [[ -f "$output_dir/opencode.json" ]]; then
        local api_key
        api_key=$(jq -r '.provider.openrouter.apiKey' "$output_dir/opencode.json")
        if [[ "$api_key" == "sk-or-v1-custom-key" ]]; then
            pass "$name"
        else
            fail "$name" "sk-or-v1-custom-key" "$api_key"
        fi
    else
        fail "$name" "opencode.json created" "file not found"
    fi
}

# Test 8: --dest flag accepts custom output path
test_dest_flag() {
    local name="--dest flag accepts custom output path"
    
    cat > "$TEST_TMP_DIR/config8.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/model",
    "planner": "test/model",
    "librarian": "test/model",
    "fallback": "test/model"
  }
}
EOF
    
    local custom_dest="$TEST_TMP_DIR/custom-output-dir"
    "$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/config8.json" --skip-deps --dest "$custom_dest" >/dev/null 2>&1
    
    if [[ -d "$custom_dest" && -f "$custom_dest/opencode.json" ]]; then
        pass "$name"
    else
        fail "$name" "files in custom directory" "directory or files missing"
    fi
}

# Test 9: Banner is printed
test_banner_printed() {
    local name="Banner is printed"
    
    cat > "$TEST_TMP_DIR/config9.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/model",
    "planner": "test/model",
    "librarian": "test/model",
    "fallback": "test/model"
  }
}
EOF
    
    local output
    output=$("$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/config9.json" --skip-deps --dest "$TEST_TMP_DIR/output9" 2>&1)
    
    if echo "$output" | grep -q "Sovereign"; then
        pass "$name"
    else
        fail "$name" "Sovereign in banner" "banner not found"
    fi
}

# Test 10: Summary shows model configuration
test_summary_shows_models() {
    local name="Summary shows model configuration"
    
    cat > "$TEST_TMP_DIR/config10.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus",
    "librarian": "google/gemini",
    "fallback": "meta-llama/llama"
  }
}
EOF
    
    local output
    output=$("$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/config10.json" --skip-deps --dest "$TEST_TMP_DIR/output10" 2>&1)
    
    if echo "$output" | grep -q "deepseek/deepseek-v3"; then
        pass "$name"
    else
        fail "$name" "model names in summary" "models not found"
    fi
}

# Test 11: All three config files are generated
test_all_configs_generated() {
    local name="All three config files are generated"
    
    cat > "$TEST_TMP_DIR/config11.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/model",
    "planner": "test/model",
    "librarian": "test/model",
    "fallback": "test/model"
  }
}
EOF
    
    local output_dir="$TEST_TMP_DIR/output11"
    "$PROJECT_DIR/install.sh" --config "$TEST_TMP_DIR/config11.json" --skip-deps --dest "$output_dir" >/dev/null 2>&1
    
    if [[ -f "$output_dir/opencode.json" && -f "$output_dir/dcp.jsonc" && -f "$output_dir/oh-my-opencode.json" ]]; then
        pass "$name"
    else
        local found=""
        [[ -f "$output_dir/opencode.json" ]] && found="$found opencode.json"
        [[ -f "$output_dir/dcp.jsonc" ]] && found="$found dcp.jsonc"
        [[ -f "$output_dir/oh-my-opencode.json" ]] && found="$found oh-my-opencode.json"
        fail "$name" "all 3 config files" "found:$found"
    fi
}

# Run all tests
echo "========================================"
echo "Running install.sh tests"
echo "========================================"
echo

test_install_exists
test_help_flag
test_short_help_flag
test_invalid_option
test_missing_config
test_skip_deps_flag
test_config_flag
test_dest_flag
test_banner_printed
test_summary_shows_models
test_all_configs_generated

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
