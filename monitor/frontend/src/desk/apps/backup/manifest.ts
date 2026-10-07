import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'backup',
  title: (ll) => ll.backup(),
  glyph: 'backup',
  tone: 'leaf',
  available: feature('backup'),
  order: 140,
  load: () => import('./BackupApp.svelte'),
})
