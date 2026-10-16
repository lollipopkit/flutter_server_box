import type { FeatureId } from './features'
import { readPref, writePref } from './prefs'
import { servers } from './servers.svelte'

/// Sidebar state with persistent desktop collapse and a transient mobile drawer.

/// 'panel' = browser-local prefs (language/theme), reached from the sidebar
/// footer, independent of any server. 'server-settings' = the currently
/// selected server's config.toml, reached from a gear icon on its dashboard.
/// 'terminal' = an SSH session on the selected server, reached from its
/// dashboard and only offered when that agent reports the feature available.
/// The machine-management pages are `FeatureId`s, listed once in
/// `lib/features.ts`.
export type View = 'dashboard' | 'panel' | 'server-settings' | 'terminal' | 'files' | FeatureId

class LayoutStore {
  collapsed = $state(readPref('sidebar.collapsed') === '1')
  mobileOpen = $state(false)
  #view = $state<View>('dashboard')
  /// Counts changes of `view`; with the server selections, every navigation.
  #views = $state(0)
  /// The navigation a `back` made, as `#step` read right after it.
  #backStep = $state<number | null>(null)
  /// Shared by the sidebar and empty state, which open the same form.
  addServerOpen = $state(false)

  toggleCollapsed() {
    this.collapsed = !this.collapsed
    writePref('sidebar.collapsed', this.collapsed ? '1' : '0')
  }

  // Panel-wide view selection; navigation does not use a router.
  get view(): View {
    return this.#view
  }

  set view(view: View) {
    if (view === this.#view) return
    this.#view = view
    this.#views++
  }

  /// Rises on every change of page or server; both counts only grow.
  get #step(): number {
    return this.#views + servers.selections
  }

  /// Which way the page transition runs: back only until the next change of
  /// page or server, so leaving and returning to the same pair is forward.
  get navDirection(): 'forward' | 'back' {
    return this.#backStep === this.#step ? 'back' : 'forward'
  }

  navigate(view: View) {
    this.#backStep = null
    this.view = view
  }

  back(view: View) {
    this.view = view
    this.#backStep = this.#step
  }
}

export const layout = new LayoutStore()
