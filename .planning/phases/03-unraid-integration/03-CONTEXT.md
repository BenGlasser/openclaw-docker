# Phase 3: Unraid Integration - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Create an XML template that allows Unraid users to install and configure OpenClaw through the Docker tab interface. Users click to add the template, configure basic settings (port, volume path), and launch the container with WebUI access. Template testing validates the installation flow on actual Unraid server.

This phase delivers the **installation interface** — making the working Docker image accessible to Unraid users.

</domain>

<decisions>
## Implementation Decisions

### Template presentation
- **Category:** Productivity (positions alongside work/organization tools)
- **Description:** "The AI that actually does things"
- **Icon source:** OpenClaw's GitHub raw icon (stays current with upstream)
- **Support URL:** Link to Unraid forum thread (created in Phase 4)

### Configuration interface
- **Port:** Configurable (default 18789, users can change to avoid conflicts)
- **API key:** Claude's discretion (balance ease-of-use vs security)
- **Appdata path:** Claude's discretion (standard Unraid conventions)
- **Advanced options:** Claude's discretion (minimal vs useful vars for typical users)

### Claude's Discretion
- Whether to include API key as template variable or post-install via UI
- Default appdata path format (/mnt/user vs /mnt/cache)
- Which advanced environment variables to expose (if any)
- Template description field verbosity (one-line vs detailed)

</decisions>

<specifics>
## Specific Ideas

- "The AI that actually does things" — User's preferred positioning/description
- Support URL placeholder until Phase 4 creates forum thread (document this dependency)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-unraid-integration*
*Context gathered: 2026-02-01*
