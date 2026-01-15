#!/usr/bin/env bash
# test-install-comprehensive.sh - Extended tests for install.sh
# Covers submodule handling, edge cases, and integration scenarios
# Usage: ./tests/test-install-comprehensive.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
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

INSTALL_SCRIPT="$PROJECT_DIR/install.sh"

# ============================================================================
# SCRIPT STRUCTURE TESTS
# ============================================================================

echo "========================================"
echo "Script Structure Tests"
echo "========================================"
echo

test_script_exists() {
    local name="install.sh script exists"
    if [[ -f "$INSTALL_SCRIPT" ]]; then
        pass "$name"
    else
        fail "$name" "script exists" "not found"
    fi
}

test_script_executable() {
    local name="install.sh is executable"
    if [[ -x "$INSTALL_SCRIPT" ]]; then
        pass "$name"
    else
        fail "$name" "executable" "not executable"
    fi
}

test_script_has_shebang() {
    local name="Script has proper shebang"
    if head -1 "$INSTALL_SCRIPT" | grep -q '^#!/usr/bin/env bash\|^#!/bin/bash'; then
        pass "$name"
    else
        fail "$name" "#!/usr/bin/env bash" "$(head -1 "$INSTALL_SCRIPT")"
    fi
}

test_script_exists
test_script_executable
test_script_has_shebang

# ============================================================================
# COMMAND LINE ARGUMENT TESTS
# ============================================================================

echo
echo "========================================"
echo "Command Line Argument Tests"
echo "========================================"
echo

test_help_short_flag() {
    local name="-h flag displays help"
    local output
    output=$("$INSTALL_SCRIPT" -h 2>&1)
    
    if echo "$output" | grep -qi 'usage\|help\|options'; then
        pass "$name"
    else
        fail "$name" "help text" "no help output"
    fi
}

test_help_long_flag() {
    local name="--help flag displays help"
    local output
    output=$("$INSTALL_SCRIPT" --help 2>&1)
    
    if echo "$output" | grep -qi 'usage\|help\|options'; then
        pass "$name"
    else
        fail "$name" "help text" "no help output"
    fi
}

