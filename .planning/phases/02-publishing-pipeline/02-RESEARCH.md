# Phase 2: Publishing Pipeline - Research

**Researched:** 2026-02-01
**Domain:** GitHub Actions CI/CD for Docker multi-platform publishing
**Confidence:** HIGH

## Summary

GitHub Actions provides official Docker actions for building and publishing multi-platform images to DockerHub. The standard stack consists of four official Docker actions (`docker/login-action`, `docker/setup-qemu-action`, `docker/setup-buildx-action`, `docker/build-push-action`) plus the `docker/metadata-action` for automated tag generation from git events.

For semantic versioning, the metadata-action automatically generates tag sets from git tags (v1.2.3 creates tags: 1.2.3, 1.2, 1, latest) and supports separate strategies for branch pushes. Multi-platform builds (AMD64/ARM64) use QEMU emulation on standard GitHub runners with buildx. Caching via GitHub Actions Cache (type=gha) is the recommended approach for public repositories, with mode=max significantly improving build times.

Common pitfalls include manifest list corruption when building platforms sequentially without proper merge strategies, GitHub Actions cache API rate limiting requiring token authentication, and security issues with DockerHub credentials. The workflow_dispatch trigger is standard practice for CI/CD workflows, enabling manual builds and debugging.

**Primary recommendation:** Use docker/metadata-action with semantic versioning patterns plus edge tag for main branch pushes, docker/build-push-action@v6 with type=gha caching in mode=max, and include workflow_dispatch for operational flexibility.

## Standard Stack

The established actions for Docker publishing to DockerHub:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| docker/login-action | v3 | Authenticate with DockerHub | Official Docker action, handles token management securely |
| docker/setup-qemu-action | v3 | Enable ARM64 emulation | Required for multi-platform builds on x86 runners |
| docker/setup-buildx-action | v3 | Configure buildx builder | Required for multi-platform and advanced caching |
| docker/build-push-action | v6 | Build and push images | Official Docker action, integrates buildx and caching |
| docker/metadata-action | v5 | Generate tags and labels | Official tag automation, supports semver and OCI labels |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| peter-evans/dockerhub-description | v4 | Sync README to DockerHub | Auto-update DockerHub description from GitHub README.md |
| actions/checkout | v4 | Clone repository | Only needed for path context (if Dockerfile uses local files beyond git clone) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| docker/build-push-action | docker/bake-action | Bake supports more complex multi-platform matrix strategies but adds complexity |
| GitHub Actions Cache (gha) | Registry cache | Registry cache avoids 10GB GitHub cache limit but costs registry storage |
| QEMU emulation | Native ARM64 runners | Native ARM64 runners are 10-30x faster but require self-hosted or paid runners |

**Installation:**
```yaml
# Actions are referenced in workflow YAML, not installed as packages
# Use in .github/workflows/docker-publish.yml
```

## Architecture Patterns

### Recommended Workflow Structure
```
.github/
└── workflows/
    └── docker-publish.yml    # Single workflow file with multiple triggers
```

### Pattern 1: Standard Multi-Platform Build with Tag Automation
**What:** Single workflow triggered by push to main and git tags, automatically generating appropriate tags based on event type
**When to use:** Standard practice for all Docker publishing workflows in 2026
**Example:**
```yaml
# Source: https://docs.docker.com/build/ci/github-actions/ + https://github.com/docker/metadata-action
name: Docker Build and Publish

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  workflow_dispatch:

env:
  REGISTRY_IMAGE: ${{ secrets.DOCKERHUB_USERNAME }}/openclaw

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY_IMAGE }}
          tags: |
            type=edge,branch=main
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Pattern 2: README Sync to DockerHub
**What:** Additional job to sync GitHub README.md to DockerHub repository description
**When to use:** Always include for public DockerHub repositories to maintain single source of truth
**Example:**
```yaml
# Source: https://github.com/peter-evans/dockerhub-description
- name: Checkout
  uses: actions/checkout@v4

- name: Docker Hub Description
  uses: peter-evans/dockerhub-description@v4
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
    repository: ${{ secrets.DOCKERHUB_USERNAME }}/openclaw
    readme-filepath: ./README.md
```

### Pattern 3: Conditional Push (Development Best Practice)
**What:** Build images on PRs for testing but only push to registry on main/tags
**When to use:** Recommended for production workflows to avoid registry clutter
**Example:**
```yaml
# Source: https://docs.docker.com/build/ci/github-actions/manage-tags-labels/
on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:

