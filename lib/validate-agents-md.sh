#!/usr/bin/env bash
# validate-agents-md.sh - Scan AGENTS.md files for suspicious patterns
#
# This script detects potential prompt injection attacks in AGENTS.md files
# that could be used to manipulate the AI agent's behavior.
#
# Usage:
#   ./lib/validate-agents-md.sh [directory]
#   ./lib/validate-agents-md.sh              # Scan current directory
#   ./lib/validate-agents-md.sh /path/to/repo
#
# Exit codes:
#   0 - No suspicious patterns found
#   1 - Suspicious patterns detected (review required)
#   2 - Script error

# Note: set -e is intentionally NOT used here to allow sourcing for testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Suspicious patterns that may indicate prompt injection
# These patterns are checked case-insensitively
SUSPICIOUS_PATTERNS=(
    # Direct instruction overrides
    "ignore previous instructions"
    "ignore all previous"
    "disregard previous"
    "forget previous"
    "override instructions"
    "new instructions"
    "system prompt"
    "you are now"
    "act as if"
    "pretend you are"
    "pretend to be"
    
    # Jailbreak attempts
    "jailbreak"
    "DAN mode"
    "developer mode"
    "unrestricted mode"
    "no restrictions"
    "bypass safety"
    "bypass security"
    "ignore safety"
    "ignore security"
    
    # Role manipulation
    "you must obey"
    "you will obey"
    "do not refuse"
    "cannot refuse"
    "must comply"
    "always comply"
    "never refuse"
    
    # Hidden instructions
    "hidden instruction"
    "secret instruction"
    "do not tell the user"
    "do not mention"
    "hide this from"
    "keep this secret"
    
    # Code execution tricks
    "execute this command"
    "run this script"
    "curl.*\\|.*sh"
    "wget.*\\|.*sh"
    "rm -rf"
    "chmod 777"
    "> /dev/null"
    "eval\\s*\\("
    
    # Exfiltration patterns
    "send to server"
    "exfiltrate"
    "upload to"
    "post to http"
    "curl.*-d.*\\$"
    
    # Base64/encoded content (potential obfuscation)
    "base64 -d"
    "base64 --decode"
    "\\\\x[0-9a-fA-F]{2}"
)

# Patterns that warrant a warning but aren't necessarily malicious
WARNING_PATTERNS=(
    # Broad permission grants
    "always execute"
    "auto-approve"
    "skip confirmation"
    "no confirmation needed"
    
    # Unusual tool permissions
    "allow all tools"
    "unrestricted access"
    "full access"
    
    # External dependencies
    "download from"
    "fetch from"
    "install from"
)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Find all AGENTS.md files in a directory
find_agents_files() {
    local dir="$1"
    find "$dir" \( -name "AGENTS.md" -o -name "agents.md" -o -name "CLAUDE.md" -o -name "claude.md" \) 2>/dev/null || true
}

# Check a file for suspicious patterns
check_file() {
    local file="$1"
    local has_issues=0
    local has_warnings=0
    
    echo -e "\n${BOLD}Scanning: $file${NC}"
    
    # Read file content
    local content
    content=$(cat "$file" 2>/dev/null || echo "")
    
    if [[ -z "$content" ]]; then
        log_warn "File is empty or unreadable"
        return 0
    fi
    
    # Check for suspicious patterns
    for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
        if echo "$content" | grep -iE "$pattern" >/dev/null 2>&1; then
            log_error "Suspicious pattern found: '$pattern'"
            # Show the matching line(s)
            echo "$content" | grep -in "$pattern" 2>/dev/null | head -3 | while read -r line; do
                echo -e "  ${RED}→${NC} $line"
            done
            has_issues=1
        fi
    done
    
    # Check for warning patterns
    for pattern in "${WARNING_PATTERNS[@]}"; do
        if echo "$content" | grep -iE "$pattern" >/dev/null 2>&1; then
            log_warn "Warning pattern found: '$pattern'"
            echo "$content" | grep -in "$pattern" 2>/dev/null | head -3 | while read -r line; do
                echo -e "  ${YELLOW}→${NC} $line"
            done
            has_warnings=1
        fi
    done
    
    # Check for unusually long lines (potential obfuscation)
    local max_line_length
    max_line_length=$(awk '{ print length }' "$file" 2>/dev/null | sort -rn | head -1)
    if [[ -n "$max_line_length" ]] && [[ "$max_line_length" -gt 500 ]]; then
        log_warn "Very long line detected ($max_line_length chars) - potential obfuscation"
        has_warnings=1
    fi
    
    # Check for hidden unicode characters (use tr instead of grep -P for portability)
    if LC_ALL=C tr -d '[:print:][:space:]' < "$file" | grep -q .; then
        log_error "Hidden/control characters detected - potential obfuscation"
        has_issues=1
    fi
    
    # Check for excessive use of code blocks (potential command hiding)
    local code_block_count
    code_block_count=$(grep -c '```' "$file" 2>/dev/null | tr -d '\n' || echo 0)
    if [[ -z "$code_block_count" ]]; then
        code_block_count=0
    fi
    if [[ "$code_block_count" -gt 20 ]]; then
        log_warn "Many code blocks detected ($code_block_count) - review carefully"
        has_warnings=1
    fi
    
    if [[ $has_issues -eq 1 ]]; then
        return 1
    elif [[ $has_warnings -eq 1 ]]; then
        return 0  # Warnings don't fail the check
    else
        log_success "No suspicious patterns found"
        return 0
    fi
}

# Main validation function
validate_agents_md() {
    local target_dir="${1:-.}"
    local exit_code=0
    local files_checked=0
    local files_suspicious=0
    
    echo -e "${BOLD}${BLUE}"
    echo "========================================"
    echo "  AGENTS.md Security Validator"
    echo "========================================"
    echo -e "${NC}"
    
    log_info "Scanning directory: $target_dir"
    
    # Check if directory exists
    if [[ ! -d "$target_dir" ]]; then
        log_error "Directory not found: $target_dir"
        exit 2
    fi
    
    # Find all AGENTS.md files
    local agents_files
    agents_files=$(find_agents_files "$target_dir")
    
    if [[ -z "$agents_files" ]]; then
        log_info "No AGENTS.md files found"
        exit 0
    fi
    
    # Check each file
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            ((files_checked++))
            if ! check_file "$file"; then
                ((files_suspicious++))
                exit_code=1
            fi
        fi
    done <<< "$agents_files"
    
    # Summary
    echo -e "\n${BOLD}${BLUE}"
    echo "========================================"
    echo "  Validation Summary"
    echo "========================================"
    echo -e "${NC}"
    
    echo "Files scanned: $files_checked"
    
    if [[ $files_suspicious -gt 0 ]]; then
        echo -e "${RED}Files with suspicious patterns: $files_suspicious${NC}"
        echo
        echo -e "${YELLOW}RECOMMENDATION:${NC}"
        echo "  Review the flagged files before running /init-deep"
        echo "  Suspicious patterns may indicate prompt injection attempts"
        echo "  that could compromise the AI agent's behavior."
    else
        echo -e "${GREEN}All files passed security checks${NC}"
    fi
    
    return $exit_code
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_agents_md "$@"
fi
