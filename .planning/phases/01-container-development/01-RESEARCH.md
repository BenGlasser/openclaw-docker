# Phase 1: Container Development - Research

**Researched:** 2026-02-01
**Domain:** Docker containerization for Node.js applications
**Confidence:** HIGH

## Summary

Researched Docker best practices for containerizing Node.js applications, specifically for OpenClaw Control UI running on Unraid. The standard approach combines the official node:22-bookworm base image with proper signal handling (dumb-init), non-root execution, health checks, and persistent volume management.

OpenClaw Control UI requires Node.js >=22 and runs a WebSocket control plane on port 18789 by default. It stores all configuration, agents, and workspace data in ~/.openclaw/ directory. The application starts via `openclaw gateway` or `openclaw dashboard` commands, and includes an onboarding wizard that sets up the initial directory structure.

Key findings indicate that Node.js was not designed to run as PID 1, requiring an init system like dumb-init to properly handle signals (SIGTERM/SIGINT). The node:22-bookworm base image creates a 'node' user with UID/GID 1000, and best practices recommend running as this non-root user with proper file ownership. Health checks should use Node.js's built-in http module rather than curl to minimize image size and dependencies.

**Primary recommendation:** Use dumb-init as ENTRYPOINT with exec form commands, run as node user (UID 1000), implement HTTP health check against port 18789, and use entrypoint script to fix volume ownership at startup.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| node:22-bookworm | 22.x | Base image | Official Node.js image matching OpenClaw requirements, includes node user (UID 1000) |
| dumb-init | 1.2.5+ | Init system (PID 1) | Handles signals properly, lightweight (~25KB), prevents zombie processes |
| OpenClaw | latest main | Application | Cloned fresh from https://github.com/openclaw/openclaw during build |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| curl | Latest (apt) | Troubleshooting | User requested basic debugging tools, not for health checks |
| bash | 5.x (included) | Shell and scripts | Entrypoint scripts, user debugging |
| ps | procps pkg | Process inspection | Troubleshooting container issues |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| node:22-bookworm | node:22-alpine | Alpine smaller (~40MB vs ~300MB) but user requested Bookworm to match OpenClaw's existing Dockerfile |
| dumb-init | tini | Both work, dumb-init slightly smaller and well-documented for Node.js |
| dumb-init | Docker --init flag | Flag works but embedding in Dockerfile ensures consistency across all environments |
| HTTP health check | Process check (pidof/ps) | Process check doesn't verify application functionality, only that process exists |

**Installation:**
```bash
# In Dockerfile
apt-get update && apt-get install -y --no-install-recommends \
  dumb-init \
  curl \
  procps \
  && rm -rf /var/lib/apt/lists/*
```

## Architecture Patterns

### Recommended Project Structure
```
/
├── app/                          # OpenClaw source (git clone)
│   ├── package.json
│   ├── node_modules/
│   └── ...
├── entrypoint.sh                 # Initialization script
├── healthcheck.js                # Node.js health check script
└── /home/node/.openclaw/         # Persistent volume mount
    ├── openclaw.json             # Main config
    ├── workspace/                # Agent files, skills
    ├── agents/                   # Agent-specific data
    └── credentials/              # OAuth tokens
```

### Pattern 1: Init System as PID 1
**What:** Use dumb-init to run as PID 1, launching Node.js application as child process
**When to use:** Always for Node.js containers (Node.js not designed for PID 1)
**Example:**
```dockerfile
# Source: https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md
# Install dumb-init
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init

# Use dumb-init as entrypoint
ENTRYPOINT ["dumb-init", "--"]

# Node.js command as CMD (allows override)
CMD ["node", "index.js"]
```

### Pattern 2: Exec Form for Commands
**What:** Use JSON array syntax for ENTRYPOINT and CMD instead of shell form
**When to use:** Always - ensures proper signal handling
**Example:**
```dockerfile
# Source: https://oneuptime.com/blog/post/2026-01-16-docker-entrypoint-vs-cmd/view
# CORRECT - Exec form, signals reach Node.js
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]

# WRONG - Shell form, signals go to /bin/sh
ENTRYPOINT dumb-init -- node server.js
```

### Pattern 3: Entrypoint Script with exec
**What:** Shell script handles initialization, then replaces itself with main command using exec
**When to use:** When startup tasks needed (fix permissions, wait for deps, etc.)
**Example:**
```bash
#!/bin/bash
# Source: Community pattern verified across multiple sources

# Initialization tasks
chown -R node:node /home/node/.openclaw 2>/dev/null || true

# Replace shell with main command (critical for signals)
exec "$@"
```

### Pattern 4: Non-Root User Execution
**What:** Run application as node user (UID 1000) after fixing file ownership
**When to use:** Always for security (Principle of Least Privilege)
**Example:**
```dockerfile
# Source: https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md
# Fix ownership during build
COPY --chown=node:node . /app

# Switch to node user
USER node

# Or in entrypoint script (as root):
chown -R node:node /home/node/.openclaw
exec su-exec node "$@"
```

