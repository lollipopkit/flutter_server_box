/// What a component started, bound to its life: an answer that comes back
/// after the window closed, or after the sidebar moved to another server,
/// must not write state, start a timer or open a socket.
///
/// Called while the component initialises (it registers `onDestroy`).

import { onDestroy } from 'svelte'
import { servers } from './servers.svelte'

export interface Scope {
  /// Aborted when the component is destroyed.
  readonly signal: AbortSignal
  readonly alive: boolean
  /// Whether an answer asked for on [serverId] no longer applies: the
  /// component is gone or the current server is another.
  stale(serverId: string | null | undefined): boolean
}

export function useScope(): Scope {
  const controller = new AbortController()
  onDestroy(() => controller.abort())
  return {
    signal: controller.signal,
    get alive() {
      return !controller.signal.aborted
    },
    stale(serverId) {
      return controller.signal.aborted || serverId !== servers.currentId
    },
  }
}
