/// Per-server display name — always the agent's own live-reported name
/// (config.toml's `name`, or its hostname fallback), never a value the panel
/// stores or lets the user override locally. Polled periodically (not a
/// one-shot cache like capabilities) since, unlike platform, the name can
/// genuinely change if someone edits config.toml while the panel is open.

import { getStatusFor } from './api'
import { servers } from './servers.svelte'

const INTERVAL_MS = 30_000

class ServerNamesStore {
  /// undefined = not fetched yet (or not authenticated)
  byServer = $state<Record<string, string | undefined>>({})

  #timer: ReturnType<typeof setInterval> | undefined

  start() {
    void this.refresh()
    this.#timer = setInterval(() => void this.refresh(), INTERVAL_MS)
  }

  stop() {
    clearInterval(this.#timer)
  }

  /// Ticks immediately, independent of the interval timer — called right
  /// after a login so the name doesn't wait up to 30s to appear
  async refresh() {
    await this.#tick()
  }

  async #tick() {
    await Promise.all(
      servers.list.map(async (s) => {
        if (!s.token) return
        try {
          const status = await getStatusFor(s)
          this.byServer[s.id] = status.name
        } catch {
          // Leave the previous value in place rather than flashing "unknown"
          // on a transient failure
        }
      }),
    )
  }
}

export const serverNames = new ServerNamesStore()
