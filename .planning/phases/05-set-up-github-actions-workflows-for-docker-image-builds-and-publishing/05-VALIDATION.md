---
phase: 5
slug: set-up-github-actions-workflows-for-docker-image-builds-and-publishing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-25
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GitHub Actions workflow syntax validation + shell script testing |
| **Config file** | `.github/workflows/docker-publish.yml`, `.github/workflows/docker-backfill.yml` |
| **Quick run command** | `actionlint .github/workflows/*.yml` |
| **Full suite command** | `actionlint .github/workflows/*.yml && shellcheck -x .github/scripts/*.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `actionlint .github/workflows/*.yml`
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | D-01,D-02,D-03 | lint | `actionlint .github/workflows/docker-publish.yml` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | D-09,D-10,D-11 | lint | `actionlint .github/workflows/docker-backfill.yml` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Install `actionlint` if not present — GitHub Actions workflow linter
- [ ] Install `shellcheck` if not present — shell script linter

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mutable tag resolution correctness | D-01, D-02 | Requires actual git tags and DockerHub push | Create test tags, run workflow, verify Docker tags on DockerHub |
| Backfill skip-if-exists logic | D-11 | Requires DockerHub API interaction | Run backfill for existing tag, verify skip with warning |
| Multi-platform image validity | D-12 | Requires docker manifest inspect on pushed image | `docker manifest inspect brglasser/openclaw:dev` |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
