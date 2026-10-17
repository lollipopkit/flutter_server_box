import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'tailscale',
  title: () => 'Tailscale',
  keywords: (ll) => [ll.tailscaleKeywords(), 'Tailscale', 'Headscale', 'VPN'],
  glyph: 'hub',
  tone: 'ink',
  available: feature('tailscale'),
  size: { width: 900, height: 720 },
  minSize: { width: 460, height: 400 },
  order: 142,
  load: () => import('./TailscaleApp.svelte'),
})
