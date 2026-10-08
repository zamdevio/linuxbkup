import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'

import { transformDocsHead } from './seo.js'
import { sidebar } from './sidebar.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
// Content source of truth: repository docs/ (single source — no sync copy).
const srcDir = resolve(__dirname, '../../../docs')
const publicDir = resolve(__dirname, '../public')

export default defineConfig({
  title: 'linuxbkup',
  description:
    'Universal Linux backup — Bash + coreutils + small tools. Desktop, VPS, WSL; Alpine/iSH/Termux best-effort.',
  lang: 'en-US',
  appearance: true,
  srcDir,
  // GitHub-browsable index stays in repo; site home is docs/index.md
  srcExclude: ['**/README.md'],
  cleanUrls: true,
  ignoreDeadLinks: true,
  site: 'https://linuxbkup.pages.dev',
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
