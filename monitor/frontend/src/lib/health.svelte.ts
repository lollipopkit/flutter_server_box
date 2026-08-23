/// Per-server reachability, shown as dots in the sidebar. Uses the
/// unauthenticated /health endpoint; cross-origin agents must allow the
/// panel origin (same CORS requirement as the rest of the panel).

import { probe } from './probe'
import { servers } from './servers.svelte'
import { forEachConcurrent } from './concurrency'

const INTERVAL_MS = 15_000
const MAX_CONCURRENT = 4

class HealthStore {
  /// undefined = not probed yet, then reachable true/false
  status = $state<Record<string, boolean | undefined>>({})

  #timer: ReturnType<typeof setTimeout> | undefined
  #controllers = new Set<AbortController>()
  #generation = 0

  start() {
    this.stop()
    const generation = ++this.#generation
    void this.#tick(generation)
  }

  stop() {
    this.#generation += 1
    clearTimeout(this.#timer)
    this.#timer = undefined
    for (const controller of this.#controllers) controller.abort()
    this.#controllers.clear()
  }

  async #tick(generation: number) {
    const entries = [...servers.list]
    try {
      await forEachConcurrent(entries, MAX_CONCURRENT, async (server) => {
        if (generation !== this.#generation) return
        const controller = new AbortController()
        this.#controllers.add(controller)
        try {
          const reachable = (await probe(server.url, controller.signal)) === 'healthy'
          if (generation === this.#generation) this.status[server.id] = reachable
        } finally {
          this.#controllers.delete(controller)
        }
      })
      if (generation === this.#generation) {
        const currentIds = new Set(entries.map((entry) => entry.id))
        for (const id of Object.keys(this.status)) {
          if (!currentIds.has(id)) delete this.status[id]
        }
      }
    } finally {
      if (generation === this.#generation) {
        this.#timer = setTimeout(() => void this.#tick(generation), INTERVAL_MS)
      }
    }
  }
}

export const health = new HealthStore()
