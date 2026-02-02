# Requirements: OpenClaw Docker for Unraid

**Defined:** 2026-02-01
**Core Value:** Unraid users can install and run OpenClaw with a few clicks, and their configuration and data persists across container restarts without manual intervention.

## v1 Requirements

Requirements for initial Community Apps submission. Each maps to roadmap phases.

### Container Foundation

- [x] **CONT-01**: Container uses Node.js 22 Bookworm base image with fresh git clone build
- [x] **CONT-02**: ~/.openclaw/ directory mapped to persistent volume at /mnt/user/appdata/openclaw/
- [x] **CONT-03**: Container runs as non-root node user with proper permissions
- [x] **CONT-04**: Entrypoint script handles permission scenarios gracefully before starting OpenClaw
- [x] **CONT-05**: OpenClaw Control UI accessible on configurable port (default 18789)
- [x] **CONT-06**: Container runs as non-root user with proper permissions
- [x] **CONT-07**: Health check configured to monitor OpenClaw service status
- [x] **CONT-08**: Container survives restarts with all config and data intact

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

- [x] **DIST-01**: Docker image published to DockerHub with public access
- [x] **DIST-02**: Image tagged with semantic versioning (1.0.0, 1.0, 1, latest)
- [x] **DIST-03**: Multi-platform Docker manifest supports AMD64 and ARM64
- [ ] **DIST-04**: Support thread created on Unraid forums before submission
- [ ] **DIST-05**: README includes installation instructions and volume mapping details
- [ ] **DIST-06**: Community Applications submission completed and approved

### Automation & CI/CD

- [x] **AUTO-01**: GitHub Actions workflow builds Docker image on push to main
- [x] **AUTO-02**: GitHub Actions workflow publishes to DockerHub with proper tags
- [x] **AUTO-03**: GitHub Actions builds multi-platform images (AMD64 + ARM64)
- [x] **AUTO-04**: Automated builds triggered on version tags (v*)

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
| CONT-01 | Phase 1 | Complete |
| CONT-02 | Phase 1 | Complete |
| CONT-03 | Phase 1 | Complete |
| CONT-04 | Phase 1 | Complete |
| CONT-05 | Phase 1 | Complete |
| CONT-06 | Phase 1 | Complete |
| CONT-07 | Phase 1 | Complete |
| CONT-08 | Phase 1 | Complete |
| UNRD-01 | Phase 3 | Complete |
| UNRD-02 | Phase 3 | Complete |
| UNRD-03 | Phase 3 | Complete |
| UNRD-04 | Phase 3 | Complete |
| UNRD-05 | Phase 3 | Complete |
| UNRD-06 | Phase 3 | Complete |
| UNRD-07 | Phase 3 | Complete |
| UNRD-08 | Phase 3 | Complete |
| DIST-01 | Phase 2 | Complete |
| DIST-02 | Phase 2 | Complete |
| DIST-03 | Phase 2 | Complete |
| DIST-04 | Phase 4 | Pending |
| DIST-05 | Phase 4 | Pending |
| DIST-06 | Phase 4 | Pending |
| AUTO-01 | Phase 2 | Complete |
| AUTO-02 | Phase 2 | Complete |
| AUTO-03 | Phase 2 | Complete |
| AUTO-04 | Phase 2 | Complete |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-01*
*Last updated: 2026-02-02 after Phase 3 completion*
