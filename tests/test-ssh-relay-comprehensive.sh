#!/usr/bin/env bash
# test-ssh-relay-comprehensive.sh - Extended tests for SSH relay management
# Covers tunnel commands, status checks, and error handling
# Usage: ./tests/test-ssh-relay-comprehensive.sh

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

SSH_RELAY_SCRIPT="$LIB_DIR/ssh-relay.sh"

# ============================================================================
# SCRIPT STRUCTURE TESTS
# ============================================================================

echo "========================================"
echo "Script Structure Tests"
echo "========================================"
echo

test_script_exists() {
    local name="ssh-relay.sh script exists"
    if [[ -f "$SSH_RELAY_SCRIPT" ]]; then
        pass "$name"
    else
        fail "$name" "script exists" "not found"
    fi
}

test_script_executable() {
    local name="ssh-relay.sh is executable"
    if [[ -x "$SSH_RELAY_SCRIPT" ]]; then
        pass "$name"
    else
        fail "$name" "executable" "not executable"
    fi
}

test_script_has_shebang() {
    local name="Script has proper shebang"
    if head -1 "$SSH_RELAY_SCRIPT" | grep -q '^#!/usr/bin/env bash\|^#!/bin/bash'; then
        pass "$name"
    else
        fail "$name" "#!/usr/bin/env bash" "$(head -1 "$SSH_RELAY_SCRIPT")"
    fi
}

test_script_exists
test_script_executable
test_script_has_shebang

# ============================================================================
# ENVIRONMENT VARIABLE TESTS
# ============================================================================

echo
echo "========================================"
echo "Environment Variable Tests"
echo "========================================"
echo

test_relay_port_default() {
    local name="RELAY_PORT defaults to 8080"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'RELAY_PORT.*:-8080\|RELAY_PORT.*:=8080'; then
        pass "$name"
    else
        fail "$name" "default 8080" "not found"
    fi
}

test_relay_port_env_override() {
    local name="RELAY_PORT can be overridden"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'SOVEREIGN_RELAY_PORT'; then
        pass "$name"
    else
        fail "$name" "SOVEREIGN_RELAY_PORT" "not found"
    fi
}

test_pid_file_defined() {
    local name="PID_FILE is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'PID_FILE='; then
        pass "$name"
    else
        fail "$name" "PID_FILE=" "not found"
    fi
}

test_socket_file_defined() {
    local name="SOCKET_FILE is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'SOCKET_FILE='; then
        pass "$name"
    else
        fail "$name" "SOCKET_FILE=" "not found"
    fi
}

test_relay_port_default
test_relay_port_env_override
test_pid_file_defined
test_socket_file_defined

# ============================================================================
# COMMAND STRUCTURE TESTS
# ============================================================================

echo
echo "========================================"
echo "Command Structure Tests"
echo "========================================"
echo

test_start_command_exists() {
    local name="start command is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'start)'; then
        pass "$name"
    else
        fail "$name" "start command" "not found"
    fi
}

test_stop_command_exists() {
    local name="stop command is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'stop)'; then
        pass "$name"
    else
        fail "$name" "stop command" "not found"
    fi
}

test_status_command_exists() {
    local name="status command is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'status)'; then
        pass "$name"
    else
        fail "$name" "status command" "not found"
    fi
}

test_run_command_exists() {
    local name="run command is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'run)'; then
        pass "$name"
    else
        fail "$name" "run command" "not found"
    fi
}

test_help_command_exists() {
    local name="help command is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'help\|--help\|-h)'; then
        pass "$name"
    else
        fail "$name" "help command" "not found"
    fi
}

test_start_command_exists
test_stop_command_exists
test_status_command_exists
test_run_command_exists
test_help_command_exists

# ============================================================================
# SSH OPTIONS TESTS
# ============================================================================

echo
echo "========================================"
echo "SSH Options Tests"
echo "========================================"
echo

test_ssh_port_forwarding() {
    local name="SSH uses -L for port forwarding"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q '\-L'; then
        pass "$name"
    else
        fail "$name" "-L flag" "not found"
    fi
}

