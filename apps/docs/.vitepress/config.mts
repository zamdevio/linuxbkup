import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'

import { transformDocsHead } from './seo.js'
import { sidebar } from './sidebar.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
// Content source of truth: repository docs/ (single source — no sync copy).
const srcDir = resolve(__dirname, '../../../docs')
const publicDir = resolve(__dirname, '../public')
// Absolute site URL for sitemap + seo.ts (VitePress 2 alpha has no UserConfig.site).
const SITE_URL = 'https://linuxbkup.pages.dev'

export default defineConfig({
  title: 'linuxbkup',
  description:
    'Universal Linux backup — Bash + coreutils + small tools. Desktop, VPS, WSL; Alpine/iSH/Termux best-effort. Atomic tar.zst, classify-not-dump, secrets with age.',
  lang: 'en-US',
  appearance: true,
  srcDir,
  // GitHub-browsable index stays in repo; site home is docs/index.md
  srcExclude: ['**/README.md'],
  cleanUrls: true,
  ignoreDeadLinks: true,
  sitemap: {
    hostname: SITE_URL,
  },
  transformHead: transformDocsHead,
  vite: {
    publicDir,
    resolve: {
      // srcDir lives outside apps/docs — pin vue for SSR bundle resolution
      alias: {
        vue: resolve(__dirname, '../node_modules/vue'),
        'vue/server-renderer': resolve(
          __dirname,
          '../node_modules/@vue/server-renderer'
        ),
      },
      dedupe: ['vue'],
    },
  },
  head: [
    ['link', { rel: 'icon', href: '/linuxbkup.svg', type: 'image/svg+xml' }],
    ['link', { rel: 'icon', href: '/linuxbkup.svg', sizes: 'any' }],
    ['meta', { name: 'theme-color', content: '#0b1220' }],
    ['meta', { name: 'color-scheme', content: 'light dark' }],
    ['meta', { name: 'application-name', content: 'linuxbkup' }],
    ['meta', { name: 'author', content: 'zamdevio' }],
    ['meta', { name: 'generator', content: 'VitePress' }],
    ['meta', { property: 'og:site_name', content: 'linuxbkup Docs' }],
    ['meta', { property: 'og:locale', content: 'en_US' }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
  ],
  themeConfig: {
    logo: '/linuxbkup.svg',
    nav: [
      { text: 'Guide', link: '/guide' },
      { text: 'Install', link: '/install' },
      { text: 'Platforms', link: '/platforms' },
      { text: 'CLI', link: '/cli' },
      { text: 'GitHub', link: 'https://github.com/zamdevio/linuxbkup' },
    ],
    sidebar,
    search: { provider: 'local' },
    socialLinks: [{ icon: 'github', link: 'https://github.com/zamdevio/linuxbkup' }],
    footer: {
      message: 'Bash-first Linux backup — no Node runtime in the CLI.',
      copyright: 'MIT · linuxbkup',
    },
  },
})
