# Project Research Summary

**Project:** OpenClaw Docker for Unraid
**Domain:** Docker containerization for Unraid Community Applications
**Researched:** 2026-02-01
**Confidence:** MEDIUM-HIGH

## Executive Summary

OpenClaw is being packaged as a Docker container for distribution through Unraid Community Applications, a curated marketplace that serves Unraid NAS users. The recommended approach follows the LinuxServer.io pattern: Alpine-based multi-stage builds with s6-overlay for process supervision, strict PUID/PGID permission management, and persistent volume mapping to `/mnt/user/appdata/openclaw/`. The container must include a standards-compliant XML template, DockerHub publishing pipeline via GitHub Actions, and active support thread on Unraid forums.

The key technical decisions are straightforward: use `node:22-alpine` as the base image for Node.js runtime, implement the PUID/PGID pattern to prevent permission conflicts with Unraid's `nobody:users` (99:100) default, and expose OpenClaw's Control UI (port 18789) via configurable bridge networking. The architecture requires four main components: Dockerfile for building the container, XML template for Unraid integration, entrypoint script for permission handling, and GitHub Actions for automated publishing.

The most critical risks are data loss from improper volume persistence (users expect `/config` to survive container updates), permission chaos from missing PUID/PGID implementation, and XML template validation failures that cause Community Applications blacklisting. These are all preventable with proper implementation of established Unraid patterns and testing against the complete update lifecycle before submission. Success depends on following community conventions rather than inventing new patterns.

## Key Findings

### Recommended Stack

The stack centers on battle-tested Unraid ecosystem standards. Alpine Linux provides minimal footprint and rapid security patches, making it the default choice for LinuxServer.io and most production Unraid containers. Multi-stage builds separate build dependencies from runtime, reducing final image size by approximately 50%. The s6-overlay v3 (latest as of Jan 2026) provides proper init system functionality with signal handling and graceful shutdown. GitHub Actions with official Docker actions (`docker/build-push-action@v6`) enables automated multi-platform builds with SBOM attestations for supply chain security.

**Core technologies:**
- **Node.js Alpine (node:22-alpine)**: Current LTS runtime base with minimal attack surface — 5x smaller than debian variants, active LTS through 2027
- **s6-overlay v3.2.2.0**: Industry-standard init system for Unraid containers — handles process supervision, service dependencies, PUID/PGID remapping
- **Docker Buildx v0.12+**: Multi-platform image building — required for efficient multi-stage builds and arm64 support, default in Docker Engine 23.0+
- **GitHub Actions (docker/build-push-action@v6)**: CI/CD for automated builds — supports BuildKit, multi-platform, and integrates seamlessly with DockerHub
- **Unraid XML Template v2 schema**: Application definition and installation UI — required for Community Applications submission

### Expected Features

Unraid users have specific expectations shaped by the LinuxServer.io ecosystem. The feature set divides cleanly into table stakes (required for approval), differentiators (competitive advantages), and anti-features (commonly requested but problematic).

**Must have (table stakes):**
- Persistent appdata volume mapped to `/mnt/user/appdata/openclaw/` — users expect configuration to survive container updates
- PUID/PGID environment variables defaulting to 99:100 — prevents root-owned files that become inaccessible from Unraid
- XML template with WebUI field pointing to `http://[IP]:[PORT:18789]/` — click-to-access from Unraid Docker tab
- Support thread on Unraid forums — required for Community Applications submission
- Icon URL (HTTPS PNG) — visual identification in Docker tab and CA store
- Bridge networking with configurable port mapping — safest, most compatible default

**Should have (competitive):**
- Health check implementation — enables Unraid to show container status and auto-restart on failure
- Branch/tag selection in template — allows users to choose between stable and beta versions
- Pre-configured sensible defaults — works out-of-box with minimal user configuration required
- Clear installation documentation — reduces support burden based on common forum questions
- Automatic permission fixing — entrypoint script applies PUID/PGID to mapped volumes

**Defer (v2+):**
- Multi-architecture support (ARM/ARM64) — add when demand from Pi/ARM users materializes
- Advanced environment variables for fine-tuned control — wait for power user requests
- Minimal image size optimization beyond basics — defer until storage/bandwidth becomes concern
- Integration with CA Auto-Update plugin — post-launch stability feature

**Anti-features (avoid):**
- Docker Compose support — Unraid doesn't natively support it, stick to XML templates
- Privileged mode by default — major security risk, only use when absolutely necessary with clear documentation
- Root user execution — breaks Unraid permission model, always implement PUID/PGID
- Hardcoded container paths — breaks `/config` convention that users expect

### Architecture Approach

