import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'containers',
  title: (ll) => ll.containers(),
  glyph: 'inventory_2',
  tone: 'sky',
  available: feature('containers'),
  order: 30,
  pinned: true,
  load: () => import('./ContainersApp.svelte'),
})
