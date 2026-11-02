import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'storage',
  title: (ll) => ll.storageTitle(),
  keywords: (ll) => [ll.storageDisks(), ll.storageRaid(), ll.storagePools(), 'RAID', 'ZFS', 'NAS'],
  glyph: 'hard_drive',
  tone: 'ink',
  available: feature('storage'),
  size: { width: 1080, height: 720 },
  order: 75,
  load: () => import('./StorageApp.svelte'),
})
