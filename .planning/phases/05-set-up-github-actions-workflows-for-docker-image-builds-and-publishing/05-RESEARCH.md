# Phase 5: GitHub Actions Docker Build and Publishing Workflows - Research

**Researched:** 2026-03-25
**Domain:** GitHub Actions CI/CD, Docker image publishing, semantic versioning, DockerHub API
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Tag Resolution Logic**
- D-01: Production releases = semver tags without pre-release suffix (e.g., v1.0.0, v2.3.1). `latest` Docker tag points to the highest stable semver.
- D-02: Beta releases = semver tags with `-beta` suffix (e.g., v1.1.0-beta.1). `beta` Docker tag points to the highest `-beta` suffixed semver. Other pre-release suffixes (-alpha, -rc) are NOT included in beta.
- D-03: `dev` Docker tag = HEAD of main branch, always. Rebuilt on every push to main regardless of release state.
- D-04: All three mutable tags (latest, beta, dev) are recalculated and rebuilt on every trigger (push to main, tag push). Keeps everything in sync.
- D-05: Semver expansion preserved from Phase 2: v1.0.0 creates Docker tags 1.0.0, 1.0, 1 (plus latest if highest stable).

**Workflow Structure**
- D-06: Replace existing docker-publish.yml with enhanced version. One auto-trigger workflow handles push-to-main and tag push events with the new mutable tag logic.
- D-07: Create a separate docker-backfill.yml for manual workflow_dispatch operations.
- D-08: README sync job stays in the main docker-publish.yml workflow as a dependent job.

**Manual Backfill Design**
- D-09: Backfill workflow uses text input for git tag (user types e.g., v1.0.0). Workflow validates the tag exists.
- D-10: Two modes in backfill: (1) build specific tag + update mutable tags, (2) mutable-only rebuild (recalculate and rebuild latest/beta/dev without building a specific release).
- D-11: If a tag already has an image on DockerHub, skip with warning. No overwrite by default.

**Docker Registry Naming**
- D-12: All images in same repo: brglasser/openclaw. Tags: latest, beta, dev, plus versioned tags (1.0.0, 1.0, 1, etc.). No separate repos.

### Claude's Discretion
- Implementation details of semver sorting/comparison in workflow scripts
- How to check DockerHub for existing images (API call or docker manifest inspect)
- Build optimization and caching strategy
- Error handling and notification patterns
- Whether to remove the existing `edge` tag or keep it alongside `dev`

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Summary

This phase replaces the existing single-job docker-publish.yml with two workflows: an enhanced auto-trigger workflow that implements the three mutable tag strategy (latest, beta, dev), and a separate manual backfill workflow with two operational modes. The core technical challenge is the mutable tag resolution logic — determining which git tag is currently the "highest stable semver" and "highest beta semver" must happen at runtime via a bash shell step, because docker/metadata-action alone cannot introspect across all existing git tags to find the global maximum.

The existing workflow already has all structural building blocks: QEMU + Buildx for multi-platform, GHA caching, provenance/SBOM, README sync, and proper secrets/vars usage. The enhancement layer adds a git-tag-scanning step that computes which tag deserves each mutable tag, then uses `type=raw` entries in metadata-action with `enable=` expressions to conditionally apply those mutable tags. The backfill workflow introduces `workflow_dispatch` with `choice` and `string` inputs, plus a DockerHub manifest existence check before building.

