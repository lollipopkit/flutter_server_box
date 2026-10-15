/// Per-server reachability, shown as the Status app's connection badge. Uses the
/// unauthenticated /health endpoint; cross-origin agents must allow the
/// panel origin (same CORS requirement as the rest of the panel).

import { EachServer } from './eachServer'
import { probe } from './probe'
import { servers } from './servers.svelte'

const INTERVAL_MS = 15_000

class HealthStore {
  /// undefined = not probed yet, then reachable true/false
  status = $state<Record<string, boolean | undefined>>({})

  #poll = new EachServer(
    INTERVAL_MS,
    () => [...servers.list],
    async (server, signal, current) => {
      const reachable = (await probe(server.url, signal)) === 'healthy'
      if (!current()) return
      this.status[server.id] = reachable
      if (reachable) servers.markOnline(server.id)
    },
    (asked) => {
      const ids = new Set(asked.map((entry) => entry.id))
      for (const id of Object.keys(this.status)) {
        if (!ids.has(id)) delete this.status[id]
      }
    },
  )

  start() {
    this.#poll.start()
  }

  stop() {
    this.#poll.stop()
  }
}

export const health = new HealthStore()
