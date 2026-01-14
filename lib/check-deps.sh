#!/usr/bin/env bash
# check-deps.sh - Verify and install required dependencies

# Only set -e when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_DIR/vendor"

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

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install jq (required for JSON parsing)
check_jq() {
    if command_exists jq; then
        log_info "jq is already installed: $(jq --version)"
        return 0
    fi

    log_warn "jq is not installed. Attempting to install..."

    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command_exists yum; then
        sudo yum install -y jq
    elif command_exists dnf; then
        sudo dnf install -y jq
    elif command_exists brew; then
        brew install jq
    elif command_exists pacman; then
        sudo pacman -S --noconfirm jq
    else
        log_error "Could not install jq. Please install it manually."
        return 1
    fi

    log_info "jq installed successfully"
}

# Check and install curl
check_curl() {
    if command_exists curl; then
        log_info "curl is already installed"
        return 0
    fi

    log_warn "curl is not installed. Attempting to install..."

    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y curl
    elif command_exists yum; then
        sudo yum install -y curl
    elif command_exists dnf; then
        sudo dnf install -y curl
    elif command_exists brew; then
        brew install curl
    elif command_exists pacman; then
        sudo pacman -S --noconfirm curl
    else
        log_error "Could not install curl. Please install it manually."
        return 1
    fi

    log_info "curl installed successfully"
}

# Check and install Go (required to build OpenCode)
check_go() {
    if command_exists go; then
        log_info "Go is already installed: $(go version)"
        return 0
    fi

    log_warn "Go is not installed. Attempting to install..."

    local go_version="1.23.4"
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) log_error "Unsupported architecture: $arch"; return 1 ;;
    esac

    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    local go_tar="go${go_version}.${os}-${arch}.tar.gz"
    local go_url="https://go.dev/dl/${go_tar}"

    log_info "Downloading Go ${go_version}..."
    curl -fsSL "$go_url" -o "/tmp/${go_tar}"

    log_info "Installing Go to /usr/local/go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${go_tar}"
    rm "/tmp/${go_tar}"

    export PATH="/usr/local/go/bin:$PATH"

    if command_exists go; then
        log_info "Go installed successfully: $(go version)"
    else
        log_error "Go installation failed"
        return 1
    fi
}

