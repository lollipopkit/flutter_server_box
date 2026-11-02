/// Store web apps (`/stacks`, `store/apps/<publisher>.<name>`) as desk apps:
/// read when a desk starts, each registered by its catalog id with its
/// manifest's name and icon, offered in All Apps while it is deployed
/// (`stackDeployed`), and opening the service in a window (`StackHost`). An
/// app the panel has its own desk app for (`STACK_APPS`) is left to it, and
/// one with no page (`web`, a model server) has no window.

import { get } from 'svelte/store'
import { STACK_APPS, stackDeployed, rememberStackApps } from '../../components/stack/apps'
import { pick } from '../../components/stack/text'
import { locale } from '../../i18n/i18n-svelte'
import { api } from '../../lib/api'
import type { StackApp } from '../../types'
import type { IconTone } from '../lk/AppIcon.svelte'
import { registry } from '../registry.svelte'
import { defineApp, type AppSpec } from '../sys/manifest'

const TONES: IconTone[] = ['berry', 'soft', 'ink', 'sky', 'teal', 'violet', 'amber', 'leaf', 'pale', 'bright', 'mist']

/// [app] as the shell reads it.
export function stackAppSpec(app: StackApp): AppSpec {
  const m = app.manifest
  const id = m.id
  return defineApp({
    publisher: m.publisher,
    name: m.name,
    title: () => pick(m.title, get(locale)),
    keywords: () => [m.project, ...m.categories],
    glyph: m.glyph,
    tone: TONES.includes(m.tone as IconTone) ? (m.tone as IconTone) : 'mist',
    available: (caps) => stackDeployed(caps, id),
    size: { width: 1180, height: 780 },
    minSize: { width: 480, height: 360 },
    load: () => import('./StackWindow.svelte'),
  })
}

/// Adds the catalog's apps; the returned function takes them away. [before]
/// runs once the list has arrived, just before adding: the desk takes away
/// what it added last, so a reload never leaves both.
export async function registerStackApps(before: () => void = () => {}): Promise<() => void> {
  const { apps } = await api.listStacks()
  before()
  const offs: (() => void)[] = []
  const ids: string[] = []
  for (const app of apps) {
    // A model server has no page: no window to open.
    if (STACK_APPS[app.manifest.id] || app.source === 'part' || !app.manifest.web) continue
    try {
      offs.push(registry.register(stackAppSpec(app)))
      ids.push(app.manifest.id)
    } catch (e) {
      // A desk app of the same id (an installed one) keeps it.
      console.warn(`web app ${app.manifest.id} not added:`, e)
    }
  }
  const forget = rememberStackApps(ids)
  return () => {
    offs.forEach((off) => off())
    forget()
  }
}