### Pattern 5: Node.js HTTP Health Check
**What:** Use Node.js built-in http module instead of curl for health checks
**When to use:** Always - avoids adding curl dependency to production images
**Example:**
```javascript
// Source: https://patrickleet.medium.com/effective-docker-healthchecks-for-node-js-b11577c3e595
const http = require('http');
const options = {
  hostname: 'localhost',
  port: process.env.PORT || 18789,
  path: '/health',
  timeout: 2000
};

http.request(options, (res) => {
  process.exit(res.statusCode === 200 ? 0 : 1);
}).on('error', () => {
  process.exit(1);
}).end();
```

### Anti-Patterns to Avoid
- **Running npm start in CMD:** npm doesn't forward signals to Node.js child process. Use `node server.js` directly.
- **Shell form commands:** Wraps command in /bin/sh -c which breaks signal handling
- **Copying node_modules from host:** Can cause platform incompatibilities, always install in container
- **Running as root:** Violates least privilege, creates security risks
- **Using curl in health checks:** Adds 2.5MB+ to image, unnecessary when Node.js can check itself
- **Missing --no-install-recommends:** Bloats Debian images with unnecessary packages

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PID 1 signal handling | Custom signal wrapper | dumb-init or tini | Handles SIGTERM forwarding, reaps zombies, thoroughly tested across millions of containers |
| Health check HTTP requests | Shell script with nc/telnet | Node.js http module | No extra dependencies, native to runtime, handles timeouts properly |
| File ownership fixing | Complex permission scripts | Simple chown in entrypoint | Built-in tool, handles edge cases (readonly mounts fail gracefully) |
| Process management | PM2, forever, nodemon | Direct node execution with init | Docker/K8s handle restarts better than in-container process managers |
| User switching | Custom su/sudo logic | Docker USER directive + su-exec | Battle-tested, minimal, proper signal passing with su-exec |

**Key insight:** Docker ecosystem has mature solutions for container patterns. Custom implementations miss edge cases (signal propagation, zombie reaping, permission errors) that standard tools handle.

## Common Pitfalls

### Pitfall 1: Volume Permission Mismatches
**What goes wrong:** Container starts but can't write to /home/node/.openclaw/ volume - permission denied errors, OpenClaw fails to save config
**Why it happens:** Host creates volume directory with different UID/GID than container's node user (1000:1000), especially on Unraid where nobody user is 99:100
**How to avoid:** Entrypoint script must fix ownership before starting application: `chown -R node:node /home/node/.openclaw`
**Warning signs:**
- Logs show EACCES or EPERM errors
- Config changes don't persist
- Fresh installs work but restarted containers fail

### Pitfall 2: Node.js Not Receiving SIGTERM
**What goes wrong:** `docker stop` takes 10+ seconds, container force-killed with SIGKILL, no graceful shutdown
**Why it happens:** Node.js runs as PID 1 without init system, or shell form commands wrap Node.js in /bin/sh
**How to avoid:** Use dumb-init as ENTRYPOINT and exec form for all commands
**Warning signs:**
- Container stop always times out (default 10s)
- Application logs don't show shutdown messages
- `docker stop` followed by `docker ps` shows container still running

### Pitfall 3: Health Check Starts Too Early
**What goes wrong:** Container marked unhealthy during startup, orchestrator restarts container repeatedly
**Why it happens:** OpenClaw needs time to clone repo, npm install, start server - health check runs before app ready
**How to avoid:** Set HEALTHCHECK --start-period=60s for git clone + npm install time
**Warning signs:**
- Container status cycling: starting -> healthy -> unhealthy -> starting
- Logs show health check failures followed by immediate success
- Works after several restarts

### Pitfall 4: Hardcoded Paths Break on Different Hosts
**What goes wrong:** Dockerfile has `/mnt/user/appdata/openclaw` hardcoded, fails on non-Unraid systems
**Why it happens:** Confusing host paths (Unraid-specific) with container paths (must be portable)
**How to avoid:** Container always uses `/home/node/.openclaw`, host path specified in docker run -v flag
**Warning signs:**
- Dockerfile references /mnt/user/ paths
- Container fails on Docker Desktop, works only on Unraid
- Volume mounts create wrong directory structure

### Pitfall 5: NPM Start Hides Real Process
**What goes wrong:** `ps aux` shows npm as PID 1, Node.js buried as child, signals don't reach app
**Why it happens:** CMD ["npm", "start"] makes npm the main process, npm doesn't forward signals
**How to avoid:** Use CMD ["node", "server.js"] or CMD ["openclaw", "gateway"] directly
**Warning signs:**
- Container takes full 10s to stop
- npm shows as PID 1 in `docker exec <container> ps aux`
- Application doesn't respond to Ctrl+C during docker run -it

