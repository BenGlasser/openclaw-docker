# Roadmap: OpenClaw Docker for Unraid

## Overview

This roadmap delivers OpenClaw to the Unraid Community Applications catalog through four phases: build a production-ready Docker container with persistent storage, automate publishing to DockerHub, create and test the Unraid XML template, then submit to Community Applications with documentation and support infrastructure. Each phase builds on the previous, following the natural dependency chain from local development to community distribution.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Container Development** - Docker container with persistent volume and permission management
- [x] **Phase 2: Publishing Pipeline** - Automated DockerHub publishing via GitHub Actions
- [x] **Phase 3: Unraid Integration** - XML template and testing on Unraid server
- [ ] **Phase 4: Community Distribution** - Forum support and Community Applications submission
- [ ] **Phase 5: Enhanced Docker Publishing** - Mutable tag strategy and backfill workflow

## Phase Details

### Phase 1: Container Development
**Goal**: Users can run OpenClaw locally with persistent data and correct permissions
**Depends on**: Nothing (foundation)
**Requirements**: CONT-01, CONT-02, CONT-03, CONT-04, CONT-05, CONT-06, CONT-07, CONT-08
**Success Criteria** (what must be TRUE):
  1. Container runs OpenClaw Control UI accessible on port 18789
  2. Container survives restart with configuration and data intact (no data loss)
  3. Files in persistent volume have correct ownership for node user permissions
  4. Health check correctly reports container status (healthy/unhealthy)
  5. Container runs as non-root user with proper permissions
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Create Dockerfile, .dockerignore, entrypoint.sh, and healthcheck.js
- [x] 01-02-PLAN.md — Test persistence, permissions, health check, and user verification

### Phase 2: Publishing Pipeline
**Goal**: Docker images are automatically built and published to DockerHub with semantic versioning
**Depends on**: Phase 1
**Requirements**: AUTO-01, AUTO-02, AUTO-03, AUTO-04, DIST-01, DIST-02, DIST-03
**Success Criteria** (what must be TRUE):
  1. GitHub Actions builds image on push to main branch
  2. Image published to DockerHub with correct tags (latest, 1.0.0, 1.0, 1)
  3. Multi-platform manifest supports both AMD64 and ARM64 architectures
  4. Users can pull image with `docker pull username/openclaw:latest`
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md — Create GitHub Actions workflow for multi-platform Docker publishing to DockerHub

### Phase 3: Unraid Integration
**Goal**: Users can install OpenClaw through Unraid Docker interface with working template
**Depends on**: Phase 2
**Requirements**: UNRD-01, UNRD-02, UNRD-03, UNRD-04, UNRD-05, UNRD-06, UNRD-07, UNRD-08
**Success Criteria** (what must be TRUE):
  1. XML template created through Unraid Docker tab (not manually edited)
  2. Template includes all required fields (repository, icon, WebUI, support URL)
  3. User clicks WebUI link in Unraid Docker tab and reaches OpenClaw Control UI
  4. Volume mapping persists data to /mnt/user/appdata/openclaw/
  5. Container installation and update tested on actual Unraid server
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Create XML template and update entrypoint for PUID/PGID support
- [x] 03-02-PLAN.md — Test complete installation flow on Unraid server
- [x] 03-03-PLAN.md — Fix verification gaps: icon URL, volume path space, repository name

### Phase 4: Community Distribution
**Goal**: OpenClaw is available in Unraid Community Applications catalog for public installation
**Depends on**: Phase 3
**Requirements**: DIST-04, DIST-05, DIST-06
**Success Criteria** (what must be TRUE):
  1. Support thread exists on Unraid forums with installation instructions
  2. README includes volume mapping details and troubleshooting guidance
  3. Community Applications submission completed and approved
**Plans**: TBD

Plans:
- [ ] TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Container Development | 2/2 | Complete | 2026-02-01 |
| 2. Publishing Pipeline | 1/1 | Complete | 2026-02-02 |
| 3. Unraid Integration | 3/3 | Complete | 2026-02-02 |
| 4. Community Distribution | 0/TBD | Not started | - |
| 5. Enhanced Docker Publishing | 0/2 | Not started | - |

### Phase 5: Set up GitHub Actions workflows for Docker image builds and publishing

**Goal:** Enhanced Docker image tagging with three mutable tags (latest, beta, dev) recalculated on every trigger, plus a manual backfill workflow for building missing releases and refreshing mutable tags
**Requirements**: D-01, D-02, D-03, D-04, D-05, D-06, D-07, D-08, D-09, D-10, D-11, D-12
**Depends on:** Phase 2
**Plans:** 2 plans

Plans:
- [ ] 05-01-PLAN.md — Replace docker-publish.yml with enhanced mutable tag workflow (build-release + build-dev + sync-readme)
- [x] 05-02-PLAN.md — Create docker-backfill.yml manual workflow with two modes

---
*Roadmap created: 2026-02-01*
*Last updated: 2026-03-25*
*Phase 1 completed: 2026-02-01*
*Phase 2 completed: 2026-02-02*
*Phase 3 completed: 2026-02-02*
