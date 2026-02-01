# Architecture Research

**Domain:** Docker containerization for Unraid Community Applications
**Researched:** 2026-02-01
**Confidence:** MEDIUM-HIGH

## Standard Architecture for Unraid Docker Applications

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Unraid Community Apps                     │
│                     (Discovery & Install)                    │
├─────────────────────────────────────────────────────────────┤
│  XML Template                                               │
│  (/boot/config/plugins/dockerMan/templates-user/)           │
│    - Metadata (name, icon, description)                      │
│    - Repository reference (DockerHub)                        │
│    - Port mappings                                           │
│    - Volume configurations                                   │
│    - Environment variables                                   │
└──────────────────┬──────────────────────────────────────────┘
                   │ (pulls from)
                   ↓
┌─────────────────────────────────────────────────────────────┐
│                      DockerHub Registry                      │
│                   (Image Distribution)                       │
└──────────────────┬──────────────────────────────────────────┘
                   │ (docker pull)
                   ↓
┌─────────────────────────────────────────────────────────────┐
│                    Docker Container Runtime                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Init System (s6-overlay or direct CMD)             │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  Application Layer                                   │    │
│  │  - Main application process                          │    │
│  │  - Configuration management                          │    │
│  │  - Health checks                                     │    │
│  └─────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│  Volume Mounts                                              │
│  Container Path        Host Path                            │
│  /config        →      /mnt/user/appdata/{appname}/         │
│  /data (opt)    →      /mnt/user/{share}/                   │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| XML Template | Installation configuration, UI presentation | XML file in GitHub repo, referenced by Community Apps |
| Dockerfile | Build instructions, base image selection, dependencies | Multi-stage build with Alpine or Debian base |
| Init System | Process supervision, startup order, shutdown | s6-overlay (LinuxServer.io pattern) or direct CMD |
| Volume Mappings | Persistent data storage outside container | Host paths to /mnt/user/appdata/{app}/ |
| Environment Variables | Runtime configuration without rebuilding | PUID/PGID, ports, feature flags, API keys |
| Network Configuration | Port exposure, container communication | Bridge mode (default), custom networks optional |

## Recommended Project Structure

### Repository Organization

```
openclaw.docker/
├── Dockerfile                    # Container build instructions
├── .dockerignore                 # Exclude unnecessary files from build context
├── docker-compose.yml            # Local testing configuration (optional)
├── README.md                     # Installation and usage documentation
├── LICENSE                       # Required for Community Apps submission
│
├── templates/                    # Unraid template files
│   └── openclaw.xml              # Community Applications template
│
├── root/                         # Files copied into container root
│   ├── etc/
│   │   └── s6-overlay/           # s6-overlay service definitions (if used)
│   │       └── s6-rc.d/
│   │           └── openclaw/
│   │               ├── type      # Service type (longrun)
│   │               ├── run       # Start script
│   │               └── finish    # Cleanup script (optional)
│   └── defaults/                 # Default configuration files
│       └── openclaw.conf         # Copied to /config on first run
│
├── scripts/                      # Helper scripts
│   ├── entrypoint.sh             # Container entrypoint logic
│   └── healthcheck.sh            # Docker health check script
│
└── .github/                      # CI/CD automation
    └── workflows/
        └── docker-publish.yml    # Automated builds to DockerHub
```

### Structure Rationale

- **Dockerfile in root:** Docker convention, easy to find and build
- **templates/ directory:** Separates Unraid-specific files from core container logic
- **root/ directory:** LinuxServer.io pattern - files copied to container root during build
- **scripts/ directory:** Centralizes executable scripts for maintainability
- **.github/workflows/:** Modern CI/CD approach (GitHub Actions preferred over DockerHub autobuild)

## Architectural Patterns

### Pattern 1: Volume Mapping for Configuration Persistence

**What:** Map container's config directory to Unraid appdata share for persistence across container lifecycles.

**When to use:** Always - required for any application that stores state, configuration, or user data.

**Trade-offs:**
- ✅ Data persists across container updates and restarts
- ✅ Users can backup/restore by copying appdata directory
- ✅ Follows Unraid conventions (users expect /mnt/user/appdata/)
- ⚠️ Requires proper permission management (PUID/PGID pattern)

