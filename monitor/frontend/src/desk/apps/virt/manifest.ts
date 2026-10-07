import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'virt',
  title: (ll) => ll.virt(),
  keywords: () => ['KVM', 'libvirt', 'Proxmox', 'PVE'],
  glyph: 'deployed_code',
  tone: 'bright',
  available: feature('virt'),
  size: { width: 1180, height: 760 },
  order: 120,
  pinned: true,
  load: () => import('./VirtApp.svelte'),
})
