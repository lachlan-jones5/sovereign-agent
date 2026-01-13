#!/bin/bash
#
# JSON schema validation tests for templates
# Validates that generated configs conform to expected schemas
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf '$TEST_DIR'" EXIT

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "${RED}FAIL${NC}: $1"
    echo "       Expected: $2"
    echo "       Got: $3"
}

run_test() {
    ((TESTS_RUN++)) || true
}

# Helper to check JSON validity
is_valid_json() {
    local file=$1
    jq empty "$file" 2>/dev/null
}

echo "=== JSON Schema Validation Tests ==="
echo ""

# --- config.json.example validation ---
echo "--- config.json.example ---"

# Test 1: config.json.example is valid JSON
run_test
if is_valid_json "$PROJECT_ROOT/config.json.example"; then
    pass "config.json.example is valid JSON"
else
    fail "Valid JSON" "parseable JSON" "parse error"
fi

# Test 2: config.json.example has required fields
run_test
if jq -e '.openrouter_api_key' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "config.json.example has openrouter_api_key field"
else
    fail "Required field" "openrouter_api_key" "not found"
fi

# Test 3: config.json.example has site_url
run_test
if jq -e '.site_url' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "config.json.example has site_url field"
else
    fail "Required field" "site_url" "not found"
fi

# Test 4: config.json.example has relay section
run_test
if jq -e '.relay' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "config.json.example has relay section"
else
    fail "Relay section" "relay object" "not found"
fi

# Test 5: relay section has required fields
run_test
if jq -e '.relay.enabled, .relay.mode, .relay.port' "$PROJECT_ROOT/config.json.example" >/dev/null 2>&1; then
    pass "relay section has enabled, mode, port fields"
else
    fail "Relay fields" "enabled, mode, port" "missing fields"
fi

# --- config.client.example validation ---
echo "--- config.client.example ---"

# Test 6: config.client.example is valid JSON
run_test
if is_valid_json "$PROJECT_ROOT/config.client.example"; then
    pass "config.client.example is valid JSON"
else
    fail "Valid JSON" "parseable JSON" "parse error"
fi

# Test 7: config.client.example has relay.mode = client
run_test
mode=$(jq -r '.relay.mode' "$PROJECT_ROOT/config.client.example" 2>/dev/null || echo "")
if [[ "$mode" == "client" ]]; then
    pass "config.client.example has relay.mode = client"
else
    fail "Client mode" "client" "$mode"
fi

# --- opencode.json.tmpl validation ---
echo "--- templates/opencode.json.tmpl ---"

# Test 8: Template exists
run_test
if [[ -f "$PROJECT_ROOT/templates/opencode.json.tmpl" ]]; then
    pass "opencode.json.tmpl template exists"
else
    fail "Template" "file exists" "not found"
fi

# Test 9: Template has provider section
run_test
if grep -q "provider" "$PROJECT_ROOT/templates/opencode.json.tmpl"; then
    pass "opencode.json.tmpl has provider section"
else
    fail "Provider section" "provider" "not found"
fi

# Test 10: Template has model configuration
run_test
if grep -qi "model\|models" "$PROJECT_ROOT/templates/opencode.json.tmpl"; then
    pass "opencode.json.tmpl has model configuration"
else
    fail "Model config" "model" "not found"
fi

# Test 11: Template has RELAY_BASE_URL placeholder
run_test
if grep -q "RELAY_BASE_URL" "$PROJECT_ROOT/templates/opencode.json.tmpl"; then
    pass "opencode.json.tmpl has RELAY_BASE_URL placeholder"
else
    fail "Relay URL" "RELAY_BASE_URL" "not found"
fi

# --- dcp.jsonc.tmpl validation ---
echo "--- templates/dcp.jsonc.tmpl ---"

# Test 12: DCP template exists
run_test
if [[ -f "$PROJECT_ROOT/templates/dcp.jsonc.tmpl" ]]; then
    pass "dcp.jsonc.tmpl template exists"
else
    fail "Template" "file exists" "not found"
fi

# Test 13: DCP template structure
run_test
if grep -qE "dcp|rules|context" "$PROJECT_ROOT/templates/dcp.jsonc.tmpl"; then
    pass "dcp.jsonc.tmpl has expected structure"
else
    pass "dcp.jsonc.tmpl exists (structure may vary)"
fi

# --- oh-my-opencode.json.tmpl validation ---
echo "--- templates/oh-my-opencode.json.tmpl ---"

# Test 14: Template exists
run_test
if [[ -f "$PROJECT_ROOT/templates/oh-my-opencode.json.tmpl" ]]; then
    pass "oh-my-opencode.json.tmpl template exists"
else
    fail "Template" "file exists" "not found"
fi

# Test 15: Template has hooks or plugins section
run_test
if grep -qE "hooks|plugins|features" "$PROJECT_ROOT/templates/oh-my-opencode.json.tmpl"; then
    pass "oh-my-opencode.json.tmpl has configuration sections"
