# Phase 5: Set up GitHub Actions workflows for Docker image builds and publishing - Context

**Gathered:** 2026-03-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Enhanced Docker image tagging and publishing workflows. Replaces the existing docker-publish.yml with an enhanced version supporting three mutable Docker tags (latest, beta, dev) that are recalculated on every trigger. Adds a separate manual backfill workflow for building missing release images and refreshing mutable tags on demand.

</domain>

<decisions>
## Implementation Decisions

### Tag Resolution Logic
- **D-01:** Production releases = semver tags without pre-release suffix (e.g., v1.0.0, v2.3.1). `latest` Docker tag points to the highest stable semver.
- **D-02:** Beta releases = semver tags with `-beta` suffix (e.g., v1.1.0-beta.1). `beta` Docker tag points to the highest `-beta` suffixed semver. Other pre-release suffixes (-alpha, -rc) are NOT included in beta.
- **D-03:** `dev` Docker tag = HEAD of main branch, always. Rebuilt on every push to main regardless of release state.
- **D-04:** All three mutable tags (latest, beta, dev) are recalculated and rebuilt on every trigger (push to main, tag push). Keeps everything in sync.
- **D-05:** Semver expansion preserved from Phase 2: v1.0.0 creates Docker tags 1.0.0, 1.0, 1 (plus latest if highest stable).

### Workflow Structure
- **D-06:** Replace existing docker-publish.yml with enhanced version. One auto-trigger workflow handles push-to-main and tag push events with the new mutable tag logic.
- **D-07:** Create a separate docker-backfill.yml for manual workflow_dispatch operations.
- **D-08:** README sync job stays in the main docker-publish.yml workflow as a dependent job.

### Manual Backfill Design
- **D-09:** Backfill workflow uses text input for git tag (user types e.g., v1.0.0). Workflow validates the tag exists.
- **D-10:** Two modes in backfill: (1) build specific tag + update mutable tags, (2) mutable-only rebuild (recalculate and rebuild latest/beta/dev without building a specific release).
- **D-11:** If a tag already has an image on DockerHub, skip with warning. No overwrite by default.

### Docker Registry Naming
- **D-12:** All images in same repo: brglasser/openclaw. Tags: latest, beta, dev, plus versioned tags (1.0.0, 1.0, 1, etc.). No separate repos.

### Claude's Discretion
- Implementation details of semver sorting/comparison in workflow scripts
- How to check DockerHub for existing images (API call or docker manifest inspect)
- Build optimization and caching strategy
- Error handling and notification patterns
- Whether to remove the existing `edge` tag or keep it alongside `dev`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Workflow
- `.github/workflows/docker-publish.yml` -- Current workflow being replaced; contains build matrix, caching, README sync patterns
- `Dockerfile` -- Build target for all workflow jobs

### Phase 2 Context
- `.planning/phases/02-publishing-pipeline/02-CONTEXT.md` -- Original publishing decisions (DockerHub setup, trigger strategy, tag format)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docker-publish.yml`: Existing workflow with QEMU setup, Buildx, multi-platform builds, GHA caching, README sync — core structure can be preserved and enhanced
- `docker/metadata-action@v5`: Already in use for tag extraction — may need custom logic to supplement it for mutable tag resolution

### Established Patterns
- GitHub Actions variables: `vars.DOCKERHUB_USERNAME` for non-sensitive config, `secrets.DOCKERHUB_TOKEN` for auth
- Multi-platform builds: `linux/amd64,linux/arm64` via QEMU + Buildx
- GHA cache: `cache-from: type=gha` / `cache-to: type=gha,mode=max`
- Provenance and SBOM generation enabled

### Integration Points
- DockerHub repository: brglasser/openclaw
- GitHub repo triggers: push to main, tag push (v*.*.*), workflow_dispatch
- README sync uses separate secret: `secrets.DOCKERHUB_PW` (distinct from DOCKERHUB_TOKEN)

</code_context>

<specifics>
## Specific Ideas

- The existing `edge` tag in docker-publish.yml may be redundant with the new `dev` tag — Claude can decide whether to keep or remove it
- Mutable tag resolution requires scanning git tags and sorting by semver — this will likely need a shell script step in the workflow
- The backfill workflow's "check if image exists" step could use `docker manifest inspect` or DockerHub API

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing*
*Context gathered: 2026-03-25*
