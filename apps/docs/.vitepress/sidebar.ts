/**
 * Manual VitePress sidebar (srcDir: repo docs/, cleanUrls: true).
 * Update when adding, renaming, or removing pages under docs/.
 */
import type { DefaultTheme } from 'vitepress'

export const sidebar: DefaultTheme.Config['sidebar'] = {
  '/': [
    {
      text: 'Start here',
      items: [
        { text: 'Overview', link: '/' },
        { text: 'Install', link: '/install' },
        { text: 'Concepts', link: '/concepts' },
        { text: 'Guide', link: '/guide' },
      ],
    },
    {
      text: 'Using linuxbkup',
      collapsed: false,
      items: [
        { text: 'Platforms', link: '/platforms' },
        { text: 'Profiles', link: '/profiles' },
        { text: 'Ask & automation', link: '/ask-and-automation' },
        { text: 'Secrets', link: '/secrets' },
      ],
    },
    {
      text: 'Reference',
      collapsed: false,
      items: [
        { text: 'CLI', link: '/cli' },
        { text: 'Schema & archive', link: '/schema' },
        { text: 'Troubleshooting', link: '/troubleshooting' },
      ],
    },
  ],
}
