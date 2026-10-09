import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'snippets',
  title: (ll) => ll.snippets(),
  glyph: 'code_blocks',
  tone: 'violet',
  available: feature('snippets'),
  order: 90,
  load: () => import('./SnippetsApp.svelte'),
})