**Primary recommendation:** Use a bash script step to compute mutable tag assignments into GITHUB_OUTPUT, then consume those booleans in metadata-action `enable=` expressions. This keeps the tag logic auditable and testable while staying within the standard docker action ecosystem.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| docker/metadata-action | v6.0.0 | Extract/generate Docker tags and OCI labels | Official Docker action; v6 migrated to Node 24 (March 2025) |
| docker/build-push-action | v7.0.0 | Build multi-platform images and push to registry | Official Docker action; v7 migrated to Node 24 (March 2025) |
| docker/setup-qemu-action | v3 | Cross-platform emulation for ARM builds | Required for linux/arm64 on amd64 runners |
| docker/setup-buildx-action | v3 | Docker Buildx builder setup | Required for multi-platform and cache support |
| docker/login-action | v3 | DockerHub authentication | Official action; handles credential scoping |
| peter-evans/dockerhub-description | v5.0.0 | Sync README.md to DockerHub | Current stable; v5 requires runner v2.327.1+ |
| actions/checkout | v4 | Checkout repository | Standard; required for git tag scanning |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| git (built-in) | system | Tag sorting and semver filtering | Used in bash steps to compute mutable tag targets |
| curl + jq (built-in on ubuntu-latest) | system | DockerHub manifest existence check | Used in backfill workflow before building |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bash git tag script | ietf-tools/semver-action | Third-party action adds dependency; bash is transparent and fully auditable |
| docker manifest inspect | DockerHub v2 registry API (curl) | `docker manifest inspect` requires experimental Docker config; curl to registry-1.docker.io is more reliable in CI |
| docker manifest inspect | tyriis/docker-image-tag-exists | Third-party action; unnecessary dependency for a simple HTTP check |

**Installation:** No installation needed — these are GitHub Actions; referenced by `uses:` in workflow YAML. Actions runner (ubuntu-latest) includes bash, git, curl, and jq by default.

**Version verification (confirmed 2026-03-25):**
- docker/metadata-action: v6.0.0 (released 2025-03-05)
- docker/build-push-action: v7.0.0 (released 2025-03-05)
- peter-evans/dockerhub-description: v5.0.0 (released 2024-10-01)
- docker/setup-qemu-action: v3 (current major; no v4 released)
- docker/setup-buildx-action: v3 (current major; no v4 released)
- docker/login-action: v3 (current major; no v4 released)
- actions/checkout: v4 (current major)

---

## Architecture Patterns

### Recommended Workflow Structure

```
.github/workflows/
├── docker-publish.yml    # Auto-trigger: push to main + tag push (REPLACES existing)
└── docker-backfill.yml   # Manual: workflow_dispatch for backfill/mutable refresh
```

### Pattern 1: Mutable Tag Resolution via Shell Script Step

**What:** A bash step runs before metadata-action. It scans all git tags, identifies the highest stable semver and highest beta semver, compares them against the current trigger ref, and writes boolean outputs (`is_latest_target`, `is_beta_target`) to `GITHUB_OUTPUT`. Downstream metadata-action `type=raw` entries consume those booleans via `enable=`.

**When to use:** Any time mutable tag assignment requires cross-tag comparison (finding the global maximum), which metadata-action cannot do natively.

**Example:**
```yaml
- name: Resolve mutable tag targets
  id: mutable
  run: |
    git fetch --tags --quiet

    # Highest stable semver (no pre-release suffix)
    LATEST_TAG=$(git tag --sort=-v:refname \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
      | head -1)

    # Highest beta semver (only -beta suffix, not -alpha, -rc)
    BETA_TAG=$(git tag --sort=-v:refname \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+-beta(\.[0-9]+)?$' \
      | head -1)

    CURRENT_REF="${{ github.ref_name }}"

    echo "latest_tag=${LATEST_TAG}" >> $GITHUB_OUTPUT
    echo "beta_tag=${BETA_TAG}" >> $GITHUB_OUTPUT

    # Set booleans for enable= expressions
    if [ "$CURRENT_REF" = "$LATEST_TAG" ]; then
      echo "is_latest_target=true" >> $GITHUB_OUTPUT
    else
      echo "is_latest_target=false" >> $GITHUB_OUTPUT
    fi

    if [ "$CURRENT_REF" = "$BETA_TAG" ]; then
      echo "is_beta_target=true" >> $GITHUB_OUTPUT
    else
      echo "is_beta_target=false" >> $GITHUB_OUTPUT
    fi

    # dev tag always applies on main push; on tag push, dev must be rebuilt
    # to point to current main HEAD. Track whether this is a main push.
    if [ "${{ github.ref }}" = "refs/heads/main" ]; then
      echo "is_dev_target=true" >> $GITHUB_OUTPUT
    else
      echo "is_dev_target=false" >> $GITHUB_OUTPUT
    fi
```

