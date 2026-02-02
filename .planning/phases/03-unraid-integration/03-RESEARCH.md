# Phase 3: Unraid Integration - Research

**Researched:** 2026-02-01
**Domain:** Unraid Docker template system, Community Applications
**Confidence:** MEDIUM

## Summary

Unraid uses XML templates to enable one-click Docker container installation through its web interface. Templates are created through Unraid's Docker tab (not manually edited), defining container metadata, port mappings, volume paths, and environment variables. The XML format follows a specific schema where Config entries define user-configurable options with Display levels controlling visibility.

The standard approach is: create container manually via Docker tab, configure all settings, then save as template. Test locally by adding template repository URL to Unraid Docker settings. Submit to Community Applications requires forum support thread, template repository, and review within 48 hours.

Key considerations: Use `/mnt/user/appdata/[app-name]` for consistency (though `/mnt/cache` performs better), PUID=99/PGID=100 for Unraid's nobody:users, mask sensitive API keys, and provide WebUI link format `http://[IP]:[PORT:18789]`. Icons/banners must be HTTPS PNG URLs.

**Primary recommendation:** Create template through Unraid Docker tab UI workflow (not hand-written XML), test with local repository before Community Apps submission, follow established conventions for appdata paths and PUID/PGID.

## Standard Stack

The established tools for Unraid Docker templates:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Unraid Docker Tab | 6.10+ | Template creation interface | Official template generator, ensures valid XML |
| XML v2.0 | 2.0 | Template format | Established Unraid standard since v6 |
| GitHub/Git | Any | Template repository hosting | Required by Community Applications system |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Community Applications Plugin | Latest | Template distribution | Public template submission and discovery |
| Application Categorizer | Latest | Category tag generation | Proper category classification before submission |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Unraid Docker Tab | Hand-written XML | Manual XML is unsupported, may break validation |
| GitHub repository | Direct XML files | CA requires Git repo, direct files don't support versioning |

**Installation:**
No installation required - Unraid Docker tab is built into Unraid OS 6.10+.

## Architecture Patterns

### Recommended Template Structure
```
github-repo/
├── my-template.xml     # Template file
└── README.md           # Documentation
```

### Pattern 1: Template Creation Workflow
**What:** Generate templates through Unraid UI, not manual XML editing
**When to use:** Always - this ensures valid XML and proper field structure
**Process:**
1. Navigate to Docker tab in Unraid WebGUI
2. Click "Add Container"
3. Fill in all configuration fields (image, ports, paths, variables)
4. Save container configuration
5. Template XML auto-generated at `/boot/config/plugins/dockerMan/templates-user/`
6. Copy XML to Git repository
7. Add repository URL to Unraid Docker settings for testing