**Example:**
```dockerfile
# In Dockerfile - define the volume
VOLUME ["/config"]

# In Unraid template XML
<Config Name="AppData" Target="/config" Default="/mnt/user/appdata/openclaw" Mode="rw" Type="Path" />
```

**Unraid User Perspective:**
- Host path: `/mnt/user/appdata/openclaw/` (on SSD cache for performance)
- Container path: `/config` (application expects config here)
- Access mode: `rw` (read/write - application needs to save state)

### Pattern 2: Multi-Stage Docker Build

**What:** Separate build environment from runtime environment to minimize final image size and attack surface.

**When to use:** For compiled applications, or when build dependencies differ from runtime dependencies.

**Trade-offs:**
- ✅ Significantly smaller final images (50-80% reduction typical)
- ✅ Reduces attack surface (no build tools in production)
- ✅ Faster pulls and deployments
- ⚠️ More complex Dockerfile structure
- ⚠️ Build caching requires understanding layer dependencies

**Example:**
```dockerfile
# Stage 1: Build environment
FROM node:20-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Stage 2: Runtime environment
FROM alpine:3.19
RUN apk add --no-cache nodejs
WORKDIR /app
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

### Pattern 3: s6-overlay for Process Supervision

**What:** Use s6-overlay as init system to manage multiple processes, handle dependencies, and ensure graceful shutdown.

**When to use:** When application requires multiple processes (e.g., main app + health monitor, or background workers), or when you need robust process supervision.

**Trade-offs:**
- ✅ Proper PID 1 functionality (no zombie processes)
- ✅ Process dependency management
- ✅ Graceful shutdown ensuring data integrity
- ✅ Built-in log rotation
- ⚠️ Adds ~5-10MB to image size
- ⚠️ Steeper learning curve than direct CMD
- ⚠️ Overkill for single-process containers

**Example:**
```dockerfile
# Add s6-overlay to image
FROM alpine:3.19
ARG S6_OVERLAY_VERSION=3.1.6.2
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

ENTRYPOINT ["/init"]
```

**Service Definition (root/etc/s6-overlay/s6-rc.d/openclaw/run):**
```bash
#!/command/with-contenv bash
cd /app
exec s6-setuidgid openclaw node server.js
```

### Pattern 4: PUID/PGID for Permission Management

**What:** Allow users to specify User ID and Group ID to match Unraid host permissions, avoiding permission conflicts.

**When to use:** Always - standard pattern for Unraid containers that write to host filesystem.

**Trade-offs:**
- ✅ Eliminates permission issues with appdata
- ✅ User can set to match their Unraid user/group
- ✅ Expected pattern by Unraid community
- ⚠️ Requires entrypoint script to apply permissions

**Example:**
```dockerfile
# In Dockerfile
ENV PUID=1000 PGID=1000

# In entrypoint.sh
groupmod -o -g "$PGID" appuser
usermod -o -u "$PUID" appuser
chown -R appuser:appuser /config
exec gosu appuser "$@"
```

```xml
<!-- In Unraid template -->
<Config Name="PUID" Target="PUID" Default="99" Mode="" Type="Variable" />
<Config Name="PGID" Target="PGID" Default="100" Mode="" Type="Variable" />
```

### Pattern 5: Environment Variable Configuration

**What:** Use environment variables for runtime configuration, avoiding hardcoded values and enabling easy customization.

**When to use:** For any configurable application behavior, API keys, feature toggles, or environment-specific settings.

**Trade-offs:**
- ✅ Portability across environments
- ✅ Security (secrets not baked into image)
- ✅ Easy to modify through Unraid UI
- ⚠️ Need sensible defaults for optional variables
- ⚠️ Required variables must be validated at startup

**Example:**
```xml
<!-- In Unraid template -->
<Config Name="Control UI Port" Target="OPENCLAW_PORT" Default="18789" Mode="" Type="Variable" />
<Config Name="API Key" Target="OPENCLAW_API_KEY" Default="" Mode="" Type="Variable" Display="always" Required="false" Mask="true" />
```

## Data Flow

### Initial Installation Flow

```
User browses Community Apps
    ↓
