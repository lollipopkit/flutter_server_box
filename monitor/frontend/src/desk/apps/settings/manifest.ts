import { defineApp } from '../../sys'

export default defineApp({
  id: 'settings',
  title: (ll) => ll.deskAppSettings(),
  glyph: 'settings',
  tone: 'mist',
  size: { width: 900, height: 640 },
  order: 150,
  pinned: true,
  load: () => import('./SettingsApp.svelte'),
})
