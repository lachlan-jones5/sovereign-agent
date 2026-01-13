#!/usr/bin/env bash
# oscillation-detector.sh - Detect flip-flopping states in Ultrawork loops
#
# Implements oscillation detection from the red team analysis:
# - Monitors file changes during agent sessions
# - Detects when files are flip-flopping between states
# - Alerts when the same test output appears consecutively
# - Helps prevent wasted tokens on infinite loops
#
# Usage:
#   ./lib/oscillation-detector.sh watch /path/to/project
#   ./lib/oscillation-detector.sh analyze /path/to/project
#   ./lib/oscillation-detector.sh hook   # Install as git hook

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
OSCILLATION_THRESHOLD=3    # Number of identical states before alerting
HASH_HISTORY_SIZE=10       # How many states to remember per file
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sovereign-agent"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize state directory
init_state() {
    mkdir -p "$STATE_DIR"
}

# Compute hash of file content
hash_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sha256sum "$file" 2>/dev/null | awk '{print $1}'
    else
        echo "DELETED"
    fi
}

# Get state file for tracking a project
get_state_file() {
    local project_path="$1"
    local project_hash
    project_hash=$(echo "$project_path" | sha256sum | awk '{print $1}' | cut -c1-16)
    echo "$STATE_DIR/oscillation-$project_hash.json"
}

