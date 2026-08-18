/// Per-server reachability, shown as dots in the sidebar. Uses the
/// unauthenticated /health endpoint; cross-origin agents must allow the
/// panel origin (same CORS requirement as the rest of the panel).

import { probe } from './probe'
import { servers } from './servers.svelte'

const INTERVAL_MS = 15_000

class HealthStore {
  /// undefined = not probed yet, then reachable true/false
  status = $state<Record<string, boolean | undefined>>({})

  #timer: ReturnType<typeof setInterval> | undefined

  start() {
    void this.#tick()
    this.#timer = setInterval(() => void this.#tick(), INTERVAL_MS)
  }

  stop() {
    clearInterval(this.#timer)
  }

  async #tick() {
    await Promise.all(
      servers.list.map(async (s) => {
        this.status[s.id] = (await probe(s.url)) === 'healthy'
      }),
    )
  }
}

export const health = new HealthStore()
