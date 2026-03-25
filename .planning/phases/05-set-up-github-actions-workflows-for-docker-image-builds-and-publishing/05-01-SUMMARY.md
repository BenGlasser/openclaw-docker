---
phase: 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing
plan: 01
subsystem: infra
tags: [github-actions, docker, dockerhub, semver, ci-cd]

# Dependency graph
requires:
  - phase: 02-publishing-pipeline
    provides: existing docker-publish.yml with multi-platform builds, GHA caching, README sync
provides:
  - Enhanced docker-publish.yml with three-job mutable tag strategy (latest, beta, dev)
  - Mutable tag resolution via git tag scanning + GITHUB_OUTPUT booleans
  - Semver-aware tag expansion on release builds
affects:
  - Future phases using DockerHub image distribution
  - Any workflow modifications to docker-publish.yml

# Tech tracking
tech-stack:
  added:
    - docker/metadata-action@v6 (upgraded from v5)
    - docker/build-push-action@v7 (upgraded from v6)
    - peter-evans/dockerhub-description@v5 (upgraded from v4)
  patterns:
    - "Mutable tag resolution: bash step computes is_latest_target/is_beta_target booleans, metadata-action consumes via enable= expressions"
    - "Two-job pattern: build-release (tag-only) + build-dev (main+tag, always ref: main)"
    - "flavor: latest=false with explicit type=raw,value=latest for full control"

key-files:
  created: []
  modified:
    - .github/workflows/docker-publish.yml

key-decisions:
  - "Removed type=edge (replaced by type=raw,value=dev with clearer semantics)"
  - "build-dev always checks out ref: main regardless of trigger, ensuring dev tracks main HEAD"
  - "sync-readme uses always() + skipped-job tolerance so it runs after either build job succeeds or is skipped"
  - "build-release login step has no pull_request guard (job is already gated by if: startsWith(github.ref, 'refs/tags/'))"

patterns-established:
  - "Mutable Docker tags resolved via shell script step before metadata-action, not metadata-action alone"
  - "fetch-depth: 0 required in tag-triggered jobs for complete git tag history"

requirements-completed: [D-01, D-02, D-03, D-04, D-05, D-06, D-08]

# Metrics
duration: 1min
completed: 2026-03-25
---

# Phase 05 Plan 01: Enhanced Docker Publish Workflow Summary

**Three-job mutable tag workflow replacing single-job build: latest/beta/dev resolved via git tag scanning with build-push-action@v7 and metadata-action@v6**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-25T16:38:47Z
- **Completed:** 2026-03-25T16:39:53Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Replaced single-job docker-publish.yml with three-job workflow (build-release, build-dev, sync-readme)
- Implemented mutable tag resolution: bash step scans git tags, computes is_latest_target/is_beta_target booleans consumed by metadata-action enable= expressions
- Upgraded all action versions: metadata-action v5→v6, build-push-action v6→v7, dockerhub-description v4→v5
- build-dev always checks out ref: main to ensure dev tag tracks main HEAD even on tag push triggers
- Removed obsolete type=edge tag; dev tag provides same semantics with clearer naming

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace docker-publish.yml with enhanced mutable tag workflow** - `5bcf6cd` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified
- `.github/workflows/docker-publish.yml` - Enhanced three-job workflow: build-release (tag-only with mutable resolution), build-dev (main+tag, always ref: main), sync-readme (graceful skipped-job handling)

## Decisions Made
- Removed `type=edge` from new workflow — `dev` tag serves the same purpose with clearer semantics per research recommendation
- `build-dev` does not need a `build-release` dependency — both jobs run independently, sync-readme waits for both
- `sync-readme` condition uses `always()` + explicit result checks for skipped-job tolerance, ensuring it runs after any successful build trigger

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Existing GitHub Actions secrets (DOCKERHUB_TOKEN, DOCKERHUB_PW) and variable (DOCKERHUB_USERNAME) are unchanged.

## Next Phase Readiness

- Enhanced docker-publish.yml is committed and ready to activate on next push to main or tag push
- Three mutable tags (latest, beta, dev) will be computed correctly on every trigger
- Phase 05 Plan 02 (docker-backfill.yml) can now be created as a separate workflow_dispatch workflow

## Self-Check: PASSED

- docker-publish.yml: FOUND
- 05-01-SUMMARY.md: FOUND
- commit 5bcf6cd: FOUND

---
*Phase: 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing*
*Completed: 2026-03-25*
