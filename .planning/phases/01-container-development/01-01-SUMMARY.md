---
phase: 01-container-development
plan: 01
subsystem: infra
tags: [docker, node, openclaw, dumb-init, pnpm, healthcheck]

# Dependency graph
requires: []
provides:
  - Buildable Docker image for OpenClaw Control UI
  - Container runs on node:22-bookworm with dumb-init PID 1
  - Health check monitoring gateway availability
  - Persistent volume support for /home/node/.openclaw
  - Non-root execution as node user (UID 1000)
affects: [02-unraid-template, 03-testing, 04-documentation]

# Tech tracking
tech-stack:
  added: [docker, dumb-init, pnpm@10.23.0, node:22-bookworm]
  patterns: [exec-form-commands, init-system-pid1, non-root-user, http-healthcheck]

key-files:
  created: [Dockerfile, .dockerignore, entrypoint.sh, healthcheck.js]
  modified: []

key-decisions:
  - "Use pnpm instead of npm (required by OpenClaw package.json)"
  - "Build Control UI assets during image build (pnpm ui:build)"
  - "Bind to LAN mode (0.0.0.0) for Docker port mapping"
  - "Generate random token if OPENCLAW_GATEWAY_TOKEN not set"
  - "Use --allow-unconfigured flag for first-run without setup"

patterns-established:
  - "dumb-init as ENTRYPOINT with exec form for signal handling"
  - "Entrypoint script uses exec to replace shell with main process"
  - "Health check uses Node.js http module (no curl dependency)"
  - "60-second start period for git clone + build operations"

# Metrics
duration: 19min
completed: 2026-02-01
---

# Phase 1 Plan 1: Container Foundation Summary

**Complete Docker container build for OpenClaw Control UI with pnpm tooling, built UI assets, and auto-generated auth token**

## Performance

- **Duration:** 19 minutes
- **Started:** 2026-02-01T23:09:54Z
- **Completed:** 2026-02-01T23:29:01Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Docker image builds successfully from node:22-bookworm base
- OpenClaw Control UI accessible on port 18789 with full UI assets
- Container runs as non-root node user with dumb-init handling PID 1
- Health check correctly monitors gateway availability
- Persistent volume support for configuration and data
- Automatic token generation for first-run without manual configuration

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Dockerfile and .dockerignore** - `a7453f5` (feat)
2. **Task 2: Create entrypoint.sh and healthcheck.js + fixes** - `10eae82` (fix)

## Files Created/Modified
- `Dockerfile` - Multi-stage container build with pnpm, TypeScript compilation, and UI build
- `.dockerignore` - Excludes node_modules, .git, .planning, and other unnecessary files from build context
- `entrypoint.sh` - Initializes volume permissions, generates auth token, logs startup info
- `healthcheck.js` - HTTP health check against OpenClaw gateway on port 18789

## Decisions Made

**Use pnpm instead of npm:** OpenClaw's package.json specifies `"packageManager": "pnpm@10.23.0"` and build scripts require pnpm. Enabled via corepack.

**Build UI assets in Dockerfile:** Control UI requires `pnpm ui:build` to generate static assets. Without this, HTTP endpoint shows error message instead of UI.

**Bind to LAN mode:** Added `--bind lan` flag to CMD so gateway listens on 0.0.0.0 instead of 127.0.0.1, enabling Docker port mapping to work.

**Auto-generate auth token:** If OPENCLAW_GATEWAY_TOKEN not set, entrypoint generates random token allowing container to start without manual configuration. Users can override with env var.

**Use --allow-unconfigured flag:** Allows gateway to start without ~/.openclaw/openclaw.json config file, eliminating first-run setup requirement.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Use pnpm instead of npm**
- **Found during:** Task 1 (Docker build)
- **Issue:** `npm install` completed but `npx openclaw gateway` failed with "Cannot find module '/app/dist/entry.js'" because OpenClaw requires pnpm for package management and uses pnpm-specific build scripts
- **Fix:** Added corepack enable and pnpm installation, changed `npm install` to `pnpm install`
- **Files modified:** Dockerfile
- **Verification:** Docker build succeeds with `pnpm install && pnpm build`
- **Committed in:** 10eae82 (combined with Task 2)