The architecture follows a four-component pattern with clear separation of concerns. The Dockerfile defines the build process and runtime environment using multi-stage builds (builder stage for dependencies, runtime stage for production). The Unraid XML template defines the installation UI, volume mappings, port configurations, and environment variables consumed by the Unraid Docker manager. Entrypoint scripts handle startup logic including PUID/PGID permission application, first-run initialization, and application launch. GitHub Actions workflows automate the build and publish pipeline from Git commits to DockerHub registry.

**Major components:**
1. **Dockerfile** — Defines container build process using node:22-alpine base, multi-stage build pattern, s6-overlay installation, and health check implementation
2. **Unraid XML Template** — Installation UI consumed by Community Applications, maps container `/config` to host `/mnt/user/appdata/openclaw/`, exposes port 18789 with configurable binding
3. **Entrypoint/Init Scripts** — Container startup logic that applies PUID/PGID permissions, detects first-run to copy default configs, launches application under correct user context
4. **GitHub Actions Workflow** — Automated build pipeline triggered by Git tags, executes multi-platform builds (amd64/arm64), publishes to DockerHub with semantic version tags
5. **Documentation** — README for GitHub, Unraid forum support thread for community, template Overview field for installation guidance

**Key patterns:**
- **Volume mapping for persistence**: Container `/config` maps to host `/mnt/user/appdata/openclaw/` ensuring data survives container lifecycle
- **PUID/PGID permission management**: Entrypoint runs `usermod`/`groupmod` to match host permissions (99:100), uses `gosu` or `s6-setuidgid` to drop privileges
- **Multi-stage builds**: Separate builder stage from runtime to minimize final image size and attack surface
- **Environment variable configuration**: Runtime customization via template variables (PUID, PGID, ports, API keys) without rebuilding
- **Health checks**: Docker HEALTHCHECK instruction pings Control UI endpoint, enables Unraid status indicators and auto-restart

### Critical Pitfalls

Research identified seven critical pitfalls that account for the majority of failed Unraid container deployments. These are ordered by severity and frequency based on Community Applications forum discussions and moderator feedback.

1. **Volume Persistence - Anonymous Volumes Lead to Data Loss** — Container data disappears when container is recreated because developers use anonymous volumes instead of explicit host path mappings. Always use explicit host paths (`/mnt/user/appdata/openclaw:/config`) and test by removing and recreating container to verify data survival.

2. **File Permission Chaos - PUID/PGID Not Configured** — Container creates root-owned files that become inaccessible to Unraid users. Implement PUID/PGID environment variables with entrypoint script that runs `usermod`/`groupmod` before starting main process. Default to 99:100 (nobody:users) matching Unraid standard.

3. **XML Template Validation Failure - Manual Editing Breaks Community Apps** — Templates edited manually instead of through Unraid interface get blacklisted from Community Applications. CRITICAL: Only edit templates through Unraid's Docker tab interface with "Template Authoring Mode" enabled, never hand-edit XML files.

4. **Port Conflict Hell - Default Ports Already in Use** — Container fails to start because common ports (80, 443, 8080) are already used by Unraid or other containers. Default to Bridge network mode with uncommon high port numbers (18789 for OpenClaw), make all ports configurable in template.

5. **Missing Health Checks - Silent Failures** — Container shows "Running" but application is crashed or non-functional. Implement `HEALTHCHECK` in Dockerfile that pings application endpoint (e.g., `curl -f http://localhost:18789/health || exit 1`) with 30s interval.

6. **Multi-Architecture Blindness - ARM Users Left Behind** — Container only works on x86/AMD64 systems, failing on ARM-based Unraid servers. Use `docker buildx build --platform linux/amd64,linux/arm64` for multi-platform builds, create multi-arch manifest on DockerHub.

7. **Corrupted Docker Image - Cache Drive Space Issues** — Container becomes unrecoverable when cache drive runs out of space during image pulls. Keep images small using Alpine base and multi-stage builds, document disk space requirements clearly in template Overview.

## Implications for Roadmap

Based on research, the project should follow a four-phase structure moving from local development to community distribution. Each phase has clear dependencies and addresses specific pitfalls identified in research.

### Phase 1: Container Development & Local Testing
**Rationale:** Must establish working containerization before publishing. Volume persistence and permission handling are foundational requirements that affect all subsequent phases. Multi-stage builds prevent having to refactor later when image size becomes an issue.

**Delivers:** Working Dockerfile with multi-stage build, entrypoint script with PUID/PGID logic, docker-compose.yml for local testing, verified volume persistence across container lifecycle

**Addresses:**
- Persistent appdata volume mapping (table stakes)
- PUID/PGID environment variables (table stakes)
- Health check implementation (differentiator)
- Minimal image size via multi-stage builds (optimization)

