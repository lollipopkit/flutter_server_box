import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'remote_desktop',
  title: (ll) => ll.desktop(),
  keywords: () => ['VNC', 'RDP'],
  glyph: 'desktop_windows',
  tone: 'sky',
  available: feature('desktop'),
  instances: 4,
  size: { width: 1180, height: 760 },
  order: 100,
  load: () => import('./RemoteDesktopApp.svelte'),
})
