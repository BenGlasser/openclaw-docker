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

# Copy entrypoint and health check scripts
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY healthcheck.js /healthcheck.js

# Symlink the locally built CLI into PATH
RUN ln -s /app/openclaw.mjs /usr/local/bin/openclaw

# Container image version
ENV OPENCLAW_DOCKER_VERSION="0.3.0"

# Expose OpenClaw Control UI port
EXPOSE 18789
EXPOSE 3001
EXPOSE 3334

# Define persistent volume for configuration and data
VOLUME ["/root/.openclaw"]

# Health check: Verify OpenClaw Control UI is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node /healthcheck.js

COPY --chmod=755 connect-qr.sh .
# Use dumb-init as PID 1 to handle signals properly
ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]

# Start OpenClaw gateway (Control UI server)
# --allow-unconfigured: Allows startup without initial configuration
# --bind lan: Listen on all interfaces (0.0.0.0) for Docker port mapping
CMD ["node", "openclaw.mjs", "gateway", "--port", "18789", "--bind", "lan", "--allow-unconfigured"]