jobs:
  build:
    steps:
      # ... setup steps ...

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
```

### Anti-Patterns to Avoid
- **Hardcoded tags instead of metadata-action:** Requires manual version management and misses OCI labels
- **Building platforms sequentially with separate pushes:** Creates race condition where last platform overwrites manifest, resulting in single-arch image instead of manifest list
- **Using inline cache only:** Limited to min mode, significantly slower rebuilds compared to gha cache with mode=max
- **Not including workflow_dispatch:** Standard practice to include for operational flexibility (debugging, manual deployments)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tag generation from git events | Custom shell scripts parsing git refs | docker/metadata-action | Handles semver patterns, branch naming, PR tags, OCI labels, flavor customization |
| Multi-platform manifest creation | Manual docker buildx imagetools create | docker/build-push-action with platforms | Automatically creates and pushes manifest list, handles platform variants |
| DockerHub README updates | Curl commands to DockerHub API | peter-evans/dockerhub-description | Handles authentication, 25KB size limit, error handling, truncation warnings |
| Docker layer caching | actions/cache with manual tar archives | type=gha or type=registry | Native buildx integration, automatic layer detection, cache invalidation |
| Semantic version parsing | Regex to extract major.minor.patch | type=semver patterns in metadata-action | Handles pre-release tags, metadata suffixes, major version zero edge cases |

**Key insight:** GitHub Actions Docker ecosystem has mature official solutions. Custom scripts introduce security risks (credential handling), edge cases (pre-release versions, platform manifest merging), and maintenance burden that official actions already solve.

## Common Pitfalls

### Pitfall 1: Multi-Platform Manifest Corruption
**What goes wrong:** When building platforms separately (e.g., in matrix jobs) with each job pushing independently, the last push "wins" and overwrites previous platforms. Users pull single-architecture image instead of multi-platform manifest list.
**Why it happens:** DockerHub doesn't automatically merge platform-specific manifests. Each push replaces the tag completely.
**How to avoid:** Always use docker/build-push-action with platforms: linux/amd64,linux/arm64 in single build step, OR use matrix strategy with docker buildx imagetools create to merge digests.
**Warning signs:** Users report "no matching manifest for platform" errors, docker inspect shows single platform instead of manifest list

### Pitfall 2: GitHub Actions Cache API Rate Limiting
**What goes wrong:** Cache export fails with timeout errors during docker/build-push-action step. Build succeeds but cache isn't saved, causing subsequent builds to be slow.
**Why it happens:** GitHub Actions cache API has rate limits. Successive builds hitting the API without authentication can trigger throttling.
**How to avoid:** docker/build-push-action@v6 automatically handles token authentication. If using older versions or manual buildx commands, pass ghtoken parameter to cache backend.
**Warning signs:** Warnings in build logs about cache export timeouts, repeated builds showing no cache hits despite identical Dockerfiles

### Pitfall 3: Insecure Credential Management
**What goes wrong:** DockerHub credentials exposed in logs, stored as plaintext in workflow files, or using account password instead of access token.
**Why it happens:** Developers unfamiliar with GitHub secrets management or DockerHub access tokens.
**How to avoid:** Always use GitHub repository secrets for DOCKERHUB_TOKEN (use DockerHub access token, not password). Reference as ${{ secrets.DOCKERHUB_TOKEN }}. Use vars context for username. Never echo or expose credentials in workflow steps.
**Warning signs:** Credentials visible in workflow file, push failures with 401 unauthorized, inability to delete exposed credentials

### Pitfall 4: latest Tag Mismanagement
**What goes wrong:** latest tag points to pre-release versions, development builds, or becomes stale when using git tag-only triggers.
**Why it happens:** Misunderstanding how metadata-action applies latest tag. By default, latest is added to the most recent semver tag, not main branch pushes.
**How to avoid:** Be explicit about latest tag strategy. Use type=edge,branch=main for development tracking. For releases, latest automatically applies to highest semver tag unless disabled with flavor: latest=false.
**Warning signs:** Users report latest is old version, latest points to -rc or -beta tags, latest is ARM-only or AMD64-only

### Pitfall 5: Missing workflow_dispatch Trigger
**What goes wrong:** Unable to manually trigger builds for debugging, hotfixes, or testing without making dummy commits.
**Why it happens:** Developers only include automated triggers (push, tags) and forget manual triggering capability.
**How to avoid:** Always include workflow_dispatch: in trigger list. Standard practice in 2026. Zero cost, enables operational flexibility.
**Warning signs:** Need to make empty commits to trigger builds, unable to test workflow changes without merging to main

### Pitfall 6: Cache Growth Without Cleanup
**What goes wrong:** GitHub Actions cache fills 10GB limit, old cache entries aren't evicted, cache becomes fragmented and slow.
**Why it happens:** With type=gha, old cache entries aren't automatically deleted. Each build with unique scope creates new cache.
**How to avoid:** Use consistent scope parameter (default: buildkit). GitHub auto-evicts caches older than 7 days or when approaching 10GB. For faster cleanup, switch to type=registry if hitting limits.
**Warning signs:** Build logs show "cache full" warnings, cache-from shows no hits despite recent builds, increasing build times over time

### Pitfall 7: Dockerfile Context Issues
**What goes wrong:** Build fails with "COPY failed: file not found" when Dockerfile references local files not in git repository.
**Why it happens:** docker/build-push-action defaults to git context (doesn't clone repo). Local files from workspace aren't available unless explicitly using path context with actions/checkout.
**How to avoid:** For Dockerfiles using only git clone (like this project), no checkout needed. If COPY requires local files, add actions/checkout@v4 and set context: . in build-push-action.
**Warning signs:** Dockerfile builds locally but fails in CI with "no such file or directory" errors

## Code Examples

Verified patterns from official sources:

### Complete Production Workflow
```yaml
# Source: https://docs.docker.com/build/ci/github-actions/ + https://github.com/docker/metadata-action
# Combined pattern for semantic versioning with multi-platform builds

