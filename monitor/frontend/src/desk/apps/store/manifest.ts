import { defineApp } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'store',
  title: (ll) => ll.storeTitle(),
  keywords: (ll) => [ll.storeKeywords()],
  glyph: 'storefront',
  tone: 'berry',
  // The web apps this agent can deploy: browsed over any link, installed
  // where the account may act.
  available: (caps) => caps?.features?.includes('stacks') === true,
  size: { width: 1040, height: 720 },
  // One window per app being installed: the guide opens a page for each of
  // the apps it recommends, and a deploy is confirmed on that page.
  instances: 6,
  minSize: { width: 420, height: 360 },
  order: 125,
  load: () => import('./StoreApp.svelte'),
})