test_ssh_background_mode() {
    local name="SSH uses -f for background mode"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q '\-f'; then
        pass "$name"
    else
        fail "$name" "-f flag" "not found"
    fi
}

test_ssh_no_command() {
    local name="SSH uses -N for no remote command"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q '\-N'; then
        pass "$name"
    else
        fail "$name" "-N flag" "not found"
    fi
}

test_ssh_master_mode() {
    local name="SSH uses -M for master mode"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q '\-M'; then
        pass "$name"
    else
        fail "$name" "-M flag" "not found"
    fi
}

test_ssh_control_socket() {
    local name="SSH uses -S for control socket"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q '\-S'; then
        pass "$name"
    else
        fail "$name" "-S flag" "not found"
    fi
}

test_ssh_server_alive() {
    local name="SSH uses ServerAliveInterval"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'ServerAliveInterval'; then
        pass "$name"
    else
        fail "$name" "ServerAliveInterval" "not found"
    fi
}

test_ssh_exit_on_forward_failure() {
    local name="SSH uses ExitOnForwardFailure"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'ExitOnForwardFailure'; then
        pass "$name"
    else
        fail "$name" "ExitOnForwardFailure" "not found"
    fi
}

test_ssh_control_persist() {
    local name="SSH uses ControlPersist"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'ControlPersist'; then
        pass "$name"
    else
        fail "$name" "ControlPersist" "not found"
    fi
}

test_ssh_port_forwarding
test_ssh_background_mode
test_ssh_no_command
test_ssh_master_mode
test_ssh_control_socket
test_ssh_server_alive
test_ssh_exit_on_forward_failure
test_ssh_control_persist

# ============================================================================
# FUNCTION STRUCTURE TESTS
# ============================================================================

echo
echo "========================================"
echo "Function Structure Tests"
echo "========================================"
echo

test_start_tunnel_function() {
    local name="start_tunnel function is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'start_tunnel()'; then
        pass "$name"
    else
        fail "$name" "start_tunnel()" "not found"
    fi
}

test_stop_tunnel_function() {
    local name="stop_tunnel function is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'stop_tunnel()'; then
        pass "$name"
    else
        fail "$name" "stop_tunnel()" "not found"
    fi
}

test_check_status_function() {
    local name="check_status function is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'check_status()'; then
        pass "$name"
    else
        fail "$name" "check_status()" "not found"
    fi
}

test_run_with_tunnel_function() {
    local name="run_with_tunnel function is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'run_with_tunnel()'; then
        pass "$name"
    else
        fail "$name" "run_with_tunnel()" "not found"
    fi
}

test_usage_function() {
    local name="usage function is defined"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'usage()'; then
        pass "$name"
    else
        fail "$name" "usage()" "not found"
    fi
}

test_start_tunnel_function
test_stop_tunnel_function
test_check_status_function
test_run_with_tunnel_function
test_usage_function

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

echo
echo "========================================"
echo "Error Handling Tests"
echo "========================================"
echo

test_missing_ssh_host_error() {
    local name="Missing SSH host produces error"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'SSH host required\|ssh_host.*-z'; then
        pass "$name"
    else
        fail "$name" "SSH host required check" "not found"
    fi
}

test_stale_socket_cleanup() {
    local name="Stale socket is cleaned up"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'rm -f.*SOCKET_FILE\|Stale socket'; then
        pass "$name"
    else
        fail "$name" "socket cleanup" "not found"
    fi
}

test_relay_timeout_check() {
    local name="Relay timeout check exists"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'attempts\|timeout\|10'; then
        pass "$name"
    else
        fail "$name" "timeout check" "not found"
    fi
}

test_missing_ssh_host_error
test_stale_socket_cleanup
test_relay_timeout_check

# ============================================================================
# HEALTH CHECK TESTS
# ============================================================================

echo
echo "========================================"
echo "Health Check Tests"
echo "========================================"
echo

test_health_check_uses_curl() {
    local name="Health check uses curl"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'curl.*health\|curl.*localhost'; then
        pass "$name"
    else
        fail "$name" "curl health check" "not found"
    fi
}

test_health_check_endpoint() {
    local name="Health check uses /health endpoint"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q '/health'; then
        pass "$name"
    else
        fail "$name" "/health endpoint" "not found"
    fi
}

