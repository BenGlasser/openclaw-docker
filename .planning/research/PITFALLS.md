# Pitfalls Research

**Domain:** Docker containers for Unraid Community Applications
**Researched:** 2026-02-01
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Volume Persistence - Anonymous Volumes Lead to Data Loss

**What goes wrong:**
Container data disappears when the container is recreated or updated because anonymous volumes are used instead of named volumes or proper host path mappings. Users lose all their configuration, save files, and application state.

**Why it happens:**
- Docker containers are ephemeral by default - all internal data is lost on container removal
- Developers use simple `-v /path` syntax without understanding it creates anonymous volumes with random IDs
- Anonymous volumes aren't automatically reused when containers are recreated
- Unraid templates sometimes lack clear guidance on required persistent paths

**How to avoid:**
- Always use explicit host path mappings: `/mnt/user/appdata/openclaw:/config` not just `/config`
- Map all game data, configuration, and user-generated content to host paths
- Use Unraid's standard appdata structure: `/mnt/user/appdata/<container-name>/`
- For optimal performance on cache drives: `/mnt/cache/appdata/<container-name>/`
- Test persistence by creating a container, adding test data, removing container, recreating, and verifying data survived

**Warning signs:**
- Users report "lost my progress" or "settings reset" after updates
- Container logs show "creating new database" or "first run detected" on every restart
- Docker volume list shows orphaned volumes with random hash names
- appdata directory is empty or missing expected files

**Phase to address:**
Phase 1 (Container Setup) - Define all persistent volumes before first release. Include in container health checks and documentation.

---

### Pitfall 2: File Permission Chaos - PUID/PGID Not Configured

**What goes wrong:**
Container creates files owned by root or random UIDs, making them inaccessible to Unraid users. Files show as "UNKNOWN" owner in file browser. Users can't edit configs, access save files, or backup data.

**Why it happens:**
- Docker runs processes as root by default, creating root-owned files
- Unraid uses `nobody:users` (99:100) for file permissions by default
- Container doesn't respect host's permission model without explicit PUID/PGID mapping
- Developers forget to implement LinuxServer.io-style user mapping in their images

**How to avoid:**
- Implement PUID/PGID environment variables in your Dockerfile
- Default to Unraid's standard: PUID=99, PGID=100
- Use an entrypoint script that runs `usermod` and `groupmod` before starting the main process
- Set UMASK=022 for proper default file creation permissions
- Document PUID/PGID settings clearly in template with Type="Variable"
- Test by creating files in container, then checking ownership on host

**Warning signs:**
- Files in appdata show owner as "root" or "UNKNOWN"
- Permission denied errors when trying to edit configuration files from Unraid
- Container works but users can't access generated files
- Backup failures due to permission issues

**Phase to address:**
Phase 1 (Container Setup) - Implement before first release. This is table-stakes functionality for Unraid containers.

---

### Pitfall 3: XML Template Validation Failure - Manual Editing Breaks Community Apps

**What goes wrong:**
Template gets blacklisted from Community Applications, preventing users from installing or updating. Container appears incompatible or generates errors during installation.

**Why it happens:**
- Manual XML editing introduces formatting incompatible with Unraid's parser
- Extra whitespace in Config element attributes breaks third-party parsers
- Using self-closing tags like `<MyIP/>` or `<Shell/>` instead of removing them
- GitHub repository URL mismatches between template and actual repository
- Missing required fields: `<Support>` or `<Project>` tags

**How to avoid:**
- **CRITICAL**: Only edit templates through Unraid's Docker tab interface, not manually
- Enable "Template Authoring Mode" in Unraid settings for safe XML editing
- Never hand-edit XML files - let Unraid generate proper formatting
- Validate required fields are present:
  - `<Support>` - Link to Unraid forum support thread (REQUIRED)
  - `<Project>` - Link to GitHub or project homepage (REQUIRED)
  - `<Icon>` - HTTPS URL to PNG image file
  - `<TemplateURL>` - Raw GitHub URL matching actual repository
- Remove unused auto-generated fields before submission
- Test template by installing through Community Applications interface
- Verify GitHub URL matches exactly: no user/repo mismatches

