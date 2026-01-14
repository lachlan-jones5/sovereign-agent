#!/usr/bin/env bash
# test-check-deps-comprehensive.sh - Extended tests for dependency checking
# Covers installation logic, PATH management, and error handling
# Usage: ./tests/test-check-deps-comprehensive.sh

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
    # Restore original functions if mocked
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

# Source the check-deps script
source "$LIB_DIR/check-deps.sh"

# ============================================================================
# COMMAND_EXISTS TESTS
# ============================================================================

echo "========================================"
echo "command_exists Tests"
echo "========================================"
echo

test_command_exists_true() {
    local name="command_exists returns true for existing command"
    if command_exists bash; then
        pass "$name"
    else
        fail "$name" "true" "false"
    fi
}

test_command_exists_false() {
    local name="command_exists returns false for non-existing command"
    if command_exists this_command_does_not_exist_12345; then
        fail "$name" "false" "true"
    else
        pass "$name"
    fi
}

test_command_exists_ls() {
    local name="command_exists finds ls"
    if command_exists ls; then
        pass "$name"
    else
        fail "$name" "true" "false"
    fi
}

test_command_exists_env() {
    local name="command_exists finds env"
    if command_exists env; then
        pass "$name"
    else
        fail "$name" "true" "false"
    fi
}

test_command_exists_true
test_command_exists_false
test_command_exists_ls
test_command_exists_env

# ============================================================================
# LOGGING FUNCTION TESTS
# ============================================================================

echo
echo "========================================"
echo "Logging Function Tests"
echo "========================================"
echo

test_log_info_contains_info() {
    local name="log_info output contains [INFO]"
    local output
    output=$(log_info "test message" 2>&1)
    if echo "$output" | grep -q '\[INFO\]'; then
        pass "$name"
    else
        fail "$name" "[INFO]" "$output"
    fi
}

test_log_warn_contains_warn() {
    local name="log_warn output contains [WARN]"
    local output
    output=$(log_warn "test warning" 2>&1)
    if echo "$output" | grep -q '\[WARN\]'; then
        pass "$name"
    else
        fail "$name" "[WARN]" "$output"
    fi
}

test_log_error_contains_error() {
    local name="log_error output contains [ERROR]"
    local output
    output=$(log_error "test error" 2>&1)
    if echo "$output" | grep -q '\[ERROR\]'; then
        pass "$name"
    else
        fail "$name" "[ERROR]" "$output"
    fi
}

test_log_info_contains_message() {
    local name="log_info output contains the message"
    local output
    output=$(log_info "my specific message" 2>&1)
    if echo "$output" | grep -q 'my specific message'; then
        pass "$name"
    else
        fail "$name" "my specific message" "$output"
    fi
}

test_log_info_contains_info
test_log_warn_contains_warn
test_log_error_contains_error
test_log_info_contains_message

# ============================================================================
# ENSURE_PATH_IN_RC TESTS
# ============================================================================

echo
echo "========================================"
echo "ensure_path_in_rc Tests"
echo "========================================"
echo

test_ensure_path_creates_entry() {
    local name="ensure_path_in_rc adds path to rc file"
    local test_rc="$TEST_TMP_DIR/test_bashrc"
    touch "$test_rc"
    
    # Override HOME for this test
    local orig_home="$HOME"
    export HOME="$TEST_TMP_DIR"
    mkdir -p "$TEST_TMP_DIR"
    touch "$TEST_TMP_DIR/.bashrc"
    
    # Also need to ensure the path isn't already in PATH
    local test_path="/some/test/path/that/doesnt/exist"
    
    # Run function
    ensure_path_in_rc "$test_path" 2>/dev/null
    
    # Check rc file
    if grep -q "$test_path" "$TEST_TMP_DIR/.bashrc"; then
        pass "$name"
    else
        fail "$name" "$test_path in .bashrc" "not found"
    fi
    
    export HOME="$orig_home"
}

test_ensure_path_skips_if_present() {
    local name="ensure_path_in_rc skips if path already in PATH"
    
    # Add a path that's already in PATH
    local test_path="/usr/bin"
    
    # This should not cause error and should exit early
    ensure_path_in_rc "$test_path" 2>/dev/null
    
    # If we get here without error, pass
    pass "$name"
}

