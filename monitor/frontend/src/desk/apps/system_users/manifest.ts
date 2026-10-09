import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'system_users',
  title: (ll) => ll.systemUsers(),
  glyph: 'group',
  tone: 'leaf',
  available: feature('system_users'),
  order: 70,
  load: () => import('./SystemUsersApp.svelte'),
})
