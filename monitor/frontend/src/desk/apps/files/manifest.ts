import { defineApp, access } from '../../sys'

export default defineApp({
  id: 'files',
  title: (ll) => ll.files(),
  glyph: 'folder',
  tone: 'soft',
  available: access('files'),
  instances: 4,
  order: 10,
  pinned: true,
  load: () => import('./FilesApp.svelte'),
})
