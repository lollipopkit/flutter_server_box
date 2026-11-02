import type { SidebarSection } from 'serverbox-desk'
import { desk } from './desk'

/// An app's pages, chosen in the window's own sidebar (`desk.sidebar`), as
/// the desk's apps are: the page shown, kept with the window (`appState`),
/// and changed by the sidebar's `navigate` or by the app itself (`go`).
export class Pages<P extends string> {
  current = $state() as P
  readonly #ids: readonly P[]

  constructor(ids: readonly P[], fallback: P) {
    this.#ids = ids
    const kept = (desk.info.appState as { page?: unknown } | null)?.page
    this.current = ids.includes(kept as P) ? (kept as P) : fallback
    desk.on('navigate', ({ id }) => {
      if (this.#ids.includes(id as P)) this.go(id as P)
    })
  }

  go(page: P) {
    this.current = page
    void desk.setAppState({ page })
  }

  /// Draws [sections] as the window's sidebar with the page shown chosen;
  /// none, no sidebar (a step the app waits on, before its pages exist).
  /// Call from an `$effect`, so it follows the words and the state it shows.
  draw(sections: SidebarSection[]) {
    void desk.sidebar({ sections, selected: this.current })
  }
}
