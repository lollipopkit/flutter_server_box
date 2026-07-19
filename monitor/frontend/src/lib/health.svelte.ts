/// Per-server reachability, shown as dots in the sidebar. Uses the
/// unauthenticated /health endpoint; cross-origin agents must allow the
/// panel origin (same CORS requirement as the rest of the panel).

import { servers } from './servers.svelte'

const INTERVAL_MS = 15_000
const TIMEOUT_MS = 5_000

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
        try {
          const res = await fetch(`${s.url}/api/v1/health`, {
            signal: AbortSignal.timeout(TIMEOUT_MS),
          })
          this.status[s.id] = res.ok
        } catch {
          this.status[s.id] = false
        }
      }),
    )
  }
}

export const health = new HealthStore()
