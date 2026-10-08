import type { HeadConfig } from 'vitepress'

const DOCS_URL = 'https://linuxbkup.pages.dev'
const SITE_NAME = 'linuxbkup'
const DEFAULT_DESCRIPTION =
  'Universal Linux backup — Bash + coreutils + small tools. Desktop, VPS, WSL; Alpine/iSH/Termux best-effort.'

type DocsPageData = {
  title?: string
  description?: string
  relativePath: string
}

function docsPageUrl(relativePath: string): string {
  const slug = relativePath
    .replace(/(^|\/)index\.md$/, '$1')
    .replace(/README\.md$/, '')
    .replace(/\.md$/, '')
    .replace(/\/+$/, '')
  const path = slug.length > 0 ? `/${slug}/` : '/'
  return `${DOCS_URL}${path === '//' ? '/' : path}`
}

/** Per-page Open Graph tags for VitePress. */
export function transformDocsHead(ctx: { pageData: DocsPageData }): HeadConfig[] {
  const { pageData } = ctx
  const headline = pageData.title ? `${pageData.title} | ${SITE_NAME}` : `${SITE_NAME} docs`
  const description = pageData.description ?? DEFAULT_DESCRIPTION
  const url = docsPageUrl(pageData.relativePath)

  return [
    ['link', { rel: 'canonical', href: url }],
    ['meta', { property: 'og:title', content: headline }],
    ['meta', { property: 'og:description', content: description }],
    ['meta', { property: 'og:url', content: url }],
    ['meta', { property: 'og:type', content: 'article' }],
    ['meta', { property: 'og:site_name', content: `${SITE_NAME} Docs` }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:title', content: headline }],
    ['meta', { name: 'twitter:description', content: description }],
  ]
}
