/// What an app shows in its window's frame rather than in its content: the
/// title bar's title, back button and tools (`ui/AppToolbar.svelte`) and the
/// inset sidebar (`ui/SplitView.svelte`). The app registers them; the window
/// (`window/Window.svelte`) draws them. Each is a stack, so a view inside an
/// app that brings its own toolbar takes over while it is shown and gives the
/// bar back when it goes.

import { untrack, type Snippet } from 'svelte'

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
}

export interface SidebarChrome {
  content: Snippet
  /// In px.
  width: number
}

export class WindowChrome {
  #toolbars = $state<ToolbarChrome[]>([])
  #sidebars = $state<SidebarChrome[]>([])
  /// A folded sidebar shown over the content (a narrow window).
  sidebarOpen = $state(false)

  get toolbar(): ToolbarChrome | null {
    return this.#toolbars.at(-1) ?? null
  }

  get sidebar(): SidebarChrome | null {
    return this.#sidebars.at(-1) ?? null
  }

  /// Shows [toolbar] until the returned function is called. Called from an
  /// effect, so the stack is changed without the effect depending on it.
  pushToolbar(toolbar: ToolbarChrome): () => void {
    untrack(() => this.#toolbars.push(toolbar))
    return () =>
      untrack(() => {
        this.#toolbars = this.#toolbars.filter((t) => t !== toolbar)
      })
  }

  pushSidebar(sidebar: SidebarChrome): () => void {
    untrack(() => this.#sidebars.push(sidebar))
    return () =>
      untrack(() => {
        this.#sidebars = this.#sidebars.filter((s) => s !== sidebar)
        if (this.#sidebars.length === 0) this.sidebarOpen = false
      })
  }
}
