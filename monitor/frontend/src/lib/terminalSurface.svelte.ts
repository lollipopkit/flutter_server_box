/// The colour under a terminal's rows, for the element that holds them.
///
/// xterm sizes its rows in whole cells, so an element of a fixed height has a
/// strip left below the last row — 9px in the dialogs. Both terminals fill it
/// with this, the terminal's own background, rather than with a colour of
/// their own, which would show as a strip under the rows.
///
/// A getter rather than a value each page reads once: it is read from the
/// document, so it follows a theme change by being read again —
/// `theme.revision` is what makes a read of it refresh.
import { theme } from './theme.svelte'
import { terminalBackground } from './xterm'

class TerminalSurface {
  get current(): string {
    void theme.revision
    return terminalBackground()
  }
}

export const terminalSurface = new TerminalSurface()
