import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'cron',
  title: (ll) => ll.cron(),
  glyph: 'schedule',
  tone: 'amber',
  available: feature('cron'),
  order: 60,
  load: () => import('./CronApp.svelte'),
})
