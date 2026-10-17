import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'cleanup',
  title: (ll) => ll.cleanup(),
  keywords: (ll) => [ll.cleanupKeywords(), 'apt', 'journal', 'cache'],
  glyph: 'cleaning_services',
  tone: 'teal',
  available: feature('cleanup'),
  size: { width: 820, height: 700 },
  minSize: { width: 440, height: 400 },
  order: 141,
  load: () => import('./CleanupApp.svelte'),
})