# Record file state
record_state() {
    local project_path="$1"
    local file="$2"
    local hash="$3"
    local timestamp
    timestamp=$(date +%s)
    
    local state_file
    state_file=$(get_state_file "$project_path")
    
    # Initialize if needed
    if [[ ! -f "$state_file" ]]; then
        echo '{"files":{}}' > "$state_file"
    fi
    
    # Add hash to file's history (using jq)
    local rel_path
    rel_path=$(realpath --relative-to="$project_path" "$file" 2>/dev/null || echo "$file")
    
    # Escape the path for jq
    local escaped_path
    escaped_path=$(printf '%s' "$rel_path" | jq -Rs '.')
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg path "$rel_path" --arg hash "$hash" --arg ts "$timestamp" '
        .files[$path] = ((.files[$path] // []) + [{hash: $hash, timestamp: ($ts | tonumber)}])[-10:]
    ' "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
}

# Check for oscillation in a file's history
check_oscillation() {
    local project_path="$1"
    local file="$2"
    
    local state_file
    state_file=$(get_state_file "$project_path")
    
    if [[ ! -f "$state_file" ]]; then
        return 0
    fi
    
    local rel_path
    rel_path=$(realpath --relative-to="$project_path" "$file" 2>/dev/null || echo "$file")
    
    # Get hash history
    local history
    history=$(jq -r --arg path "$rel_path" '.files[$path] // [] | .[].hash' "$state_file")
    
    if [[ -z "$history" ]]; then
        return 0
    fi
    
    # Check for patterns:
    # 1. Same hash appearing multiple times (file being reverted)
    # 2. Alternating between two hashes (flip-flopping)
    
    local unique_hashes
    unique_hashes=$(echo "$history" | sort | uniq)
    local total_count
    total_count=$(echo "$history" | wc -l)
    local unique_count
    unique_count=$(echo "$unique_hashes" | wc -l)
    
    # If we have many entries but few unique hashes, likely oscillating
    if [[ $total_count -ge 5 && $unique_count -le 2 ]]; then
        return 1  # Oscillation detected
    fi
    
    # Check for same hash appearing consecutively
    local prev_hash=""
    local consecutive=0
    local max_consecutive=0
    
    while IFS= read -r hash; do
        if [[ "$hash" == "$prev_hash" ]]; then
            ((consecutive++))
            if [[ $consecutive -gt $max_consecutive ]]; then
                max_consecutive=$consecutive
            fi
        else
            consecutive=1
        fi
        prev_hash="$hash"
    done <<< "$history"
    
    # Check for A-B-A-B pattern
    local pattern_detected=false
    local hashes_array=()
    while IFS= read -r h; do
        hashes_array+=("$h")
    done <<< "$history"
    
    if [[ ${#hashes_array[@]} -ge 4 ]]; then
        local len=${#hashes_array[@]}
        for ((i=0; i<len-3; i++)); do
            if [[ "${hashes_array[$i]}" == "${hashes_array[$((i+2))]}" && \
                  "${hashes_array[$((i+1))]}" == "${hashes_array[$((i+3))]}" && \
                  "${hashes_array[$i]}" != "${hashes_array[$((i+1))]}" ]]; then
                pattern_detected=true
                break
            fi
        done
    fi
    
    if [[ "$pattern_detected" == true ]]; then
        return 1  # Oscillation detected
    fi
    
    return 0
}

# Watch a project directory for changes
watch_project() {
    local project_path="${1:-.}"
    project_path=$(realpath "$project_path")
    
    init_state
    
    echo -e "${BOLD}${BLUE}=== Oscillation Detector ===${NC}"
    echo "Watching: $project_path"
    echo "Press Ctrl+C to stop"
    echo
    
    # Check if inotifywait is available
    if ! command -v inotifywait &> /dev/null; then
        log_error "inotifywait not found. Install inotify-tools:"
        echo "  sudo apt install inotify-tools  # Debian/Ubuntu"
        echo "  sudo yum install inotify-tools  # RHEL/CentOS"
        exit 1
    fi
    
    # Watch for file modifications
    inotifywait -m -r -e modify -e create -e delete \
        --exclude '\.(git|node_modules|__pycache__|\.pytest_cache)' \
        "$project_path" 2>/dev/null | while read -r dir event file; do
        
        local full_path="${dir}${file}"
        
        # Skip hidden files and common noise
        if [[ "$file" == .* || "$file" == *~ || "$file" == *.swp ]]; then
            continue
        fi
        
        local hash
        hash=$(hash_file "$full_path")
        
        # Record the state
        record_state "$project_path" "$full_path" "$hash"
        
        # Check for oscillation
        if ! check_oscillation "$project_path" "$full_path"; then
            echo
            log_warn "OSCILLATION DETECTED in: $file"
            echo "  File appears to be flip-flopping between states!"
            echo "  This may indicate an infinite loop in the agent."
            echo
            echo -e "  ${YELLOW}Recommended actions:${NC}"
            echo "    1. Stop the current Ultrawork session"
            echo "    2. Review the agent's reasoning"
            echo "    3. Manually verify the expected behavior"
            echo
            
            # Optionally could send a notification or trigger a hook here
        fi
    done
}

# Analyze a project for oscillation patterns
analyze_project() {
    local project_path="${1:-.}"
    project_path=$(realpath "$project_path")
    
    init_state
    
    echo -e "${BOLD}${BLUE}=== Oscillation Analysis ===${NC}"
    echo "Project: $project_path"
    echo
    
    local state_file
    state_file=$(get_state_file "$project_path")
    
    if [[ ! -f "$state_file" ]]; then
        log_info "No tracking data found for this project."
        echo "Run 'watch' command first to collect data."
        return
    fi
    
    # Analyze each tracked file
    local oscillating_files=()
    local stable_files=()
    
    local files
    files=$(jq -r '.files | keys[]' "$state_file")
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        local full_path="$project_path/$file"
        if ! check_oscillation "$project_path" "$full_path"; then
            oscillating_files+=("$file")
        else
            stable_files+=("$file")
        fi
    done <<< "$files"
    
    if [[ ${#oscillating_files[@]} -gt 0 ]]; then
        echo -e "${RED}Files with oscillation patterns:${NC}"
        for f in "${oscillating_files[@]}"; do
            echo "  - $f"
            # Show hash history
            local hashes
            hashes=$(jq -r --arg path "$f" '.files[$path][-5:] | .[].hash[:8]' "$state_file" | tr '\n' ' ')
            echo "    Recent states: $hashes"
        done
        echo
    fi
    
    if [[ ${#stable_files[@]} -gt 0 ]]; then
        echo -e "${GREEN}Stable files:${NC}"
        for f in "${stable_files[@]}"; do
            echo "  - $f"
        done
        echo
    fi
    
    echo -e "${BOLD}Summary:${NC}"
    echo "  Total tracked: $((${#oscillating_files[@]} + ${#stable_files[@]}))"
    echo "  Oscillating:   ${#oscillating_files[@]}"
    echo "  Stable:        ${#stable_files[@]}"
    
    if [[ ${#oscillating_files[@]} -gt 0 ]]; then
        echo
        log_warn "Oscillation detected! Review the files above."
    fi
}

# Record test output for comparison
record_test_output() {
    local project_path="${1:-.}"
    local test_output="$2"
    
    project_path=$(realpath "$project_path")
    init_state
    
    local state_file
    state_file=$(get_state_file "$project_path")
    
    if [[ ! -f "$state_file" ]]; then
        echo '{"files":{}, "test_outputs":[]}' > "$state_file"
    fi
    
    local output_hash
    output_hash=$(echo "$test_output" | sha256sum | awk '{print $1}')
    local timestamp
    timestamp=$(date +%s)
    
    # Add to test output history
    local temp_file
    temp_file=$(mktemp)
    jq --arg hash "$output_hash" --arg ts "$timestamp" '
        .test_outputs = ((.test_outputs // []) + [{hash: $hash, timestamp: ($ts | tonumber)}])[-20:]
    ' "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
    
    # Check for repeated test output
    local recent_hashes
    recent_hashes=$(jq -r '.test_outputs[-5:] | .[].hash' "$state_file")
    local unique_recent
    unique_recent=$(echo "$recent_hashes" | sort | uniq | wc -l)
    
    if [[ $(echo "$recent_hashes" | wc -l) -ge 3 && $unique_recent -eq 1 ]]; then
        log_warn "Test output is identical across last 3+ runs!"
        echo "  The agent may be stuck in a loop."
        return 1
    fi
    
    return 0
}

# Clear tracking data
clear_state() {
    local project_path="${1:-.}"
    project_path=$(realpath "$project_path")
    
    local state_file
    state_file=$(get_state_file "$project_path")
    
    if [[ -f "$state_file" ]]; then
        rm "$state_file"
        log_info "Cleared oscillation tracking for: $project_path"
    else
        log_info "No tracking data found for: $project_path"
    fi
}

# Print usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  watch <path>      Watch directory for file changes and detect oscillation"
    echo "  analyze <path>    Analyze existing tracking data for oscillation patterns"
    echo "  record <path>     Record test output (reads from stdin)"
    echo "  clear <path>      Clear tracking data for a project"
    echo
    echo "Options:"
    echo "  --threshold N     Number of repetitions before alerting (default: 3)"
    echo
    echo "Environment:"
    echo "  OSCILLATION_THRESHOLD   Override detection threshold"
    echo
    echo "Examples:"
    echo "  $0 watch ./my-project"
    echo "  npm test 2>&1 | $0 record ./my-project"
    echo "  $0 analyze ./my-project"
}

# Main
case "${1:-}" in
    watch)
        watch_project "${2:-.}"
        ;;
    analyze)
        analyze_project "${2:-.}"
        ;;
    record)
        record_test_output "${2:-.}" "$(cat)"
        ;;
    clear)
        clear_state "${2:-.}"
        ;;
    -h|--help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
