# Phase 1: Container Development - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Docker container that runs OpenClaw Control UI with persistent storage to ~/.openclaw/, proper file permissions, and health monitoring. Installation and updates through Unraid Docker interface are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Base image and runtime
- Use `FROM node:22-bookworm` to match OpenClaw's existing Dockerfile
- Clone and build from source (fresh git clone + npm install during build)
- Always use latest main branch

### Permission handling strategy
- Use the existing `node` user from base image (default UID/GID from node:22-bookworm)
- No custom PUID/PGID environment variables - rely on base image defaults

### Volume structure and initialization
- Single volume mapping: host path → `/home/node/.openclaw/` in container
- Include basic troubleshooting tools: curl, bash, ps (not minimal production image)

### Claude's Discretion
- Port exposure beyond 18789 - determine based on OpenClaw's actual requirements
- Ownership fixing strategy - choose most user-friendly approach if files have wrong permissions
- Entrypoint initialization tasks - determine what's needed based on OpenClaw's setup requirements
- First-run handling - examine OpenClaw's startup behavior and handle appropriately
- Health check method - choose most reliable approach (HTTP vs process check)
- Health check timing - select appropriate interval, timeout, and startup grace period values

</decisions>

<specifics>
## Specific Ideas

- Match OpenClaw's existing development setup (node:22-bookworm base)
- Fresh git clone ensures users always get latest features
- Single volume keeps configuration simple for Unraid users

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 01-container-development*
*Context gathered: 2026-02-01*