Searches for "OpenClaw"
    ↓
Clicks "Install"
    ↓
Unraid fetches XML template from GitHub
    ↓
User reviews/edits config in UI
  - Port mappings
  - Volume paths (/mnt/user/appdata/openclaw/)
  - Environment variables (PUID/PGID)
    ↓
User clicks "Apply"
    ↓
Unraid runs docker pull from DockerHub
    ↓
Unraid creates container with specified config
    ↓
Container starts, entrypoint runs
    ↓
Application checks /config directory
  - If empty: copy defaults, run first-time setup
  - If populated: load existing configuration
    ↓
Application starts and binds to configured port
    ↓
User accesses via http://[SERVER_IP]:[PORT]
```

### Container Update Flow

```
New version published to DockerHub
    ↓
Community Apps checks for updates (periodic scan)
    ↓
Unraid UI shows "Update Available" badge
    ↓
User clicks "Update"
    ↓
Unraid stops existing container
    ↓
Unraid pulls new image from DockerHub
    ↓
Unraid recreates container with SAME config
  - Same volume mounts (/config preserved)
  - Same environment variables
  - Same port mappings
    ↓
Container starts with new image
    ↓
Application loads existing /config data
    ↓
User configuration and data intact
```

### Persistent Storage Flow

```
Application writes config file
    ↓
Writes to /config/app.json (container path)
    ↓
Volume mount maps to host path
    ↓
Actually written to /mnt/user/appdata/openclaw/app.json
    ↓
Stored on Unraid array/cache
    ↓
Survives container stops, restarts, updates, and removals
    ↓
User can backup by copying /mnt/user/appdata/openclaw/
```

## Scaling Considerations

| User Scale | Architecture Approach | Notes |
|------------|----------------------|-------|
| Single Unraid server | Standard container, bridge network | Default pattern - simplest deployment |
| Multiple containers (different apps) | Shared appdata, separate subdirectories | /mnt/user/appdata/app1/, /mnt/user/appdata/app2/ |
| High I/O requirements | Appdata on SSD cache | Unraid best practice - faster config access |
| Network isolation needs | Custom Docker networks | Create network, set in template's Network mode |

### Scaling Priorities

**For this project (OpenClaw):**
1. **First priority:** Correct volume persistence - users must not lose data
2. **Second priority:** Proper port exposure - Control UI must be accessible
3. **Third priority:** Easy updates - configuration must survive image updates

**Not a priority:**
- Multi-instance deployments (single instance per server is expected pattern)
- Horizontal scaling (not applicable to Unraid use case)
- Load balancing (single-server deployment model)

## Component Boundaries for OpenClaw Docker

### Component 1: Dockerfile

**Responsibility:** Define container build process, base image, dependencies, and application installation.

**Communicates with:**
- DockerHub (publishes to)
- GitHub Actions (triggered by commits)
- Base image registries (Alpine/Debian official images)

**Key decisions:**
- Base image selection (Alpine for size vs Debian for compatibility)
- Multi-stage build (if OpenClaw has build step) vs single-stage
- s6-overlay inclusion (needed if multiple processes)

### Component 2: Unraid XML Template

**Responsibility:** Define installation UI, volume mappings, port configurations, and environment variables for Unraid users.

**Communicates with:**
- Community Applications catalog (discovered through)
- Unraid Docker manager (consumed by)
- DockerHub (references image repository)

**Key decisions:**
- Volume mapping paths (container /config → host /mnt/user/appdata/openclaw/)
- Required vs optional fields
- Default values for ports and variables

### Component 3: Entrypoint/Init Scripts

**Responsibility:** Container startup logic, permission management, first-run initialization, and application launch.

**Communicates with:**
- Host filesystem (applies PUID/PGID)
- Application configuration (copies defaults if needed)
- s6-overlay (if used as init system)

**Key decisions:**
- First-run detection mechanism
- Permission application strategy
- Health check implementation

### Component 4: GitHub Actions Workflow

**Responsibility:** Automated build and publish pipeline from Git commits to DockerHub registry.

**Communicates with:**
- GitHub repository (triggered by push)
- DockerHub (authenticates and pushes images)
- Docker build system (executes docker buildx)

**Key decisions:**
- Build triggers (tags, branches, or both)
- Multi-architecture support
- Versioning strategy (semantic tags)

### Component 5: Documentation

**Responsibility:** User-facing installation guide, troubleshooting, and Unraid forum support thread.

**Communicates with:**
- GitHub README (primary docs)
- Unraid forum thread (community support)
- XML template Overview field (brief description)

**Key decisions:**
- Installation instructions specificity
- Troubleshooting common issues
- Migration path from existing setups

## Anti-Patterns

### Anti-Pattern 1: Hardcoded Paths in Application

**What people do:** Configure application to always use specific paths like `/root/.openclaw/` without making it configurable.

**Why it's wrong:** Breaks volume mapping flexibility, prevents users from organizing their appdata, and makes backups harder.

**Do this instead:** Use environment variable for config path (e.g., `OPENCLAW_CONFIG_DIR=/config`) or symlink from expected path to /config in entrypoint.

### Anti-Pattern 2: Running as Root

**What people do:** Run application as root user inside container (UID 0).

**Why it's wrong:**
- Security risk (container escape = root on host)
- Permission conflicts with host filesystem
- Files created with UID 0 not accessible to Unraid user
- Community Apps reviewers flag this as issue

**Do this instead:** Use PUID/PGID pattern with gosu or s6-setuidgid to run as non-root user matching host permissions.

### Anti-Pattern 3: Multiple Individual Volume Mounts

**What people do:** Mount separate volumes for different data types:
```
/movies → /mnt/user/movies
/tv → /mnt/user/tv
/downloads → /mnt/user/downloads
```

**Why it's wrong:**
- Breaks hardlink capability (files appear on different filesystems)
- Forces slower copy operations instead of instant moves
- More I/O intensive
- Unraid TRaSH Guides explicitly warn against this

**Do this instead:** Use single mount point with subdirectories:
```
/data → /mnt/user/data
  ├── movies/
  ├── tv/
  └── downloads/
