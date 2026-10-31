import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'services',
  title: (ll) => ll.services(),
  glyph: 'dns',
  tone: 'bright',
  available: feature('services'),
  order: 50,
  load: () => import('./ServicesApp.svelte'),
})
