import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'firewall',
  title: (ll) => ll.fwTitle(),
  glyph: 'shield_lock',
  tone: 'pale',
  available: feature('firewall'),
  order: 80,
  load: () => import('./FirewallApp.svelte'),
})