**2. [Rule 3 - Blocking] Add TypeScript build step**
- **Found during:** Task 1 verification (container startup)
- **Issue:** OpenClaw source is TypeScript, npm install alone doesn't compile to JavaScript dist files
- **Fix:** Added `pnpm build` step to run TypeScript compilation and build scripts
- **Files modified:** Dockerfile
- **Verification:** Container starts successfully, openclaw binary works
- **Committed in:** 10eae82 (combined with Task 2)

**3. [Rule 2 - Missing Critical] Build Control UI assets**
- **Found during:** Task 2 verification (HTTP endpoint test)
- **Issue:** HTTP endpoint returned "Control UI assets not found. Build them with `pnpm ui:build`" error message instead of serving the UI
- **Fix:** Added `pnpm ui:build` step to generate Vite-built UI assets in dist/control-ui/
- **Files modified:** Dockerfile
- **Verification:** HTTP 200 response with full HTML UI
- **Committed in:** 10eae82 (combined with Task 2)

**4. [Rule 3 - Blocking] Configure LAN binding**
- **Found during:** Task 2 verification (external HTTP access)
- **Issue:** Gateway bound to 127.0.0.1 (localhost only), preventing Docker port mapping from working. curl from host failed despite correct port exposure.
- **Fix:** Added `--bind lan` flag to CMD to bind to 0.0.0.0 (all interfaces)
- **Files modified:** Dockerfile
- **Verification:** curl http://localhost:18789/ returns HTTP 200 from host
- **Committed in:** 10eae82 (combined with Task 2)

**5. [Rule 2 - Missing Critical] Handle missing auth token**
- **Found during:** Task 2 verification (container startup)
- **Issue:** Gateway exited with "No token configured" error when OPENCLAW_GATEWAY_TOKEN not set
- **Fix:** Added token generation in entrypoint.sh using /dev/urandom, exports as OPENCLAW_GATEWAY_TOKEN env var
- **Files modified:** entrypoint.sh
- **Verification:** Container starts successfully, logs show generated token
- **Committed in:** 10eae82 (combined with Task 2)

**6. [Rule 2 - Missing Critical] Allow unconfigured startup**
- **Found during:** Task 2 verification (container startup)
- **Issue:** Gateway exited with "Missing config. Run `openclaw setup`" error on first start
- **Fix:** Added `--allow-unconfigured` flag to CMD per openclaw gateway --help documentation
- **Files modified:** Dockerfile
- **Verification:** Container starts without config file, creates minimal config automatically
- **Committed in:** 10eae82 (combined with Task 2)

---

**Total deviations:** 6 auto-fixed (3 blocking, 3 missing critical)
**Impact on plan:** All auto-fixes necessary for container to function. OpenClaw's requirements (pnpm, build process, UI compilation, network binding, auth token, config initialization) not fully detailed in upstream docs required discovery during build/test. No scope creep - all changes essential for basic operation.

## Issues Encountered

**OpenClaw documentation gaps:** Research phase couldn't determine exact build requirements because OpenClaw's Docker documentation is minimal. Required iterative discovery:
- package.json inspection revealed pnpm requirement
- Build errors revealed TypeScript compilation needed
- Runtime errors revealed UI build needed
- Network testing revealed binding mode issue
- Startup logs revealed auth and config requirements

**Resolution:** Applied deviation rules (Rule 2 & 3) to fix each blocking issue immediately during verification steps. All fixes verified before committing.

## User Setup Required

**Environment variables (optional):**
- `OPENCLAW_GATEWAY_TOKEN` - Set to use persistent auth token instead of random generation

**Volume mapping:**
- `/home/node/.openclaw` - Required for persistent config, agents, and workspace data

**Port exposure:**
- `18789` - OpenClaw Control UI and WebSocket gateway

No external service configuration required - container is self-contained.

## Next Phase Readiness

**Ready for Unraid template creation (Phase 02):**
- Docker image builds and runs successfully
- Health check functioning (goes healthy after ~60s startup)
- Volume persistence working (/home/node/.openclaw contains config)
- Port mapping verified (18789:18789)

**No blockers.**

**Considerations for Phase 02:**
- Template should document OPENCLAW_GATEWAY_TOKEN env var for persistent token
- Template should expose port 18789 as TCP
- Template should map volume to /mnt/user/appdata/openclaw (Unraid convention)
- Template should use container-development branch tag until Phase 04 releases to main

---
*Phase: 01-container-development*
*Completed: 2026-02-01*
