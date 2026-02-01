# Requirements: OpenClaw Docker for Unraid

**Defined:** 2026-02-01
**Core Value:** Unraid users can install and run OpenClaw with a few clicks, and their configuration and data persists across container restarts without manual intervention.

## v1 Requirements

Requirements for initial Community Apps submission. Each maps to roadmap phases.

### Container Foundation

- [ ] **CONT-01**: Container uses Node.js 22 Alpine base image with multi-stage build
- [ ] **CONT-02**: ~/.openclaw/ directory mapped to persistent volume at /mnt/user/appdata/openclaw/
- [ ] **CONT-03**: Container accepts PUID and PGID environment variables (default 99:100)
- [ ] **CONT-04**: Entrypoint script fixes file ownership based on PUID/PGID before starting OpenClaw
- [ ] **CONT-05**: OpenClaw Control UI accessible on configurable port (default 18789)
- [ ] **CONT-06**: Container runs as non-root user with proper permissions
- [ ] **CONT-07**: Health check configured to monitor OpenClaw service status
- [ ] **CONT-08**: Container survives restarts with all config and data intact

### Unraid Integration

- [ ] **UNRD-01**: XML template created via Unraid Docker tab (not manually edited)
- [ ] **UNRD-02**: Template includes repository, registry, icon, and support thread URLs
- [ ] **UNRD-03**: Template configures WebUI field for Control UI access (:18789)
- [ ] **UNRD-04**: Template includes PUID/PGID variables with descriptions and defaults
- [ ] **UNRD-05**: Template volume path follows /mnt/user/appdata/openclaw/ convention
- [ ] **UNRD-06**: Icon and banner assets available via HTTPS PNG URLs
- [ ] **UNRD-07**: Template includes category tags for proper Community Apps placement
- [ ] **UNRD-08**: Template tested via local Unraid installation

### Distribution & Publishing

- [ ] **DIST-01**: Docker image published to DockerHub with public access
- [ ] **DIST-02**: Image tagged with semantic versioning (1.0.0, 1.0, 1, latest)
- [ ] **DIST-03**: Multi-platform Docker manifest supports AMD64 and ARM64
- [ ] **DIST-04**: Support thread created on Unraid forums before submission
- [ ] **DIST-05**: README includes installation instructions and volume mapping details
- [ ] **DIST-06**: Community Applications submission completed and approved

### Automation & CI/CD

- [ ] **AUTO-01**: GitHub Actions workflow builds Docker image on push to main
- [ ] **AUTO-02**: GitHub Actions workflow publishes to DockerHub with proper tags
- [ ] **AUTO-03**: GitHub Actions builds multi-platform images (AMD64 + ARM64)
- [ ] **AUTO-04**: Automated builds triggered on version tags (v*)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Features

- **ENHA-01**: Template includes example configurations for common use cases
- **ENHA-02**: Changelog documentation for version history
- **ENHA-03**: Update notifications in Community Apps
- **ENHA-04**: s6-overlay integration for multi-process supervision
- **ENHA-05**: Automated testing pipeline for container validation

### Advanced Configuration

- **ADVN-01**: Environment variable configuration for OpenClaw settings
- **ADVN-02**: Branch selection (stable/beta) in XML template
- **ADVN-03**: GPU passthrough support (if OpenClaw requires it)
- **ADVN-04**: Custom network mode options in template

## Out of Scope

| Feature | Reason |
|---------|--------|
| Docker Compose files | Unraid doesn't support Docker Compose natively - uses XML templates |
| Privileged mode | Security risk unless absolutely necessary; OpenClaw likely doesn't need it |
| Root user execution | Violates Unraid best practices and creates permission issues |
| In-place binary upgrades | Container updates handle upgrades; adds complexity |
| Bundling multiple services | OpenClaw is single service; follows Unix philosophy |
| Custom GUI beyond OpenClaw's Control UI | OpenClaw provides Control UI at :18789; no need to duplicate |
| Forking OpenClaw codebase | Maintain compatibility with upstream; package, don't modify |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONT-01 | TBD | Pending |
| CONT-02 | TBD | Pending |
| CONT-03 | TBD | Pending |
| CONT-04 | TBD | Pending |
| CONT-05 | TBD | Pending |
| CONT-06 | TBD | Pending |
| CONT-07 | TBD | Pending |
| CONT-08 | TBD | Pending |
| UNRD-01 | TBD | Pending |
| UNRD-02 | TBD | Pending |
| UNRD-03 | TBD | Pending |
| UNRD-04 | TBD | Pending |
| UNRD-05 | TBD | Pending |
| UNRD-06 | TBD | Pending |
| UNRD-07 | TBD | Pending |
| UNRD-08 | TBD | Pending |
| DIST-01 | TBD | Pending |
| DIST-02 | TBD | Pending |
| DIST-03 | TBD | Pending |
| DIST-04 | TBD | Pending |
| DIST-05 | TBD | Pending |
| DIST-06 | TBD | Pending |
| AUTO-01 | TBD | Pending |
| AUTO-02 | TBD | Pending |
| AUTO-03 | TBD | Pending |
| AUTO-04 | TBD | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 0 (pending roadmap creation)
- Unmapped: 28 ⚠️

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-01 after initial definition*
