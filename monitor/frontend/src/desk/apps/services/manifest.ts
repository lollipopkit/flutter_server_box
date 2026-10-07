import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'services',
  title: (ll) => ll.services(),
  glyph: 'dns',
  tone: 'violet',
  available: feature('services'),
  order: 50,
  load: () => import('./ServicesApp.svelte'),
})
