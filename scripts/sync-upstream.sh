#!/usr/bin/env bash
# sync-upstream.sh - Sync forks with upstream repositories
# Usage: ./scripts/sync-upstream.sh [opencode|oh-my-opencode|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_DIR/vendor"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

sync_submodule() {
    local name="$1"
    local dir="$VENDOR_DIR/$name"
    local branch="${2:-main}"

    if [[ ! -d "$dir" ]]; then
        log_error "Submodule not found: $dir"
        return 1
    fi

    log_header "Syncing $name"

    cd "$dir"

    # Fetch upstream
    log_info "Fetching upstream..."
    git fetch upstream

    # Check current branch
    local current_branch
    current_branch=$(git branch --show-current)
    
    if [[ -z "$current_branch" ]]; then
        log_warn "Detached HEAD state. Checking out $branch..."
        git checkout "$branch"
        current_branch="$branch"
    fi

    # Check for local changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log_warn "You have uncommitted changes. Please commit or stash them first."
        git status --short
        return 1
    fi

    # Try to determine upstream branch
    local upstream_branch="main"
    if git rev-parse --verify upstream/master >/dev/null 2>&1; then
        upstream_branch="master"
    fi

    log_info "Rebasing $current_branch onto upstream/$upstream_branch..."
    
    if git rebase "upstream/$upstream_branch"; then
        log_info "Rebase successful!"
        
        echo
        log_info "To push changes to your fork, run:"
        echo "  cd $dir"
        echo "  git push origin $current_branch --force-with-lease"
    else
        log_error "Rebase failed. Resolve conflicts, then:"
        echo "  git rebase --continue"
        echo "Or abort with:"
        echo "  git rebase --abort"
        return 1
    fi

    cd "$PROJECT_DIR"
}

show_status() {
    log_header "Submodule Status"

    for submodule in opencode oh-my-opencode; do
        local dir="$VENDOR_DIR/$submodule"
        if [[ -d "$dir" ]]; then
            echo -e "${BLUE}$submodule:${NC}"
            cd "$dir"
            
            local branch
            branch=$(git branch --show-current 2>/dev/null || echo "detached")
            local origin_url
            origin_url=$(git remote get-url origin 2>/dev/null || echo "unknown")
            local upstream_url
            upstream_url=$(git remote get-url upstream 2>/dev/null || echo "not configured")
            local commit
            commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

            echo "  Branch:   $branch"
            echo "  Commit:   $commit"
            echo "  Origin:   $origin_url"
            echo "  Upstream: $upstream_url"
            
            # Check if behind upstream
            git fetch upstream --quiet 2>/dev/null || true
            local upstream_branch="main"
            if git rev-parse --verify upstream/master >/dev/null 2>&1; then
                upstream_branch="master"
            fi
            
            local behind
            behind=$(git rev-list --count HEAD..upstream/$upstream_branch 2>/dev/null || echo "?")
            local ahead
            ahead=$(git rev-list --count upstream/$upstream_branch..HEAD 2>/dev/null || echo "?")
            
            echo "  Status:   $ahead ahead, $behind behind upstream/$upstream_branch"
            echo
            
            cd "$PROJECT_DIR"
        fi
    done
}

usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  opencode        Sync opencode submodule with upstream"
    echo "  oh-my-opencode  Sync oh-my-opencode submodule with upstream"
    echo "  all             Sync all submodules"
    echo "  status          Show submodule status"
    echo
    echo "Options:"
    echo "  -b, --branch BRANCH  Branch to rebase (default: main)"
    echo "  -h, --help           Show this help"
    echo
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 all"
    echo "  $0 opencode --branch main"
}

# Parse arguments
COMMAND="${1:-status}"
BRANCH="main"

shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

case "$COMMAND" in
    opencode)
        sync_submodule opencode "$BRANCH"
        ;;
    oh-my-opencode)
        sync_submodule oh-my-opencode "$BRANCH"
        ;;
    all)
        sync_submodule opencode "$BRANCH"
        sync_submodule oh-my-opencode "$BRANCH"
        ;;
    status)
        show_status
        ;;
    -h|--help)
        usage
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
