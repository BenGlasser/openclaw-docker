# Phase 2: Publishing Pipeline - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Automated Docker image building and publishing to DockerHub with semantic versioning. GitHub Actions workflow builds multi-platform images (AMD64, ARM64) and publishes them to DockerHub with appropriate tags. Users can pull images with standard Docker commands.

</domain>

<decisions>
## Implementation Decisions

### DockerHub setup
- Personal account hosting (not organization)
- Repository name: `openclaw` (short, matches project name)
- README auto-syncs from GitHub README.md (single source of truth)
- Repository will be `username/openclaw` on DockerHub

### Trigger strategy
- Dual trigger: both push to main AND git tags
- Push to main: Updates tracking tags (researcher/planner determines best practice for 'latest' vs 'latest'+'dev')
- Git tags (v1.0.0 format): Creates full semver set — 1.0.0, 1.0, 1, latest
- Manual workflow dispatch: Claude's discretion (include if standard practice)

### Claude's Discretion
- Exact tag strategy for main branch pushes (latest-only vs latest+dev/edge)
- Whether to include workflow_dispatch for manual triggering
- Build optimization strategy (layer caching, parallelization)
- GitHub Actions workflow structure and job organization

</decisions>

<specifics>
## Specific Ideas

- Tag format follows semantic versioning: v1.0.0 creates Docker tags 1.0.0, 1.0, 1, latest
- Multi-platform support is required: AMD64 and ARM64 architectures
- Success criteria requires `docker pull username/openclaw:latest` to work

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-publishing-pipeline*
*Context gathered: 2026-02-01*
