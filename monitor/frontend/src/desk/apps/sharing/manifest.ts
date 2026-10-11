import { defineApp } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'sharing',
  title: (ll) => ll.sharingTitle(),
  keywords: (ll) => [ll.sharingSmb(), ll.sharingNfs(), 'SMB', 'NFS', 'Samba', 'NAS'],
  glyph: 'folder_shared',
  tone: 'ink',
  // Every change is root's: an admin's page, on an agent that serves it.
  available: (caps) => caps?.features?.includes('shares') === true && caps.me?.admin === true,
  size: { width: 980, height: 680 },
  order: 76,
  load: () => import('./SharingApp.svelte'),
})