### Pitfall 6: Missing .dockerignore Bloats Context
**What goes wrong:** `docker build` slow, uploads .git/ directory, node_modules from host
**Why it happens:** Without .dockerignore, entire directory sent to Docker daemon
**How to avoid:** Create .dockerignore with node_modules, .git, .env, .planning, etc.
**Warning signs:**
- "Sending build context" shows 500MB+ on first line of docker build
- Build takes minutes just to start
- Host's node_modules conflict with container's

### Pitfall 7: Secrets in Environment Variables
**What goes wrong:** API keys visible in `docker inspect`, image metadata, logs
**Why it happens:** ENV or ARG used for secrets, both persist in image layers
**How to avoid:** Use Docker secrets, volume mount credentials file, or runtime-only env vars (docker run -e)
**Warning signs:**
- Dockerfile has ENV ANTHROPIC_KEY=sk-...
- `docker history` shows secrets in plain text
- Credentials appear in docker inspect output

## Code Examples

Verified patterns from official sources:

### Complete Dockerfile Pattern
```dockerfile
# Source: Synthesized from https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md
# and https://www.docker.com/blog/9-tips-for-containerizing-your-node-js-application/

FROM node:22-bookworm

# Install init system and tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    dumb-init \
    curl \
    procps \
    git \
  && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Clone OpenClaw (always latest main)
RUN git clone https://github.com/openclaw/openclaw.git . \
  && npm install --omit=dev

# Copy entrypoint and health check scripts
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY healthcheck.js /healthcheck.js

# Fix ownership
RUN chown -R node:node /app

# Expose port
EXPOSE 18789

# Volume for persistent data
VOLUME ["/home/node/.openclaw"]

# Switch to non-root user
USER node

# Health check using Node.js
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node /healthcheck.js

# Use dumb-init to handle signals
ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]

# Default command (can be overridden)
CMD ["node", "path/to/openclaw/gateway.js", "--port", "18789"]
```

### Entrypoint Script Pattern
```bash
#!/bin/bash
# Source: Community pattern from multiple sources

set -e

# Fix ownership of persistent volume
if [ -d /home/node/.openclaw ]; then
  # Run as root to fix permissions, ignore errors if already correct
  chown -R node:node /home/node/.openclaw 2>/dev/null || true
fi

# Create directory if doesn't exist
mkdir -p /home/node/.openclaw

# Execute main command (replaces this shell with node process)
# Critical: exec ensures signals reach node, not bash
exec "$@"
```

### Health Check Script
```javascript
// Source: https://patrickleet.medium.com/effective-docker-healthchecks-for-node-js-b11577c3e595
const http = require('http');

const options = {
  hostname: 'localhost',
  port: process.env.OPENCLAW_PORT || 18789,
  path: '/',
  method: 'GET',
  timeout: 2000
};

const request = http.request(options, (res) => {
  console.log(`Health check status: ${res.statusCode}`);
  // OpenClaw gateway should return 200 or 3xx
  if (res.statusCode >= 200 && res.statusCode < 400) {
    process.exit(0);
  } else {
    process.exit(1);
  }
});

request.on('error', (err) => {
  console.error(`Health check failed: ${err.message}`);
  process.exit(1);
});

request.on('timeout', () => {
  console.error('Health check timed out');
  request.destroy();
  process.exit(1);
});

request.end();
```

