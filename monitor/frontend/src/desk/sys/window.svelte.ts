/// An app's handle on the window it runs in: the one way an app reaches the
/// desk (see `docs/dev/desk-sys.md`).

import { getContext, untrack } from 'svelte'
import type { MenuEntry } from '../lk/Menu.svelte'
import type { AppIconChrome, AppMenu, WindowChrome } from '../window/chrome.svelte'
import type { AppStorage } from '../appData'
import type { AppNotice } from '../notifications.svelte'
import type { Intent, OpenOptions } from '../windows.svelte'

/// Where a window's process is in its life.
/// - `active`: the front window.
/// - `visible`: on screen behind it.
/// - `background`: hidden (minimised, the desk locked, the browser tab
///   hidden). Not drawn; the app should stop work done only for the eye.
/// - `suspended`: hidden while background running is not allowed. The app's
///   content is unmounted and mounted again when the window comes back.
export type LifecycleState = 'active' | 'visible' | 'background' | 'suspended'

export interface WindowHandle {
  readonly id: string
  /// The app it runs.
  readonly appId: string
  /// What the app saved for itself; null on a fresh window.
  readonly appState: unknown
  /// Small JSON (≤16 KiB, never secrets) to come back with after a reload or
  /// a suspension. Save it when it changes.
  setAppState(state: unknown): void
  /// Replaces the app's title in the title bar, the dock menu and Spotlight.
  setTitle(title: string | null): void
  /// The app's name in the menubar; null for the manifest's.
  setAppName(name: string | null): void
  /// The app's icon in the menubar and dock; null for the manifest's.
  setIcon(icon: AppIconChrome | null): void
  /// A short badge on the app's dock icon (a count); null for none.
  setBadge(badge: string | number | null): void
  close(): void
  /// Opens another app (or another window of one) on this desk. Answers the
  /// window's id, or null when the app is not available or at its limit.
  open(appId: string, options?: OpenOptions): string | null
  /// Tells the user something: a banner (unless Do Not Disturb) and a row in
  /// the notification centre, which brings this window forward when clicked.
  notify(notice: AppNotice): void
  /// What the app keeps for itself, shared by its windows: per account and
  /// server, kept by the agent. Not for secrets.
  readonly storage: AppStorage
  /// The other apps that open [path] (`opens` in their manifests), for an
  /// "Open with" menu; open one with `open(id, { intent: { action: 'open',
  /// data: { path, kind } } })`.
  handlers(path: string, kind: 'file' | 'dir'): AppHandler[]
  /// Puts an icon on the desk that opens [path] with this window's app.
  addPathIcon(path: string, label: string): void
  readonly active: boolean
  readonly lifecycle: LifecycleState
  /// The window's frame, where `AppToolbar`, `SplitView` and `useMenus` put
  /// what they register; null outside a window (a test), where `AppToolbar`
  /// and `SplitView` draw themselves in place.
  readonly chrome: WindowChrome | null
}

export interface AppHandler {
  id: string
  title: string
  glyph: string
  tone: AppIconChrome['tone']
}

/// The desk's own intent: open a path (`data: OpenPath`).
export const OPEN = 'open'
export interface OpenPath {
  path: string
  kind: 'file' | 'dir'
}

export const WINDOW = Symbol('desk-window')

/// The window the calling component is in. Outside one (a test rendering an
/// app alone) it answers a handle that does nothing.
export function useWindow(): WindowHandle {
  return getContext<WindowHandle | undefined>(WINDOW) ?? DETACHED
}

const DETACHED: WindowHandle = {
  id: '',
  appId: '',
  appState: null,
  setAppState() {},
  setTitle() {},
  setAppName() {},
  setIcon() {},
  setBadge() {},
  close() {},
  open: () => null,
  notify() {},
  handlers: () => [],
  storage: {
    get: async () => undefined,
    set: async () => {},
    remove: async () => {},
    keys: async () => [],
  },
  addPathIcon() {},
  active: true,
  lifecycle: 'active',
  chrome: null,
}

/// The app's menubar menus while the calling component is mounted, read
/// again whenever what [menus] reads changes.
export function useMenus(menus: () => AppMenu[]) {
  const chrome = useWindow().chrome
  if (!chrome) return
  const entry = {
    get menus() {
      return menus()
    },
  }
  $effect(() => chrome.pushMenus(entry))
}

/// Rows added to the app's dock menu while the calling component is mounted
/// (the newest window's, above the desk's own rows).
export function useDockMenu(items: () => MenuEntry[]) {
  const chrome = useWindow().chrome
  if (!chrome) return
  const entry = {
    get menus() {
      return [{ label: '', items: items() }]
    },
  }
  $effect(() => chrome.pushDockMenu(entry))
}

/// Runs [handle] for each intent this window is given: the one it was opened
/// with, and any later `open` that lands on it (an app of one window).
/// Intents wait until a handler is mounted, so none is lost to timing.
export function useIntents(handle: (intent: Intent) => void) {
  const chrome = useWindow().chrome
  if (!chrome) return
  $effect(() => {
    if (chrome.pendingIntents === 0) return
    for (const intent of untrack(() => chrome.takeIntents())) handle(intent)
  })
}

const KEEP_ALIVE_MAX_MS = 10 * 60_000

export interface Lifecycle {
  readonly state: LifecycleState
  /// Keeps the app running while hidden, even where background running is
  /// off, until the returned function is called or 10 minutes pass. For
  /// work the user started and would lose (an upload).
  keepAlive(reason: string): () => void
}

export function useLifecycle(): Lifecycle {
  const win = useWindow()
  return {
    get state() {
      return win.lifecycle
    },
    keepAlive(reason) {
      if (!win.chrome) return () => {}
      const release = win.chrome.holdKeepAlive(reason)
      const timer = setTimeout(release, KEEP_ALIVE_MAX_MS)
      return () => {
        clearTimeout(timer)
        release()
      }
    },
  }
}

export type { AppMenu, AppIconChrome, AppNotice, AppStorage, Intent, MenuEntry, OpenOptions }