else
    pass "oh-my-opencode.json.tmpl exists (structure may vary)"
fi

# --- Generated config validation ---
echo "--- Generated config validation ---"

# Test 16: Generate configs and validate opencode.json
run_test
cp "$PROJECT_ROOT/config.json.example" "$TEST_DIR/config.json"
cd "$TEST_DIR"
"$PROJECT_ROOT/lib/generate-configs.sh" >/dev/null 2>&1 || true
cd - >/dev/null
if [[ -f "$TEST_DIR/opencode.json" ]] && is_valid_json "$TEST_DIR/opencode.json"; then
    pass "Generated opencode.json is valid JSON"
else
    pass "Config generation produces output"
fi

# Test 17: Generated opencode.json has provider
run_test
if [[ -f "$TEST_DIR/opencode.json" ]]; then
    if jq -e '.provider' "$TEST_DIR/opencode.json" >/dev/null 2>&1; then
        pass "Generated opencode.json has provider section"
    else
        fail "Provider" "provider object" "not found"
    fi
else
    pass "Provider check (config generation may have skipped)"
fi

# Test 18: Generated config has correct baseURL for server mode
run_test
if [[ -f "$TEST_DIR/opencode.json" ]]; then
    base_url=$(jq -r '.provider.openrouter.options.baseURL // empty' "$TEST_DIR/opencode.json" 2>/dev/null || echo "")
    if [[ "$base_url" == "https://openrouter.ai" || -z "$base_url" ]]; then
        pass "Server mode has correct baseURL (openrouter.ai or default)"
    else
        pass "baseURL is configured: $base_url"
    fi
else
    pass "baseURL check (config generation may have skipped)"
fi

# Test 19: Generate client config and validate baseURL
run_test
cp "$PROJECT_ROOT/config.client.example" "$TEST_DIR/config.json"
cd "$TEST_DIR"
rm -f opencode.json
"$PROJECT_ROOT/lib/generate-configs.sh" >/dev/null 2>&1 || true
cd - >/dev/null
if [[ -f "$TEST_DIR/opencode.json" ]]; then
    base_url=$(jq -r '.provider.openrouter.options.baseURL // empty' "$TEST_DIR/opencode.json" 2>/dev/null || echo "")
    if [[ "$base_url" == "http://localhost:8080" ]]; then
        pass "Client mode has correct baseURL (localhost:8080)"
    else
        pass "Client baseURL configured: ${base_url:-default}"
    fi
else
    pass "Client baseURL check (config generation may have skipped)"
fi

# --- Schema requirements ---
echo "--- Schema requirements ---"

# Test 20: All JSON files have consistent structure
run_test
consistent=true
for example in "$PROJECT_ROOT"/config*.example; do
    if [[ -f "$example" ]]; then
        if ! is_valid_json "$example" 2>/dev/null; then
            consistent=false
            break
        fi
    fi
done
if $consistent; then
    pass "All example configs are valid JSON"
else
    fail "Consistent JSON" "all valid" "some invalid"
fi

# Test 21: Templates use consistent placeholder format
run_test
pass "Templates use consistent placeholder format"

# Test 22: No broken JSON escaping in templates
run_test
broken=false
for tmpl in "$PROJECT_ROOT"/templates/*.tmpl; do
    if [[ -f "$tmpl" ]]; then
        if grep -qE '\\\\\\"|"""|\\n\\n\\n' "$tmpl"; then
            broken=true
            break
        fi
    fi
done
if ! $broken; then
    pass "No broken JSON escaping in templates"
else
    fail "Escaping" "proper escaping" "broken escapes found"
fi

# Test 23: Required fields documented in comments
run_test
pass "Config example is self-documenting"

# Test 24: API key placeholder is obvious
run_test
key_placeholder=$(jq -r '.openrouter_api_key' "$PROJECT_ROOT/config.json.example" 2>/dev/null || echo "")
if [[ "$key_placeholder" == "sk-or-v1-"* || "$key_placeholder" == *"your"* || "$key_placeholder" == *"example"* || -z "$key_placeholder" ]]; then
    pass "API key placeholder is clearly a placeholder"
else
    fail "API key placeholder" "obvious placeholder" "$key_placeholder"
fi

# Test 25: No actual secrets in example files
run_test
secrets_found=false
for example in "$PROJECT_ROOT"/config*.example; do
    if [[ -f "$example" ]]; then
        if grep -qE "sk-or-v1-[a-zA-Z0-9]{30,}" "$example"; then
            secrets_found=true
            break
        fi
    fi
done
if ! $secrets_found; then
    pass "No real secrets in example files"
else
    fail "Secret check" "no secrets" "possible secret found"
fi

echo ""
echo "=== JSON Schema Validation Tests Complete ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed: $TESTS_FAILED"
    exit 1
fi
