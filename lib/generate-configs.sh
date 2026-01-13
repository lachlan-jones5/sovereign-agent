#!/usr/bin/env bash
# generate-configs.sh - Generate OpenCode config files from templates

# Only set -e when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_DIR/templates"

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

# Extract values from config.json
# Note: handles boolean false correctly (jq's // operator treats false as falsy)
get_config_value() {
    local config_file="$1"
    local jq_path="$2"
    local default="$3"
    
    local value
    # Use if-then-else to properly handle false/null/missing values
    value=$(jq -r "if $jq_path == null then \"\" elif $jq_path == false then \"false\" else $jq_path end" "$config_file")
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Generate a config file from a template
generate_from_template() {
    local template_file="$1"
    local output_file="$2"
    local config_file="$3"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi

    # Read template
    local content
    content=$(cat "$template_file")

    # Extract config values
    local openrouter_api_key
    openrouter_api_key=$(get_config_value "$config_file" '.openrouter_api_key' '')
    
    local site_url
    site_url=$(get_config_value "$config_file" '.site_url' 'https://localhost')
    
    local site_name
    site_name=$(get_config_value "$config_file" '.site_name' 'SovereignAgent')
    
    local orchestrator_model
    orchestrator_model=$(get_config_value "$config_file" '.models.orchestrator' 'deepseek/deepseek-v3')
    
    local planner_model
    planner_model=$(get_config_value "$config_file" '.models.planner' 'anthropic/claude-opus-4.5')
    
    local librarian_model
    librarian_model=$(get_config_value "$config_file" '.models.librarian' 'google/gemini-3-flash')
    
    local fallback_model
    fallback_model=$(get_config_value "$config_file" '.models.fallback' 'meta-llama/llama-3.3-70b-instruct')
    
    local ultrawork_max
    ultrawork_max=$(get_config_value "$config_file" '.preferences.ultrawork_max_iterations' '50')
    
    local dcp_turn_protection
    dcp_turn_protection=$(get_config_value "$config_file" '.preferences.dcp_turn_protection' '2')
    
    local dcp_error_retention
    dcp_error_retention=$(get_config_value "$config_file" '.preferences.dcp_error_retention_turns' '4')
    
    local dcp_nudge_frequency
    dcp_nudge_frequency=$(get_config_value "$config_file" '.preferences.dcp_nudge_frequency' '10')

    # Security settings
    local provider_whitelist
    provider_whitelist=$(jq -c '.security.provider_whitelist // ["DeepInfra", "Fireworks", "Together"]' "$config_file")
    
    local orchestrator_max_tokens
    orchestrator_max_tokens=$(get_config_value "$config_file" '.security.max_tokens.orchestrator' '32000')
    
    local planner_max_tokens
    planner_max_tokens=$(get_config_value "$config_file" '.security.max_tokens.planner' '16000')
    
    local librarian_max_tokens
    librarian_max_tokens=$(get_config_value "$config_file" '.security.max_tokens.librarian' '64000')

    # Plugin version pinning
    local pin_versions
    pin_versions=$(get_config_value "$config_file" '.plugins.pin_versions' 'true')
    
    local dcp_version
    if [[ "$pin_versions" == "true" ]]; then
        dcp_version=$(get_config_value "$config_file" '.plugins.opencode_dcp_version' '0.5.0')
    else
        dcp_version="latest"
    fi
    
    local oh_my_opencode_version
    if [[ "$pin_versions" == "true" ]]; then
        oh_my_opencode_version=$(get_config_value "$config_file" '.plugins.oh_my_opencode_version' '1.0.0')
    else
        oh_my_opencode_version="latest"
    fi

    # Relay configuration
    local relay_enabled
    relay_enabled=$(get_config_value "$config_file" '.relay.enabled' 'false')
    
    local relay_mode
    relay_mode=$(get_config_value "$config_file" '.relay.mode' 'server')
    
    local relay_port
    relay_port=$(get_config_value "$config_file" '.relay.port' '8080')
    
    local relay_base_url
    if [[ "$relay_enabled" == "true" && "$relay_mode" == "client" ]]; then
        # Client mode: point at local relay tunnel
        relay_base_url="http://localhost:${relay_port}"
    else
        # Server mode or disabled: use OpenRouter directly
        relay_base_url="https://openrouter.ai"
    fi

    # Bash tool permissions (granular control)
    local bash_permission_mode
    bash_permission_mode=$(get_config_value "$config_file" '.tool_permissions.bash.mode' 'blocklist')
    
    local bash_allowed_commands
    bash_allowed_commands=$(jq -c '.tool_permissions.bash.allowed_commands // []' "$config_file")
    
    local bash_blocked_commands
    bash_blocked_commands=$(jq -c '.tool_permissions.bash.blocked_commands // ["rm -rf /", "mkfs", "dd", ":(){ :|:& };:"]' "$config_file")
    
    local bash_blocked_patterns
    bash_blocked_patterns=$(jq -c '.tool_permissions.bash.blocked_patterns // []' "$config_file")
    
    # Escape backslashes for bash variable substitution
    # jq output has proper JSON escaping, but bash substitution eats backslashes
    bash_blocked_patterns="${bash_blocked_patterns//\\/\\\\}"

    # Replace placeholders
    content="${content//\{\{OPENROUTER_API_KEY\}\}/$openrouter_api_key}"
    content="${content//\{\{SITE_URL\}\}/$site_url}"
    content="${content//\{\{SITE_NAME\}\}/$site_name}"
    content="${content//\{\{ORCHESTRATOR_MODEL\}\}/$orchestrator_model}"
    content="${content//\{\{PLANNER_MODEL\}\}/$planner_model}"
    content="${content//\{\{LIBRARIAN_MODEL\}\}/$librarian_model}"
    content="${content//\{\{FALLBACK_MODEL\}\}/$fallback_model}"
    content="${content//\{\{ULTRAWORK_MAX_ITERATIONS\}\}/$ultrawork_max}"
    content="${content//\{\{DCP_TURN_PROTECTION\}\}/$dcp_turn_protection}"
    content="${content//\{\{DCP_ERROR_RETENTION_TURNS\}\}/$dcp_error_retention}"
    content="${content//\{\{DCP_NUDGE_FREQUENCY\}\}/$dcp_nudge_frequency}"
    content="${content//\{\{PROVIDER_WHITELIST\}\}/$provider_whitelist}"
    content="${content//\{\{ORCHESTRATOR_MAX_TOKENS\}\}/$orchestrator_max_tokens}"
    content="${content//\{\{PLANNER_MAX_TOKENS\}\}/$planner_max_tokens}"
    content="${content//\{\{LIBRARIAN_MAX_TOKENS\}\}/$librarian_max_tokens}"
    content="${content//\{\{DCP_VERSION\}\}/$dcp_version}"
    content="${content//\{\{OH_MY_OPENCODE_VERSION\}\}/$oh_my_opencode_version}"
    content="${content//\{\{BASH_PERMISSION_MODE\}\}/$bash_permission_mode}"
    content="${content//\{\{BASH_ALLOWED_COMMANDS\}\}/$bash_allowed_commands}"
    content="${content//\{\{BASH_BLOCKED_COMMANDS\}\}/$bash_blocked_commands}"
    content="${content//\{\{BASH_BLOCKED_PATTERNS\}\}/$bash_blocked_patterns}"
    content="${content//\{\{RELAY_BASE_URL\}\}/$relay_base_url}"

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"

    # Write output file
    echo "$content" > "$output_file"
    log_info "Generated: $output_file"
}

# Generate all config files
generate_all_configs() {
    local config_file="$1"
    local opencode_config_dir="${2:-$HOME/.config/opencode}"

    if [[ -z "$config_file" ]]; then
        log_error "No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    log_info "Generating config files..."
    log_info "OpenCode config directory: $opencode_config_dir"
    echo

    # Create config directory
    mkdir -p "$opencode_config_dir"

    # Backup existing configs
    if [[ -f "$opencode_config_dir/opencode.json" ]]; then
        local backup_file="$opencode_config_dir/opencode.json.backup.$(date +%Y%m%d%H%M%S)"
        cp "$opencode_config_dir/opencode.json" "$backup_file"
        log_warn "Backed up existing opencode.json to $backup_file"
    fi

    if [[ -f "$opencode_config_dir/dcp.jsonc" ]]; then
        local backup_file="$opencode_config_dir/dcp.jsonc.backup.$(date +%Y%m%d%H%M%S)"
        cp "$opencode_config_dir/dcp.jsonc" "$backup_file"
        log_warn "Backed up existing dcp.jsonc to $backup_file"
    fi

    if [[ -f "$opencode_config_dir/oh-my-opencode.json" ]]; then
        local backup_file="$opencode_config_dir/oh-my-opencode.json.backup.$(date +%Y%m%d%H%M%S)"
        cp "$opencode_config_dir/oh-my-opencode.json" "$backup_file"
        log_warn "Backed up existing oh-my-opencode.json to $backup_file"
    fi

    # Generate configs
    generate_from_template \
        "$TEMPLATES_DIR/opencode.json.tmpl" \
        "$opencode_config_dir/opencode.json" \
        "$config_file"

    generate_from_template \
        "$TEMPLATES_DIR/dcp.jsonc.tmpl" \
        "$opencode_config_dir/dcp.jsonc" \
        "$config_file"

    generate_from_template \
        "$TEMPLATES_DIR/oh-my-opencode.json.tmpl" \
        "$opencode_config_dir/oh-my-opencode.json" \
        "$config_file"

    # Copy .opencodeignore template to user's home directory
    if [[ -f "$TEMPLATES_DIR/opencodeignore.tmpl" ]]; then
        local opencodeignore_dest="$HOME/.opencodeignore"
        if [[ -f "$opencodeignore_dest" ]]; then
            local backup_file="$opencodeignore_dest.backup.$(date +%Y%m%d%H%M%S)"
            cp "$opencodeignore_dest" "$backup_file"
            log_warn "Backed up existing .opencodeignore to $backup_file"
        fi
        cp "$TEMPLATES_DIR/opencodeignore.tmpl" "$opencodeignore_dest"
        log_info "Generated: $opencodeignore_dest"
    fi

    echo
    log_info "All config files generated successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_all_configs "$1" "$2"
fi
