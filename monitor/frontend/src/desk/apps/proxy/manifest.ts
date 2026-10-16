import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'proxy',
  title: (ll) => ll.proxy(),
  keywords: (ll) => [ll.proxyKeywords(), 'nginx', 'Caddy', 'Traefik'],
  glyph: 'alt_route',
  tone: 'sky',
  available: feature('proxy'),
  size: { width: 980, height: 700 },
  minSize: { width: 480, height: 400 },
  order: 138,
  load: () => import('./ProxyApp.svelte'),
})