**Warning signs:**
- "Template has been blacklisted" error in Community Apps
- "GitHub user appears to be different" validation error
- Container installs but shows errors in Community Apps Action Centre
- Template changes don't appear after pushing to GitHub
- Installation fails with XML parsing errors

**Phase to address:**
Phase 2 (Unraid Integration) - Before Community Apps submission. Critical for distribution success.

---

### Pitfall 4: Port Conflict Hell - Default Ports Already in Use

**What goes wrong:**
Container fails to start because another service (Unraid UI, another container, or system service) is already using the required port. Users see binding errors and can't access the application.

**Why it happens:**
- Common ports (80, 443, 8080, 3000) are already used by Unraid or other containers
- Templates use "Host" network mode instead of "Bridge" for simplicity
- Developers hardcode ports instead of making them configurable
- Pi-hole and DNS containers conflict with system DNS (port 53)

**How to avoid:**
- Default to "Bridge" network mode, not "Host"
- Make ALL ports configurable in the template with sane defaults
- Choose uncommon default ports (avoid 80, 443, 8080, 3000, 5000, etc.)
- For OpenClaw, use high port numbers like 8765 for web UI
- Document port requirements clearly with Port Type="Port" configs
- Only use Host mode if application absolutely requires direct network access
- Test on fresh Unraid install to verify no default conflicts
- Provide clear error messages if port binding fails

**Warning signs:**
- Container status shows "Starting" forever, never reaches "Started"
- Logs show "address already in use" or "bind: address already in use"
- Container repeatedly restarts
- Users report "can't access web UI"
- Conflicts with common containers: Pi-hole, Plex, nginx

**Phase to address:**
Phase 1 (Container Setup) - Design with port flexibility from the start. Document in template.

---

### Pitfall 5: Corrupted Docker Image - Cache Drive Space Issues

**What goes wrong:**
Container becomes unrecoverable, Unraid can't start any containers, entire Docker service fails. Requires complete Docker reinstallation and container recreation.

**Why it happens:**
- Cache pool runs out of space during image pulls or container operations
- Unclean Unraid shutdown (power loss, crash) while Docker is writing
- docker.img file becomes corrupted
- Multiple large containers fill cache drive
- Image layers consume more space than expected

**How to avoid:**
- Keep Docker images small - use Alpine base images where possible
- Implement multi-stage builds to minimize final image size
- Document disk space requirements clearly in Overview
- Recommend users allocate sufficient cache drive space
- Use .dockerignore to prevent bloat
- Provide image size estimates in template description
- Recommend regular cache drive maintenance to users

**Warning signs:**
- Docker service won't start after reboot
- All containers show "Stopped" and won't start
- Unraid diagnostics show "docker.img corrupted"
- Cache drive shows near 100% usage
- Logs show "no space left on device"

**Phase to address:**
Phase 1 (Container Setup) - Optimize image size during development. Document requirements.

---

### Pitfall 6: Missing Health Checks - Silent Failures

**What goes wrong:**
Container shows as "Running" but application is actually crashed or non-functional. Users can't tell if the service is actually working without manual testing.

**Why it happens:**
- Dockerfile lacks HEALTHCHECK instruction
- Process stays alive but stops responding (zombie process)
- Application crashes but container doesn't exit
- Unraid shows green indicator despite application failure

**How to avoid:**
- Implement HEALTHCHECK in Dockerfile
- For OpenClaw with web UI: `HEALTHCHECK --interval=30s CMD curl -f http://localhost:PORT/ || exit 1`
- For game servers: Check if game process is responding
- Test healthcheck locally: `docker inspect --format='{{json .State.Health}}' container`
- Document that health checks are implemented in template Overview
- Make health check endpoint configurable if custom ports used

**Warning signs:**
- Users report "container running but can't connect"
- No health indicator (colored dot) appears in Unraid
- Container logs show errors but status is "Running"
- Application restarts don't happen automatically

**Phase to address:**
Phase 1 (Container Setup) - Add to Dockerfile before first release.

---

### Pitfall 7: Multi-Architecture Blindness - ARM Users Left Behind

