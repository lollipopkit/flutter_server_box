import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'process',
  title: (ll) => ll.processes(),
  glyph: 'browse_activity',
  tone: 'teal',
  available: feature('process'),
  order: 40,
  load: () => import('./ProcessApp.svelte'),
})
