# Phase 07 — VitePress site (`apps/docs` → CF Pages)

**Goal:** Ship docs site at **https://linuxbkup.pages.dev** via Cloudflare Pages project `linuxbkup` (already created). Content lives in repo `docs/`; app shell in `apps/docs`.

**Non-goals:** Turning the Bash CLI into Node; docs app is the only Node surface.

## Pattern sources (steal structure, not brand)

Borrow layout/patterns from:

| Sibling pattern repo (operator) | Steal |
|------|--------|
| `gform/apps/docs` | Home hero layout, feature grid, command-heavy sidebar, cyan/CLI-adjacent chrome, frosted nav |
| `i18nprune/apps/docs` | SEO/`transformHead`, OG helpers, cleanUrls + `srcDir`, Pages functions if needed |
| `expgov/apps/docs` | Leaner config.mts + sidebar split — good baseline size for a smaller product |

**Do not** copy gform/i18nprune brand colors blindly — pick a **linuxbkup** palette (terminal-green / slate; avoid purple-on-white default AI look).

## Target layout

```text
apps/docs/
  package.json              # @zamdevio/linuxbkup-docs or linuxbkup-docs
  .vitepress/
    config.mts              # site: https://linuxbkup.pages.dev
    sidebar.ts              # manual sidebar → docs pages
    seo.ts                  # canonical + og (lightweight; no heavy SEO pkg required v1)
    theme/
      index.ts
      custom.css
      sidebar.ts            # mobile overlay helper (from gform/expgov pattern)
    public/                 # logo svg, favicon
  index.md                  # VitePress home (layout: home) — custom landing
  README.md                 # how to dev/deploy this app
```

Content source options (pick one in slice 07.1):

1. **Preferred:** `srcDir: '../../docs'` and keep a **separate** `apps/docs/index.md` as the marketing home (gform style: home in app, deep pages in `docs/`).  
   - If VitePress needs home inside srcDir, use `docs/index.md` as home **or** symlink/copy strategy documented in README.
2. Alternate: mirror/copy — avoid; single source of truth = `docs/`.

Locked preference: **one source** (`docs/*.md`). Custom VitePress home either:

- `docs/index.md` with `layout: home`, and repo `docs/README.md` becomes overview link, **or**
- `apps/docs` uses `srcDir: '.'` with re-exports — only if (1) fights VitePress; document the choice in 07.1.

## Home (`index.md`) content sketch

```yaml
layout: home
hero:
  name: linuxbkup
  text: Backup what can't be regenerated
  tagline: Portable Linux backup/restore — desktop, VPS, and WSL. Scan, decide, archive, restore with a real schema.
  actions:
    - Get started → /install
    - Guide → /guide
    - CLI → /cli
features:
  - Safety by default
  - Portable archives + schema
  - Full-home scan with unexpected-path reporting
  - Ask UI without requiring fzf
  - Secrets with age
  - Same CLI across machines
```

Quick start block with **generic** commands only.

## Deploy

```bash
# from apps/docs after build
wrangler pages deploy <dist> --project-name=linuxbkup
```

- Production branch: `main` (as created)
- URL: https://linuxbkup.pages.dev
- Optional: root `package.json` / pnpm workspace **only for apps/docs** — CLI stays Bash-first; do not pull Node into core runtime

## Slices

- [ ] **07.1** Scaffold `apps/docs` from expgov/gform lean template; lock `srcDir` / home strategy
- [ ] **07.2** `config.mts` + `sidebar.ts` matching phase 06 tree; `site` / hostname = `https://linuxbkup.pages.dev`
- [ ] **07.3** Theme `custom.css` — distinct palette, frosted nav (pattern from gform), light + dark
- [ ] **07.4** Custom `index.md` home (hero + features + quick start)
- [ ] **07.5** Lightweight SEO (canonical + og title/description)
- [ ] **07.6** Scripts: `dev`, `build`, `deploy` (wrangler pages)
- [ ] **07.7** First deploy to Pages; verify https://linuxbkup.pages.dev
- [ ] **07.8** Root README + `docs/README` link to live site

## Acceptance

- Local `pnpm --filter … docs:dev` (or equiv) serves content from `docs/`
- Production deploy reachable at https://linuxbkup.pages.dev
- Home is custom VitePress landing; inner pages are real guides
- Core CLI still has **zero** Node runtime dependency

## After ship

`shipped/` row + optional `systems/docs-site.md`.
