import { defineApp, feature } from '../../sys'

export default defineApp({
  id: 'bmc',
  title: (ll) => ll.bmc(),
  keywords: () => ['IPMI', 'Redfish'],
  glyph: 'developer_board',
  tone: 'teal',
  available: feature('bmc'),
  order: 130,
  load: () => import('./BmcApp.svelte'),
})
