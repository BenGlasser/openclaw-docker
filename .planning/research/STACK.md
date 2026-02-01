# Stack Research

**Domain:** Docker image for Unraid Community Applications
**Researched:** 2026-02-01
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Docker Buildx | v0.12+ | Multi-platform image building | Default in Docker Engine 23.0+. Required for efficient multi-stage builds and multi-platform support (amd64/arm64). BuildKit backend provides concurrent stage building and improved caching. |
| Node.js Alpine base | node:22-alpine | Production runtime base image | Current LTS version (22.x) with minimal footprint. Alpine reduces attack surface and image size. LinuxServer.io and Docker official images both recommend Alpine for production. |
| s6-overlay | v3.2.2.0 | Process supervisor and init system | Industry standard for Unraid containers. LinuxServer.io uses s6 v3 across entire ecosystem. Provides proper signal handling, service dependencies, and graceful shutdown. Latest version (Jan 2026) includes Docker sync support. |
| GitHub Actions | docker/build-push-action@v6 | CI/CD for automated builds | Official Docker action. Supports BuildKit, multi-platform builds, SBOM/provenance attestations for supply chain security. Integrates seamlessly with DockerHub. |
| Unraid XML Template | Community Apps v2 schema | Application definition | Required for Community Applications submission. Defines container config, volumes, ports, and metadata. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| docker/metadata-action | v5 | Automated image tagging | Use in GitHub Actions to generate semantic version tags and labels automatically from git tags/branches. |
| docker/setup-qemu-action | v3 | Multi-architecture emulation | Required when building for arm64 on amd64 runners (or vice versa). Enables cross-platform builds. |
| Docker Healthcheck | Native Dockerfile instruction | Container health monitoring | Essential for production. Unraid uses health status for UI indicators. Check every 30s with 30s timeout. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| docker-compose | Local testing and orchestration | While Unraid doesn't use Compose, it's valuable for local development and testing volume mappings. |
| .dockerignore | Build optimization | Exclude .git, node_modules, .env files. Critical for smaller context and faster builds. |
| Docker Scout | Vulnerability scanning | Built into Docker Desktop 4.38+. Scans for CVEs and suggests base image updates. |

## Installation

```bash
# Core - GitHub Actions workflow dependencies
# (Add to .github/workflows/docker-build.yml)
- uses: docker/setup-buildx-action@v3
- uses: docker/setup-qemu-action@v3
- uses: docker/login-action@v3
- uses: docker/metadata-action@v5
- uses: docker/build-push-action@v6

# Local development
brew install docker docker-compose  # macOS
# or
apt-get install docker.io docker-compose-v2  # Ubuntu/Debian

# s6-overlay (included in Dockerfile)
ADD https://github.com/just-containers/s6-overlay/releases/download/v3.2.2.0/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v3.2.2.0/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
```

## Base Image Strategy

**Recommended Pattern:**
```dockerfile
# Multi-stage build
FROM node:22-alpine AS builder
# Build dependencies and compile assets

FROM node:22-alpine AS runtime
# Copy s6-overlay
# Copy built artifacts
# Install only production dependencies
```

**Rationale:**
- **node:22-alpine**: Current LTS (Active LTS as of 2025), minimal attack surface, 5x smaller than debian variants
- **Multi-stage**: Separates build tools from runtime, reduces final image size by ~50%
- **Alpine over Debian**: Despite smaller Alpine community, timely security patches and widespread Unraid ecosystem adoption (LinuxServer.io standard) outweigh concerns. Debian has broader ecosystem but larger attack surface.

## Volume Management Pattern

**Standard for Unraid:**
```dockerfile
# Create non-root user matching Unraid PUID/PGID pattern
RUN addgroup -g 1000 openclaw && \
    adduser -D -H -u 1000 -G openclaw openclaw

# Application data directory
VOLUME ["/config"]

# s6-overlay handles PUID/PGID remapping at runtime
```

