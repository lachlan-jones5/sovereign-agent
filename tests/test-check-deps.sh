#!/usr/bin/env bash
# test-check-deps.sh - Test the dependency checking script
# Usage: ./tests/test-check-deps.sh

# Don't use set -e as we test various scenarios

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

# Source the check-deps script
source "$LIB_DIR/check-deps.sh"

# Test 1: command_exists returns true for existing command
test_command_exists_true() {
    local name="command_exists returns true for 'bash'"
    if command_exists bash; then
        pass "$name"
    else
        fail "$name" "true" "false"
    fi
}

# Test 2: command_exists returns false for non-existing command
test_command_exists_false() {
    local name="command_exists returns false for 'nonexistent_command_xyz'"
    if command_exists nonexistent_command_xyz; then
        fail "$name" "false" "true"
    else
        pass "$name"
    fi
}

# Test 3: check_curl succeeds when curl is installed
test_check_curl_installed() {
    local name="check_curl succeeds when curl is installed"
    if command_exists curl; then
        if check_curl >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (curl not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 4: check_jq succeeds when jq is installed
test_check_jq_installed() {
    local name="check_jq succeeds when jq is installed"
    if command_exists jq; then
        if check_jq >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (jq not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 5: check_go succeeds when go is installed
test_check_go_installed() {
    local name="check_go succeeds when go is installed"
    if command_exists go; then
        if check_go >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (go not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 6: check_bun succeeds when bun is installed
test_check_bun_installed() {
    local name="check_bun succeeds when bun is installed"
    # Ensure bun is in PATH
    if [[ -d "$HOME/.bun/bin" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
    fi
    
    if command_exists bun; then
        if check_bun >/dev/null 2>&1; then
            pass "$name"
        else
            fail "$name" "success" "failure"
        fi
    else
        echo "SKIP: $name (bun not installed)"
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
    fi
}

# Test 7: log_info outputs correct format
test_log_info_format() {
    local name="log_info outputs correct format"
    local output
    output=$(log_info "test message" 2>&1)
    
    if echo "$output" | grep -q "INFO.*test message"; then
        pass "$name"
    else
        fail "$name" "[INFO] test message" "$output"
    fi
}

# Test 8: log_warn outputs correct format
test_log_warn_format() {
    local name="log_warn outputs correct format"
    local output
    output=$(log_warn "warning message" 2>&1)
    
    if echo "$output" | grep -q "WARN.*warning message"; then
        pass "$name"
    else
        fail "$name" "[WARN] warning message" "$output"
    fi
}

# Test 9: log_error outputs correct format
test_log_error_format() {
    local name="log_error outputs correct format"
    local output
    output=$(log_error "error message" 2>&1)
    
    if echo "$output" | grep -q "ERROR.*error message"; then
        pass "$name"
    else
        fail "$name" "[ERROR] error message" "$output"
    fi
}

# Test 10: VENDOR_DIR is correctly set
test_vendor_dir_set() {
    local name="VENDOR_DIR is correctly set"
    if [[ -n "$VENDOR_DIR" && -d "$VENDOR_DIR" ]]; then
        pass "$name"
    else
        fail "$name" "non-empty directory path" "$VENDOR_DIR"
    fi
}

# Test 11: PROJECT_DIR is correctly set
test_project_dir_set() {
    local name="PROJECT_DIR is correctly set"
    if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
        pass "$name"
    else
        fail "$name" "non-empty directory path" "$PROJECT_DIR"
    fi
}

# Test 12: build_opencode checks for submodule
test_build_opencode_checks_submodule() {
    local name="build_opencode checks for submodule existence"
    
    # Temporarily override VENDOR_DIR to non-existent path
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    local output
    output=$(build_opencode 2>&1)
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q -i "submodule"; then
        pass "$name"
    else
        fail "$name" "error about submodule" "$output"
    fi
}

# Test 13: build_oh_my_opencode checks for submodule
test_build_omo_checks_submodule() {
    local name="build_oh_my_opencode checks for submodule existence"
    
    # Temporarily override VENDOR_DIR to non-existent path
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    local output
    output=$(build_oh_my_opencode 2>&1)
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q -i "submodule"; then
        pass "$name"
    else
        fail "$name" "error about submodule" "$output"
    fi
}

# ============================================
# PATH Persistence Tests (ensure_path_in_rc)
# ============================================

# Test 14: ensure_path_in_rc creates rc file if not exists
test_ensure_path_creates_rc() {
    local name="ensure_path_in_rc creates rc file if not exists"
    local test_home="$TEST_TMP_DIR/home_no_rc"
    mkdir -p "$test_home"
    
    # Override HOME temporarily
    local original_home="$HOME"
    HOME="$test_home"
    SHELL="/bin/bash"
    
    # Remove PATH so we trigger the add
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    ensure_path_in_rc "$test_home/.local/bin" 2>/dev/null
    
    HOME="$original_home"
    PATH="$original_path"
    
    # Check that rc file was created with PATH export
    if [[ -f "$test_home/.profile" ]] || [[ -f "$test_home/.bashrc" ]]; then
        local rc_content
        rc_content=$(cat "$test_home/.profile" 2>/dev/null || cat "$test_home/.bashrc" 2>/dev/null)
        if echo "$rc_content" | grep -q "export PATH="; then
            pass "$name"
        else
            fail "$name" "PATH export in rc file" "$rc_content"
        fi
    else
        fail "$name" "rc file created" "no rc file"
    fi
}

# Test 15: ensure_path_in_rc adds correct export statement
test_ensure_path_correct_export() {
    local name="ensure_path_in_rc adds correct export statement"
    local test_home="$TEST_TMP_DIR/home_export"
    mkdir -p "$test_home"
    touch "$test_home/.bashrc"
    
    local original_home="$HOME"
    HOME="$test_home"
    SHELL="/bin/bash"
    
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    ensure_path_in_rc "$test_home/custom/bin" 2>/dev/null
    
    HOME="$original_home"
    PATH="$original_path"
    
    if grep -q 'export PATH=".*custom/bin.*:\$PATH"' "$test_home/.bashrc"; then
        pass "$name"
    else
        fail "$name" "export PATH with custom/bin" "$(cat "$test_home/.bashrc")"
    fi
}

# Test 16: ensure_path_in_rc skips if already in PATH
test_ensure_path_skips_if_in_path() {
    local name="ensure_path_in_rc skips if already in PATH"
    local test_home="$TEST_TMP_DIR/home_skip"
    mkdir -p "$test_home"
    touch "$test_home/.bashrc"
    
    local original_home="$HOME"
    HOME="$test_home"
    SHELL="/bin/bash"
    
    # Add the target to PATH
    local original_path="$PATH"
    PATH="$test_home/.local/bin:/usr/bin:/bin"
    
    ensure_path_in_rc "$test_home/.local/bin" 2>/dev/null
    
    HOME="$original_home"
    PATH="$original_path"
    
    # .bashrc should be empty (no additions)
    local rc_size
    rc_size=$(wc -c < "$test_home/.bashrc")
    if [[ $rc_size -eq 0 ]]; then
        pass "$name"
    else
        fail "$name" "empty .bashrc (skipped)" "$(cat "$test_home/.bashrc")"
    fi
}

# Test 17: ensure_path_in_rc skips if already in rc file
test_ensure_path_skips_if_in_rc() {
    local name="ensure_path_in_rc skips if already in rc file"
    local test_home="$TEST_TMP_DIR/home_already"
    mkdir -p "$test_home"
    echo 'export PATH="$HOME/.local/bin:$PATH"' > "$test_home/.bashrc"
    
    local original_home="$HOME"
    HOME="$test_home"
    SHELL="/bin/bash"
    
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    ensure_path_in_rc "$test_home/.local/bin" 2>/dev/null
    
    HOME="$original_home"
    PATH="$original_path"
    
    # Should only have 1 line (no duplicates)
    local line_count
    line_count=$(wc -l < "$test_home/.bashrc")
    if [[ $line_count -eq 1 ]]; then
        pass "$name"
    else
        fail "$name" "1 line (no duplicates)" "$line_count lines"
    fi
}

# Test 18: ensure_path_in_rc uses .zshrc for zsh
test_ensure_path_uses_zshrc() {
    local name="ensure_path_in_rc uses .zshrc for zsh shell"
    local test_home="$TEST_TMP_DIR/home_zsh"
    mkdir -p "$test_home"
    
    local original_home="$HOME"
    HOME="$test_home"
    local original_shell="$SHELL"
    SHELL="/bin/zsh"
    
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    ensure_path_in_rc "$test_home/.local/bin" 2>/dev/null
    
    HOME="$original_home"
    SHELL="$original_shell"
    PATH="$original_path"
    
    if [[ -f "$test_home/.zshrc" ]] && grep -q "\.local/bin" "$test_home/.zshrc"; then
        pass "$name"
    else
        fail "$name" ".zshrc with .local/bin" "$(ls -la "$test_home" 2>&1)"
    fi
}

# Test 19: ensure_path_in_rc adds sovereign-agent comment
test_ensure_path_adds_comment() {
    local name="ensure_path_in_rc adds 'Added by sovereign-agent' comment"
    local test_home="$TEST_TMP_DIR/home_comment"
    mkdir -p "$test_home"
    touch "$test_home/.bashrc"
    
    local original_home="$HOME"
    HOME="$test_home"
    SHELL="/bin/bash"
    
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    ensure_path_in_rc "$test_home/.local/bin" 2>/dev/null
    
    HOME="$original_home"
    PATH="$original_path"
    
    if grep -q "Added by sovereign-agent" "$test_home/.bashrc"; then
        pass "$name"
    else
        fail "$name" "comment present" "$(cat "$test_home/.bashrc")"
    fi
}

# Test 20: ensure_local_bin_in_path is convenience wrapper
test_ensure_local_bin_wrapper() {
    local name="ensure_local_bin_in_path is convenience wrapper for ~/.local/bin"
    local test_home="$TEST_TMP_DIR/home_wrapper"
    mkdir -p "$test_home"
    touch "$test_home/.bashrc"
    
    local original_home="$HOME"
    HOME="$test_home"
    SHELL="/bin/bash"
    
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    ensure_local_bin_in_path 2>/dev/null
    
    HOME="$original_home"
    PATH="$original_path"
    
    if grep -q '\.local/bin' "$test_home/.bashrc"; then
        pass "$name"
    else
        fail "$name" ".local/bin in .bashrc" "$(cat "$test_home/.bashrc")"
    fi
}

# ============================================
# Bun PATH Persistence Tests
# ============================================

# Test 21: check_bun calls ensure_path_in_rc for ~/.bun/bin
test_check_bun_persists_path() {
    local name="check_bun persists ~/.bun/bin to shell rc (static check)"
    
    # This is a static code analysis test - verify check_bun calls ensure_path_in_rc
    if grep -q 'ensure_path_in_rc.*\.bun/bin\|ensure_path_in_rc.*bun' "$LIB_DIR/check-deps.sh"; then
        pass "$name"
    else
        fail "$name" "ensure_path_in_rc call in check_bun" "not found"
    fi
}

# Test 22: check_bun adds ~/.bun/bin for already installed bun
test_check_bun_ensures_path_if_installed() {
    local name="check_bun ensures path even when bun already installed"
    
    # Check that the "bun is already installed" branch also calls ensure_path_in_rc
    local check_bun_func
    check_bun_func=$(sed -n '/^check_bun()/,/^}/p' "$LIB_DIR/check-deps.sh")
    
    # The function should call ensure_path_in_rc regardless of whether bun was just installed
    if echo "$check_bun_func" | grep -q 'already installed' && \
       echo "$check_bun_func" | head -15 | grep -q 'ensure_path_in_rc'; then
        pass "$name"
    else
        fail "$name" "ensure_path_in_rc in 'already installed' branch" "not found in first 15 lines"
    fi
}

# ============================================
# Build OpenCode Error Handling Tests
# ============================================

# Test 23: build_opencode checks for package.json (empty submodule detection)
test_build_opencode_checks_packagejson() {
    local name="build_opencode detects empty submodule (missing package.json)"
    
    # Create a fake empty submodule directory
    local fake_vendor="$TEST_TMP_DIR/vendor"
    mkdir -p "$fake_vendor/opencode"
    
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="$fake_vendor"
    
    local output
    output=$(build_opencode 2>&1)
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -qi "empty\|package.json"; then
        pass "$name"
    else
        fail "$name" "error about empty submodule" "exit=$exit_code output=$output"
    fi
}

# Test 24: build_opencode checks for Bun availability
test_build_opencode_checks_bun() {
    local name="build_opencode checks for Bun in PATH"
    
    # Create a fake submodule with package.json
    local fake_vendor="$TEST_TMP_DIR/vendor_bun"
    mkdir -p "$fake_vendor/opencode"
    echo '{"name": "opencode"}' > "$fake_vendor/opencode/package.json"
    
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="$fake_vendor"
    
    # Hide bun from PATH
    local original_path="$PATH"
    PATH="/usr/bin:/bin"
    
    local output
    output=$(build_opencode 2>&1)
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    PATH="$original_path"
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -qi "bun.*not found\|bun is required"; then
        pass "$name"
    else
        fail "$name" "error about Go not found" "exit=$exit_code output=$output"
    fi
}

# Test 25: build_opencode returns non-zero on failure
test_build_opencode_returns_nonzero() {
    local name="build_opencode returns non-zero exit code on failure"
    
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    build_opencode >/dev/null 2>&1
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]]; then
        pass "$name"
    else
        fail "$name" "non-zero exit code" "$exit_code"
    fi
}

# ============================================
# check_all_deps Fail-Fast Tests
# ============================================

# Test 26: check_all_deps fails if build_opencode fails
test_check_all_deps_fails_on_opencode() {
    local name="check_all_deps fails if build_opencode fails"
    
    # Override VENDOR_DIR to trigger failure
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    check_all_deps >/dev/null 2>&1
    local exit_code=$?
    
    VENDOR_DIR="$original_vendor"
    
    if [[ $exit_code -ne 0 ]]; then
        pass "$name"
    else
        fail "$name" "non-zero exit code" "$exit_code"
    fi
}

# Test 27: check_all_deps returns error message on failure
test_check_all_deps_error_message() {
    local name="check_all_deps outputs error message on failure"
    
    local original_vendor="$VENDOR_DIR"
    VENDOR_DIR="/nonexistent/path"
    
    local output
    output=$(check_all_deps 2>&1)
    
    VENDOR_DIR="$original_vendor"
    
    if echo "$output" | grep -qi "error\|fail"; then
        pass "$name"
    else
        fail "$name" "error message in output" "$output"
    fi
}

# Run all tests
echo "========================================"
echo "Running check-deps.sh tests"
echo "========================================"
echo

test_command_exists_true
test_command_exists_false
test_check_curl_installed
test_check_jq_installed
test_check_go_installed
test_check_bun_installed
test_log_info_format
test_log_warn_format
test_log_error_format
test_vendor_dir_set
test_project_dir_set
test_build_opencode_checks_submodule
test_build_omo_checks_submodule

echo
echo "--- PATH Persistence Tests ---"
echo
test_ensure_path_creates_rc
test_ensure_path_correct_export
test_ensure_path_skips_if_in_path
test_ensure_path_skips_if_in_rc
test_ensure_path_uses_zshrc
test_ensure_path_adds_comment
test_ensure_local_bin_wrapper
test_check_bun_persists_path
test_check_bun_ensures_path_if_installed

echo
echo "--- Build Error Handling Tests ---"
echo
test_build_opencode_checks_packagejson
test_build_opencode_checks_bun
test_build_opencode_returns_nonzero
test_check_all_deps_fails_on_opencode
test_check_all_deps_error_message

echo
echo "--- OpenCode Wrapper Tests ---"
echo

# Test 28: opencode wrapper exports PATH with bun
if grep -q 'export PATH.*\.bun' "$LIB_DIR/check-deps.sh"; then
    pass "opencode wrapper exports PATH with ~/.bun/bin"
else
    fail "opencode wrapper should export PATH with ~/.bun/bin for child processes"
fi

# Test 29: opencode wrapper uses full bun path
if grep -q '\.bun/bin/bun\|HOME.*\.bun.*bun' "$LIB_DIR/check-deps.sh"; then
    pass "opencode wrapper uses full bun path (~/.bun/bin/bun)"
else
    fail "opencode wrapper should use full bun path for PATH-less execution"
fi

# Test 29: opencode wrapper has fallback to command -v bun
if grep -q 'command -v bun\|which bun' "$LIB_DIR/check-deps.sh"; then
    pass "opencode wrapper has fallback to find bun in PATH"
else
    fail "opencode wrapper should fallback to bun in PATH"
fi

# Test 30: opencode wrapper provides helpful error if bun not found
if grep -q 'bun not found\|bun.sh/install' "$LIB_DIR/check-deps.sh"; then
    pass "opencode wrapper provides helpful error if bun not found"
else
    fail "opencode wrapper should provide helpful error if bun not found"
fi

echo
echo "--- oh-my-opencode Install CLI Tests ---"
echo

# Test 31: oh-my-opencode install uses CLI command, not package.json script
# The bug was: 'bun run install' hit /usr/bin/install instead of the CLI
if grep -q 'dist/cli/index.js install\|bunx oh-my-opencode install' "$LIB_DIR/check-deps.sh"; then
    pass "oh-my-opencode install uses CLI command (not bun run install)"
else
    fail "oh-my-opencode install should use CLI (dist/cli/index.js install), not 'bun run install' which hits /usr/bin/install"
fi

# Test 32: oh-my-opencode install is preceded by build step
# The CLI needs to be built first before running dist/cli/index.js
if grep -B15 'dist/cli/index.js install' "$LIB_DIR/check-deps.sh" | grep -q 'bun run build'; then
    pass "oh-my-opencode builds CLI before running install command"
else
    fail "oh-my-opencode should run 'bun run build' before 'dist/cli/index.js install'"
fi

# Test 33: oh-my-opencode install passes --no-tui flag
if grep -q 'install.*--no-tui' "$LIB_DIR/check-deps.sh"; then
    pass "oh-my-opencode install passes --no-tui flag"
else
    fail "oh-my-opencode install should pass --no-tui for non-interactive mode"
fi

# Test 34: oh-my-opencode install does NOT use 'bun run install' pattern
# This pattern would hit /usr/bin/install on systems where there's no 'install' script in package.json
if ! grep -q 'bun run install --no-tui' "$LIB_DIR/check-deps.sh"; then
    pass "oh-my-opencode does NOT use 'bun run install' pattern (avoids /usr/bin/install)"
else
    fail "oh-my-opencode should NOT use 'bun run install' - this pattern hits /usr/bin/install"
fi

# Test 35: Verify oh-my-opencode package.json has no 'install' script
# This confirms why 'bun run install' fails - there is no such script
if [[ -f "$PROJECT_DIR/vendor/oh-my-opencode/package.json" ]]; then
    if ! jq -e '.scripts.install' "$PROJECT_DIR/vendor/oh-my-opencode/package.json" >/dev/null 2>&1; then
        pass "oh-my-opencode package.json has no 'install' script (confirms CLI is needed)"
    else
        fail "oh-my-opencode has 'install' script in package.json - test assumption wrong"
    fi
else
    # Submodule might not be initialized in test environment
    pass "oh-my-opencode package.json check skipped (submodule not initialized)"
fi

# Test 36: oh-my-opencode install uses correct provider flags
if grep -q 'install.*--claude=\|install.*--gemini=' "$LIB_DIR/check-deps.sh"; then
    pass "oh-my-opencode install uses provider selection flags"
else
    fail "oh-my-opencode install should use provider flags (--claude, --gemini, etc.)"
fi

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