**Avoids:**
- Volume persistence data loss (critical pitfall 1)
- File permission chaos (critical pitfall 2)
- Corrupted docker image from bloat (critical pitfall 7)

**Research flag:** Standard patterns, skip phase-specific research. Dockerfile patterns are well-documented.

### Phase 2: Publishing Pipeline & DockerHub
**Rationale:** Can't test Unraid template without published Docker image. Automated publishing prevents manual errors and enables consistent versioning. Multi-architecture support should be built into pipeline from start rather than retrofitted.

**Delivers:** GitHub Actions workflow for automated builds, DockerHub repository with semantic version tags (latest, 1.0.0, 1.0, 1), multi-platform manifest (amd64/arm64)

**Uses:**
- GitHub Actions with docker/build-push-action@v6 (stack)
- Docker Buildx for multi-platform builds (stack)
- Semantic versioning strategy (stack)

**Implements:** GitHub Actions workflow component (architecture)

**Avoids:**
- Multi-architecture blindness (critical pitfall 6)
- Unpredictable updates from latest-only tagging

**Research flag:** Standard patterns, skip phase-specific research. GitHub Actions Docker integration is well-documented.

### Phase 3: Unraid Template & Testing
**Rationale:** Template must be created through Unraid interface to avoid XML validation issues. Private testing required before public submission to verify installation, updates, port mapping, and volume persistence in actual Unraid environment.

**Delivers:** XML template created via Unraid Docker tab, icon PNG hosted on GitHub, tested installation through private template repository, verified update workflow preserves configuration

**Addresses:**
- XML template for Community Apps (table stakes)
- WebUI access configuration (table stakes)
- Icon URL (table stakes)
- Bridge networking with port mapping (table stakes)

**Implements:** Unraid XML Template component (architecture)

**Avoids:**
- XML template validation failure (critical pitfall 3)
- Port conflict hell (critical pitfall 4)

**Research flag:** Standard patterns, skip phase-specific research. XML template creation is well-documented in Selfhosters.net guide.

### Phase 4: Community Submission & Documentation
**Rationale:** Support thread and documentation are submission requirements. Forum thread must exist before template submission. Documentation quality affects support burden and user adoption.

**Delivers:** Unraid forum support thread, comprehensive README with installation/troubleshooting, Community Applications submission, template Overview field with setup instructions

**Addresses:**
- Support thread on Unraid forums (table stakes)
- Clear installation documentation (differentiator)

**Implements:** Documentation component (architecture)

**Avoids:**
- Poor user documentation (UX pitfall)
- Unclear variable descriptions (UX pitfall)

**Research flag:** Standard patterns, skip phase-specific research. Community Applications submission process is well-documented.

### Phase Ordering Rationale

This order follows strict dependency chains discovered in research:
- Can't publish to DockerHub without working Dockerfile (Phase 1 → Phase 2)
- Can't test XML template without published Docker image (Phase 2 → Phase 3)
- Can't submit to Community Apps without forum support thread (Phase 4 dependency)
- Can't create accurate template without understanding volume requirements (Phase 1 → Phase 3)

Grouping is based on architectural boundaries from ARCHITECTURE.md: local development (Phase 1), build automation (Phase 2), Unraid integration (Phase 3), community distribution (Phase 4). This sequence ensures each component is testable before integration with the next.

The ordering specifically avoids the top three critical pitfalls by addressing them in Phase 1 before any publishing occurs: volume persistence and PUID/PGID are validated locally, XML template issues are prevented by using Unraid interface in Phase 3, and port conflicts are designed out through configurable bridge networking.

### Research Flags

Phases with standard patterns (skip research-phase):
- **Phase 1 (Container Development):** Well-documented Dockerfile patterns from Docker official docs, LinuxServer.io examples, and Node.js Docker best practices
- **Phase 2 (Publishing Pipeline):** GitHub Actions Docker integration is standard with official action documentation
- **Phase 3 (Unraid Template):** Template creation process documented in Selfhosters.net guide and Unraid wiki
- **Phase 4 (Community Submission):** Submission requirements clearly documented in Community Applications forum

No phases need `/gsd:research-phase` during planning. All patterns are established with high-confidence official documentation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified with official sources as of 2026-02-01. Versions confirmed against current releases. Alpine vs Debian trade-off explicitly considered. |
| Features | MEDIUM-HIGH | Feature expectations verified with official Unraid documentation and LinuxServer.io standards. MVP definition based on Community Applications submission requirements. Some prioritization based on forum discussions rather than official policy. |
| Architecture | MEDIUM-HIGH | Architecture patterns verified with official Docker and Unraid documentation. Component boundaries clear. Some implementation details (health check endpoints) need validation against OpenClaw specifics. |
| Pitfalls | HIGH | All critical pitfalls sourced from official Unraid troubleshooting docs, Docker best practices, and verified Community Applications moderator feedback. Prevention strategies tested by community. |

