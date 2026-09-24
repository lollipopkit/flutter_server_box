/// One snippet waiting to be typed, handed from the library to the terminal.
///
/// The library is a page of its own — the feature bar reaches it, and it is
/// where an operator reads the names and tags to decide what to run — while the
/// only thing that can run a snippet is a terminal. So a Run press names the
/// snippet here and opens the terminal, which is the one screen that owns a
/// session.
///
/// One slot, and not a queue: two Runs in a row are one decision revised, and a
/// script typed twice into a shell is not undoable.
///
/// The steps are already expanded when they arrive, so this holds no script and
/// no context — by the time a snippet is queued the agent has answered exactly
/// what to type, and nothing here re-reads the text it came from.
import type { SnippetStep } from '../types'

class SnippetRun {
  /// What is waiting, or `null`. Named so the terminal can say what it is about
  /// to type before it types it.
  waiting = $state<{ name: string; steps: SnippetStep[] } | null>(null)

  queue(name: string, steps: SnippetStep[]) {
    this.waiting = { name, steps }
  }

  /// Takes what is waiting and clears the slot, so a reconnecting terminal
  /// cannot type the same script twice.
  take(): { name: string; steps: SnippetStep[] } | null {
    const taken = this.waiting
    this.waiting = null
    return taken
  }

  /// Drops it, for a terminal that is not going to run it.
  clear() {
    this.waiting = null
  }
}

export const snippetRun = new SnippetRun()
