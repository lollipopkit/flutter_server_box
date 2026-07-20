/// Sidebar layout state: desktop collapse persisted, mobile drawer transient

export type View = 'dashboard' | 'settings'

class LayoutStore {
  collapsed = $state(window.localStorage.getItem('sidebar.collapsed') === '1')
  mobileOpen = $state(false)
  // Agent-level (not per-server) view switch — no router, mirrors the
  // existing Dashboard/detail local-state pattern
  view = $state<View>('dashboard')

  toggleCollapsed() {
    this.collapsed = !this.collapsed
    window.localStorage.setItem('sidebar.collapsed', this.collapsed ? '1' : '0')
  }
}

export const layout = new LayoutStore()
