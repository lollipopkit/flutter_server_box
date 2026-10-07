/// The design system's tab switch for content: the incoming view fades in
/// (`--dur-tab-content`, 160ms); the outgoing one has no exit, no slide, no
/// scale. `use:viewIn={key}` replays it whenever [key] changes to a value
/// other than `null` (null: nothing on show), never on the first render.
export function viewIn(node: HTMLElement, key: unknown) {
  let last = key
  return {
    update(next: unknown) {
      if (next === last) return
      last = next
      if (next === null) return
      node.classList.remove('lk-view-in')
      // Reading layout restarts the animation on the same element.
      void node.offsetWidth
      node.classList.add('lk-view-in')
    },
  }
}

/// The same fade for a view that arrives as the switch itself (a new tab's
/// content): played once when it mounts, if [on].
export function viewEnter(node: HTMLElement, on: boolean = true) {
  if (on) node.classList.add('lk-view-in')
}