# Check and install Bun
check_bun() {
    if command_exists bun; then
        log_info "Bun is already installed: $(bun --version)"
        # Ensure it's in rc file even if already installed
        ensure_path_in_rc "$HOME/.bun/bin"
        return 0
    fi

    log_warn "Bun is not installed. Installing..."
    curl -fsSL https://bun.sh/install | bash

    # Add to path for current session
    if [[ -d "$HOME/.bun/bin" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
        # Persist to shell rc
        ensure_path_in_rc "$HOME/.bun/bin"
    fi

    if command_exists bun; then
        log_info "Bun installed successfully"
    else
        log_warn "Bun installed but may require a new terminal session"
    fi
}

# Add a directory to PATH in shell rc file if not already present
# Usage: ensure_path_in_rc /path/to/dir
ensure_path_in_rc() {
    local target_dir="$1"
    local dir_name="${target_dir/#$HOME/\~}"  # For display: /home/user/.bun -> ~/.bun
    
    # Determine which shell rc file to use
    local rc_file=""
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
        rc_file="$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
        if [[ -f "$HOME/.bashrc" ]]; then
            rc_file="$HOME/.bashrc"
        else
            rc_file="$HOME/.profile"
        fi
    else
        rc_file="$HOME/.profile"
    fi
    
    # Check if already in PATH
    if [[ ":$PATH:" == *":$target_dir:"* ]]; then
        return 0
    fi
    
    # Check if already in rc file (match the directory name)
    local dir_basename
    dir_basename=$(basename "$target_dir")
    if [[ -f "$rc_file" ]] && grep -q "$dir_basename" "$rc_file"; then
        return 0
    fi
    
    # Add to rc file
    log_info "Adding $dir_name to PATH in $rc_file"
    echo "" >> "$rc_file"
    echo "# Added by sovereign-agent installer" >> "$rc_file"
    echo "export PATH=\"$target_dir:\$PATH\"" >> "$rc_file"
    
    # Also export for current session
    export PATH="$target_dir:$PATH"
}

# Add ~/.local/bin to PATH (convenience wrapper)
ensure_local_bin_in_path() {
    ensure_path_in_rc "$HOME/.local/bin"
}

# Build OpenCode from submodule
build_opencode() {
    local opencode_dir="$VENDOR_DIR/opencode"

    if [[ ! -d "$opencode_dir" ]]; then
        log_error "OpenCode submodule not found at $opencode_dir"
        log_error "Run: git submodule update --init --recursive"
        return 1
    fi

    # Verify submodule has content (not just empty directory)
    if [[ ! -f "$opencode_dir/go.mod" ]]; then
        log_error "OpenCode submodule appears empty at $opencode_dir"
        log_error "Run: git submodule update --init --recursive"
        return 1
    fi

    # Verify Go is available
    if ! command_exists go; then
        log_error "Go is required but not found in PATH"
        return 1
    fi

    log_info "Building OpenCode from source..."

    cd "$opencode_dir"

    # Check if already built
    if [[ -f "./opencode" ]]; then
        log_info "OpenCode binary already exists, rebuilding..."
    fi

    # Build with error handling
    if ! go build -o opencode ./cmd/opencode; then
        log_error "Failed to build OpenCode"
        cd "$PROJECT_DIR"
        return 1
    fi

    # Verify binary was created
    if [[ ! -f "./opencode" ]]; then
        log_error "Build succeeded but binary not found"
        cd "$PROJECT_DIR"
        return 1
    fi

    # Install to ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    if ! cp opencode "$HOME/.local/bin/opencode"; then
        log_error "Failed to copy opencode to ~/.local/bin"
        cd "$PROJECT_DIR"
        return 1
    fi
    chmod +x "$HOME/.local/bin/opencode"

    # Verify installation
    if [[ ! -x "$HOME/.local/bin/opencode" ]]; then
        log_error "opencode not found at ~/.local/bin/opencode after install"
        cd "$PROJECT_DIR"
        return 1
    fi

    log_info "OpenCode binary installed to ~/.local/bin/opencode"

    # Ensure ~/.local/bin is in PATH (persisted to shell rc)
    ensure_local_bin_in_path

    cd "$PROJECT_DIR"

    if command_exists opencode; then
        log_info "OpenCode built and installed successfully"
    else
        log_warn "OpenCode installed but you may need to restart your shell for PATH changes to take effect"
    fi
}

# Build and install oh-my-opencode from submodule
build_oh_my_opencode() {
    local omo_dir="$VENDOR_DIR/oh-my-opencode"

    if [[ ! -d "$omo_dir" ]]; then
        log_error "oh-my-opencode submodule not found at $omo_dir"
        log_error "Run: git submodule update --init --recursive"
        return 1
    fi

    log_info "Installing oh-my-opencode from source..."

    # Ensure bun is in path
    if [[ -d "$HOME/.bun/bin" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
    fi

    if ! command_exists bun; then
        log_error "Bun is required but not found in PATH"
        return 1
    fi

    cd "$omo_dir"

    # Install dependencies
    bun install

    # Run the install script with our options
    bun run install --no-tui --claude=no --chatgpt=no --gemini=yes

    cd "$PROJECT_DIR"

    log_info "oh-my-opencode installed successfully"
}

# Main check function
check_all_deps() {
    log_info "Checking dependencies..."
    echo

    if ! check_curl; then
        log_error "Failed to install curl"
        return 1
    fi
    echo

    if ! check_jq; then
        log_error "Failed to install jq"
        return 1
    fi
    echo

    if ! check_go; then
        log_error "Failed to install Go"
        return 1
    fi
    echo

    if ! check_bun; then
        log_error "Failed to install Bun"
        return 1
    fi
    echo

    if ! build_opencode; then
        log_error "Failed to build/install OpenCode"
        return 1
    fi
    echo

    if ! build_oh_my_opencode; then
        log_error "Failed to install oh-my-opencode"
        return 1
    fi
    echo

    log_info "All dependencies checked/installed successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_all_deps
fi
