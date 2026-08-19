/// Per-server display name — always the agent's own live-reported name
/// (config.toml's `name`, or its hostname fallback), never a value the panel
/// stores or lets the user override locally. Polled periodically (not a
/// one-shot cache like capabilities) since, unlike platform, the name can
/// genuinely change if someone edits config.toml while the panel is open.

import { getStatusFor } from './api'
import { servers } from './servers.svelte'
import { forEachConcurrent } from './concurrency'

const INTERVAL_MS = 30_000
const MAX_CONCURRENT = 4

class ServerNamesStore {
  /// undefined = not fetched yet (or not authenticated)
  byServer = $state<Record<string, string | undefined>>({})

  #timer: ReturnType<typeof setTimeout> | undefined
  #controllers = new Set<AbortController>()
  #generation = 0
  #running = false

  start() {
    this.stop()
    this.#running = true
    const generation = ++this.#generation
    void this.#tick(generation)
  }

  stop() {
    this.#running = false
    this.#cancelPending()
  }

  /// Ticks immediately, independent of the interval timer — called right
  /// after a login so the name doesn't wait up to 30s to appear
  async refresh() {
    this.#cancelPending()
    const generation = ++this.#generation
    await this.#tick(generation)
  }

  #cancelPending() {
    this.#generation += 1
    clearTimeout(this.#timer)
    this.#timer = undefined
    for (const controller of this.#controllers) controller.abort()
    this.#controllers.clear()
  }

  async #tick(generation: number) {
    const entries = servers.list.filter((server) => server.token)
    try {
      await forEachConcurrent(entries, MAX_CONCURRENT, async (server) => {
        if (generation !== this.#generation) return
        const controller = new AbortController()
        this.#controllers.add(controller)
        try {
          const status = await getStatusFor(server, controller.signal)
          if (generation === this.#generation) this.byServer[server.id] = status.name
        } catch {
          // Leave the previous value in place rather than flashing "unknown"
          // on a transient failure
        } finally {
          this.#controllers.delete(controller)
        }
      })
    } finally {
      if (this.#running && generation === this.#generation) {
        this.#timer = setTimeout(() => void this.#tick(generation), INTERVAL_MS)
      }
    }
  }
}

export const serverNames = new ServerNamesStore()
