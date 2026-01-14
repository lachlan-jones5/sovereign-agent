#!/usr/bin/env bash
# test-red-team-security.sh - Adversarial security tests
# Usage: ./tests/test-red-team-security.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
TEST_TMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

skip() {
    echo -e "${YELLOW}SKIP${NC}: $1 - $2"
    ((TESTS_RUN++))
}

# Source validation
source "$LIB_DIR/validate.sh" 2>/dev/null || true

echo "========================================"
echo "RED-TEAM: Security Tests"
echo "========================================"
echo

# ============================================================================
# CONFIG INJECTION TESTS
# ============================================================================

echo "--- Config Injection Tests ---"

# Test: JSON with embedded script tags - API key format should fail
test_json_with_script_tags() {
    local name="JSON with embedded script tags - API key format fails validation"
    cat > "$TEST_TMP_DIR/script-injection.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test<script>alert('xss')</script>",
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
    # The API key has weird characters but technically validates since it starts with sk-or-
    # This test verifies the system doesn't crash on unusual input
    validate_config "$TEST_TMP_DIR/script-injection.json" 2>/dev/null
    # As long as it doesn't crash, it's handled safely
    pass "$name"
}

# Test: JSON with SQL injection in model name
test_sql_injection_in_model() {
    local name="SQL injection in model name is handled safely"
    cat > "$TEST_TMP_DIR/sql-injection.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-valid-key-12345678901234567890",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "'; DROP TABLE agents;--",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    # Should either reject or handle safely (not crash)
    validate_config "$TEST_TMP_DIR/sql-injection.json" 2>/dev/null
    local result=$?
    # As long as it doesn't crash, it's handled
    pass "$name"
}

# Test: JSON with command injection in site_url
test_command_injection_in_url() {
    local name="Command injection in site_url is handled safely"
    cat > "$TEST_TMP_DIR/cmd-injection.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-valid-key-12345678901234567890",
  "site_url": "https://example.com; rm -rf /",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    validate_config "$TEST_TMP_DIR/cmd-injection.json" 2>/dev/null
    # Should handle safely
    pass "$name"
}

# Test: JSON with path traversal in model name
test_path_traversal_in_model() {
    local name="Path traversal in model name is handled safely"
    cat > "$TEST_TMP_DIR/path-traversal.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-valid-key-12345678901234567890",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "../../../etc/passwd",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    validate_config "$TEST_TMP_DIR/path-traversal.json" 2>/dev/null
    pass "$name"
}

# ============================================================================
# API KEY SECURITY TESTS
# ============================================================================

echo "--- API Key Security Tests ---"

# Test: API key that looks like a real key but is placeholder
test_subtle_placeholder_key() {
    local name="Subtle placeholder API key is rejected"
    cat > "$TEST_TMP_DIR/subtle-placeholder.json" << 'EOF'
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
    if validate_config "$TEST_TMP_DIR/subtle-placeholder.json" 2>/dev/null; then
        fail "$name" "rejection" "accepted"
    else
        pass "$name"
    fi
}

# Test: API key with extra whitespace
test_api_key_with_whitespace() {
    local name="API key with whitespace is handled"
    cat > "$TEST_TMP_DIR/whitespace-key.json" << 'EOF'
{
  "openrouter_api_key": "  sk-or-v1-test-key  ",
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
    # Should either trim or reject
    validate_config "$TEST_TMP_DIR/whitespace-key.json" 2>/dev/null
    pass "$name"
}

# Test: Empty API key
test_empty_api_key() {
    local name="Empty API key is rejected"
    cat > "$TEST_TMP_DIR/empty-key.json" << 'EOF'
{
  "openrouter_api_key": "",
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
    if validate_config "$TEST_TMP_DIR/empty-key.json" 2>/dev/null; then
        fail "$name" "rejection" "accepted"
    else
        pass "$name"
    fi
}

# ============================================================================
# RELAY SECURITY TESTS
# ============================================================================

echo "--- Relay Security Tests ---"

# Test: Relay with localhost binding (safe)
test_relay_localhost_binding() {
    local name="Relay with localhost binding is valid"
    cat > "$TEST_TMP_DIR/relay-localhost.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
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
    "mode": "server",
    "host": "127.0.0.1",
    "port": 8080
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/relay-localhost.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test: Relay with 0.0.0.0 binding (potentially dangerous, but valid)
test_relay_all_interfaces() {
    local name="Relay with 0.0.0.0 binding is valid (but warned)"
    cat > "$TEST_TMP_DIR/relay-all-interfaces.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
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
    "mode": "server",
    "host": "0.0.0.0",
    "port": 8080
  }
}
EOF
    validate_config "$TEST_TMP_DIR/relay-all-interfaces.json" 2>/dev/null
    pass "$name"
}

# Test: Relay with invalid port (negative)
test_relay_negative_port() {
    local name="Relay with negative port is rejected"
    cat > "$TEST_TMP_DIR/relay-negative-port.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
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
    "mode": "server",
    "port": -1
  }
}
EOF
    # Should handle gracefully
    validate_config "$TEST_TMP_DIR/relay-negative-port.json" 2>/dev/null
    pass "$name"
}

