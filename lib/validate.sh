#!/usr/bin/env bash
# validate.sh - Validate user's config.json

# Only set -e when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate that config.json exists and has required fields
validate_config() {
    local config_file="$1"

    if [[ -z "$config_file" ]]; then
        log_error "No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        echo
        echo "Please create a config.json file. You can copy the example:"
        echo "  cp config.json.example config.json"
        echo "  # Then edit config.json with your API keys"
        return 1
    fi

    log_info "Validating config file: $config_file"

    # Check if file is valid JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Config file is not valid JSON"
        return 1
    fi

    local errors=0

    # Required fields
    local required_fields=(
        ".openrouter_api_key"
        ".site_url"
        ".site_name"
        ".models.orchestrator"
        ".models.planner"
        ".models.librarian"
        ".models.fallback"
    )

    for field in "${required_fields[@]}"; do
        local value
        value=$(jq -r "$field // empty" "$config_file")
        
        if [[ -z "$value" ]]; then
            log_error "Missing required field: $field"
            ((errors++))
        fi
    done

    # Validate API key format
    local api_key
    api_key=$(jq -r '.openrouter_api_key // empty' "$config_file")
    
    if [[ -n "$api_key" && "$api_key" == "sk-or-v1-your-api-key-here" ]]; then
        log_error "Please replace the placeholder API key with your actual OpenRouter API key"
        ((errors++))
    fi

    if [[ -n "$api_key" && ! "$api_key" =~ ^sk-or- ]]; then
        log_warn "API key doesn't start with 'sk-or-' - are you sure this is an OpenRouter key?"
    fi

    # Validate optional preferences (set defaults if missing)
    local ultrawork_max
    ultrawork_max=$(jq -r '.preferences.ultrawork_max_iterations // empty' "$config_file")
    if [[ -z "$ultrawork_max" ]]; then
        log_warn "preferences.ultrawork_max_iterations not set, will use default: 50"
    fi

    local turn_protection
    turn_protection=$(jq -r '.preferences.dcp_turn_protection // empty' "$config_file")
    if [[ -z "$turn_protection" ]]; then
        log_warn "preferences.dcp_turn_protection not set, will use default: 2"
    fi

    local error_retention
    error_retention=$(jq -r '.preferences.dcp_error_retention_turns // empty' "$config_file")
    if [[ -z "$error_retention" ]]; then
        log_warn "preferences.dcp_error_retention_turns not set, will use default: 4"
    fi

    local nudge_freq
    nudge_freq=$(jq -r '.preferences.dcp_nudge_frequency // empty' "$config_file")
    if [[ -z "$nudge_freq" ]]; then
        log_warn "preferences.dcp_nudge_frequency not set, will use default: 10"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed with $errors error(s)"
        return 1
    fi

    log_info "Config validation passed"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_config "$1"
fi
