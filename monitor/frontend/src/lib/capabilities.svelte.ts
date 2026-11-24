/// Per-server capabilities cache — platform-only, doesn't change between
/// samples, so this fetches once per authenticated server (not polled) and
/// is shared between the lock screen (every entry's OS icon), the desk's app
/// availability and the Status app's card gating.

import { getCapabilitiesFor } from './api'
import { servers } from './servers.svelte'
import type { Capabilities } from '../types'

class CapabilitiesStore {
  /// undefined = not fetched yet (or not authenticated); a failed fetch
  /// leaves it undefined too, so the next ensure() call retries
  byServer = $state<Record<string, Capabilities | undefined>>({})

  async ensure(id: string) {
    if (this.byServer[id] !== undefined) return
    await this.refresh(id)
  }

  /// Reads them again, keeping the cached answer until the new one arrives —
  /// what is drawn from them (the dock, an app's actions) does not blink.
  async refresh(id: string) {
    const entry = servers.list.find((s) => s.id === id)
    if (!entry?.token) return
    try {
      this.byServer[id] = await getCapabilitiesFor(entry)
    } catch {
      // Keeps any cached value (or undefined on first fetch) so callers can retry.
    }
  }

  /// Drops a cached entry, e.g. after logout/URL change invalidates it
  clear(id: string) {
    delete this.byServer[id]
  }
}

export const capabilitiesStore = new CapabilitiesStore()
