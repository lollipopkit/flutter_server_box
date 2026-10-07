/// What an app shows of itself outside its content: the title bar's title,
/// back button and tools (`sys/AppToolbar.svelte`), the inset sidebar
/// (`sys/SplitView.svelte`), the footer (`sys/WindowFooter.svelte`), its menubar menus (`sys.useMenus`) and its
/// name, icon and badge as the menubar and dock show them. The app sets them
/// through `sys`; the window (`window/Window.svelte`) and the shell draw them.
/// Toolbars, sidebars and menus are stacks, so a view inside an app that
/// brings its own takes over while it is shown and gives them back when it
/// goes.

import { untrack, type Snippet } from 'svelte'
import type { MenuEntry } from '../lk/Menu.svelte'
import type { IconTone } from '../lk/AppIcon.svelte'
import type { LifecycleState } from '../sys/window.svelte'
import type { Intent } from '../windows.svelte'

export interface ToolbarChrome {
  title?: string
  subtitle?: string
  /// Before the title (an OS icon, a status dot).
  leading?: Snippet
  /// Leaves a view inside the app.
  back?: () => void
  /// At the bar's right: the view's actions.
  actions?: Snippet
  /// Other views of the app, under the bar.
  tabs?: Snippet
  /// Instead of the title (and subtitle): a path, a breadcrumb.
  heading?: Snippet
  /// A solid bar running to the window's edge, never glass: for a view whose
  /// table header sits right under it.
  flush?: boolean
}

export interface FooterChrome {
  /// A `StatusBar`, and what goes over it (the selection's detail).
  content: Snippet
}

export interface SidebarChrome {
  content: Snippet
  /// In px.
  width: number
}

/// One menubar menu: its title and rows. A row's `shortcut` (`⌘⇧N`) runs
/// it while the window is in front.
export interface AppMenu {
  label: string
  items: MenuEntry[]
}

export interface MenusChrome {
  readonly menus: AppMenu[]
}

export interface AppIconChrome {
  glyph: string
  tone: IconTone
}

export class WindowChrome {
  // Raw: an entry is the registrant's own object, found again by identity.
  #toolbars = $state.raw<ToolbarChrome[]>([])
  #sidebars = $state.raw<SidebarChrome[]>([])
  #footers = $state.raw<FooterChrome[]>([])
  #menus = $state.raw<MenusChrome[]>([])
  #dockMenus = $state.raw<MenusChrome[]>([])
  #keepAlive = $state.raw<string[]>([])
  #intents = $state.raw<Intent[]>([])
  /// A folded sidebar shown over the content (a narrow window).
  sidebarOpen = $state(false)
  /// The app's name, icon and badge as this window shows them; null is the
  /// manifest's (no badge).
  appName = $state<string | null>(null)
  icon = $state<AppIconChrome | null>(null)
  badge = $state<string | null>(null)
  /// Where the window's process is; the window keeps it current.
  lifecycle = $state<LifecycleState>('active')

  get toolbar(): ToolbarChrome | null {
    return this.#toolbars.at(-1) ?? null
  }

  get sidebar(): SidebarChrome | null {
    return this.#sidebars.at(-1) ?? null
  }

  get footer(): FooterChrome | null {
    return this.#footers.at(-1) ?? null
  }

  get menus(): AppMenu[] {
    return this.#menus.at(-1)?.menus ?? []
  }

  /// Rows the app adds to its dock menu (only the first menu's rows).
  get dockItems(): MenuEntry[] {
    return this.#dockMenus.at(-1)?.menus[0]?.items ?? []
  }

  /// Why the app asked to keep running while hidden; empty when it did not.
  get keepAlive(): readonly string[] {
    return this.#keepAlive
  }

  /// Shows [toolbar] until the returned function is called. Called from an
  /// effect, so the stack is changed without the effect depending on it.
  pushToolbar(toolbar: ToolbarChrome): () => void {
    return this.#push(
      () => (this.#toolbars = [...this.#toolbars, toolbar]),
      () => (this.#toolbars = this.#toolbars.filter((t) => t !== toolbar)),
    )
  }

  pushSidebar(sidebar: SidebarChrome): () => void {
    return this.#push(
      () => (this.#sidebars = [...this.#sidebars, sidebar]),
      () => {
        this.#sidebars = this.#sidebars.filter((s) => s !== sidebar)
        if (this.#sidebars.length === 0) this.sidebarOpen = false
      },
    )
  }

  pushFooter(footer: FooterChrome): () => void {
    return this.#push(
      () => (this.#footers = [...this.#footers, footer]),
      () => (this.#footers = this.#footers.filter((f) => f !== footer)),
    )
  }

  pushMenus(menus: MenusChrome): () => void {
    return this.#push(
      () => (this.#menus = [...this.#menus, menus]),
      () => (this.#menus = this.#menus.filter((m) => m !== menus)),
    )
  }

  pushDockMenu(menu: MenusChrome): () => void {
    return this.#push(
      () => (this.#dockMenus = [...this.#dockMenus, menu]),
      () => (this.#dockMenus = this.#dockMenus.filter((m) => m !== menu)),
    )
  }

  /// Intents waiting for the app to take them.
  get pendingIntents(): number {
    return this.#intents.length
  }

  deliver(...intents: Intent[]) {
    if (intents.length) untrack(() => (this.#intents = [...this.#intents, ...intents]))
  }

  takeIntents(): Intent[] {
    const taken = this.#intents
    untrack(() => (this.#intents = []))
    return taken
  }

  holdKeepAlive(reason: string): () => void {
    const entry = String(reason)
    let held = true
    untrack(() => (this.#keepAlive = [...this.#keepAlive, entry]))
    return () => {
      if (!held) return
      held = false
      untrack(() => {
        const at = this.#keepAlive.indexOf(entry)
        if (at >= 0) this.#keepAlive = this.#keepAlive.filter((_, i) => i !== at)
      })
    }
  }

  /// The app's content went away (suspended): what it set goes with it.
  reset() {
    this.#toolbars = []
    this.#sidebars = []
    this.#footers = []
    this.#menus = []
    this.#dockMenus = []
    this.#keepAlive = []
    this.sidebarOpen = false
    this.appName = null
    this.icon = null
    this.badge = null
  }

  #push(add: () => void, remove: () => void): () => void {
    untrack(add)
    return () => untrack(remove)
  }
}