name: Docker Build and Publish

on:
  push:
    branches: [ main ]
    tags: [ 'v*.*.*' ]
  pull_request:
  workflow_dispatch:

env:
  REGISTRY_IMAGE: ${{ secrets.DOCKERHUB_USERNAME }}/openclaw

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY_IMAGE }}
          tags: |
            # Generate edge tag from main branch
            type=edge,branch=main
            # Generate semver tags from git tags
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
          flavor: |
            # latest tag is auto-applied to highest semver tag
            latest=auto

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: mode=max
          sbom: true

  sync-readme:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Sync README to Docker Hub
        uses: peter-evans/dockerhub-description@v4
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
          repository: ${{ secrets.DOCKERHUB_USERNAME }}/openclaw
          readme-filepath: ./README.md
```

### Tag Strategy Configuration Patterns
```yaml
# Source: https://github.com/docker/metadata-action

# Pattern 1: Edge tag for main branch (recommended for this project)
# Push to main → username/openclaw:edge
# Git tag v1.2.3 → username/openclaw:1.2.3, 1.2, 1, latest
tags: |
  type=edge,branch=main
  type=semver,pattern={{version}}
  type=semver,pattern={{major}}.{{minor}}
  type=semver,pattern={{major}}

# Pattern 2: Latest tag for main branch (alternative)
# Push to main → username/openclaw:latest
# Git tag v1.2.3 → username/openclaw:1.2.3, 1.2, 1, latest (overwrites)
tags: |
  type=ref,event=branch
  type=semver,pattern={{version}}
  type=semver,pattern={{major}}.{{minor}}
  type=semver,pattern={{major}}
flavor: |
  latest=true

# Pattern 3: Separate latest and edge (maximum flexibility)
# Push to main → username/openclaw:edge, latest
# Git tag v1.2.3 → username/openclaw:1.2.3, 1.2, 1
tags: |
  type=edge,branch=main
  type=raw,value=latest,enable={{is_default_branch}}
  type=semver,pattern={{version}}
  type=semver,pattern={{major}}.{{minor}}
  type=semver,pattern={{major}}
flavor: |
  latest=false
```

### Caching Configuration Patterns
```yaml
# Source: https://docs.docker.com/build/ci/github-actions/cache/

# Pattern 1: GitHub Actions Cache (recommended for public repos)
cache-from: type=gha
cache-to: type=gha,mode=max

# Pattern 2: Registry Cache (for large images or private repos hitting 10GB limit)
cache-from: type=registry,ref=${{ env.REGISTRY_IMAGE }}:buildcache
cache-to: type=registry,ref=${{ env.REGISTRY_IMAGE }}:buildcache,mode=max

# Pattern 3: Inline Cache (simplest but least efficient)
cache-from: type=registry,ref=${{ env.REGISTRY_IMAGE }}:latest
cache-to: type=inline
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| docker/build-push-action@v2 | docker/build-push-action@v6 | v6 released 2024 | Auto-handles authentication, provenance, SBOM generation |
| Manual tag generation scripts | docker/metadata-action@v5 | Standard since 2021 | Automatic semver parsing, OCI labels, event-based tagging |
| actions/cache with docker save/load | type=gha cache backend | Introduced 2021, v2 API required April 2025 | Native buildx integration, 80%+ faster than manual caching |
| Single platform builds | Multi-platform with QEMU | Standard since 2020 | AMD64 + ARM64 by default, required for Apple Silicon + ARM servers |
| Docker passwords | Access tokens | Enforced ~2022 | Required for automation, better security granularity |

