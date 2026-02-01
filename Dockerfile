# OpenClaw Docker Container
# Base: node:22-bookworm (matches OpenClaw's development environment)
FROM node:22-bookworm

# Install init system and debugging tools
# dumb-init: Handles PID 1 signal forwarding to prevent zombie processes
# curl, procps, git: Debugging and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init \
    curl \
    procps \
    git \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone OpenClaw from GitHub (always latest main branch)
RUN git clone https://github.com/openclaw/openclaw.git . \
  && npm install

# Copy entrypoint and health check scripts
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY healthcheck.js /healthcheck.js

# Fix ownership of application files
RUN chown -R node:node /app

# Create persistent data directory with correct ownership
RUN mkdir -p /home/node/.openclaw && chown -R node:node /home/node/.openclaw

# Expose OpenClaw Control UI port
EXPOSE 18789

# Define persistent volume for configuration and data
VOLUME ["/home/node/.openclaw"]

# Switch to non-root user for security
USER node

# Health check: Verify OpenClaw Control UI is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node /healthcheck.js

# Use dumb-init as PID 1 to handle signals properly
ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]

# Start OpenClaw gateway (Control UI server)
CMD ["npx", "openclaw", "gateway", "--port", "18789"]