**What goes wrong:**
Container only works on x86/AMD64 systems, failing on ARM-based Unraid servers or newer hardware. Users with Raspberry Pi or ARM NAS can't install.

**Why it happens:**
- Image built only for AMD64 architecture
- No multi-arch manifest on DockerHub
- Dependencies or binaries are architecture-specific without fallbacks
- Developer only tests on x86 hardware
- OpenClaw may have x86-only dependencies

**How to avoid:**
- Use Docker buildx for multi-platform builds:
  ```bash
  docker buildx build --platform linux/amd64,linux/arm64 --push -t image:latest .
  ```
- Create multi-arch manifest pointing to both architectures
- Test if OpenClaw source supports ARM compilation
- If ARM not possible: Clearly document "AMD64 only" in template
- Use `--platform` tag in template Config if architecture-specific
- Inspect manifest: `docker buildx imagetools inspect image:latest`
- Provide clear error message if wrong architecture detected

**Warning signs:**
- Users report "image not found" or "manifest unknown"
- Container fails immediately on ARM systems
- Logs show "exec format error" or "no matching manifest"
- DockerHub shows only one platform in manifest

**Phase to address:**
Phase 3 (Publishing) - Address before DockerHub publication. Investigate OpenClaw ARM support early.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using root user without PUID/PGID | Simpler Dockerfile, no permission logic | Files owned by root, permission issues, security risk | Never - always implement proper user mapping |
| Host network mode | Easier port management, no mapping needed | Port conflicts, security exposure, breaks container isolation | Only for DNS/DHCP services (Pi-hole) |
| Storing config in container | No volume setup needed | Data loss on updates, can't backup configs | Never - always externalize config |
| Hardcoded paths and ports | Less configuration code | Inflexible, conflicts with other containers | Never - make everything configurable |
| Anonymous volumes | Quick start, minimal setup | Orphaned volumes, data loss, debugging nightmare | Never for production containers |
| Single architecture builds | Faster build pipeline, simpler CI/CD | Excludes ARM users, limits platform support | Only if application physically cannot support ARM |
| Skipping HEALTHCHECK | One less thing to maintain | Silent failures, no automatic recovery | Never - critical for reliability |
| Manual XML editing | Quick fixes, precise control | Blacklist risk, parser incompatibility | Never - always use Unraid interface |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| DockerHub Publishing | Not using `--push` flag with multi-platform builds | `docker buildx build --platform linux/amd64,linux/arm64 --push` - multi-arch images can't load locally |
| Community Apps Submission | Submitting without Unraid forum support thread | Create support thread FIRST, then add `<Support>` URL to template |
| GitHub Template URL | Using regular GitHub URL instead of raw.githubusercontent.com | Use raw URL: `https://raw.githubusercontent.com/user/repo/master/template.xml` |
| Volume Mounts | Mapping to `/mnt/user/` on cache-only shares | Use `/mnt/cache/` for appdata to bypass user share layer overhead |
| Icon URLs | Using HTTP or linking to GitHub repo pages | Use HTTPS direct link to PNG: `https://raw.githubusercontent.com/.../icon.png` |
| VNC/Display for Games | Expecting GPU passthrough to work automatically | Document that GPU passthrough is complex/optional, provide software rendering fallback |
| Environment Variables | Not referencing container's actual documentation | Extract from official container README, validate each variable |
| Template Categories | Forgetting to add category tags | Use Application Categorizer plugin to generate proper tags |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Writing to array instead of cache | Slow container startup, laggy UI | Map appdata to `/mnt/cache/` not `/mnt/user/` | Immediately noticeable with any significant I/O |
| Large image size (>2GB) | Slow pulls, cache drive fills, update pain | Multi-stage builds, Alpine base, .dockerignore | Cache pools <100GB |
| No resource limits | One container starves others | Document CPU/RAM needs, recommend limits | Multiple resource-heavy containers |
| Verbose logging to volume | Fills appdata, slows I/O | Log to stdout/stderr, let Docker handle rotation | Long-running containers |
| Polling instead of inotify | High CPU on file watching | Use proper file watch APIs | Large config directories |
| Unraid user share for active data | Slow reads/writes, high latency | Direct cache path for active data, array for archives | Any real-time application |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Running as root without dropping privileges | Container breakout, host compromise | Implement PUID/PGID, run as nobody/users (99:100) |
| Template exposes unnecessary privileged mode | Full host access if container compromised | Set `<Privileged>false</Privileged>` unless absolutely required |
| Port exposed to WAN without auth | Public access to container management | Default to Bridge mode, document VPN/reverse proxy requirement |
| Storing passwords in template defaults | Credentials in public GitHub repo | Use `<Mask>true</Mask>`, force user to set password on first run |
| No input validation on environment vars | Command injection via template variables | Validate/sanitize all environment inputs in entrypoint |
| Icon URL over HTTP | MITM attacks, mixed content warnings | Require HTTPS for all external resources in template |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No WebUI template tag | Users don't know how to access application | Add `<WebUI>http://[IP]:[PORT:8765]/</WebUI>` with actual port variable |
| Unclear variable descriptions | Users set wrong values, container breaks | Reference official docs, provide examples: "Set to 99 for Unraid compatibility" |
| Template missing initial setup steps | Users install but can't configure | Add detailed Overview with first-run instructions |
| No default values | Every install requires research | Provide Unraid-compatible defaults: PUID=99, PGID=100, sensible ports |
| Error messages reference Docker, not Unraid | Users don't understand Docker commands | Provide Unraid-specific troubleshooting in support thread |
| No "first run" indicator | Users think broken when initial setup incomplete | Log clear "First run detected, initializing..." messages |
| Template changes require full reinstall | Users lose data trying to update config | Make configs editable through WebUI or environment variables |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Persistent volumes:** Container runs but are ALL config/save paths mapped? Test: remove and recreate container, does data survive?
- [ ] **Permissions tested:** Can Unraid users edit files in appdata? Test: create file in container, check ownership on host (should be 99:100)
- [ ] **Port conflicts checked:** Does it start on fresh Unraid with common containers? Test with Plex, Pi-hole, nginx running
- [ ] **Multi-arch manifest:** DockerHub shows both AMD64 and ARM64? Test: `docker buildx imagetools inspect image:latest`
- [ ] **Health check works:** Does Unraid show green/red health indicator? Test: `docker inspect --format='{{json .State.Health}}' container`
- [ ] **Template validates:** Does Community Apps accept it? Test: install through CA, check for blacklist warnings
- [ ] **Support thread exists:** Is there an Unraid forum thread linked in template? Required for CA submission
- [ ] **Icon displays:** Does PNG icon appear in Unraid Docker tab? Test: verify HTTPS URL returns valid image
- [ ] **XML is clean:** Generated by Unraid, not hand-edited? Template should show proper formatting
- [ ] **Variables documented:** Does each environment variable have clear description? User shouldn't need to check Docker docs
- [ ] **First run tested:** Install on fresh system works without manual intervention? Test on clean Unraid VM
- [ ] **Upgrade tested:** Existing users don't lose data on container update? Test update path from previous version

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Lost data (no volumes) | HIGH - data unrecoverable | Restore from Unraid appdata backup if exists; implement volumes; document backup strategy for users |
| Permission issues | LOW - fixable with chown | SSH to Unraid: `chown -R 99:100 /mnt/user/appdata/openclaw/`; restart container |
| Template blacklisted | MEDIUM - requires resubmission | Delete template from GitHub; recreate through Unraid Docker tab; resubmit to Community Apps; update forum thread |
| Port conflicts | LOW - reconfigure port | Edit container; change host port to unused value; update documentation |
| Corrupted docker.img | HIGH - full reinstall | Settings → Docker → Disable; delete docker.img; Enable Docker; reinstall all containers from templates (data safe if appdata preserved) |
| Wrong architecture | LOW - rebuild image | Build with buildx multi-platform; push new manifest; users re-pull image |
| Missing health check | LOW - add to Dockerfile | Add HEALTHCHECK instruction; rebuild; update on DockerHub; users update container |
| XML parse error | MEDIUM - recreate template | Remove template; create new through Unraid UI; test installation; commit to GitHub |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Volume persistence data loss | Phase 1: Container Setup | Test data survives container recreation; check appdata directory has all expected files |
| PUID/PGID permission issues | Phase 1: Container Setup | Files in appdata owned by 99:100; users can edit configs from Unraid file browser |
| XML template validation failure | Phase 2: Unraid Integration | Template installs through Community Apps without errors; no blacklist warnings |
| Port conflicts | Phase 1: Container Setup | Container starts with common Unraid apps running; ports configurable in template |
| Corrupted docker image | Phase 1: Container Setup | Image size documented; multi-stage build minimizes size |
| Missing health checks | Phase 1: Container Setup | Health indicator shows in Unraid; `docker inspect` shows healthy status |
| Multi-architecture issues | Phase 3: Publishing | DockerHub manifest includes AMD64 and ARM64 (if supported) |
| Missing support thread | Phase 2: Unraid Integration | Unraid forum thread created and linked in template before CA submission |
| Icon not displaying | Phase 2: Unraid Integration | PNG icon appears in Unraid Docker tab; HTTPS URL accessible |
| Poor user documentation | Phase 2: Unraid Integration | Overview field has clear setup instructions; variables have descriptions |
| No WebUI link | Phase 2: Unraid Integration | Template includes WebUI tag with correct port variable |
| First-run setup unclear | Phase 1: Container Setup | Container logs show clear initialization messages; README documents first-run process |

