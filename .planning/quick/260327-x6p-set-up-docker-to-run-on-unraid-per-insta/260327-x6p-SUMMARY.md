---
phase: quick
plan: 260327-x6p
subsystem: docker
tags: [dockerfile, entrypoint, unraid, alignment, cleanup]
dependency_graph:
  requires: []
  provides: [official-docs-aligned-docker-setup]
  affects: [Dockerfile, entrypoint.sh, unraid-template/openclaw.xml]
tech_stack:
  added: []
  patterns: [node-user-uid-1000, curl-healthcheck, dumb-init-entrypoint]
key_files:
  created: []
  modified:
    - Dockerfile
    - entrypoint.sh
    - unraid-template/openclaw.xml
  deleted:
    - connect-qr.sh
    - healthcheck.js
decisions:
  - "Use curl /healthz inline in Dockerfile HEALTHCHECK instead of a separate healthcheck.js node script"
  - "Remove EXPOSE 3001 and 3334 — only port 18789 is used per official docs"
metrics:
  duration: "~5 min"
  completed: "2026-03-28T05:58:16Z"
  tasks_completed: 2
  files_changed: 5
---

# Quick Task 260327-x6p: Align Docker Setup with Official OpenClaw Docs

**One-liner:** Aligned Dockerfile, entrypoint.sh, and Unraid template with official OpenClaw Docker docs — node user (uid 1000), dist/index.js CMD, /healthz health check, /home/node/.openclaw volume path, no stale files.

## What Was Done

This quick task fixed six mismatches between the Docker setup and the official OpenClaw Docker install documentation:

1. **User:** Changed from root to `USER node` (uid 1000)
2. **CMD binary:** Changed from `openclaw.mjs` to `dist/index.js`
3. **Health check:** Replaced `healthcheck.js` node script with `curl -f http://localhost:18789/healthz || exit 1`
4. **Volume path:** Changed from `/data/.openclaw` (with symlink) to `/home/node/.openclaw` throughout
5. **Stale entrypoint commands:** Removed `./connect-qr.sh || true` call
6. **Unraid template:** Updated `Target="/data/.openclaw"` to `Target="/home/node/.openclaw"`

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Align Dockerfile and entrypoint.sh | 0553cb2 | Dockerfile, entrypoint.sh |
| 2 | Align Unraid template, remove stale files | 4f458bc | unraid-template/openclaw.xml, connect-qr.sh (deleted), healthcheck.js (deleted) |

## Verification Results

All 8 plan verification checks passed:

1. `USER node` present in Dockerfile
2. `dist/index.js` in CMD
3. `/healthz` in HEALTHCHECK
4. Only 1 EXPOSE directive (18789)
5. Unraid template Target="/home/node/.openclaw"
6. docker-compose.yml already used /home/node/.openclaw (no changes needed)
7. connect-qr.sh and healthcheck.js absent from repo
8. No stale commands in entrypoint.sh

## Deviations from Plan

None - plan executed exactly as written.

The entrypoint.sh in the worktree already lacked `apt install go || true` (that line appeared in the main repo copy but was already absent in the worktree branch). The `./connect-qr.sh || true` line was still present and was removed as planned.

## Known Stubs

None.

## Self-Check: PASSED

- Dockerfile: EXISTS
- entrypoint.sh: EXISTS
- unraid-template/openclaw.xml: EXISTS
- connect-qr.sh: ABSENT (deleted as intended)
- healthcheck.js: ABSENT (deleted as intended)
- Commit 0553cb2: EXISTS
- Commit 4f458bc: EXISTS
