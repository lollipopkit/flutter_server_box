import { defineApp } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'storage',
  title: (ll) => ll.storageTitle(),
  keywords: (ll) => [ll.storageDisks(), ll.storageRaid(), ll.storagePools(), 'RAID', 'ZFS', 'NAS'],
  glyph: 'hard_drive',
  tone: 'ink',
  // Every change is root's: an admin's page, on an agent that serves it.
  available: (caps) => caps?.features?.includes('storage') === true && caps.me?.admin === true,
  size: { width: 1080, height: 720 },
  order: 75,
  load: () => import('./StorageApp.svelte'),
})
