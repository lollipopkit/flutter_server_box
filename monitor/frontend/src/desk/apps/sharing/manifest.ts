import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'sharing',
  title: (ll) => ll.sharingTitle(),
  keywords: (ll) => [ll.sharingSmb(), ll.sharingNfs(), 'SMB', 'NFS', 'Samba', 'NAS'],
  glyph: 'folder_shared',
  tone: 'ink',
  available: feature('shares'),
  size: { width: 980, height: 680 },
  order: 76,
  load: () => import('./SharingApp.svelte'),
})
