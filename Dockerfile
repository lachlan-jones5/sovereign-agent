# Dockerfile - Sovereign Agent
# Multi-stage build for the OpenCode-DCP Pipeline
#
# Usage:
#   docker build -t sovereign-agent .
#   docker run -it -v $(pwd):/workspace -v ~/.config/opencode:/root/.config/opencode sovereign-agent
#
# With config.json:
#   docker run -it \
#     -v $(pwd):/workspace \
#     -v /path/to/config.json:/app/config.json:ro \
#     sovereign-agent --config /app/config.json

# =============================================================================
# Stage 1: Build OpenCode and oh-my-opencode (Bun/TypeScript)
# =============================================================================
FROM oven/bun:1.1-debian AS builder

# Install git for workspaces
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy OpenCode source and build
COPY vendor/opencode/ ./opencode/
WORKDIR /build/opencode
RUN bun install --frozen-lockfile || bun install
RUN bun run --cwd packages/opencode build

# Copy oh-my-opencode source and install dependencies
WORKDIR /build
COPY vendor/oh-my-opencode/ ./oh-my-opencode/
WORKDIR /build/oh-my-opencode
RUN bun install --frozen-lockfile || bun install

# =============================================================================
# Stage 2: Runtime Image
# =============================================================================
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Bun runtime
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Create directories
RUN mkdir -p /app /root/.config/opencode /root/.local/bin

# Copy built OpenCode
COPY --from=builder /build/opencode/packages/opencode/bin/opencode /root/.local/bin/opencode
COPY --from=builder /build/opencode/packages/opencode/dist/ /app/opencode-dist/

# Copy oh-my-opencode with node_modules
COPY --from=builder /build/oh-my-opencode /app/oh-my-opencode

# Copy installer and templates
COPY install.sh /app/
COPY lib/ /app/lib/
COPY templates/ /app/templates/
COPY config.json.example /app/

# Make scripts executable
RUN chmod +x /app/install.sh /app/lib/*.sh /root/.local/bin/opencode 2>/dev/null || true

# Set PATH
ENV PATH="/root/.local/bin:/root/.bun/bin:$PATH"

# Working directory for user projects
WORKDIR /workspace

# Create entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}Sovereign Agent Container${NC}"
echo

# Check if config exists
CONFIG_PATH="${CONFIG_PATH:-/root/.config/opencode/config.json}"

if [[ ! -f "$CONFIG_PATH" ]] && [[ ! -f "/app/config.json" ]]; then
    echo -e "${YELLOW}No config.json found.${NC}"
    echo
    echo "Options:"
    echo "  1. Mount your config: -v /path/to/config.json:/root/.config/opencode/config.json"
    echo "  2. Run installer:     /app/install.sh --config /app/config.json"
    echo
    echo "Example config.json:"
    cat /app/config.json.example
    echo
    echo -e "${YELLOW}Starting shell for manual setup...${NC}"
    exec /bin/bash
fi

# If config exists, check if we need to run installer
if [[ ! -f "/root/.config/opencode/opencode.json" ]]; then
    echo -e "${GREEN}Running installer...${NC}"
    
    # Determine config location
    if [[ -f "/app/config.json" ]]; then
        /app/install.sh --config /app/config.json --skip-deps
    elif [[ -f "$CONFIG_PATH" ]]; then
        /app/install.sh --config "$CONFIG_PATH" --skip-deps
    fi
fi

# Handle arguments
if [[ $# -eq 0 ]]; then
    # No args - start OpenCode
    echo -e "${GREEN}Starting OpenCode...${NC}"
    exec opencode
elif [[ "$1" == "bash" ]] || [[ "$1" == "sh" ]]; then
    # Shell access
    exec /bin/bash
elif [[ "$1" == "--install" ]]; then
    # Manual install
    shift
    exec /app/install.sh "$@"
else
    # Pass to OpenCode
    exec opencode "$@"
fi
EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
