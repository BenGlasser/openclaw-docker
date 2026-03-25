# Phase 5: Set up GitHub Actions workflows for Docker image builds and publishing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-25
**Phase:** 05-set-up-github-actions-workflows-for-docker-image-builds-and-publishing
**Areas discussed:** Tag resolution logic, Workflow structure, Manual backfill design, Docker registry naming

---

## Tag Resolution Logic

### How should 'latest' (production) be determined?

| Option | Description | Selected |
|--------|-------------|----------|
| Semver without suffix = production | Tags like v1.0.0, v2.3.1 are production. Tags with -beta, -alpha, -rc suffixes are pre-release. | ✓ |
| GitHub Release marked as 'latest' | Use GitHub's release metadata. Whatever release is marked 'Latest' becomes 'latest' Docker tag. | |
| Explicit promotion | Require a manual step to promote a tag to 'latest'. | |

**User's choice:** Semver without suffix = production
**Notes:** Clean separation — no suffix means stable.

### How should the 'beta' tag be resolved?

| Option | Description | Selected |
|--------|-------------|----------|
| Highest semver with -beta suffix | Scan git tags, find the highest version matching *-beta*. Only -beta suffix. | ✓ |
| Any pre-release suffix | The 'beta' Docker tag points to the highest pre-release of any kind. | |
| Most recent pre-release GitHub Release | Use GitHub's 'pre-release' checkbox. | |

**User's choice:** Highest semver with -beta suffix
**Notes:** Only -beta suffix counts, not -alpha or -rc.

### When should mutable tags be rebuilt?

| Option | Description | Selected |
|--------|-------------|----------|
| Rebuild all three on every trigger | Push to main rebuilds dev + recalculates latest/beta. Tag push also recalculates. | ✓ |
| Only rebuild affected tag | Push to main only rebuilds dev. Tag push only builds that tag. | |
| Split logic | Tag events update release tags, main events update dev only. | |

**User's choice:** Rebuild all three on every trigger
**Notes:** Keeps everything in sync always.

### Should dev always track HEAD of main?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, dev = HEAD of main always | dev always tracks main branch HEAD regardless of release tags. | ✓ |
| Only if main is ahead of latest | Skip dev tag when main matches the latest release tag exactly. | |

**User's choice:** Yes, dev = HEAD of main always

---

## Workflow Structure

### Modify existing or create new?

| Option | Description | Selected |
|--------|-------------|----------|
| Replace existing with enhanced version | Rewrite docker-publish.yml with new tag logic. One workflow handles all auto triggers. | ✓ |
| Keep existing + add new workflow | Leave docker-publish.yml as-is, add new workflow for mutable tags. | |
| Split into multiple focused workflows | Separate files for push-to-main, tag releases, manual backfill. | |

**User's choice:** Replace existing with enhanced version

### Manual backfill: same or separate workflow?

| Option | Description | Selected |
|--------|-------------|----------|
| Separate workflow file | Create docker-backfill.yml with workflow_dispatch. | ✓ |
| Same workflow with dispatch inputs | Add workflow_dispatch inputs to docker-publish.yml. | |

**User's choice:** Separate workflow file

### README sync placement

| Option | Description | Selected |
|--------|-------------|----------|
| Keep in main workflow | README sync stays as dependent job in docker-publish.yml. | ✓ |
| Move to its own workflow | Separate file, only triggers on README changes. | |
| You decide | Claude's discretion. | |

**User's choice:** Keep in main workflow

---

## Manual Backfill Design

### How to accept input?

| Option | Description | Selected |
|--------|-------------|----------|
| Text input for git tag | User types a git tag in workflow_dispatch input. Workflow validates it exists. | ✓ |
| Dropdown of recent tags | Choice input with predefined list. | |
| Build all missing tags at once | Scan all tags, check DockerHub, build missing ones. | |

**User's choice:** Text input for git tag

### Mutable-only rebuild option?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add checkbox for mutable-only rebuild | Two modes: build specific tag + mutable, or just mutable tags. | ✓ |
| No, always require a tag input | Keep simple. Push to main for mutable updates. | |
| You decide | Claude's discretion. | |

**User's choice:** Yes, add checkbox for mutable-only rebuild

### Handle existing images?

| Option | Description | Selected |
|--------|-------------|----------|
| Skip with warning | Check DockerHub first. If image exists, log warning and skip. | ✓ |
| Always rebuild/overwrite | Rebuild regardless of existing images. | |
| Add a force flag | Default skip, allow force rebuild checkbox. | |

**User's choice:** Skip with warning

---

## Docker Registry Naming

### Same repo or separate?

| Option | Description | Selected |
|--------|-------------|----------|
| Same repo, different tags | All images in brglasser/openclaw. One repo, many tags. | ✓ |
| Separate repos for stability tiers | brglasser/openclaw, brglasser/openclaw-beta, etc. | |

**User's choice:** Same repo, different tags

### Semver expansion strategy?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep existing expansion | v1.0.0 creates 1.0.0, 1.0, 1 plus latest if highest. | ✓ |
| Only exact version | v1.0.0 only creates 1.0.0. | |
| You decide | Claude's discretion. | |

**User's choice:** Keep existing expansion

---

## Claude's Discretion

- Implementation details of semver sorting in workflow scripts
- DockerHub image existence check method
- Build optimization and caching strategy
- Whether to remove or keep the existing `edge` tag

## Deferred Ideas

None — discussion stayed within phase scope
