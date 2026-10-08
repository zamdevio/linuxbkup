# linuxbkup docs app (VitePress)

Docs **content** lives in the repository [`docs/`](../../docs) — single source of truth.

## Layout choice (07.1) — direct `srcDir`, no sync

| Approach | Used here? | Why |
|----------|------------|-----|
| CepatEdge / expgov **sync** `docs/` → `apps/docs/content/` | No | Built for large corpora + markdown sanitization + workspace SEO packages |
| **Direct** `srcDir: ../../../docs` | **Yes** | Small stable corpus; build already green; no copy drift |

- Marketing home: [`docs/index.md`](../../docs/index.md) (`layout: home`) → site `/`
- Repo [`docs/README.md`](../../docs/README.md) stays the **GitHub folder index** — excluded from the site (`srcExclude: **/README.md`) so it does not fight `index.md` at `/`
- Public assets: `apps/docs/public/` (logo)
- If the corpus grows or markdown needs sanitization (`${…}`, `{{…}}`), switch to CepatEdge-style `scripts/sync.js` later — content source stays `docs/`

## Commands

```bash
cd apps/docs
pnpm install
pnpm dev          # http://localhost:8283
pnpm build        # → .vitepress/dist
pnpm typecheck
pnpm deploy       # wrangler pages deploy .vitepress/dist --project-name=linuxbkup
```

Production URL: **https://linuxbkup.pages.dev** (Cloudflare Pages project `linuxbkup`)

## Social card

`public/og.png` (1200×630) is the Open Graph / Twitter image. Regenerate:

```bash
python3 scripts/make-og.py   # needs Pillow
```

Favicon/logo stays `public/linuxbkup.svg`.

## Rules

- Core CLI stays **Bash** — Node is only used under `apps/docs`
- Update `.vitepress/sidebar.ts` when adding/renaming pages in `docs/`
- `pnpm-workspace.yaml` in this app allows `esbuild` + `workerd` build scripts
