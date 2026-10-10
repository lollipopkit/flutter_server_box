import { defineApp } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'store',
  title: (ll) => ll.storeTitle(),
  keywords: (ll) => [ll.storeKeywords()],
  glyph: 'storefront',
  tone: 'berry',
  // The web apps this agent can deploy: every account browses, an admin
  // installs.
  available: (caps) => caps?.features?.includes('stacks') === true,
  size: { width: 1040, height: 720 },
  minSize: { width: 420, height: 360 },
  order: 125,
  load: () => import('./StoreApp.svelte'),
})
