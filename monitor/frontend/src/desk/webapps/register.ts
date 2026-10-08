/// Installed (`web`) apps: read from the agent when a desk starts and added
/// to the registry for that desk's life, each opening in a sandboxed frame
/// (`WebAppFrame.svelte`).

import { get } from 'svelte/store'
import { locale } from '../../i18n/i18n-svelte'
import type { ServerEntry } from '../../lib/servers.svelte'
import type { InstalledApp } from '../../types'
import { deskApi } from '../deskApi'
import type { IconTone } from '@lollipopkit/desk-ui/AppIcon.svelte'
import { registry } from '../registry.svelte'
import { defineApp, type AppSpec } from '../sys/manifest'

const TONES: IconTone[] = ['berry', 'soft', 'ink', 'sky', 'teal', 'violet', 'amber', 'leaf', 'pale', 'bright', 'mist']

/// The title in the panel's language, else English.
function title(t: InstalledApp['manifest']['title']): () => string {
  if (typeof t === 'string') return () => t
  return () => {
    const current = get(locale)
    return t[current] ?? t[current.split('-')[0]] ?? t.en ?? ''
  }
}

/// [app] as the shell reads it. Only approved apps are given here.
export function webAppSpec(app: InstalledApp): AppSpec {
  const m = app.manifest
  const spec = defineApp({
    id: m.id,
    title: title(m.title),
    keywords: () => m.keywords ?? [],
    glyph: m.glyph,
    tone: TONES.includes(m.tone as IconTone) ? (m.tone as IconTone) : 'mist',
    instances: m.instances,
    size: m.size,
    minSize: m.min_size,
    opens: m.opens,
    load: () => import('./WebAppFrame.svelte'),
  })
  return { ...spec, kind: 'web', permissions: app.approved_permissions ?? [] }
}

/// Adds [entry]'s approved apps; the returned function takes them away. An
/// app whose id a built-in app has is skipped, never replaced.
///
/// [before] runs once the list has arrived, just before adding: the desk
/// takes away what it added last, so a reload never leaves both.
export async function registerWebApps(entry: ServerEntry, before: () => void = () => {}): Promise<() => void> {
  const { apps } = await deskApi.apps(entry)
  before()
  const offs: (() => void)[] = []
  for (const app of apps) {
    if (!app.approved_permissions) continue
    try {
      offs.push(registry.register(webAppSpec(app)))
    } catch (e) {
      console.warn(`desk app ${app.id} not added:`, e)
    }
  }
  return () => offs.forEach((off) => off())
}
