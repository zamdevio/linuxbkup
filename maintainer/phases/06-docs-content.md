# Phase 06 — Docs content (`docs/*`)

**Goal:** Clear, portable end-user markdown under `docs/` that VitePress can consume later (`srcDir` → repo `docs/`). No sprint/`maintainer/` leakage. Generic examples only.

**Non-goals:** Building or deploying the site (phase 07).

## Target tree

```text
docs/
  README.md              # index for humans browsing the repo (also sidebar “Overview”)
  install.md
  concepts.md            # regenerate vs backup, safety, portability
  guide.md               # inspect → plan → backup → verify → restore
  profiles.md
  ask-and-automation.md  # --ask, --yes, non-TTY, --json, --print-plan
  platforms.md           # desktop / VPS / WSL — same tool
  schema.md              # archive layout + schema.json
  secrets.md
  troubleshooting.md
  cli.md                 # command reference (keep, rewrite)
  commands/              # optional per-command pages if cli.md grows
    backup.md
    restore.md
    inspect.md
    verify.md
    deps.md
```

## Content rules

- Product name: **linuxbkup** everywhere
- Platforms: “Works on most Linux distros — desktop, VPS, and WSL”
- Paths: `/home/user`, `~/Backups/linuxbkup/archive.tar.zst` — never personal hosts
- Defaults: safety + portability called out explicitly
- No `wslbkup` history lessons

## Slices

- [ ] **06.1** Rewrite `docs/README.md` + `docs/cli.md` for linuxbkup
- [ ] **06.2** Add install, concepts, guide
- [ ] **06.3** Add profiles, ask-and-automation, platforms
- [ ] **06.4** Add schema, secrets, troubleshooting
- [ ] **06.5** Cross-link consistently; match real flags from phases 00–05
- [ ] **06.6** Root `README.md` points at docs + https://linuxbkup.pages.dev (once live)

## Acceptance

- Someone can install and run a dry `--print-plan` from docs alone
- No personal paths; no maintainer links in `docs/`
- Tree matches what phase 07 sidebar will list

## After ship

Note in `shipped/`; site wiring is phase 07.
