# Docs site — VitePress → Cloudflare Pages

**Live:** https://linuxbkup.pages.dev · CF Pages project `linuxbkup` · git provider **No** (wrangler upload)

## Layout

| Piece | Path | Role |
|-------|------|------|
| Content (single source) | `docs/*.md` | End-user markdown; `srcDir` points here |
| App shell | `apps/docs/` | VitePress config, theme, public assets, deploy scripts |
| Home | `docs/index.md` | `layout: home` marketing landing |
| Repo folder index | `docs/README.md` | GitHub-only — `srcExclude: **/README.md` |
| Theme | `apps/docs/.vitepress/theme/` | Slate + terminal-green custom.css |
| SEO | `apps/docs/.vitepress/seo.ts` | Per-page canonical, OG/Twitter, JSON-LD |
| Social card | `apps/docs/public/og.png` | 1200×630 PNG (`scripts/make-og.py`) |
| Favicon/logo | `apps/docs/public/linuxbkup.svg` | Also served for README `<img>` |

## Deploy

```bash
cd apps/docs
pnpm install
pnpm build && pnpm typecheck
pnpm deploy   # wrangler pages deploy .vitepress/dist --project-name=linuxbkup
```

Node is **only** under `apps/docs`. Core CLI stays Bash — zero Node runtime dependency.

## SEO rules

- Canonical paths match `sitemap.xml` + `cleanUrls` — **no trailing slash** except `/`
- Every page needs frontmatter `description` — VitePress yields `''` without it; `seo.ts` falls back to the site default
- `og:image` = `/og.png` (PNG); SVG is favicon/logo only
- `robots.txt` in `public/` points at `sitemap.xml`
- Update `sidebar.ts` when adding/renaming `docs/` pages

## Layout choice (07.1)

Direct `srcDir: ../../../docs` — no copy/sync step. If the corpus grows or markdown needs sanitization, switch to a CepatEdge-style sync script later; content source stays `docs/`.

Umbrella: [`../phases/focus.md`](../phases/focus.md) · roadmap [`../phases/roadmap.md`](../phases/roadmap.md)
