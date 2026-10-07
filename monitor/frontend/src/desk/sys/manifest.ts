/// What an app tells the desk about itself: its manifest. Every app, built in
/// or not, is one `defineApp({...})` (a built-in app's sits in
/// `apps/<id>/manifest.ts` and is found on its own); the dock, the
/// launchpad, Spotlight, the window manager and the session read nothing else.

import type { Component } from 'svelte'
import type { TranslationFunctions } from '../../i18n/i18n-types'
import { dashboardAccess } from '../../lib/access'
import { enabledFeatures, type FeatureId } from '../../lib/features'
import type { Capabilities } from '../../types'
import type { IconTone } from '../lk/AppIcon.svelte'
import type { Size } from '../geometry'
import type { WindowPolicy } from '../windows.svelte'

/// Text in the user's language: a fixed string, or read from the
/// translations when the app has keys there.
export type Localized = string | ((ll: TranslationFunctions) => string)

export interface Opens {
  dirs?: boolean
  ext?: string[]
}

/// Whether an app that opens [opens] takes [path] of [kind].
export function opensPath(opens: Opens, path: string, kind: 'file' | 'dir'): boolean {
  if (kind === 'dir') return opens.dirs === true
  const ext = /\.([^./]+)$/.exec(path)?.[1]?.toLowerCase()
  return (opens.ext ?? []).some((e) => e === '*' || e === ext)
}

export interface AppManifest {
  /// Stable: windows, the dock and desk icons are stored by it.
  /// Lowercase letters, digits and `_`, starting with a letter.
  id: string
  title: Localized
  /// Words Spotlight also finds it by, besides its title.
  keywords?: (ll: TranslationFunctions) => string[]
  /// The app icon's glyph (Material Symbols Rounded) and tile tone.
  glyph: string
  tone: IconTone
  /// Whether this server and this account can use it; always when absent.
  /// `undefined` capabilities (not fetched yet) answer false for anything
  /// gated.
  available?: (caps: Capabilities | undefined) => boolean
  /// How many windows may be open; 1 (the default) focuses the open one.
  instances?: number
  size?: Size
  minSize?: Size
  /// What it opens, for Files' "Open with" and the `open` intent: folders,
  /// and files by extension (lowercase, no dot; `*` for any file).
  opens?: Opens
  /// Its page in Settings → Apps, lazy like [load]. It runs as the app
  /// (`useWindow().storage` is the app's), inside the Settings window.
  settings?: () => Promise<{ default: Component }>
  /// Place in the launchpad and Spotlight, lowest first; then by id.
  order?: number
  /// In a fresh desk's dock.
  pinned?: boolean
  /// The window's content. Lazy, so an app nobody opens is never loaded.
  load: () => Promise<{ default: Component }>
}

/// A manifest with every default filled in, as the shell reads it.
export interface AppSpec extends WindowPolicy {
  id: string
  /// `system`: built in, trusted. `web`: installed on the agent, run in a
  /// sandboxed frame with only its approved [permissions].
  kind: 'system' | 'web'
  permissions?: readonly string[]
  title: (ll: TranslationFunctions) => string
  keywords?: (ll: TranslationFunctions) => string[]
  glyph: string
  tone: IconTone
  available: (caps: Capabilities | undefined) => boolean
  opens: Opens
  settings?: () => Promise<{ default: Component }>
  order: number
  pinned: boolean
  load: () => Promise<{ default: Component }>
}

/// The agent keeps app ids to 32 bytes (`api::desk::valid_app_id`).
const ID = /^[a-z][a-z0-9_]{0,31}$/
const SIZE: Size = { width: 1040, height: 680 }
const MIN_SIZE: Size = { width: 420, height: 300 }

export function defineApp(m: AppManifest): AppSpec {
  if (!ID.test(m.id)) throw new Error(`app id ${JSON.stringify(m.id)}: lowercase letters, digits and _`)
  const instances = m.instances ?? 1
  if (!Number.isInteger(instances) || instances < 1) throw new Error(`app ${m.id}: instances must be ≥ 1`)
  const title = m.title
  return {
    id: m.id,
    kind: 'system',
    title: typeof title === 'string' ? () => title : title,
    keywords: m.keywords,
    glyph: m.glyph,
    tone: m.tone,
    available: m.available ?? (() => true),
    opens: { dirs: m.opens?.dirs === true, ext: (m.opens?.ext ?? []).map((e) => e.toLowerCase().replace(/^\./, '')) },
    instances,
    size: m.size ?? SIZE,
    minSize: m.minSize ?? MIN_SIZE,
    settings: m.settings,
    order: m.order ?? Number.MAX_SAFE_INTEGER,
    pinned: m.pinned ?? false,
    load: m.load,
  }
}

/// Available when the agent lists [id] among its features.
export function feature(id: FeatureId) {
  return (caps: Capabilities | undefined) => enabledFeatures(caps).some((f) => f.id === id)
}

/// Available when this account may use the server's terminal or files.
export function access(kind: 'terminal' | 'files') {
  return (caps: Capabilities | undefined) => dashboardAccess(caps)[kind]
}