```

### Anti-Pattern 4: Embedding Secrets in Dockerfile

**What people do:** Hardcode API keys, passwords, or tokens in Dockerfile or config files baked into image.

**Why it's wrong:**
- Secrets exposed in Docker Hub public image layers
- Can't change secrets without rebuilding image
- Security best practices violation
- Community Apps submission rejection

**Do this instead:** Use environment variables marked with `Mask="true"` in template, or mount secret files from host.

### Anti-Pattern 5: No Health Check

**What people do:** Omit Docker HEALTHCHECK instruction, relying only on process existence.

**Why it's wrong:**
- Container appears "running" even if application crashed
- Unraid can't detect and auto-restart failed containers
- Users don't get visual feedback about application state
- Debugging harder without clear status

**Do this instead:** Implement proper health check:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:18789/health || exit 1
```

### Anti-Pattern 6: Using `latest` Tag in Production

**What people do:** Pull and reference `latest` tag without version pinning.

**Why it's wrong:**
- Unpredictable updates (latest changes without user control)
- Difficult rollback (what was "latest" yesterday?)
- Breaks reproducibility
- Community Apps can't show version information

**Do this instead:** Tag images with semantic versions:
```
username/openclaw:1.0.0
username/openclaw:1.0
username/openclaw:latest  # Also publish latest, but users should choose version
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| DockerHub | GitHub Actions push on tag | Automated builds preferred over manual push |
| Community Apps | GitHub repo URL in XML | Template pulled from public GitHub repo |
| Unraid Forums | Support thread link | Required in template's Support field |
| Base Images | Official Alpine/Debian | Verify on Docker Hub, use specific version tags |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Container ↔ Host Storage | Volume mounts | /config → /mnt/user/appdata/{app}/ |
| Container ↔ Unraid Network | Bridge network (default) | Port mapping in template |
| Application ↔ Configuration | File-based | App reads/writes /config/* |
| Init System ↔ Application | Process execution | s6-overlay supervises app, or direct CMD |
| Template ↔ Container | Environment variables | Runtime configuration injection |

## Build Order and Dependencies

### Recommended Implementation Order

**Phase 1: Local Container Development**
1. Create Dockerfile
2. Create entrypoint script with PUID/PGID logic
3. Test locally with docker-compose.yml
4. Verify volume persistence across restarts

**Dependencies:** OpenClaw source/binary, understanding of its config structure

**Phase 2: DockerHub Publishing**
5. Create GitHub repository for docker setup
6. Set up GitHub Actions workflow for automated builds
7. Test manual docker pull and run

**Dependencies:** Phase 1 complete, DockerHub account

**Phase 3: Unraid Template Creation**
8. Create XML template with correct mappings
9. Test installation through Community Apps (private repo)
10. Verify updates work correctly

**Dependencies:** Phase 2 complete, access to Unraid test server

**Phase 4: Community Submission**
11. Create Unraid forum support thread
12. Submit template to Community Applications
13. Respond to moderator feedback

**Dependencies:** Phase 3 complete, proven working setup

### Critical Dependencies

```
Dockerfile ────────────────┐
                           ↓
