---
phase: 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing
plan: 02
subsystem: infra
tags: [github-actions, docker, dockerhub, ci-cd, semver, workflow-dispatch]

# Dependency graph
requires:
  - phase: 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing
    provides: "docker-publish.yml patterns: QEMU+Buildx multi-platform, GHA cache, DOCKERHUB_USERNAME vars/secrets patterns"
provides:
  - "Manual backfill workflow (.github/workflows/docker-backfill.yml) with two operational modes"
  - "DockerHub image existence check before building (prevents overwriting)"
  - "Input validation: semver format check + git tag existence check"
  - "Matrix-based mutable tag rebuild (latest/beta/dev from correct commits)"
affects: [phase-05-verification, future-release-management]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "workflow_dispatch with choice and string input types for manual CI operation"
    - "Job-level outputs pattern: validate job computes derived values (latest_tag, beta_tag) consumed by downstream jobs"
    - "DockerHub v2 registry API manifest check via curl + auth.docker.io bearer token"
    - "Matrix strategy for multi-target builds (latest/beta/dev) with skip field for empty tag resolution"
    - "Conditional step execution via if: steps.image-check.outputs.image_exists != 'true' pattern"
    - "always() && needs.validate.result == 'success' for jobs that run after skippable jobs"

key-files:
  created:
    - .github/workflows/docker-backfill.yml
  modified: []

key-decisions:
  - "build-mutable job uses always() condition so it runs in both modes (after build-tag completes or is skipped)"
  - "Matrix skip field handles missing stable/beta tags -- empty string from git tag sorting causes skip"
  - "build-tag job uses per-step if conditions (not job-level) to allow image-check to always run"

patterns-established:
  - "Job output chaining: validate job writes mode/git_tag/latest_tag/beta_tag, downstream jobs consume via needs.validate.outputs.*"
  - "DockerHub existence check: GET manifest from registry-1.docker.io/v2/{image}/manifests/{tag} with bearer token from auth.docker.io"
  - "Mutable tag skip: matrix.skip field set to needs.validate.outputs.latest_tag == '' expression"

requirements-completed: [D-07, D-09, D-10, D-11, D-12]

# Metrics
duration: 1min
completed: 2026-03-25
---

# Phase 05 Plan 02: Docker Backfill Workflow Summary

**Manual backfill workflow with two modes (build-tag-and-update-mutable, mutable-only), DockerHub existence check, and matrix-based mutable tag refresh via git tag sorting**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-25T16:38:39Z
- **Completed:** 2026-03-25T16:40:03Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `.github/workflows/docker-backfill.yml` with `workflow_dispatch` trigger supporting two operational modes
- Implemented three-job pipeline: `validate` (input + tag resolution), `build-tag` (specific version with existence check), `build-mutable` (matrix rebuild of latest/beta/dev)
- Input validation rejects missing tags, invalid semver format, and non-existent git tags with clear error messages
- DockerHub manifest check via v2 registry API prevents overwriting existing images (D-11)
- Matrix strategy rebuilds each mutable tag from its correct commit: latest tag commit, beta tag commit, main HEAD for dev

## Task Commits

Each task was committed atomically:

1. **Task 1: Create docker-backfill.yml manual workflow** - `0fbc22f` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `.github/workflows/docker-backfill.yml` - Manual backfill workflow with validate/build-tag/build-mutable jobs

## Decisions Made

- `build-mutable` uses `always() && needs.validate.result == 'success'` so it runs after `build-tag` is skipped in mutable-only mode (skipped jobs have result 'skipped', not 'success')
- Matrix `skip` field is set via job output expressions; steps using `if: matrix.skip != 'true'` avoid errors when no stable/beta tags exist yet
- `build-tag` job uses per-step `if` conditions rather than job-level skip so the `image-check` step always runs and produces the output needed by downstream steps

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - workflow is complete and functional. The skip logic for missing tags is intentional design (not a stub).

## Self-Check: PASSED

- `.github/workflows/docker-backfill.yml` exists: FOUND
- Task commit `0fbc22f` exists: FOUND (verified via git log)

---
*Phase: 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing*
*Completed: 2026-03-25*
