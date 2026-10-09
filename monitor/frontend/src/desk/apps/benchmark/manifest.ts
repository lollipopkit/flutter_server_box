import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'benchmark',
  title: (ll) => ll.benchmark(),
  glyph: 'speed',
  tone: 'amber',
  available: feature('benchmark'),
  order: 110,
  load: () => import('./BenchmarkApp.svelte'),
})
