import { defineApp } from '../../sys'

export default defineApp({
  id: 'status',
  title: (ll) => ll.deskAppStatus(),
  keywords: (ll) => [ll.cpuUsage(), ll.memory(), ll.diskUsage(), ll.network()],
  glyph: 'monitoring',
  tone: 'berry',
  size: { width: 1100, height: 720 },
  order: 0,
  pinned: true,
  load: () => import('./StatusApp.svelte'),
})
