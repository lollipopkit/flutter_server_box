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
/// Addressed to one terminal window, the one the Run press opened: several
/// terminals can be open on the desk, and a script typed into whichever shell
/// happened to be running (an editor, a tmux pane) is not what was asked.
///
/// The steps are already expanded when they arrive, so this holds no script and
/// no context — by the time a snippet is queued the agent has answered exactly
/// what to type, and nothing here re-reads the text it came from.
import type { SnippetStep } from '../types'

class SnippetRun {
  /// What is waiting, or `null`. Named so the terminal can say what it is about
  /// to type before it types it.
  waiting = $state<{ name: string; steps: SnippetStep[]; window: string } | null>(null)

  queue(name: string, steps: SnippetStep[], window: string) {
    this.waiting = { name, steps, window }
  }

  /// What is waiting for [window], if anything.
  for(window: string): { name: string; steps: SnippetStep[] } | null {
    return this.waiting?.window === window ? this.waiting : null
  }

  /// Takes what is waiting for [window] and clears the slot, so a reconnecting
  /// terminal cannot type the same script twice.
  take(window: string): { name: string; steps: SnippetStep[] } | null {
    const taken = this.for(window)
    if (taken) this.waiting = null
    return taken
  }

  /// Drops it, for the terminal it was for, which is not going to run it.
  clear(window: string) {
    if (this.waiting?.window === window) this.waiting = null
  }
}

export const snippetRun = new SnippetRun()
