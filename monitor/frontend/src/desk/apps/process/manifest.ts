import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'process',
  title: (ll) => ll.processes(),
  glyph: 'memory',
  tone: 'ink',
  available: feature('process'),
  order: 40,
  load: () => import('./ProcessApp.svelte'),
  settings: () => import('./ProcessSettings.svelte'),
})
