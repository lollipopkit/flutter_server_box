/// Installed (`web`) apps: read from the agent when a desk starts and added
/// to the registry for that desk's life, each opening in a sandboxed frame
/// (`WebAppFrame.svelte`).

import { get } from 'svelte/store'
import { locale } from '../../i18n/i18n-svelte'
import type { ServerEntry } from '../../lib/servers.svelte'
import type { InstalledApp } from '../../types'
import { deskApi } from '../deskApi'
import type { IconTone } from '../lk/AppIcon.svelte'
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
    publisher: m.publisher,
    name: m.name,
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

/// [entry]'s approved apps in the registry for one desk, kept in step with
/// the agent. An app whose package and grant are unchanged keeps its
/// registration, so its open windows stay as they are (a frame mid-form, a
/// sudo dialog waiting); one removed, replaced or no longer approved goes,
/// and a new one is added. An app whose id a built-in app has is skipped,
/// never replaced.
export class WebApps {
  readonly #entry: ServerEntry
  /// By app id: what was registered (its package and grant) and how to take
  /// it away.
  readonly #held = new Map<string, { key: string; off: () => void }>()
  /// One read at a time, in order: several changes may be said at once.
  #queue: Promise<void> = Promise.resolve()
  #closed = false

  constructor(entry: ServerEntry) {
    this.#entry = entry
  }

  /// Reads the installed apps again and registers what changed.
  reload(): Promise<void> {
    this.#queue = this.#queue.then(
      () => this.#reload(),
      () => this.#reload(),
    )
    return this.#queue
  }

  async #reload() {
    const { apps } = await deskApi.apps(this.#entry)
    if (this.#closed) return
    const next = new Map(apps.filter((a) => a.approved_permissions).map((a) => [a.id, a]))
    for (const [id, held] of this.#held) {
      const app = next.get(id)
      if (!app || keyOf(app) !== held.key) {
        held.off()
        this.#held.delete(id)
      }
    }
    for (const [id, app] of next) {
      if (this.#held.has(id)) continue
      try {
        this.#held.set(id, { key: keyOf(app), off: registry.register(webAppSpec(app)) })
      } catch (e) {
        console.warn(`desk app ${id} not added:`, e)
      }
    }
  }

  /// Takes every app away, for good: the desk is going.
  close() {
    this.#closed = true
    for (const held of this.#held.values()) held.off()
    this.#held.clear()
  }
}

/// What a registration stands for: the package and what it was granted.
function keyOf(app: InstalledApp): string {
  return `${app.sha256}|${(app.approved_permissions ?? []).join(',')}`
}