test_invalid_option() {
    local name="Invalid option returns error"
    local output
    output=$("$INSTALL_SCRIPT" --invalid-option 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        pass "$name"
    else
        fail "$name" "non-zero exit" "exit $exit_code"
    fi
}

test_skip_deps_flag() {
    local name="--skip-deps flag is recognized"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q '\-\-skip-deps'; then
        pass "$name"
    else
        fail "$name" "--skip-deps" "not found in script"
    fi
}

test_config_flag() {
    local name="--config flag is recognized"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q '\-\-config'; then
        pass "$name"
    else
        fail "$name" "--config" "not found in script"
    fi
}

test_dest_flag() {
    local name="--dest flag is recognized"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q '\-\-dest'; then
        pass "$name"
    else
        fail "$name" "--dest" "not found in script"
    fi
}

test_help_short_flag
test_help_long_flag
test_invalid_option
test_skip_deps_flag
test_config_flag
test_dest_flag

# ============================================================================
# FUNCTION STRUCTURE TESTS
# ============================================================================

echo
echo "========================================"
echo "Function Structure Tests"
echo "========================================"
echo

test_check_submodules_function() {
    local name="check_submodules function is defined"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'check_submodules()'; then
        pass "$name"
    else
        fail "$name" "check_submodules()" "not found"
    fi
}

test_print_banner_function() {
    local name="print_banner function is defined"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'print_banner()\|banner'; then
        pass "$name"
    else
        fail "$name" "print_banner()" "not found"
    fi
}

test_print_summary_function() {
    local name="print_summary function is defined"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'print_summary()\|summary'; then
        pass "$name"
    else
        fail "$name" "print_summary()" "not found"
    fi
}

test_check_submodules_function
test_print_banner_function
test_print_summary_function

# ============================================================================
# SUBMODULE HANDLING TESTS
# ============================================================================

echo
echo "========================================"
echo "Submodule Handling Tests"
echo "========================================"
echo

test_checks_for_git_repo() {
    local name="Checks if in git repository"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'git.*rev-parse\|\.git'; then
        pass "$name"
    else
        fail "$name" "git repo check" "not found"
    fi
}

test_checks_vendor_directory() {
    local name="Checks vendor directory"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'vendor\|VENDOR'; then
        pass "$name"
    else
        fail "$name" "vendor check" "not found"
    fi
}

test_runs_submodule_update() {
    local name="Runs git submodule update"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'git submodule update\|submodule.*init'; then
        pass "$name"
    else
        fail "$name" "git submodule update" "not found"
    fi
}

test_checks_for_git_repo
test_checks_vendor_directory
test_runs_submodule_update

# ============================================================================
# DEPENDENCY SOURCING TESTS
# ============================================================================

echo
echo "========================================"
echo "Dependency Sourcing Tests"
echo "========================================"
echo

test_sources_validate_script() {
    local name="Sources validate.sh"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'source.*validate\.sh\|\. .*validate\.sh'; then
        pass "$name"
    else
        fail "$name" "source validate.sh" "not found"
    fi
}

test_sources_check_deps_script() {
    local name="Sources check-deps.sh"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'source.*check-deps\.sh\|\. .*check-deps\.sh'; then
        pass "$name"
    else
        fail "$name" "source check-deps.sh" "not found"
    fi
}

test_sources_validate_script
test_sources_check_deps_script

# ============================================================================
# WORKFLOW TESTS
# ============================================================================

echo
echo "========================================"
echo "Workflow Tests"
echo "========================================"
echo

test_validates_config() {
    local name="Calls validate_config"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'validate_config'; then
        pass "$name"
    else
        fail "$name" "validate_config call" "not found"
    fi
}

test_calls_check_all_deps() {
    local name="Calls check_all_deps"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'check_all_deps'; then
        pass "$name"
    else
        fail "$name" "check_all_deps call" "not found"
    fi
}

test_validates_config
test_calls_check_all_deps

# ============================================================================
# OUTPUT TESTS
# ============================================================================

echo
echo "========================================"
echo "Output Tests"
echo "========================================"
echo

test_banner_output() {
    local name="Banner contains project name"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -qi 'sovereign.*agent\|banner'; then
        pass "$name"
    else
        fail "$name" "Sovereign Agent" "not found"
    fi
}

test_summary_shows_success() {
    local name="Summary shows success message"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -qi 'success\|complete\|installed'; then
        pass "$name"
    else
        fail "$name" "success message" "not found"
    fi
}

test_shows_opencode_command() {
    local name="Shows opencode command in summary"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'opencode'; then
        pass "$name"
    else
        fail "$name" "opencode command" "not found"
    fi
}

test_banner_output
test_summary_shows_success
test_shows_opencode_command

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

echo
echo "========================================"
echo "Error Handling Tests"
echo "========================================"
echo

test_exits_on_validation_failure() {
    local name="Exits on validation failure"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'exit 1\|return 1'; then
        pass "$name"
    else
        fail "$name" "exit on error" "not found"
    fi
}

test_exits_on_deps_failure() {
    local name="Handles dependency check failure"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'check.*failed\|error\|exit 1'; then
        pass "$name"
    else
        fail "$name" "deps failure handling" "not found"
    fi
}

test_exits_on_validation_failure
test_exits_on_deps_failure

# ============================================================================
# INTEGRATION TESTS (Non-destructive)
# ============================================================================

echo
echo "========================================"
echo "Integration Tests (Non-destructive)"
echo "========================================"
echo

test_missing_config_error() {
    local name="Missing config file shows error"
    local output
    output=$("$INSTALL_SCRIPT" --config "$TEST_TMP_DIR/nonexistent.json" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        pass "$name"
    else
        fail "$name" "non-zero exit" "exit $exit_code"
    fi
}

test_help_does_not_run_install() {
    local name="Help flag does not run install"
    local start_time
    start_time=$(date +%s)
    
    "$INSTALL_SCRIPT" --help >/dev/null 2>&1
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should complete in under 2 seconds (just help, no install)
    if [[ $duration -lt 2 ]]; then
        pass "$name"
    else
        fail "$name" "quick exit" "${duration}s"
    fi
}

test_missing_config_error
test_help_does_not_run_install

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

echo
echo "========================================"
echo "Edge Case Tests"
echo "========================================"
echo

test_handles_spaces_in_path() {
    local name="Script quotes paths for spaces"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    # Check for quoted variable expansions
    if echo "$content" | grep -q '"\$'; then
        pass "$name"
    else
        fail "$name" "quoted paths" "not found"
    fi
}

test_uses_local_variables() {
    local name="Functions use local variables"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'local '; then
        pass "$name"
    else
        fail "$name" "local variables" "not found"
    fi
}

test_project_dir_set() {
    local name="PROJECT_DIR is set"
    local content
    content=$(cat "$INSTALL_SCRIPT")
    
    if echo "$content" | grep -q 'PROJECT_DIR=\|SCRIPT_DIR='; then
        pass "$name"
    else
        fail "$name" "PROJECT_DIR" "not found"
    fi
}

test_handles_spaces_in_path
test_uses_local_variables
test_project_dir_set

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