**Source:** [Unraid Docker template schema documentation](https://selfhosters.net/docker/templating/templating/)

### Pattern 2: Config Entry Structure
**What:** Standardized XML Config elements for user-configurable options
**When to use:** For every port, path, and environment variable users should configure
**Example:**
```xml
<!-- Port configuration -->
<Config Name="WebUI Port" Target="18789" Default="18789" Mode="tcp" Display="always" Required="true" Type="Port" Description="WebUI access port">18789</Config>

<!-- Path configuration -->
<Config Name="Appdata" Target="/root/.openclaw" Default="/mnt/user/appdata/openclaw/" Mode="rw" Display="always" Required="true" Type="Path" Description="Stores configuration and data">/mnt/user/appdata/openclaw/</Config>

<!-- Environment variable -->
<Config Name="PUID" Target="PUID" Default="99" Mode="" Display="advanced-hide" Required="true" Type="Variable" Description="User ID (Unraid default: 99)">99</Config>

<!-- Masked sensitive variable -->
<Config Name="API Key" Target="ANTHROPIC_API_KEY" Default="" Mode="" Display="always" Required="false" Type="Variable" Mask="true" Description="Claude API key (can be set post-install via UI)"></Config>
```

**Source:** [Selfhosters.net Unraid templating guide](https://selfhosters.net/docker/templating/templating/)

### Pattern 3: WebUI Field Format
**What:** Special URL format for Unraid to auto-populate server IP and mapped port
**When to use:** When container exposes web interface
**Example:**
```xml
<WebUI>http://[IP]:[PORT:18789]</WebUI>
```
- `[IP]` = Unraid auto-fills server IP
- `[PORT:18789]` = Unraid translates container port 18789 to mapped host port
- Use `https` if service requires SSL

**Source:** [Selfhosters.net Unraid templating guide](https://selfhosters.net/docker/templating/templating/)

### Pattern 4: Display Levels
**What:** Control visibility and editability of Config entries
**Options:**
- `always` - Visible in basic view, fully editable (use for essential config)
- `always-hide` - Visible but locked in basic view (use for standard defaults)
- `advanced` - Hidden until "Show more settings" (use for optional tweaks)
- `advanced-hide` - Advanced section only, locked (use for system defaults like PUID/PGID)

**Source:** [Selfhosters.net Unraid templating guide](https://selfhosters.net/docker/templating/templating/)

### Anti-Patterns to Avoid
- **Hand-editing XML from scratch:** Unraid's validator expects XML generated by Docker tab. Manual XML often breaks or gets rejected by CA.
- **Using /mnt/cache explicitly in templates:** While `/mnt/cache` is faster, use `/mnt/user` in templates for consistency. Power users can override to `/mnt/cache` if they want performance.
- **Exposing all environment variables:** Show only what typical users need. Advanced users can add variables manually.
- **Missing Required="true" on essential fields:** Users can skip required fields and get broken installations.
- **Empty default values for critical paths:** Always provide sensible defaults like `/mnt/user/appdata/[app-name]`.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Template validation | Manual XML schema validation | Unraid Docker tab "Save" function | Docker tab ensures proper XML structure, required fields, and CA compatibility |
| Template hosting | Custom server or CDN | GitHub repository | CA requires Git repos for versioning and moderation team access |
| Icon/banner hosting | Self-hosted images | GitHub raw URLs or established CDN | Must be HTTPS PNG, Git raw URLs are reliable and free |
| Category selection | Manual category tags | Application Categorizer plugin | Generates proper tags CA expects, prevents categorization issues |
| Template testing | Directly submit to CA | Local repository testing first | Can iterate without CA review delays, validate before submission |

**Key insight:** Unraid's template ecosystem has established tooling and workflows. Fighting against these (manual XML, custom hosting) creates friction with CA moderation and user expectations.

## Common Pitfalls

### Pitfall 1: Path Mapping Confusion (/mnt/user vs /mnt/cache)
**What goes wrong:** Template uses `/mnt/cache/appdata/app` which breaks on systems without cache pool, or user confusion about which to use
**Why it happens:** `/mnt/cache` performs better (bypasses FUSE layer) but not all systems have cache pools
**How to avoid:** Always use `/mnt/user/appdata/[app-name]` in templates for compatibility. Document that power users can change to `/mnt/cache` manually for performance
**Warning signs:** Template testing fails on cache-less systems, users report "path not found" errors

**Source:** [Unraid forum discussion on appdata paths](https://forums.unraid.net/topic/55028-mntuserappdata-vs-mntcacheappdata/)

### Pitfall 2: Wrong PUID/PGID Defaults
**What goes wrong:** Using PUID=1000/PGID=1000 (Linux desktop defaults) causes permission issues on Unraid
**Why it happens:** Developers copy templates from non-Unraid sources or assume Linux desktop defaults
**How to avoid:** Always use PUID=99 and PGID=100 (Unraid's nobody:users). Set Display="advanced-hide" so users don't accidentally change these
**Warning signs:** Users report permission denied errors, files owned by wrong user, container can't write to volumes

**Source:** [LinuxServer.io PUID/PGID documentation](https://docs.linuxserver.io/general/understanding-puid-and-pgid/) and [Unraid managing containers docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/)

### Pitfall 3: Missing or Incorrect WebUI Field
**What goes wrong:** WebUI button in Unraid Docker tab doesn't work, links to wrong port, or shows "Connection refused"
**Why it happens:** Wrong port number, missing [PORT:] syntax, using container port instead of format specifier
**How to avoid:** Use exact format `http://[IP]:[PORT:XXXX]` where XXXX matches the Target port in Port Config entry. Test clicking WebUI button after install
**Warning signs:** WebUI button missing, links to wrong URL, users have to manually type IP:port

**Source:** [Selfhosters.net WebUI field configuration](https://selfhosters.net/docker/templating/templating/)

### Pitfall 4: Unmasked Sensitive Environment Variables
**What goes wrong:** API keys, passwords visible in plaintext in Unraid UI, appear in screenshots/logs
**Why it happens:** Forgetting to set Mask="true" on sensitive Config entries
**How to avoid:** Set `Mask="true"` on any Config with Target containing KEY, PASSWORD, TOKEN, SECRET. Balance security with usability - if API key can be set post-install via app UI, consider not requiring it in template
**Warning signs:** Sensitive values visible when editing container, users accidentally share API keys in forum posts

**Source:** [Unraid managing containers best practices](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/)

### Pitfall 5: Template Not Generated By Docker Tab
**What goes wrong:** Community Applications rejects template, validation errors, "not compatible with CA"
**Why it happens:** Hand-written XML or templates from docker-compose converters have incorrect structure
**How to avoid:** ALWAYS create template by: configure container in Docker tab → Save → copy auto-generated XML. Never start from blank XML file
**Warning signs:** CA submission rejected, fields don't render properly, "Format not recognized" errors

**Source:** [Unraid Docker Template Schema](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/) and multiple forum discussions

### Pitfall 6: Missing Support Thread Before CA Submission
**What goes wrong:** CA submission rejected immediately, moderator asks for forum thread
**Why it happens:** Developers skip ahead to submission form without reading requirements
**How to avoid:** Before submitting to CA: 1) Test template locally, 2) Create Unraid forum support thread with template details, 3) Then submit to CA with forum thread URL
**Warning signs:** CA submission rejected within hours citing missing support thread

**Source:** [Community Applications submission requirements](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/community-applications/)

## Code Examples

Verified patterns from official sources:

### Complete Minimal Template
```xml
<?xml version="1.0" encoding="utf-8"?>
<Container version="2">
  <Name>openclaw</Name>
  <Repository>your-dockerhub-user/openclaw</Repository>
  <Registry>https://hub.docker.com/r/your-dockerhub-user/openclaw/</Registry>
  <Network>bridge</Network>
  <Privileged>false</Privileged>
  <Support>https://forums.unraid.net/topic/XXXXX-support-openclaw/</Support>
  <Project>https://github.com/anthropics/claude-code</Project>
  <Overview>The AI that actually does things. OpenClaw brings Claude's capabilities to your command line with full agentic workflows.</Overview>
  <Category>Productivity:</Category>
  <WebUI>http://[IP]:[PORT:18789]</WebUI>
  <Icon>https://raw.githubusercontent.com/anthropics/claude-code/main/icon.png</Icon>
  <Description>OpenClaw is a powerful AI assistant...</Description>

  <Config Name="WebUI Port" Target="18789" Default="18789" Mode="tcp" Display="always" Required="true" Type="Port" Description="Port for accessing the OpenClaw WebUI">18789</Config>

  <Config Name="Appdata" Target="/root/.openclaw" Default="/mnt/user/appdata/openclaw/" Mode="rw" Display="always" Required="true" Type="Path" Description="Stores OpenClaw configuration, agent data, and conversation history">/mnt/user/appdata/openclaw/</Config>

  <Config Name="ANTHROPIC_API_KEY" Target="ANTHROPIC_API_KEY" Default="" Mode="" Display="always" Required="false" Type="Variable" Mask="true" Description="Claude API key (can be set via WebUI after installation)"></Config>

  <Config Name="PUID" Target="PUID" Default="99" Mode="" Display="advanced-hide" Required="true" Type="Variable" Description="User ID for file permissions (Unraid default: 99)">99</Config>

  <Config Name="PGID" Target="PGID" Default="100" Mode="" Display="advanced-hide" Required="true" Type="Variable" Description="Group ID for file permissions (Unraid default: 100)">100</Config>
</Container>
```

**Source:** Synthesized from [Unraid template schema](https://selfhosters.net/docker/templating/templating/) and [real-world examples](https://github.com/binhex/docker-templates)

### Local Testing Setup
```bash
# 1. Create Git repository with template
mkdir unraid-openclaw-template
cd unraid-openclaw-template
# Copy your XML template here as openclaw.xml
git init
git add openclaw.xml
git commit -m "Initial OpenClaw template"
git remote add origin https://github.com/yourusername/unraid-openclaw-template.git
git push -u origin main

# 2. In Unraid WebGUI:
# - Navigate to Docker tab
# - Scroll to bottom section "Template repositories"
# - Add URL: https://github.com/yourusername/unraid-openclaw-template
# - Click SAVE
# - Click "Add Container"
# - Your template should appear in dropdown

# 3. Test installation:
# - Select template from dropdown
# - Verify all fields populated correctly
# - Click CREATE
# - After container starts, click WebUI button
# - Verify OpenClaw Control UI loads

# 4. Test update flow:
# - Update XML in repository
# - In Unraid Docker tab, click "Check for Updates"
# - Verify new template version detected
```

**Source:** [Unraid Docker template testing workflow](https://forums.unraid.net/topic/183067-how-do-i-make-a-docker-template-please/)

### Category Field Format
```xml
<!-- Single category -->
<Category>Productivity:</Category>

<!-- Multiple categories (colon-separated) -->
<Category>Productivity: Tools: Status: Stable:</Category>
```

**Note:** Use Application Categorizer plugin to generate proper category tags. CA expects specific category names.

**Source:** [Unraid template schema](https://selfhosters.net/docker/templating/templating/)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual XML editing | Docker tab template generation | Unraid 6.x | Auto-generated XML ensures CA compatibility |
| Mixed Config types (Networking, Data, Environment sections) | Unified Config tags only | Unraid 6.10+ | Cleaner XML, easier parsing |
| HTTP icon URLs | HTTPS PNG URLs required | CA policy ~2024 | Improved security, consistent branding |
| `/mnt/cache` in templates | `/mnt/user` recommended | Community consensus 2025 | Better compatibility across systems |

**Deprecated/outdated:**
- **Old XML version 1:** Version 2 is current standard, version 1 templates may not render properly
- **Separate Networking/Data/Environment tags:** Replaced by unified `<Config>` entries with Type attribute
- **MyIP placeholder:** Replaced by `[IP]` in WebUI field
- **Manual category strings:** Application Categorizer plugin generates proper tags

**Source:** Multiple sources including [Unraid docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/) and community forums

## Open Questions

Things that couldn't be fully resolved:

1. **API Key Strategy: Template Variable vs Post-Install UI**
   - What we know: Can be template variable (Mask="true"), or users can set via OpenClaw Control UI after install
   - What's unclear: Community preference - some apps require API key at install, others allow post-config
   - Recommendation: Make API key optional in template (Required="false"), document both options. This provides flexibility and doesn't expose keys during template screenshots/sharing. User can start container without key, then configure via OpenClaw's built-in UI.

2. **Exact Icon/Banner Dimensions**
   - What we know: Must be PNG hosted via HTTPS
   - What's unclear: CA doesn't specify exact dimensions or aspect ratios in documentation
   - Recommendation: Use OpenClaw's existing GitHub raw icon URL. Examine similar apps in CA Productivity category for typical dimensions. Standard appears to be square icons (128x128 to 512x512) and wide banners (728x90 or similar).

3. **Support Forum Thread Timing**
   - What we know: Support thread required before CA submission
   - What's unclear: Should thread exist before Phase 3 completion, or created in Phase 4?
   - Recommendation: Phase 3 delivers working template tested locally. Phase 4 creates forum thread and submits to CA. Document this dependency in template (use placeholder URL that gets updated in Phase 4).

4. **Advanced Environment Variables Exposure**
   - What we know: OpenClaw may have additional env vars for advanced configuration
   - What's unclear: Which vars typical Unraid users need vs power users
   - Recommendation: Start minimal - only expose WebUI port, appdata path, API key, PUID/PGID. Power users can add variables manually through "Add another Variable" in Unraid UI. Gather feedback from Phase 4 forum thread about commonly needed vars.

## Sources

### Primary (HIGH confidence)
- [Unraid Docker Template Schema - Selfhosters.net](https://selfhosters.net/docker/templating/templating/) - Complete template structure and field definitions
- [Unraid Managing & Customizing Containers Docs](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/) - Official appdata paths and PUID/PGID guidance
- [Community Applications Requirements](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/community-applications/) - Submission process and requirements
- [LinuxServer.io PUID/PGID Documentation](https://docs.linuxserver.io/general/understanding-puid-and-pgid/) - Authoritative explanation of user/group IDs in containers

### Secondary (MEDIUM confidence)
- [Unraid Forums: /mnt/user vs /mnt/cache appdata discussion](https://forums.unraid.net/topic/55028-mntuserappdata-vs-mntcacheappdata/) - Community consensus on path recommendations
- [Unraid Forums: How to make a docker template](https://forums.unraid.net/topic/183067-how-do-i-make-a-docker-template-please/) - Template creation workflow
- [CookieCode: Create custom Docker template](https://cookiecode.dev/unraid/unraid-create-custom-docker-template.html) - Local testing setup
- [Unraid Docker Troubleshooting Docs](https://docs.unraid.net/unraid-os/troubleshooting/common-issues/docker-troubleshooting/) - Common issues and solutions
- [GitHub: binhex/docker-templates](https://github.com/binhex/docker-templates) - Real-world template examples (SABnzbd examined)
- [GitHub: digiblur/unraid-docker-templates](https://github.com/digiblur/unraid-docker-templates) - Real-world template examples (ha-dockermon examined)

### Tertiary (LOW confidence - marked for validation)
- Various Unraid forum threads on template issues - anecdotal evidence of common mistakes
- WebSearch results for 2026 Unraid practices - no major changes from 2025 detected, stable ecosystem

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Unraid template system is well-documented and stable
- Architecture: MEDIUM - Core patterns verified via official docs, some details inferred from examples
- Pitfalls: MEDIUM - Common issues documented across multiple sources, some from community reports
- API key strategy: LOW - Multiple valid approaches, no single authoritative best practice found

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - stable ecosystem, infrequent breaking changes)

**Notes:**
- Unraid template system is mature and stable - no major changes expected in near term
- Community Applications process is well-established with ~48hr review cycle
- User decisions from CONTEXT.md fully incorporated (Category: Productivity, Description: "The AI that actually does things", Icon from GitHub raw, Support URL placeholder for Phase 4)
- Recommendations favor standard Unraid conventions over performance optimizations for broader compatibility