Entrypoint Script ────→ Working Container
                           ↓
                      DockerHub Push
                           ↓
                      XML Template ────→ Unraid Installation
                           ↑
                           │
                    Forum Thread ──────→ Community Apps Submission
```

**Blocker relationships:**
- Can't test XML template without published Docker image
- Can't submit to Community Apps without forum support thread
- Can't publish to DockerHub without working Dockerfile
- Can't create accurate template without understanding volume requirements

## Dockerfile Patterns for OpenClaw

### Pattern Option A: Simple Single-Stage (if OpenClaw ships pre-built)

```dockerfile
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    curl

# Create application user
RUN addgroup -g 1000 openclaw && \
    adduser -D -u 1000 -G openclaw openclaw

# Copy application files
WORKDIR /app
COPY . .

# Setup volume for persistent data
VOLUME ["/config"]

# Default environment variables
ENV PUID=1000 \
    PGID=1000 \
    OPENCLAW_PORT=18789

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${OPENCLAW_PORT}/health || exit 1

EXPOSE 18789

ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "server.js"]
```

### Pattern Option B: s6-overlay with Multiple Services

```dockerfile
FROM alpine:3.19

ARG S6_OVERLAY_VERSION=3.1.6.2

# Add s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz && \
    rm -rf /tmp/*.tar.xz

# Install dependencies
RUN apk add --no-cache nodejs npm curl

# Copy service definitions
COPY root/ /

VOLUME ["/config"]
ENV PUID=1000 PGID=1000

EXPOSE 18789

ENTRYPOINT ["/init"]
```

## Sources

### HIGH Confidence - Official Documentation
- [Unraid Docker Management Docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/)
- [Docker Template XML Schema](https://wiki.unraid.net/DockerTemplateSchema)
- [LinuxServer.io Container Architecture](https://docs.linuxserver.io/general/running-our-containers/)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [s6-overlay GitHub](https://github.com/just-containers/s6-overlay)

### MEDIUM Confidence - Community Best Practices
- [Selfhosters.net Unraid Templating Guide](https://selfhosters.net/docker/templating/templating/)
- [Unraid Community Apps Forum Thread](https://forums.unraid.net/topic/101424-how-to-publish-docker-templates-to-community-applications-on-unraid/)
- [TRaSH Guides - Unraid File Structure](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Unraid/)
- [Platform Engineers s6-overlay Guide](https://platformengineers.io/blog/s6-overlay-quickstart/)

### MEDIUM Confidence - Current Patterns (2026)
- [GitHub Actions Docker Integration](https://docs.docker.com/guides/gha/)
- [LinuxServer.io 2025 Improvements](https://www.linuxserver.io/blog/new-and-improved-for-2025)
- [Alpine Linux Docker Image](https://hub.docker.com/_/alpine)

### LOW Confidence - Community Discussion (needs validation for OpenClaw specifics)
- Game server Docker patterns from search results
- Specific PUID/PGID implementation approaches
- Health check endpoints (need to verify OpenClaw provides /health or similar)

---
*Architecture research for: OpenClaw Docker for Unraid*
*Researched: 2026-02-01*