**Overall confidence:** MEDIUM-HIGH

The recommended approach is solid with high-confidence sources for all core decisions. Uncertainty exists only in OpenClaw-specific implementation details (exact configuration paths, whether Control UI provides health endpoint, ARM compatibility of OpenClaw binary).

### Gaps to Address

Areas where research was inconclusive or needs validation during implementation:

- **OpenClaw configuration structure**: Research assumes OpenClaw stores config in `~/.openclaw/` but this needs verification from OpenClaw documentation. Implementation may need to symlink expected path to `/config` or set environment variable.

- **OpenClaw health check endpoint**: HEALTHCHECK implementation assumes OpenClaw Control UI provides health endpoint or at minimum responds to HTTP GET on port 18789. Need to verify actual endpoint or implement simple TCP check.

- **OpenClaw ARM compatibility**: Multi-architecture build pipeline is recommended but research couldn't confirm if OpenClaw binary supports ARM64. May need to limit to amd64-only with clear documentation, or investigate cross-compilation.

- **OpenClaw Node.js version requirements**: Recommended node:22-alpine as current LTS, but OpenClaw may have specific version constraints. Verify compatibility before finalizing base image selection.

- **First-run initialization**: Architecture assumes default configs should be copied to `/config` on first run, but need to understand OpenClaw's actual initialization process and what files are required vs generated.

These gaps should be resolved during Phase 1 (Container Development) by examining OpenClaw source code, testing containerization approaches, and validating assumptions against actual application behavior.

## Sources

### PRIMARY (HIGH confidence)

**Official Documentation:**
- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/) — Multi-stage builds, layer caching, security
- [Unraid Community Applications Documentation](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/community-applications/) — Template requirements, submission process
- [Unraid Docker Management](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/) — Container configuration, volume mapping
- [Docker Template XML Schema](https://wiki.unraid.net/DockerTemplateSchema) — Official XML structure
- [LinuxServer.io: Running Our Containers](https://docs.linuxserver.io/general/running-our-containers/) — PUID/PGID pattern
- [LinuxServer.io: Understanding PUID and PGID](https://docs.linuxserver.io/general/understanding-puid-and-pgid/) — Permission management
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md) — Official Node.js Docker team guidance
- [GitHub Actions: Build and Push Docker Images](https://github.com/marketplace/actions/build-and-push-docker-images) — Official action documentation
- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/) — Build optimization
- [s6-overlay GitHub Releases](https://github.com/just-containers/s6-overlay/releases) — v3.2.2.0 (latest as of Jan 2026)

### SECONDARY (MEDIUM confidence)

**Community Best Practices:**
- [Selfhosters.net: Writing a Template Compatible for Unraid](https://selfhosters.net/docker/templating/templating/) — Complete XML schema reference
- [Better Stack: Dockerizing Node.js Apps](https://betterstack.com/community/guides/scaling-nodejs/dockerize-nodejs/) — Production patterns
- [Snyk: 10 Best Practices to Containerize Node.js](https://snyk.io/blog/10-best-practices-to-containerize-nodejs-web-applications-with-docker/) — Security focus
- [Lumigo: Docker Health Check Practical Guide](https://lumigo.io/container-monitoring/docker-health-check-a-practical-guide/) — Health check implementation
- [TRaSH Guides - Unraid File Structure](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Unraid/) — Volume mapping best practices

**Unraid Community:**
- [How to Submit New Docker Containers to Community Apps](https://forums.unraid.net/topic/55503-how-to-submit-new-docker-containers-to-community-apps/) — Submission process
- [CA - Application Policies & Privacy Policy](https://forums.unraid.net/topic/87144-ca-application-policies-notes/) — Approval requirements
- [Docker container developer best practice guidelines for unRAID](https://forums.unraid.net/topic/32278-docker-container-developer-best-practice-guidelines-for-unraid/) — Community standards
- [binhex/docker-templates](https://github.com/binhex/docker-templates) — Example templates

### TERTIARY (LOW confidence - needs validation)

**Implementation Details:**
- OpenClaw configuration paths and structure — Needs verification from OpenClaw source/docs
- OpenClaw Control UI health endpoints — Needs testing against actual application
- OpenClaw ARM64 compatibility — Needs investigation of build system and dependencies
- Game server Docker patterns from search results — General patterns, not OpenClaw-specific

---
*Research completed: 2026-02-01*
*Ready for roadmap: yes*
