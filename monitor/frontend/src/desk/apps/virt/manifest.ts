import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'virt',
  title: (ll) => ll.virt(),
  keywords: () => ['KVM', 'libvirt', 'Proxmox', 'PVE'],
  glyph: 'stacks',
  tone: 'berry',
  available: feature('virt'),
  size: { width: 1180, height: 760 },
  order: 120,
  pinned: true,
  load: () => import('./VirtApp.svelte'),
})
