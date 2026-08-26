/// Sidebar layout state: desktop collapse persisted, mobile drawer transient

/// 'panel' = browser-local prefs (language/theme), reached from the sidebar
/// footer, independent of any server. 'server-settings' = the currently
/// selected server's config.toml, reached from a gear icon on its dashboard.
/// 'terminal' = an SSH session on the selected server, reached from its
/// dashboard and only offered when that agent reports the feature available.
export type View = 'dashboard' | 'panel' | 'server-settings' | 'terminal' | 'files'

class LayoutStore {
  collapsed = $state(window.localStorage.getItem('sidebar.collapsed') === '1')
  mobileOpen = $state(false)
  // Agent-level (not per-server) view switch — no router, mirrors the
  // existing Dashboard/detail local-state pattern
  view = $state<View>('dashboard')
  // Drives which way the page-level transition slides — set by the call
  // site (navigate() vs back()) so a "back" navigation visually reverses
  // the "forward" one instead of always sliding the same direction
  navDirection = $state<'forward' | 'back'>('forward')
  /// Whether the add-server form is up. Here rather than inside the sidebar
  /// because the empty state opens the same one form, and there is nowhere
  /// else the two of them meet.
  addServerOpen = $state(false)

  toggleCollapsed() {
    this.collapsed = !this.collapsed
    window.localStorage.setItem('sidebar.collapsed', this.collapsed ? '1' : '0')
  }

  navigate(view: View) {
    this.navDirection = 'forward'
    this.view = view
  }

  back(view: View) {
    this.navDirection = 'back'
    this.view = view
  }
}

export const layout = new LayoutStore()
