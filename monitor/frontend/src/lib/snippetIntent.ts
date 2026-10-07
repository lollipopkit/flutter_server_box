/// A snippet handed from the Snippets app to a terminal window: the intent
/// (`sys.useIntents`) Run opens a terminal with.
///
/// The library is where an operator reads names and tags to decide what to
/// run, while only a terminal owns a session; so Run asks the agent for the
/// steps (`/snippets/plan`) and opens a terminal of its own with them. The
/// steps are already expanded: nothing here re-reads the script.
///
/// One per terminal: a second intent replaces a snippet not yet typed (two
/// Runs in a row are one decision revised; a script typed twice into a shell
/// is not undoable).

import type { SnippetStep } from '../types'

/// Taken by Terminal from the Snippets app only (`Intent.from`).
export const TYPE_SNIPPET = 'terminal.type'

export interface QueuedSnippet {
  name: string
  steps: SnippetStep[]
}

/// [data] as a snippet to type, or null when it is not one.
export function queuedSnippet(data: unknown): QueuedSnippet | null {
  const d = data as Partial<QueuedSnippet> | null
  if (!d || typeof d.name !== 'string' || !Array.isArray(d.steps)) return null
  return { name: d.name, steps: d.steps }
}
