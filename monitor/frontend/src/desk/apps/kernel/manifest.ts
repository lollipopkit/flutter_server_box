import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'kernel',
  title: (ll) => ll.kernel(),
  keywords: (ll) => [ll.kernelKeywords(), 'Linux', 'GRUB'],
  glyph: 'memory',
  tone: 'ink',
  available: feature('kernel'),
  size: { width: 860, height: 680 },
  minSize: { width: 440, height: 380 },
  order: 139,
  load: () => import('./KernelApp.svelte'),
})