test_health_uses_jq() {
    local name="Health output uses jq for formatting"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'jq'; then
        pass "$name"
    else
        fail "$name" "jq formatting" "not found"
    fi
}

test_health_check_uses_curl
test_health_check_endpoint
test_health_uses_jq

# ============================================================================
# USAGE OUTPUT TESTS
# ============================================================================

echo
echo "========================================"
echo "Usage Output Tests"
echo "========================================"
echo

test_usage_shows_start() {
    local name="Usage shows start command"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'start.*ssh-host\|start <'; then
        pass "$name"
    else
        fail "$name" "start command in usage" "not found"
    fi
}

test_usage_shows_stop() {
    local name="Usage shows stop command"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'stop.*tunnel\|stop[[:space:]]'; then
        pass "$name"
    else
        fail "$name" "stop command in usage" "not found"
    fi
}

test_usage_shows_status() {
    local name="Usage shows status command"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'status'; then
        pass "$name"
    else
        fail "$name" "status command in usage" "not found"
    fi
}

test_usage_shows_run() {
    local name="Usage shows run command"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'run.*ssh-host\|run <'; then
        pass "$name"
    else
        fail "$name" "run command in usage" "not found"
    fi
}

test_usage_shows_examples() {
    local name="Usage shows examples"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'Examples:\|example'; then
        pass "$name"
    else
        fail "$name" "examples in usage" "not found"
    fi
}

test_usage_shows_architecture() {
    local name="Usage shows architecture diagram"
    local content
    content=$(cat "$SSH_RELAY_SCRIPT")
    
    if echo "$content" | grep -q 'Architecture:\|Client.*SSH\|──>'; then
        pass "$name"
    else
        fail "$name" "architecture in usage" "not found"
    fi
}

test_usage_shows_start
test_usage_shows_stop
test_usage_shows_status
test_usage_shows_run
test_usage_shows_examples
test_usage_shows_architecture

# ============================================================================
# INTEGRATION TESTS (Non-destructive)
# ============================================================================

echo
echo "========================================"
echo "Integration Tests (Non-destructive)"
echo "========================================"
echo

test_help_flag_works() {
    local name="--help flag displays usage"
    local output
    output=$("$SSH_RELAY_SCRIPT" --help 2>&1)
    
    if echo "$output" | grep -qi 'usage\|ssh tunnel\|commands'; then
        pass "$name"
    else
        fail "$name" "usage text" "no output"
    fi
}

test_h_flag_works() {
    local name="-h flag displays usage"
    local output
    output=$("$SSH_RELAY_SCRIPT" -h 2>&1)
    
    if echo "$output" | grep -qi 'usage\|ssh tunnel\|commands'; then
        pass "$name"
    else
        fail "$name" "usage text" "no output"
    fi
}

test_invalid_command_shows_usage() {
    local name="Invalid command shows usage"
    local output
    output=$("$SSH_RELAY_SCRIPT" invalid_command 2>&1)
    
    if echo "$output" | grep -qi 'usage\|ssh tunnel\|commands'; then
        pass "$name"
    else
        fail "$name" "usage text" "no output"
    fi
}

test_no_args_shows_usage() {
    local name="No arguments shows usage"
    local output
    output=$("$SSH_RELAY_SCRIPT" 2>&1)
    
    if echo "$output" | grep -qi 'usage\|ssh tunnel\|commands'; then
        pass "$name"
    else
        fail "$name" "usage text" "no output"
    fi
}

test_start_without_host_errors() {
    local name="start without host shows error"
    local output
    output=$("$SSH_RELAY_SCRIPT" start 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi 'required\|error\|usage'; then
        pass "$name"
    else
        fail "$name" "error message" "$output"
    fi
}

test_run_without_host_errors() {
    local name="run without host shows error"
    local output
    output=$("$SSH_RELAY_SCRIPT" run 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi 'required\|error\|usage'; then
        pass "$name"
    else
        fail "$name" "error message" "$output"
    fi
}

test_help_flag_works
test_h_flag_works
test_invalid_command_shows_usage
test_no_args_shows_usage
test_start_without_host_errors
test_run_without_host_errors

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
