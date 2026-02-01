# OpenClaw Docker for Unraid

## What This Is

A production-ready Docker setup for OpenClaw optimized for Unraid, featuring persistent volume management, DockerHub distribution, and a Community Applications template that makes installation simple for Unraid users.

## Core Value

Unraid users can install and run OpenClaw with a few clicks, and their configuration and data persists across container restarts without manual intervention.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Dockerfile creates image with persistent ~/.openclaw/ directory mapping
- [ ] Container survives restarts with all config and data intact
- [ ] OpenClaw Control UI accessible after container start
- [ ] Docker image published to DockerHub for easy pulling
- [ ] Unraid XML template follows Community Applications conventions
- [ ] Template configures port mappings and volume paths correctly
- [ ] Installation workflow tested on Unraid server
- [ ] Submitted to Unraid Community Applications catalog

### Out of Scope

- Custom GUI beyond OpenClaw's Control UI — their existing UI at :18789 is sufficient
- Forking or modifying OpenClaw's core behavior — keep their structure intact
- Multi-platform optimization — focused on Unraid first, general Docker compatibility secondary
- Real-time sync between instances — single-instance deployment model

## Context

**OpenClaw Background:**
OpenClaw is an AI gateway platform that manages agents, channels (WhatsApp, Telegram, Discord), and tool execution. It has an existing Docker setup via docker-setup.sh, but it's not optimized for Unraid's Community Applications system and doesn't clearly handle persistent storage.

**Current State:**
- OpenClaw provides docker-setup.sh script for setup
- Control UI runs on port 18789
- Configuration stored in ~/.openclaw/
- Current setup may not persist data across container restarts properly

**Target Environment:**
Unraid Community Applications system, which uses XML templates stored in /boot/config/plugins/dockerMan/templates-user. Users install apps through a web GUI that reads these templates.

**Onboarding Question:**
OpenClaw has an interactive onboarding wizard. Need to explore whether to: (1) auto-run on first start, (2) configure via environment variables, or (3) let users run manually through Control UI.

## Constraints

- **Platform**: Unraid-first optimization — must follow Unraid Community Applications conventions
- **Compatibility**: Keep OpenClaw's structure unchanged — don't fork or modify core behavior
- **Licensing**: Must use open-source licensing for Community Applications submission
- **Documentation**: Requires dedicated support thread on Unraid forums per Community Apps requirements
- **Build Order**: Local validation → DockerHub publish → Community Apps submission

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Target Unraid community (not just personal use) | Makes OpenClaw accessible to broader audience, justifies Community Apps submission | — Pending |
| Use OpenClaw's existing Control UI | Their UI already handles setup/interaction, no need to duplicate | — Pending |
| Full ~/.openclaw/ persistence | User selected "everything" — captures config, agent data, conversation history | — Pending |

---
*Last updated: 2026-02-01 after initialization*
