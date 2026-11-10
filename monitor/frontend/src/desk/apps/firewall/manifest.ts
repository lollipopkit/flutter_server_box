import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'firewall',
  title: (ll) => ll.fwTitle(),
  glyph: 'shield_lock',
  tone: 'pale',
  available: feature('firewall'),
  order: 80,
  load: () => import('./FirewallApp.svelte'),
})
