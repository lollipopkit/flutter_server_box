/// Whether the panel's terminals run xterm's screen reader mode.
///
/// Opt-in, not on for everyone: a page cannot tell whether a screen reader is
/// running, and the mode has a cost for those without one. It stops xterm
/// from cancelling key events, so Tab also moves the browser's focus out of
/// the terminal (no shell completion) and keys reach the page's own
/// listeners; and every printed character raises an accessibility event.
/// One setting for every terminal, applied to open ones as it changes.

import { readPref, writePref } from './prefs'

const KEY = 'terminal.screenReader'

class ScreenReaderPref {
  enabled = $state(readPref(KEY) === '1')
  readonly #listeners = new Set<(on: boolean) => void>()

  set(on: boolean) {
    this.enabled = on
    writePref(KEY, on ? '1' : '0')
    for (const listener of this.#listeners) listener(on)
  }

  toggle() {
    this.set(!this.enabled)
  }

  /// For a terminal made outside a component; returns the unsubscribe.
  watch(listener: (on: boolean) => void): () => void {
    this.#listeners.add(listener)
    return () => this.#listeners.delete(listener)
  }
}

export const screenReader = new ScreenReaderPref()
