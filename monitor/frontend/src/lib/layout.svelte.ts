/// Sidebar layout state: desktop collapse persisted, mobile drawer transient

class LayoutStore {
  collapsed = $state(window.localStorage.getItem('sidebar.collapsed') === '1')
  mobileOpen = $state(false)

  toggleCollapsed() {
    this.collapsed = !this.collapsed
    window.localStorage.setItem('sidebar.collapsed', this.collapsed ? '1' : '0')
  }
}

export const layout = new LayoutStore()
