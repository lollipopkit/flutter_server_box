/// Per-server capabilities cache — platform-only, doesn't change between
/// samples, so this fetches once per authenticated server (not polled) and
/// is shared between the sidebar (every entry's OS icon) and the dashboard
/// header/card-visibility gating for the current entry.

import { getCapabilitiesFor } from './api'
import { servers } from './servers.svelte'
import type { Capabilities } from '../types'

class CapabilitiesStore {
  /// undefined = not fetched yet (or not authenticated); a failed fetch
  /// leaves it undefined too, so the next ensure() call retries
  byServer = $state<Record<string, Capabilities | undefined>>({})

  async ensure(id: string) {
    if (this.byServer[id] !== undefined) return
    const entry = servers.list.find((s) => s.id === id)
    if (!entry?.token) return
    try {
      this.byServer[id] = await getCapabilitiesFor(entry)
    } catch {
      // Left undefined: caller sees "unknown" and can retry later
    }
  }

  /// Drops a cached entry, e.g. after logout/URL change invalidates it
  clear(id: string) {
    delete this.byServer[id]
  }
}

export const capabilitiesStore = new CapabilitiesStore()