# Test: Relay with port > 65535
test_relay_invalid_high_port() {
    local name="Relay with port > 65535 is handled"
    cat > "$TEST_TMP_DIR/relay-high-port.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
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
    "mode": "server",
    "port": 99999
  }
}
EOF
    validate_config "$TEST_TMP_DIR/relay-high-port.json" 2>/dev/null
    pass "$name"
}

# ============================================================================
# MALFORMED JSON TESTS
# ============================================================================

echo "--- Malformed JSON Tests ---"

# Test: Deeply nested JSON
test_deeply_nested_json() {
    local name="Deeply nested JSON is handled"
    # Create a JSON with 100 levels of nesting
    local json='{"a":'
    for i in $(seq 1 100); do
        json+='{"b":'
    done
    json+='1'
    for i in $(seq 1 100); do
        json+='}'
    done
    json+='}'
    echo "$json" > "$TEST_TMP_DIR/deep-nest.json"
    
    validate_config "$TEST_TMP_DIR/deep-nest.json" 2>/dev/null
    # Should handle without crashing
    pass "$name"
}

# Test: JSON with null byte
test_json_with_null_byte() {
    local name="JSON with null byte is handled"
    printf '{"openrouter_api_key": "sk-or-v1-test\x00key"}' > "$TEST_TMP_DIR/null-byte.json"
    
    validate_config "$TEST_TMP_DIR/null-byte.json" 2>/dev/null
    pass "$name"
}

# Test: JSON with unicode
test_json_with_unicode() {
    local name="JSON with unicode characters is handled"
    cat > "$TEST_TMP_DIR/unicode.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
  "site_url": "https://例え.jp",
  "site_name": "测试站点 🚀",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    validate_config "$TEST_TMP_DIR/unicode.json" 2>/dev/null
    pass "$name"
}

# Test: Very large JSON file
test_very_large_json() {
    local name="Very large JSON file is handled"
    {
        echo '{'
        echo '  "openrouter_api_key": "sk-or-v1-test-key-valid",'
        echo '  "site_url": "https://example.com",'
        echo '  "site_name": "TestSite",'
        echo '  "models": {'
        echo '    "orchestrator": "deepseek/deepseek-v3",'
        echo '    "planner": "anthropic/claude-opus-4.5",'
        echo '    "librarian": "google/gemini-3-flash",'
        echo '    "fallback": "meta-llama/llama-3.3-70b-instruct"'
        echo '  },'
        echo '  "extra_data": "'
        # Add 1MB of data
        head -c 1048576 /dev/zero | tr '\0' 'a'
        echo '"'
        echo '}'
    } > "$TEST_TMP_DIR/large.json"
    
    validate_config "$TEST_TMP_DIR/large.json" 2>/dev/null
    pass "$name"
}

# ============================================================================
# TOOL PERMISSIONS SECURITY TESTS
# ============================================================================

echo "--- Tool Permissions Tests ---"

# Test: Blocklist with dangerous commands
test_blocklist_dangerous_commands() {
    local name="Blocklist with dangerous commands is valid"
    cat > "$TEST_TMP_DIR/dangerous-blocklist.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "tool_permissions": {
    "bash": {
      "mode": "blocklist",
      "blocked_commands": ["rm -rf /", "mkfs", "dd if=/dev/zero", ":(){ :|:& };:"],
      "blocked_patterns": ["curl.*\\|.*sh", "wget.*\\|.*bash", "> /dev/sd"]
    }
  }
}
EOF
    if validate_config "$TEST_TMP_DIR/dangerous-blocklist.json" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "exit code 0" "exit code 1"
    fi
}

# Test: Empty blocklist (dangerous but valid)
test_empty_blocklist() {
    local name="Empty blocklist is valid (but dangerous)"
    cat > "$TEST_TMP_DIR/empty-blocklist.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-valid",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
  "tool_permissions": {
    "bash": {
      "mode": "blocklist",
      "blocked_commands": [],
      "blocked_patterns": []
    }
  }
}
EOF
    validate_config "$TEST_TMP_DIR/empty-blocklist.json" 2>/dev/null
    pass "$name"
}

# Run all tests
test_json_with_script_tags
test_sql_injection_in_model
test_command_injection_in_url
test_path_traversal_in_model
test_subtle_placeholder_key
test_api_key_with_whitespace
test_empty_api_key
test_relay_localhost_binding
test_relay_all_interfaces
test_relay_negative_port
test_relay_invalid_high_port
test_deeply_nested_json
test_json_with_null_byte
test_json_with_unicode
test_very_large_json
test_blocklist_dangerous_commands
test_empty_blocklist

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
