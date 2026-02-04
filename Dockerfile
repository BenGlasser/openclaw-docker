# OpenClaw Docker Container
# Base: node:22-bookworm (matches OpenClaw's development environment)
FROM node:22-bookworm

# Install init system and debugging tools
# dumb-init: Handles PID 1 signal forwarding to prevent zombie processes
# gosu: Allows running commands as different UID without su/sudo issues
# curl, procps, git: Debugging and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init \
    gosu      \
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

# Fix ownership of application files
RUN chown -R node:node /app

# Create persistent data directory with correct ownership
RUN mkdir -p /home/node/.openclaw && chown -R node:node /home/node/.openclaw

# Create user-level npm global directory so openclaw installs without root
RUN mkdir -p /home/node/.npm-global && chown -R node:node /home/node/.npm-global

# Add user-level npm bin to PATH
ENV PATH="/home/node/.npm-global/bin:${PATH}"
ENV NPM_CONFIG_PREFIX="/home/node/.npm-global"

# Expose OpenClaw Control UI port
EXPOSE 18789

# Define persistent volume for configuration and data
VOLUME ["/home/node/.openclaw"]

# Health check: Verify OpenClaw Control UI is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node /healthcheck.js

# Use dumb-init as PID 1 to handle signals properly
ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]

# Start OpenClaw gateway (Control UI server)
# --allow-unconfigured: Allows startup without initial configuration
# --bind lan: Listen on all interfaces (0.0.0.0) for Docker port mapping
CMD ["npx", "openclaw", "gateway", "--port", "18789", "--bind", "lan", "--allow-unconfigured"]