**Environment Variables:**
```bash
PUID=1000  # User ID for file ownership
PGID=1000  # Group ID for file ownership
```

**Rationale:**
- LinuxServer.io pattern is ubiquitous in Unraid ecosystem
- `/config` is conventional mount point (not `/data` or app-specific paths)
- PUID/PGID allows host user to access container-created files
- Solves permission mismatches between container and host

## Image Tagging Strategy

**Required tags for each build:**
```
username/openclaw:latest
username/openclaw:1.0.0
username/openclaw:1.0
username/openclaw:1
```

**Rationale:**
- Semantic versioning (MAJOR.MINOR.PATCH) required for production
- Multiple tags allow users to pin to major/minor versions
- `latest` updated on every release (Unraid templates default to this)
- Never overwrite existing version tags (immutability principle)
- Auto-generated via docker/metadata-action from git tags

## Security Practices

**Non-Root Execution:**
```dockerfile
USER openclaw
```

**Read-Only Root Filesystem (where possible):**
```dockerfile
# In docker-compose for testing
read_only: true
tmpfs:
  - /tmp
  - /run
```

**Health Check:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:18789/health || exit 1
```

**Rationale:**
- Principle of least privilege: non-root user reduces container escape impact
- Health checks enable Unraid to show container status and auto-restart unhealthy containers
- 60s start-period accommodates OpenClaw's initialization time
- Read-only root prevents runtime tampering (if app supports it)

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| node:22-alpine | node:22-slim (Debian) | When you need glibc compatibility or encounter musl-specific bugs. Debian has larger community for security research. |
| s6-overlay v3 | supervisord | Never for Unraid. Supervisord not designed for containers, poor signal handling, outdated pattern. |
| GitHub Actions | GitLab CI / Jenkins | If already using those platforms. GitHub Actions has best Docker integration and free tier for public repos. |
| Multi-stage builds | Single-stage | Never for production. Single-stage includes build tools in runtime, 2x larger images, security risk. |
| Semantic versioning | Date-based tags (2026-02-01) | Never. Semantic versioning communicates compatibility, required by Unraid ecosystem conventions. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `latest` tag in production Dockerfile FROM statements | Breaks build reproducibility. Base image updates can introduce breaking changes silently. | Pin to specific version: `node:22.11.0-alpine3.20` or digest `@sha256:...` |
| `npm install` in production stage | Installs devDependencies, slower, non-deterministic. | `npm ci --only=production` for lockfile-based, production-only installs |
| Root user (uid 0) | Security vulnerability. Container escape gives host root access. Violates least privilege. | Create non-root user with PUID/PGID support (uid 1000) |
| `node` base images (not -alpine or -slim) | 10x more CVEs than Alpine, 5x larger size. Unnecessary packages increase attack surface. | `node:22-alpine` for production |
| `ENTRYPOINT ["npm", "start"]` | npm swallows SIGTERM/SIGINT, prevents graceful shutdown. Extra process overhead. | `CMD ["node", "server.js"]` or use s6-overlay for multi-process |
| Hardcoded paths like `/home/openclaw/.openclaw` | Breaks Unraid convention. Users expect `/config`. | Always use `/config` for Unraid volumes |
| `ADD` for local files | Has implicit tar extraction and URL fetching. Less clear than COPY. | `COPY` for local files, `ADD` only for tarballs that need extraction |
| `RUN apt-get update` and `RUN apt-get install` separately | Cache invalidation causes stale package indices. Security issue. | `RUN apt-get update && apt-get install -y ...` in same layer |

## Stack Patterns by Variant

**If building for both Unraid and general Docker users:**
- Use same Dockerfile
- Provide both Unraid XML template AND docker-compose.yml example
- Document both `/config` (Unraid convention) and alternative mount points
- Because: Unraid users can use standard Docker images; isolation helps testing

**If OpenClaw requires GPU access (future):**
- Use `nvidia/cuda:12.x-runtime-ubuntu22.04` base instead of Alpine
- Because: CUDA unavailable on Alpine (glibc requirement)
- Add `--gpus all` to Unraid template ExtraParams

**If multi-process services needed beyond s6:**
- s6-overlay handles this natively via `/etc/s6-overlay/s6-rc.d/` service definitions
- Because: s6 designed for multi-service containers, better than supervisord

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| s6-overlay@v3.2.2.0 | Docker Engine 20.10+, Unraid 6.9+ | Requires Docker with overlay2 storage driver. v3 uses different config structure than v2. |
| node:22-alpine | Alpine 3.19+ | Uses musl libc. Native modules may need rebuild. Works with npm, yarn, pnpm, bun. |
| docker/build-push-action@v6 | GitHub Actions, Docker Buildx 0.10+ | Requires BuildKit. Not compatible with legacy Docker builder. |
| Unraid XML v2 schema | Unraid 6.10+ | Older Unraid versions use v1 schema (different field names). |

## Dockerfile Optimization Checklist

- [ ] Multi-stage build separates builder and runtime
- [ ] Alpine base image for minimal footprint
- [ ] Non-root user (uid 1000) for security
- [ ] PUID/PGID environment variables for Unraid compatibility
- [ ] Single RUN layer for each logical operation (minimize layers)
- [ ] HEALTHCHECK with appropriate intervals
- [ ] VOLUME declaration for /config
- [ ] .dockerignore excludes .git, node_modules, .env
- [ ] COPY package*.json before npm ci (leverage layer caching)
- [ ] NODE_ENV=production set
- [ ] CMD uses node directly, not npm start
- [ ] LABEL with org.opencontainers.image.* metadata
- [ ] Specific base image version tag (not :latest)

## Sources

**HIGH Confidence (Official Documentation):**
- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/) — Multi-stage builds, layer caching, security
- [Docker GitHub Actions Official Guide](https://docs.docker.com/guides/gha/) — CI/CD workflow patterns
- [GitHub Actions: Build and Push Docker Images](https://github.com/marketplace/actions/build-and-push-docker-images) — Official action documentation
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md) — Official Node.js Docker team guidance
- [Unraid Community Applications Documentation](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/community-applications/) — Template requirements
- [LinuxServer.io: Running Our Containers](https://docs.linuxserver.io/general/running-our-containers/) — PUID/PGID pattern
- [LinuxServer.io: Understanding PUID and PGID](https://docs.linuxserver.io/general/understanding-puid-and-pgid/) — Permission management
- [s6-overlay GitHub Releases](https://github.com/just-containers/s6-overlay/releases) — v3.2.2.0 (latest as of Jan 2026)

**MEDIUM Confidence (Verified Community Sources):**
- [Selfhosters.net: Writing a Template Compatible for Unraid](https://selfhosters.net/docker/templating/templating/) — Complete XML schema reference
- [Docker Multi-Stage Builds Official Docs](https://docs.docker.com/build/building/multi-stage/) — Build optimization
- [Better Stack: Dockerizing Node.js Apps](https://betterstack.com/community/guides/scaling-nodejs/dockerize-nodejs/) — Production patterns
- [Snyk: 10 Best Practices to Containerize Node.js](https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/) — Security focus
- [Lumigo: Docker Health Check Practical Guide](https://lumigo.io/container-monitoring/docker-health-check-a-practical-guide/) — Health check implementation
- [Container Registry: Image Versioning](https://container-registry.com/posts/container-image-versioning/) — Semantic versioning strategy

**Research Notes:**
- All version numbers verified against official releases as of 2026-02-01
- Alpine vs Debian trade-off: chose Alpine for size/security despite smaller community
- s6-overlay v3 is latest (released Jan 24, 2026), significant changes from v2
- GitHub Actions workflow uses official Docker actions (docker org namespace)
- Unraid XML template v2 schema confirmed as current standard

---
*Stack research for: OpenClaw Docker for Unraid*
*Researched: 2026-02-01*