## Sources

### Official Documentation
- [Unraid Docker Template Schema](https://wiki.unraid.net/DockerTemplateSchema) - Official XML template structure
- [Writing a template compatible for Unraid](https://selfhosters.net/docker/templating/templating/) - Comprehensive templating guide
- [Managing & customizing containers | Unraid Docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/) - Official container management documentation
- [Docker troubleshooting | Unraid Docs](https://docs.unraid.net/unraid-os/troubleshooting/common-issues/docker-troubleshooting/) - Official troubleshooting guide
- [Community Applications | Unraid Docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/community-applications/) - CA submission requirements
- [Understanding PUID and PGID - LinuxServer.io](https://docs.linuxserver.io/general/understanding-puid-and-pgid/) - User permission mapping

### Docker and Multi-Architecture
- [Docker Volumes and Data Persistence](https://blog.pmunhoz.com/docker/docker-data-persistence-volumes) - Volume persistence explained
- [Docker Volumes and Data Persistence - Part 1](https://www.owais.io/blog/2025-09-12_docker-volumes-data-persistence-part1/) - Container data loss and volume basics
- [Multi-platform | Docker Docs](https://docs.docker.com/build/building/multi-platform/) - Official multi-arch build documentation
- [How to Build Multi-Architecture Docker Images (ARM64 + AMD64)](https://oneuptime.com/blog/post/2026-01-06-docker-multi-architecture-images/view) - 2026 guide

### Unraid Community Resources
- [Unleash your Unraid Server: Tips for Optimizing Your Server](https://jamiecounsell.me/posts/tips-for-optimizing-unraid/) - Appdata best practices
- [Unraid Forums - Docker Engine](https://forums.unraid.net/forum/46-docker-engine/) - Community troubleshooting
- [binhex/docker-templates GitHub](https://github.com/binhex/docker-templates) - Example template repository

### Specific Issues and Discussions
- [PUID PGID and UMASK - Docker Engine - Unraid](https://forums.unraid.net/topic/118751-puid-pgid-and-umask/) - Permission configuration
- [Port conflicts with Docker](https://forums.unraid.net/bug-reports/stable-releases/612-port-conflicts-with-docker-r2998/) - Port troubleshooting
- [Adding a healthcheck to a docker image?](https://forums.unraid.net/topic/160408-adding-a-healthcheck-to-a-docker-image/) - Health check implementation
- [Template error GitHub user appears to be different](https://forums.unraid.net/topic/191911-template-error-github-user-apprears-to-be-different-between-template-repository-and-xmlplugin/) - Blacklist issues

---
*Pitfalls research for: OpenClaw Docker for Unraid*
*Researched: 2026-02-01*
