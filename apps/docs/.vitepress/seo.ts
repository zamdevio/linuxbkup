import type { HeadConfig } from 'vitepress'

const DOCS_URL = 'https://linuxbkup.pages.dev'
const SITE_NAME = 'linuxbkup'
const SITE_TITLE = 'linuxbkup — Universal Linux backup'
const DEFAULT_DESCRIPTION =
  'Universal Linux backup — Bash + coreutils + small tools. Desktop, VPS, WSL; Alpine/iSH/Termux best-effort. Atomic tar.zst, classify-not-dump, secrets with age.'
const OG_IMAGE = `${DOCS_URL}/linuxbkup.svg`
const GITHUB_URL = 'https://github.com/zamdevio/linuxbkup'

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

function isHome(relativePath: string): boolean {
  return (
    relativePath === 'index.md' ||
    relativePath.endsWith('/index.md') ||
    relativePath === '' ||
    relativePath === './'
  )
}

function serializeJsonLd(value: Record<string, unknown>): string {
  return JSON.stringify(value).replace(/</g, '\\u003c')
}

/** Per-page Open Graph, Twitter, robots, and JSON-LD. */
export function transformDocsHead(ctx: { pageData: DocsPageData }): HeadConfig[] {
  const { pageData } = ctx
  const home = isHome(pageData.relativePath)
  const description = pageData.description ?? DEFAULT_DESCRIPTION
  const url = docsPageUrl(pageData.relativePath)

  const headline = home
    ? SITE_TITLE
    : pageData.title
      ? `${pageData.title} | ${SITE_NAME}`
      : `${SITE_NAME} docs`

  const ogType = home ? 'website' : 'article'

  const jsonLd = home
    ? {
        '@context': 'https://schema.org',
        '@type': 'WebSite',
        name: SITE_NAME,
        alternateName: 'linuxbkup docs',
        url: `${DOCS_URL}/`,
        description: DEFAULT_DESCRIPTION,
        inLanguage: 'en-US',
        isPartOf: {
          '@type': 'WebSite',
          url: `${DOCS_URL}/`,
          name: SITE_NAME,
        },
        mainEntity: {
          '@type': 'SoftwareApplication',
          name: 'linuxbkup',
          applicationCategory: 'DeveloperApplication',
          operatingSystem: 'Linux',
          url: GITHUB_URL,
          description: DEFAULT_DESCRIPTION,
          license: 'https://github.com/zamdevio/linuxbkup/blob/main/LICENSE',
        },
      }
    : {
        '@context': 'https://schema.org',
        '@type': 'TechArticle',
        headline,
        description,
        url,
        mainEntityOfPage: url,
        inLanguage: 'en-US',
        isPartOf: {
          '@type': 'WebSite',
          name: SITE_NAME,
          url: `${DOCS_URL}/`,
        },
        author: {
          '@type': 'Organization',
          name: 'zamdevio',
          url: GITHUB_URL,
        },
        publisher: {
          '@type': 'Organization',
          name: SITE_NAME,
          url: `${DOCS_URL}/`,
        },
      }

  return [
    ['link', { rel: 'canonical', href: url }],
    ['meta', { name: 'description', content: description }],
    ['meta', { name: 'robots', content: home ? 'index, follow, max-image-preview:large' : 'index, follow' }],
    ['meta', { name: 'author', content: 'zamdevio' }],
    ['meta', { name: 'application-name', content: SITE_NAME }],
    ['meta', { name: 'color-scheme', content: 'light dark' }],
    // Open Graph
    ['meta', { property: 'og:site_name', content: `${SITE_NAME} Docs` }],
    ['meta', { property: 'og:locale', content: 'en_US' }],
    ['meta', { property: 'og:type', content: ogType }],
    ['meta', { property: 'og:title', content: headline }],
    ['meta', { property: 'og:description', content: description }],
    ['meta', { property: 'og:url', content: url }],
    ['meta', { property: 'og:image', content: OG_IMAGE }],
    ['meta', { property: 'og:image:alt', content: `${SITE_NAME} logo` }],
    // Twitter
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:site', content: '@zamdevio' }],
    ['meta', { name: 'twitter:title', content: headline }],
    ['meta', { name: 'twitter:description', content: description }],
    ['meta', { name: 'twitter:image', content: OG_IMAGE }],
    ['meta', { name: 'twitter:image:alt', content: `${SITE_NAME} logo` }],
    ['script', { type: 'application/ld+json' }, serializeJsonLd(jsonLd)],
  ]
}