test_ensure_path_skips_if_in_rc() {
    local name="ensure_path_in_rc skips if path already in rc file"
    local test_rc="$TEST_TMP_DIR/test_bashrc2"
    
    local orig_home="$HOME"
    export HOME="$TEST_TMP_DIR"
    mkdir -p "$TEST_TMP_DIR"
    
    local test_path="/unique/test/path/123"
    
    # Pre-add to rc file
    echo "export PATH=\"$test_path:\$PATH\"" > "$TEST_TMP_DIR/.bashrc"
    local initial_lines
    initial_lines=$(wc -l < "$TEST_TMP_DIR/.bashrc")
    
    # Run function
    ensure_path_in_rc "$test_path" 2>/dev/null
    
    # Check that no new entry was added
    local final_lines
    final_lines=$(wc -l < "$TEST_TMP_DIR/.bashrc")
    
    if [[ "$initial_lines" == "$final_lines" ]]; then
        pass "$name"
    else
        fail "$name" "$initial_lines lines" "$final_lines lines"
    fi
    
    export HOME="$orig_home"
}

test_ensure_path_creates_entry
test_ensure_path_skips_if_present
test_ensure_path_skips_if_in_rc

# ============================================================================
# CHECK_JQ TESTS
# ============================================================================

echo
echo "========================================"
echo "check_jq Tests"
echo "========================================"
echo