```yaml
- name: Extract metadata (tags, labels)
  id: meta
  uses: docker/metadata-action@v6
  with:
    images: ${{ env.REGISTRY_IMAGE }}
    flavor: |
      latest=false
    tags: |
      # Immutable versioned tags (only on tag push)
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
      type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
      # Mutable tags — conditionally applied based on shell script results
      type=raw,value=latest,enable=${{ steps.mutable.outputs.is_latest_target }}
      type=raw,value=beta,enable=${{ steps.mutable.outputs.is_beta_target }}
      type=raw,value=dev,enable=${{ steps.mutable.outputs.is_dev_target }}
```

**Key note:** `flavor: latest=false` disables metadata-action's automatic latest assignment. The manual `type=raw,value=latest` entry provides explicit control instead.

**Source:** [docker/metadata-action GitHub](https://github.com/docker/metadata-action), [Docker build CI docs](https://docs.docker.com/build/ci/github-actions/manage-tags-labels/)

### Pattern 2: Dev Tag on Tag Push (Rebuild main HEAD)

**What:** When a tag push triggers the workflow, the `dev` tag (which always represents main HEAD) must also be refreshed. This requires a second build job targeting the main branch checkout, or a single job that builds both the tagged commit and the main HEAD when triggered by a tag push.

**Recommended approach:** On tag push, the single build job outputs both the versioned tags AND the dev tag by checking out main and building twice, or by using a matrix job. The simpler approach is two jobs: `build-release` (triggered on tag) and `build-dev` (triggered on main push and on tag push targeting main). The `build-dev` job always checks out main.

**Example (two-job approach):**
```yaml
jobs:
  build-release:
    if: startsWith(github.ref, 'refs/tags/')
    # ... builds versioned tags + latest/beta if applicable

  build-dev:
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')
    # ... always checks out main branch, builds dev tag
    steps:
      - uses: actions/checkout@v4
        with:
          ref: main   # Always build main HEAD for dev tag
```

### Pattern 3: Backfill Workflow with Mode Selection

**What:** `workflow_dispatch` with a `choice` input for mode and `string` input for git tag. The workflow validates the provided tag exists, optionally checks DockerHub for image existence (skip if found), then builds.

**When to use:** Recovering from failed CI runs, building tags that predated the CI workflow, or refreshing mutable tags after an out-of-band change.

**Example:**
```yaml
on:
  workflow_dispatch:
    inputs:
      mode:
        description: 'Operation mode'
        required: true
        type: choice
        options:
          - build-tag-and-update-mutable
          - mutable-only
        default: mutable-only
      git_tag:
        description: 'Git tag to build (e.g., v1.0.0) — required for build-tag-and-update-mutable mode'
        required: false
        type: string
```

**Validation step:**
```yaml
- name: Validate inputs
  run: |
    MODE="${{ github.event.inputs.mode }}"
    TAG="${{ github.event.inputs.git_tag }}"

    if [ "$MODE" = "build-tag-and-update-mutable" ]; then
      if [ -z "$TAG" ]; then
        echo "ERROR: git_tag input is required for build-tag-and-update-mutable mode"
        exit 1
      fi
      # Validate tag format
      if ! echo "$TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-beta(\.[0-9]+)?)?$'; then
        echo "ERROR: git_tag must be semver format (v1.0.0 or v1.0.0-beta.1)"
        exit 1
      fi
      # Validate tag exists in repo
      git fetch --tags
      if ! git tag -l | grep -qx "$TAG"; then
        echo "ERROR: Tag $TAG does not exist in the repository"
        exit 1
      fi
    fi
```

**Source:** [GitHub Actions workflow_dispatch docs](https://graphite.com/guides/github-actions-workflow-dispatch), [GitHub Changelog: Input types](https://github.blog/changelog/2021-11-10-github-actions-input-types-for-manual-workflows/)

### Pattern 4: DockerHub Existence Check

**What:** Before building a specific tag in the backfill workflow, check if the image already exists on DockerHub to avoid overwriting (D-11). Uses curl against the Docker Registry v2 API with a bearer token from the Docker auth service.

**Example:**
```yaml
- name: Check if image already exists on DockerHub
  id: image-check
  run: |
    IMAGE="${{ vars.DOCKERHUB_USERNAME }}/openclaw"
    TAG="${{ github.event.inputs.git_tag }}"
    # Strip leading 'v' for Docker tag (v1.0.0 → 1.0.0)
    DOCKER_TAG="${TAG#v}"

    # Get anonymous bearer token for pull scope
    TOKEN=$(curl -fsSL \
      "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull" \
      | jq -r '.token')

    # Check manifest existence — 200 means exists, 404 means not found
    HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
      "https://registry-1.docker.io/v2/${IMAGE}/manifests/${DOCKER_TAG}")

    if [ "$HTTP_CODE" = "200" ]; then
      echo "Image ${IMAGE}:${DOCKER_TAG} already exists — skipping build"
      echo "image_exists=true" >> $GITHUB_OUTPUT
    else
      echo "image_exists=false" >> $GITHUB_OUTPUT
    fi

- name: Build and push
  if: steps.image-check.outputs.image_exists != 'true'
  uses: docker/build-push-action@v7
  # ...
```

**Source:** [DockerHub Registry API examples](https://www.arthurkoziel.com/dockerhub-registry-api/), [Docker manifest docs](https://docs.docker.com/reference/cli/docker/manifest/)

### Anti-Patterns to Avoid

- **Relying on metadata-action alone for mutable tag logic:** metadata-action cannot compare the current trigger against all other tags to determine "highest." It only knows about the current ref. Use a shell script step to compute the comparison.
- **Setting `latest=auto` in flavor when managing latest manually:** This causes metadata-action to apply `latest` automatically on tag events, conflicting with the custom logic. Explicitly set `flavor: latest=false` and use `type=raw,value=latest,enable=...` instead.
- **Not fetching tags before sorting:** Shallow checkouts (default for `actions/checkout`) do not include all tags. Must run `git fetch --tags` before the mutable tag resolution step.
- **Using `git tag | sort -V` for semver with pre-release:** GNU `sort -V` treats `-beta.1` unexpectedly. The `git tag --sort=-v:refname` git-native sort handles semver pre-release precedence correctly per semver spec (pre-release < release).
- **Building dev from the tagged commit:** The `dev` tag must always represent main HEAD. When triggered by a tag push, the build job for `dev` must explicitly check out `refs/heads/main`, not the tagged commit.
- **Storing DOCKERHUB_PW in the wrong secret:** The existing pattern uses `secrets.DOCKERHUB_TOKEN` for docker/login-action (push access) and `secrets.DOCKERHUB_PW` for peter-evans/dockerhub-description (README sync). These are distinct credentials; do not swap them.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-platform Docker builds | Custom buildx scripts | docker/build-push-action@v7 | Handles manifest lists, attestations, provenance |
| OCI label generation | Manual label strings | docker/metadata-action@v6 | Auto-generates org.opencontainers.image.* labels |
| QEMU cross-compilation setup | Manual QEMU install | docker/setup-qemu-action@v3 | Handles binfmt_misc registration correctly |
| GHA layer cache management | Custom cache keys | `cache-from/cache-to: type=gha` | GHA cache is ephemeral/scoped; action handles invalidation |
| README sync to DockerHub | Custom curl to DockerHub API | peter-evans/dockerhub-description@v5 | Handles auth, content truncation at 25,000 byte limit |
| Semver comparison across tags | Custom semver parser | `git tag --sort=-v:refname` + grep | Git's built-in version sort handles semver pre-release precedence |

**Key insight:** The Docker action ecosystem (metadata, build-push, login, setup-qemu, setup-buildx) is a cohesive family designed to work together. The only gap it has for this phase is cross-tag comparison for mutable tag resolution — that specific gap should be filled with a shell script, not a third-party action.

---

## Common Pitfalls

### Pitfall 1: Shallow Clone Missing Tags
**What goes wrong:** `git tag --sort=-v:refname` returns only the tags reachable in the shallow checkout, missing older tags. The "highest stable tag" computation returns wrong results.
**Why it happens:** `actions/checkout@v4` performs a shallow clone by default (depth=1).
**How to avoid:** Add `git fetch --tags --unshallow` (or `git fetch --tags`) before any git tag scanning step. Alternatively, use `fetch-depth: 0` in the checkout step.
**Warning signs:** Mutable tag computation returns a tag that is not actually the global maximum.

### Pitfall 2: Tag Sort with Pre-Release Confusion
**What goes wrong:** `sort -V` or `sort -t. -k1,1n -k2,2n -k3,3n` misorders semver pre-release tags. `v1.1.0-beta.1` may sort higher than `v1.1.0` with naive sort.
**Why it happens:** Standard sort tools treat `-` as a separator character in ways that don't match semver spec (pre-release versions have lower precedence than release versions).
**How to avoid:** Use `git tag --sort=-v:refname` which uses Git's built-in version sort, implementing the semver specification correctly. For stable-only filtering, pipe through `grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$'` to exclude any tag containing a hyphen.
**Warning signs:** The `latest` tag points to a `-beta` version.

### Pitfall 3: Dev Tag Points to Tagged Commit, Not main HEAD
**What goes wrong:** When a tag push triggers the workflow, the checkout is at the tagged commit. Building `dev` from that commit means `dev` stops tracking main HEAD.
**Why it happens:** `actions/checkout@v4` without an explicit `ref` checks out the ref that triggered the workflow.
**How to avoid:** For the dev build job, always specify `ref: main` in the checkout step, regardless of the triggering event.
**Warning signs:** After pushing v1.0.0, the `dev` tag no longer reflects commits made to main after that tag.

### Pitfall 4: `edge` Tag Collision with `dev` Logic
**What goes wrong:** The existing workflow uses `type=edge,branch=main` which creates an `edge` tag on every main push. With the new `dev` tag serving the same purpose, two tags pointing to main HEAD creates confusing semantics.
**Why it happens:** The existing docker-publish.yml was not aware of the new tag strategy.
**How to avoid:** Remove `type=edge,branch=main` from the new workflow. If backward compatibility for `edge` is needed (existing users pulling `edge`), keep it as an alias alongside `dev` with `type=raw,value=edge,enable=${{ steps.mutable.outputs.is_dev_target }}`.
**Warning signs:** Both `dev` and `edge` appear in DockerHub and point to the same image.

### Pitfall 5: Backfill Mutable-Only Mode Requires a Build
**What goes wrong:** The "mutable-only" backfill mode (D-10) sounds like it only updates tags, but Docker does not support retagging without re-pushing. Updating `latest` to point to an existing image digest requires pulling the manifest and re-pushing it, or rebuilding.
**Why it happens:** Docker tags are pointers to image digests; to move a tag, you must push an image or manifest to that tag.
**How to avoid:** In mutable-only mode, the workflow must still execute docker/build-push-action against the resolved target commit (latest stable tag, latest beta tag, and main HEAD), building all three mutable images. It should skip the immutable versioned tags (1.0.0, 1.0, 1). This is effectively the same build as normal — just without building a user-specified new version.
**Warning signs:** Mutable-only mode completes instantly with no push activity, but DockerHub shows stale digest for `latest`.

### Pitfall 6: GITHUB_OUTPUT Expression Evaluation Timing
**What goes wrong:** Using `steps.mutable.outputs.is_latest_target` in a `type=raw,enable=` expression inside metadata-action fails if the shell script step hasn't run yet, or if the expression evaluates at parse time rather than runtime.
**Why it happens:** GitHub Actions expressions in `with:` blocks evaluate at job step execution time, but YAML multi-line `|` blocks in `tags:` sometimes confuse people about when values are substituted.
**How to avoid:** Ensure the mutable tag resolution step (`id: mutable`) runs before the metadata-action step. The expression `${{ steps.mutable.outputs.is_latest_target }}` evaluates at the step's runtime, not at YAML parse time. Test with explicit `echo` steps to validate output values.
**Warning signs:** `enable=` always evaluates to false, causing no tags to be applied.

---

## Code Examples

Verified patterns from official sources:

### Existing Workflow Structure (Preserved Base)
```yaml
# Source: .github/workflows/docker-publish.yml (current)
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Login to Docker Hub
  if: github.event_name != 'pull_request'
  uses: docker/login-action@v3
  with:
    username: ${{ vars.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

- name: Build and push
  uses: docker/build-push-action@v7
  with:
    platforms: linux/amd64,linux/arm64
    push: ${{ github.event_name != 'pull_request' }}
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
    provenance: mode=max
    sbom: true
```

### Metadata-Action with Manual Latest Control
```yaml
# Source: docker/metadata-action v6 docs
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v6
  with:
    images: ${{ env.REGISTRY_IMAGE }}
    flavor: |
      latest=false
    tags: |
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
      type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
      type=raw,value=latest,enable=${{ steps.mutable.outputs.is_latest_target }}
      type=raw,value=beta,enable=${{ steps.mutable.outputs.is_beta_target }}
      type=raw,value=dev,enable=${{ steps.mutable.outputs.is_dev_target }}
```

### Semver Tag Filtering in Bash (Git Native)
```bash
# Source: git documentation + verified against git tag --sort behavior
# Highest stable semver (no hyphen = no pre-release)
LATEST_TAG=$(git tag --sort=-v:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | head -1)

# Highest beta semver (only -beta suffix, not -alpha or -rc)
BETA_TAG=$(git tag --sort=-v:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+-beta(\.[0-9]+)?$' \
  | head -1)
```

### workflow_dispatch with Choice and String Inputs
```yaml
# Source: GitHub Actions docs - workflow_dispatch input types
on:
  workflow_dispatch:
    inputs:
      mode:
        description: 'Operation mode'
        required: true
        type: choice
        options:
          - build-tag-and-update-mutable
          - mutable-only
        default: mutable-only
      git_tag:
        description: 'Git tag to build (e.g., v1.0.0)'
        required: false
        type: string
```

### DockerHub Bearer Token + Manifest Check
```bash
# Source: https://www.arthurkoziel.com/dockerhub-registry-api/
IMAGE="brglasser/openclaw"
TAG="1.0.0"  # Docker tag without leading 'v'

TOKEN=$(curl -fsSL \
  "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull" \
  | jq -r '.token')

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  "https://registry-1.docker.io/v2/${IMAGE}/manifests/${TAG}")

# HTTP_CODE == "200" → exists, "404" → does not exist
```

### README Sync (Upgraded from v4 to v5)
```yaml
# Source: peter-evans/dockerhub-description v5
- name: Sync README to Docker Hub
  uses: peter-evans/dockerhub-description@v5
  with:
    username: ${{ vars.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_PW }}
    repository: ${{ vars.DOCKERHUB_USERNAME }}/openclaw
    readme-filepath: ./README.md
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| docker/metadata-action@v5 | docker/metadata-action@v6 | March 2025 | Node 24 runtime; API compatible |
| docker/build-push-action@v6 | docker/build-push-action@v7 | March 2025 | Node 24 runtime; API compatible |
| peter-evans/dockerhub-description@v4 | v5 | October 2024 | Node 24 runtime; v5 requires runner v2.327.1+ |
| `flavor: latest=auto` | `flavor: latest=false` + explicit `type=raw,value=latest` | Ongoing best practice | Required when latest needs conditional logic beyond "is default branch" |

**Deprecated/outdated in existing workflow:**
- `type=edge,branch=main`: Superseded by `type=raw,value=dev` in new strategy — should be removed
- `docker/build-push-action@v6`: Working but current is v7 (Node 24); low priority upgrade
- `peter-evans/dockerhub-description@v4`: Working but v5 is current; worth upgrading in this pass

---

## Open Questions

1. **Does the `dev` build in the main publish workflow need a separate checkout step targeting `refs/heads/main`?**
   - What we know: On tag push, `actions/checkout` checks out the tagged commit. The build job produces versioned tags AND must produce `dev` pointing to main HEAD.
   - What's unclear: Whether two builds in the same job (one at tagged commit, one at main) are feasible with docker/build-push-action, or whether two separate jobs (build-release, build-dev) are cleaner.
   - Recommendation: Use two jobs. `build-release` runs only on tag push; `build-dev` runs on both main push and tag push, always checking out main. `sync-readme` depends on both.

2. **Backfill "mutable-only" mode: which commits to target for latest/beta/dev?**
   - What we know: Latest = main checkout for the commit pointed to by the highest stable tag. Beta = commit pointed to by highest beta tag. Dev = current main HEAD.
   - What's unclear: Building "latest" in mutable-only mode requires checking out the tagged commit (not main). This means mutable-only mode may need multiple build steps or a matrix for the three targets.
   - Recommendation: In mutable-only mode, build three times: checkout `$LATEST_TAG` and push `latest`, checkout `$BETA_TAG` and push `beta`, checkout `main` and push `dev`. Each is a separate step with a different `context` or a separate job.

3. **`edge` tag backward compatibility: keep or remove?**
   - What we know: Current workflow emits `edge` on every main push. This is within Claude's discretion.
   - Recommendation: Remove `edge` from the new workflow. The `dev` tag serves the same purpose with a clearer name. If any downstream tooling depends on `edge`, it will need to migrate to `dev`. DockerHub tags persist even after workflow removal — a one-time manual cleanup step may be needed to remove the stale `edge` tag from DockerHub.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GitHub Actions runner (ubuntu-latest) | All workflow jobs | ✓ | ubuntu-latest | — |
| git (with --sort=-v:refname) | Mutable tag resolution | ✓ | git 2.43+ on ubuntu-latest | — |
| curl + jq | DockerHub existence check | ✓ | Both pre-installed on ubuntu-latest | — |
| DOCKERHUB_TOKEN secret | docker/login-action | ✓ (already configured) | — | — |
| DOCKERHUB_PW secret | peter-evans/dockerhub-description | ✓ (already configured) | — | — |
| DOCKERHUB_USERNAME var | Registry image name | ✓ (already configured) | — | — |

**Missing dependencies with no fallback:** None.

**Note:** The existing `git tag` in this repo currently has only one tag (`1.0`). Testing the mutable tag resolution logic will require creating test tags or verifying logic against a repo with multiple semver tags.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None (workflow YAML only — shell script logic testable manually) |
| Config file | N/A |
| Quick run command | `act push` (if act is installed locally) or trigger workflow manually |
| Full suite command | GitHub Actions workflow run via push/tag |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-01 | `latest` tag points to highest stable semver on tag push | smoke | Manual: push a tag, verify DockerHub | ❌ manual only |
| D-02 | `beta` tag points to highest `-beta` semver on tag push | smoke | Manual: push a beta tag, verify DockerHub | ❌ manual only |
| D-03 | `dev` tag rebuilds on every push to main | smoke | Manual: push to main, verify DockerHub | ❌ manual only |
| D-04 | All three mutable tags recalculated on every trigger | smoke | Manual: trigger workflow, verify all tags updated | ❌ manual only |
| D-05 | Semver expansion: v1.0.0 creates tags 1.0.0, 1.0, 1 | smoke | Manual: push version tag, verify DockerHub | ❌ manual only |
| D-09 | Backfill validates tag exists before building | unit-like | Manual: trigger backfill with invalid tag, expect failure | ❌ manual only |
| D-11 | Backfill skips existing image with warning | unit-like | Manual: trigger backfill for existing tag, verify skip | ❌ manual only |

**Note:** GitHub Actions workflows cannot be unit-tested without running them against GitHub. The shell script logic (semver sorting, tag detection) can be tested locally with `bash` but there is no automated test harness in this repo. Validation is primarily smoke testing via manual workflow runs.

### Sampling Rate
- **Per task commit:** Lint YAML with `actionlint` if available; otherwise visual review
- **Per wave merge:** Manual trigger of both workflows against a test tag
- **Phase gate:** Full workflow run producing expected DockerHub tags before phase complete

### Wave 0 Gaps
- [ ] `actionlint` not confirmed installed — workflow YAML linting optional but recommended
- [ ] Test tags may need to be created in the repo to exercise multi-tag semver logic

*(If actionlint is not available locally, visual YAML review and the GitHub Actions UI validation on PR is the fallback)*

---

## Sources

### Primary (HIGH confidence)
- [docker/metadata-action GitHub](https://github.com/docker/metadata-action) — tag types, flavor config, enable expressions, v6 version
- [docker/build-push-action releases](https://github.com/docker/build-push-action/releases) — v7.0.0 confirmed current (2025-03-05)
- [docker/metadata-action releases](https://github.com/docker/metadata-action/releases) — v6.0.0 confirmed current (2025-03-05)
- [peter-evans/dockerhub-description releases](https://github.com/peter-evans/dockerhub-description/releases) — v5.0.0 confirmed current (2024-10-01)
- `.github/workflows/docker-publish.yml` — existing workflow structure, established patterns
- `.planning/phases/05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing/05-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- [DockerHub Registry API examples (arthurkoziel.com)](https://www.arthurkoziel.com/dockerhub-registry-api/) — bearer token + manifest check pattern; verified against Docker v2 API spec
- [Docker manage-tags-labels docs](https://docs.docker.com/build/ci/github-actions/manage-tags-labels/) — official Docker CI documentation
- [Git tag sort documentation (andycarter.dev)](https://andycarter.dev/blog/sort-git-tags-by-ascending-and-descending-semver) — `git tag --sort=-v:refname` behavior
- [GitHub Actions expression functions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/evaluate-expressions-in-workflows-and-actions) — startsWith, contains, enable= behavior
- [GitHub Changelog: workflow_dispatch input types](https://github.blog/changelog/2021-11-10-github-actions-input-types-for-manual-workflows/) — choice, boolean, string input types

### Tertiary (LOW confidence)
- WebSearch results on semver sorting patterns — verified against git documentation; patterns confirmed

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions verified against GitHub releases (2026-03-25)
- Architecture: HIGH — patterns derived from existing working workflow + official action docs
- Shell script semver logic: HIGH — `git tag --sort=-v:refname` + grep is git-native, well-documented
- DockerHub API check: MEDIUM — pattern from third-party article, but verified against Docker v2 API spec structure
- Pitfalls: HIGH — most derived from direct analysis of the constraints (D-01 through D-12)

**Research date:** 2026-03-25
**Valid until:** 2026-06-25 (90 days; GitHub Actions action major versions are stable)
