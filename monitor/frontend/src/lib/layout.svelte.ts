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
  // Panel-wide view selection; navigation does not use a router.
  view = $state<View>('dashboard')
  /// The page a `back` went to, on the server it was on.
  #backTo = $state<{ view: View; server: string } | null>(null)
  /// Shared by the sidebar and empty state, which open the same form.
  addServerOpen = $state(false)

  toggleCollapsed() {
    this.collapsed = !this.collapsed
    writePref('sidebar.collapsed', this.collapsed ? '1' : '0')
  }

  /// Which way the page transition runs: back only while the page a `back`
  /// opened is still the one shown, so a server switch after it is forward.
  get navDirection(): 'forward' | 'back' {
    const to = this.#backTo
    return to && to.view === this.view && to.server === servers.currentId ? 'back' : 'forward'
  }

  navigate(view: View) {
    this.#backTo = null
    this.view = view
  }

  back(view: View) {
    this.#backTo = { view, server: servers.currentId }
    this.view = view
  }
}

export const layout = new LayoutStore()
