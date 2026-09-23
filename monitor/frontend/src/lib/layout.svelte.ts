/// Sidebar state with persistent desktop collapse and a transient mobile drawer.

/// 'panel' = browser-local prefs (language/theme), reached from the sidebar
/// footer, independent of any server. 'server-settings' = the currently
/// selected server's config.toml, reached from a gear icon on its dashboard.
/// 'terminal' = an SSH session on the selected server, reached from its
/// dashboard and only offered when that agent reports the feature available.
/// 'cron' = the selected server's crontab, reached the same way and offered on
/// the agent's own `cron` capability — the shell's grant, but its own field,
/// because an agent that predates the route would answer the wider grant.
export type View =
  | 'dashboard'
  | 'panel'
  | 'server-settings'
  | 'terminal'
  | 'files'
  | 'cron'

class LayoutStore {
  collapsed = $state(window.localStorage.getItem('sidebar.collapsed') === '1')
  mobileOpen = $state(false)
  // Panel-wide view selection; navigation does not use a router.
  view = $state<View>('dashboard')
  // Reverse the page transition when navigating back.
  navDirection = $state<'forward' | 'back'>('forward')
  /// Shared by the sidebar and empty state, which open the same form.
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