**Deprecated/outdated:**
- **GitHub Actions Cache v1 API**: Deprecated April 2025, requires buildx v0.21.0+ for v2 API. Workflows using old versions will fail.
- **docker driver**: Incompatible with modern features (multi-platform, advanced caching). Always use docker-container driver via setup-buildx-action.
- **Manual manifest creation**: docker manifest create/push replaced by build-push-action automatic manifest list creation
- **type=semver,pattern={{raw}}**: Deprecated in favor of pattern={{version}} for full semver tag

## Open Questions

1. **Optimal cache strategy for this specific Dockerfile**
   - What we know: Dockerfile includes git clone, pnpm install, pnpm build, pnpm ui:build. Heavy dependencies likely benefit from mode=max.
   - What's unclear: Whether registry cache (mode=max) would be better than gha cache given large node_modules and build artifacts.
   - Recommendation: Start with type=gha,mode=max (standard approach). Monitor cache hit rates and build times. If hitting 10GB limit or slow cache, switch to registry cache.

2. **Edge vs latest tag for main branch pushes**
   - What we know: edge tag is Docker official image pattern (Alpine uses this). latest typically points to stable releases.
   - What's unclear: User expectation for this project - do users expect latest to track main or latest stable release?
   - Recommendation: Use edge tag for main branch (type=edge,branch=main). Let latest tag come from git tags only. This is clearest distinction between development (edge) and stable (latest). Document in README.

3. **Major version zero handling**
   - What we know: Project is pre-1.0. Semantic versioning treats 0.x as unstable. metadata-action recommends not generating tag 0 for version 0.x.y.
   - What's unclear: Whether project wants 0.x.y tags to generate 0.x and 0 tags, or skip major tag until 1.0 release.
   - Recommendation: Include pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }} to skip major tag for 0.x versions. When 1.0 releases, tag 1 becomes available.

## Sources

### Primary (HIGH confidence)
- Docker official docs: Build with GitHub Actions - https://docs.docker.com/build/ci/github-actions/
- Docker official docs: Multi-platform with GitHub Actions - https://docs.docker.com/build/ci/github-actions/multi-platform/
- Docker official docs: Cache management - https://docs.docker.com/build/ci/github-actions/cache/
- Docker official docs: GitHub Actions cache backend - https://docs.docker.com/build/cache/backends/gha/
- Docker official docs: Manage tags and labels - https://docs.docker.com/build/ci/github-actions/manage-tags-labels/
- docker/build-push-action GitHub repository - https://github.com/docker/build-push-action
- docker/metadata-action GitHub repository - https://github.com/docker/metadata-action
- peter-evans/dockerhub-description GitHub repository - https://github.com/peter-evans/dockerhub-description

### Secondary (MEDIUM confidence)
- Cache is King: Docker layer caching guide (Blacksmith, 2024+) - https://www.blacksmith.sh/blog/cache-is-king-a-guide-for-docker-layer-caching-in-github-actions
- Building Multi-Platform Docker Images for ARM64 (Blacksmith, 2024+) - https://www.blacksmith.sh/blog/building-multi-platform-docker-images-for-arm64-in-github-actions
- Best practices for managing secrets in GitHub Actions (Blacksmith, 2024+) - https://www.blacksmith.sh/blog/best-practices-for-managing-secrets-in-github-actions
- Using Semver for Docker Image Tags (Medium, Marc Campbell) - https://medium.com/@mccode/using-semantic-versioning-for-docker-image-tags-dfde8be06699
- GitHub Actions workflow_dispatch guide (Graphite) - https://graphite.com/guides/github-actions-workflow-dispatch

### Tertiary (LOW confidence)
- None - all key findings verified with official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All actions are official Docker actions with verified current versions (v3, v5, v6)
- Architecture patterns: HIGH - Patterns extracted directly from Docker official documentation and action README files
- Tag strategies: HIGH - Semantic versioning patterns verified in docker/metadata-action official docs
- Caching: HIGH - Cache types and modes verified in official Docker buildx cache backend documentation
- Pitfalls: MEDIUM-HIGH - Common issues verified across official docs, GitHub issue trackers, and community reports
- Security practices: HIGH - DockerHub token requirements and secrets management verified in Docker and GitHub official docs

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - stable ecosystem, official actions update quarterly)

---

**Notes for planner:**
- User has locked in: DockerHub personal account, repository name "openclaw", dual triggers (push to main + git tags), multi-platform (AMD64+ARM64)
- Claude's discretion: Tag strategy for main (recommend: edge tag), workflow_dispatch (recommend: include), caching (recommend: type=gha,mode=max), workflow structure (recommend: single workflow with conditional push)
- All recommended actions are official Docker actions except peter-evans/dockerhub-description (community action with 1.4k+ stars, actively maintained)
- No package installation needed - all functionality via GitHub Actions workflow YAML
- Secrets required: DOCKERHUB_USERNAME (repository variable), DOCKERHUB_TOKEN (repository secret - access token not password)
