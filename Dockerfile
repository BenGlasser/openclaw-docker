# OpenClaw Docker Container
# Base: node:22-bookworm (matches OpenClaw's development environment)
FROM node:22-bookworm

# Install init system and debugging tools
# dumb-init: Handles PID 1 signal forwarding to prevent zombie processes
# curl, procps, git: Debugging and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init \
    curl      \
    procps    \
    git       \
    vim       \
    iproute2  \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone OpenClaw from GitHub (always latest main branch)
RUN git clone https://github.com/openclaw/openclaw.git .

# Enable pnpm (required by OpenClaw)
RUN corepack enable && corepack prepare pnpm@10.23.0 --activate

# Install dependencies and build
RUN pnpm install && pnpm build

# Build Control UI assets
RUN pnpm ui:build

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Container image version
ENV OPENCLAW_DOCKER_VERSION="0.4.0"

# Expose OpenClaw Control UI port
EXPOSE 18789

# Persistent data directory for node user
RUN mkdir -p /home/node/.openclaw /home/node/.openclaw/workspace && chown -R node:node /home/node/.openclaw
VOLUME ["/home/node/.openclaw"]

# Health check: Verify OpenClaw Control UI is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:18789/healthz || exit 1

# Switch to non-root node user (uid 1000) per official docs
USER node

# Use dumb-init as PID 1 to handle signals properly
ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]

# Start OpenClaw gateway (Control UI server)
# --allow-unconfigured: Allows startup without initial configuration
# --bind lan: Listen on all interfaces (0.0.0.0) for Docker port mapping
CMD ["node", "dist/index.js", "gateway", "--port", "18789", "--bind", "lan", "--allow-unconfigured"]
