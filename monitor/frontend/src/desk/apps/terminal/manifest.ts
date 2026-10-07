import { defineApp, access } from '../../sys'

export default defineApp({
  id: 'terminal',
  title: (ll) => ll.terminal(),
  glyph: 'terminal',
  tone: 'ink',
  available: access('terminal'),
  instances: 6,
  size: { width: 860, height: 540 },
  minSize: { width: 360, height: 220 },
  order: 20,
  pinned: true,
  load: () => import('./TerminalApp.svelte'),
  settings: () => import('./TerminalSettings.svelte'),
})