### .dockerignore Pattern
```
# Source: https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/
node_modules
npm-debug.log
.git
.gitignore
.env
.env.*
.DS_Store
*.md
.vscode
.idea
coverage
.planning
dist
build
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Run as root | Run as node user (UID 1000) | 2018+ | Security: Principle of Least Privilege, container escapes less dangerous |
| Shell form CMD | Exec form CMD | 2019+ | Signals reach application properly, faster container stops |
| npm start in CMD | Direct node execution | 2020+ | Proper signal handling, faster startup, clearer process tree |
| curl in HEALTHCHECK | Node.js http module | 2021+ | Smaller images (-2.5MB), fewer dependencies, faster checks |
| tini | dumb-init or --init | 2022+ | Both work, dumb-init preferred for explicit Dockerfile control |
| Multi-stage builds for separation | Single stage with --omit=dev | 2023+ | Simpler for apps that build from source, multi-stage still best for compiled/bundled apps |
| PUID/PGID env vars | Fixed UID 1000 + runtime chown | 2024+ | Simpler configuration, entrypoint handles permission fixing |

**Deprecated/outdated:**
- **Alpine for all Node.js containers:** Still common but Debian (Bookworm/Slim) increasingly preferred for compatibility, especially when native modules involved
- **PM2/Forever in containers:** Process managers unnecessary with Docker/K8s orchestration, adds complexity
- **--init flag instead of explicit init:** Flag works but less visible in Dockerfile, explicit dumb-init install preferred for clarity
- **gosu for user switching:** Deprecated in favor of su-exec (Alpine) or Docker's native USER directive

## Open Questions

Things that couldn't be fully resolved:

1. **OpenClaw's exact startup command**
   - What we know: Can use `openclaw gateway --port 18789 --verbose` or `openclaw dashboard`
   - What's unclear: Whether OpenClaw binary is in PATH after npm install, or needs explicit path like `node dist/cli.js gateway`
   - Recommendation: Test during implementation, check package.json bin field, may need `npx openclaw gateway`

2. **Additional ports beyond 18789**
   - What we know: Gateway WebSocket runs on 18789, documentation shows http://127.0.0.1:18789
   - What's unclear: Whether any channels (WhatsApp, Telegram, etc.) need additional ports, or if webhook servers spawn on different ports
   - Recommendation: Expose only 18789 initially, document how users can add -p flags if needed, check OpenClaw logs during testing

3. **First-run initialization requirements**
   - What we know: `openclaw onboard --install-daemon` runs initial setup wizard, creates ~/.openclaw/ structure
   - What's unclear: Whether onboard is required, or if gateway auto-initializes with sensible defaults
   - Recommendation: Test both approaches - may need entrypoint to run `openclaw onboard --non-interactive` on first start if ~/.openclaw/openclaw.json doesn't exist

4. **Health check endpoint**
   - What we know: Control UI accessible on port 18789, serves web interface
   - What's unclear: Whether there's a dedicated /health or /api/health endpoint, or if root path / is sufficient
   - Recommendation: Try root path first (/) with 2xx-3xx status codes accepted, add dedicated health endpoint to OpenClaw if needed (future enhancement)

5. **OpenClaw's handling of missing config**
   - What we know: Config stored in ~/.openclaw/openclaw.json, agents in ~/.openclaw/agents/
   - What's unclear: Behavior when these don't exist - does it fail, create defaults, or run onboarding wizard?
   - Recommendation: Include initialization logic in entrypoint to handle first run gracefully, possibly detect missing config and log instructions

## Sources

### Primary (HIGH confidence)
- [docker-node Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md) - Node.js Docker official guidance
- [node:22-bookworm Dockerfile](https://github.com/nodejs/docker-node/blob/de1c8c994e1bf8a5843ff7d4d987eee0cad69243/22/bookworm/Dockerfile) - node user UID/GID verification
- [OpenClaw GitHub Repository](https://github.com/openclaw/openclaw) - Application requirements
- [OpenClaw Getting Started](https://docs.openclaw.ai/start/getting-started) - Port, configuration, startup commands
- [Docker Official Docs - Variables](https://docs.docker.com/build/building/variables/) - ARG vs ENV best practices
- [Docker Blog - Best Practices Using ARG and ENV](https://www.docker.com/blog/docker-best-practices-using-arg-and-env-in-your-dockerfiles/) - Official guidance

### Secondary (MEDIUM confidence)
- [9 Tips for Containerizing Your Node.js Application | Docker](https://www.docker.com/blog/9-tips-for-containerizing-your-node-js-application/) - Official Docker blog (2024)
- [10 best practices to containerize Node.js | Snyk](https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/) - Security-focused best practices
- [Effective Docker Healthchecks For Node.js](https://patrickleet.medium.com/effective-docker-healthchecks-for-node-js-b11577c3e595) - Health check patterns
- [Docker ENTRYPOINT vs CMD](https://oneuptime.com/blog/post/2026-01-16-docker-entrypoint-vs-cmd/view) - Recent guide (Jan 2026)
- [Stopping Docker Containers Safely: How dumb-init Saved My NestJsWorker](https://medium.com/@salimian/stopping-docker-containers-safely-how-dumb-init-saved-my-nestjsworker-88529b5a9f13) - Recent real-world example (Jan 2026)
- [Unraid Docker Template Guide](https://selfhosters.net/docker/templating/templating/) - Unraid-specific requirements
- [Managing containers | Unraid Docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/) - Official Unraid documentation

### Tertiary (LOW confidence)
- Various web search results about Docker permission handling - Patterns consistent across sources but implementation details vary
- Community discussions about volume ownership strategies - Multiple valid approaches, chose simplest based on user requirements

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Node.js Docker images, well-documented dumb-init, OpenClaw repo verified
- Architecture: HIGH - Patterns from official Docker/Node.js documentation, verified across multiple authoritative sources
- Pitfalls: MEDIUM-HIGH - Common issues well-documented in community, some OpenClaw-specific items need testing
- OpenClaw specifics: MEDIUM - Official docs provide port/config info, but some runtime behavior needs verification during implementation

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - Docker/Node.js practices stable, OpenClaw may update)
