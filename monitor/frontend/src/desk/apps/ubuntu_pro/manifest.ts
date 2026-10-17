import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'ubuntu_pro',
  title: (ll) => ll.ubuntuPro(),
  keywords: (ll) => [ll.ubuntuProKeywords(), 'Livepatch', 'ESM', 'FIPS'],
  glyph: 'verified_user',
  tone: 'amber',
  available: feature('ubuntu_pro'),
  size: { width: 820, height: 680 },
  minSize: { width: 440, height: 380 },
  order: 140,
  load: () => import('./UbuntuProApp.svelte'),
})
