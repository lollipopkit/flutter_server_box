import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'containers',
  title: (ll) => ll.containers(),
  glyph: 'deployed_code',
  tone: 'pale',
  available: feature('containers'),
  order: 30,
  pinned: true,
  load: () => import('./ContainersApp.svelte'),
})