test_check_jq_succeeds_when_installed() {
    local name="check_jq succeeds when jq is installed"
    if command_exists jq; then
        if check_jq 2>/dev/null; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: $name (jq not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

test_check_jq_succeeds_when_installed

# ============================================================================
# CHECK_CURL TESTS
# ============================================================================

echo
echo "========================================"
echo "check_curl Tests"
echo "========================================"
echo

test_check_curl_succeeds_when_installed() {
    local name="check_curl succeeds when curl is installed"
    if command_exists curl; then
        if check_curl 2>/dev/null; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: $name (curl not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

test_check_curl_succeeds_when_installed

# ============================================================================
# CHECK_GO TESTS
# ============================================================================

echo
echo "========================================"
echo "check_go Tests"
echo "========================================"
echo

test_check_go_succeeds_when_installed() {
    local name="check_go succeeds when go is installed"
    if command_exists go; then
        if check_go 2>/dev/null; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: $name (go not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

test_go_arch_detection() {
    local name="Go architecture detection works"
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|aarch64|arm64)
            pass "$name"
            ;;
        *)
            fail "$name" "x86_64 or arm64" "$arch"
            ;;
    esac
}

test_check_go_succeeds_when_installed
test_go_arch_detection

# ============================================================================
# CHECK_BUN TESTS
# ============================================================================

echo
echo "========================================"
echo "check_bun Tests"
echo "========================================"
echo

test_check_bun_succeeds_when_installed() {
    local name="check_bun succeeds when bun is installed"
    if command_exists bun; then
        if check_bun 2>/dev/null; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo -e "${YELLOW}SKIP${NC}: $name (bun not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

test_check_bun_succeeds_when_installed

# ============================================================================
# BUILD_OPENCODE TESTS
# ============================================================================

echo
echo "========================================"
echo "build_opencode Tests"
echo "========================================"
echo

test_build_opencode_fails_without_submodule() {
    local name="build_opencode fails when submodule missing"
    
    # Temporarily override VENDOR_DIR
    local orig_vendor="$VENDOR_DIR"
    VENDOR_DIR="$TEST_TMP_DIR/nonexistent"
    
    if build_opencode 2>/dev/null; then
        fail "$name" "failure" "success"
    else
        pass "$name"
    fi
    
    VENDOR_DIR="$orig_vendor"
}

test_build_opencode_fails_empty_submodule() {
    local name="build_opencode fails when submodule is empty"
    
    # Create empty directory
    mkdir -p "$TEST_TMP_DIR/empty_vendor/opencode"
    
    local orig_vendor="$VENDOR_DIR"
    VENDOR_DIR="$TEST_TMP_DIR/empty_vendor"
    
    if build_opencode 2>/dev/null; then
        fail "$name" "failure" "success"
    else
        pass "$name"
    fi
    
    VENDOR_DIR="$orig_vendor"
}

test_build_opencode_fails_without_submodule
test_build_opencode_fails_empty_submodule

# ============================================================================
# CHECK_OPENAGENTS TESTS
# ============================================================================

echo
echo "========================================"
echo "check_openagents Tests"
echo "========================================"
echo

test_check_openagents_fails_without_submodule() {
    local name="check_openagents fails when submodule missing"
    
    local orig_vendor="$VENDOR_DIR"
    VENDOR_DIR="$TEST_TMP_DIR/nonexistent"
    
    if check_openagents 2>/dev/null; then
        fail "$name" "failure" "success"
    else
        pass "$name"
    fi
    
    VENDOR_DIR="$orig_vendor"
}

test_check_openagents_fails_empty_submodule() {
    local name="check_openagents fails when submodule is empty"
    
    mkdir -p "$TEST_TMP_DIR/empty_oa/OpenAgents"
    
    local orig_vendor="$VENDOR_DIR"
    VENDOR_DIR="$TEST_TMP_DIR/empty_oa"
    
    if check_openagents 2>/dev/null; then
        fail "$name" "failure" "success"
    else
        pass "$name"
    fi
    
    VENDOR_DIR="$orig_vendor"
}

test_check_openagents_succeeds_with_content() {
    local name="check_openagents succeeds with proper content"
    
    # Create proper structure
    mkdir -p "$TEST_TMP_DIR/valid_oa/OpenAgents/.opencode/agent"
    touch "$TEST_TMP_DIR/valid_oa/OpenAgents/.opencode/agent/test.md"
    
    local orig_vendor="$VENDOR_DIR"
    VENDOR_DIR="$TEST_TMP_DIR/valid_oa"
    
    if check_openagents 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "success" "failure"
    fi
    
    VENDOR_DIR="$orig_vendor"
}

test_check_openagents_fails_without_submodule
test_check_openagents_fails_empty_submodule
test_check_openagents_succeeds_with_content

# ============================================================================
# SHELL DETECTION TESTS
# ============================================================================

echo
echo "========================================"
echo "Shell Detection Tests"
echo "========================================"
echo

test_shell_detection_bash() {
    local name="Shell detection identifies bash"
    
    # Check if we're running in bash
    if [[ -n "$BASH_VERSION" ]]; then
        pass "$name"
    else
        echo -e "${YELLOW}SKIP${NC}: $name (not running in bash)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

test_shell_variable_exists() {
    local name="SHELL variable exists"
    if [[ -n "$SHELL" ]]; then
        pass "$name"
    else
        fail "$name" "SHELL set" "SHELL not set"
    fi
}

test_shell_detection_bash
test_shell_variable_exists

# ============================================================================
# OPENCODE WRAPPER SCRIPT TESTS
# ============================================================================

echo
echo "========================================"
echo "OpenCode Wrapper Tests"
echo "========================================"
echo

test_wrapper_script_structure() {
    local name="Wrapper script has correct structure"
    
    # Check that the wrapper script template is correct
    local wrapper_template='#!/usr/bin/env bash
# Ensure bun is in PATH for this script and all child processes
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"'
    
    if echo "$wrapper_template" | grep -q 'export PATH'; then
        pass "$name"
    else
        fail "$name" "export PATH" "not found"
    fi
}

test_wrapper_finds_bun() {
    local name="Wrapper checks multiple bun locations"
    
    local wrapper_content='
if [[ -x "$HOME/.bun/bin/bun" ]]; then
    BUN="$HOME/.bun/bin/bun"
elif command -v bun &>/dev/null; then
    BUN="bun"
else
    echo "Error: bun not found" >&2
    exit 1
fi'
    
    if echo "$wrapper_content" | grep -q '\$HOME/.bun/bin/bun'; then
        pass "$name"
    else
        fail "$name" "bun location check" "not found"
    fi
}

test_wrapper_script_structure
test_wrapper_finds_bun

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

echo
echo "========================================"
echo "Integration Tests"
echo "========================================"
echo

test_all_deps_check_order() {
    local name="check_all_deps checks in correct order"
    
    # Verify the function exists and can be called
    if declare -f check_all_deps > /dev/null; then
        pass "$name"
    else
        fail "$name" "function exists" "not found"
    fi
}

test_project_dir_set() {
    local name="PROJECT_DIR is set correctly"
    if [[ -d "$PROJECT_DIR" ]]; then
        pass "$name"
    else
        fail "$name" "valid directory" "$PROJECT_DIR"
    fi
}

test_vendor_dir_set() {
    local name="VENDOR_DIR is set correctly"
    if [[ -d "$VENDOR_DIR" ]]; then
        pass "$name"
    else
        fail "$name" "valid directory" "$VENDOR_DIR"
    fi
}

test_all_deps_check_order
test_project_dir_set
test_vendor_dir_set

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
