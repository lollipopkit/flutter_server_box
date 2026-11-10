/// Per-server display names reported by each agent from `config.toml` or its
/// hostname fallback. Names are polled because they can change while the panel
/// is open; platform capabilities use a one-shot cache instead.

import { getStatusFor } from './api'
import { EachServer } from './eachServer'
import { servers } from './servers.svelte'

const INTERVAL_MS = 30_000

class ServerNamesStore {
  /// `undefined` means not fetched or not authenticated.
  byServer = $state<Record<string, string | undefined>>({})

  #poll = new EachServer(
    INTERVAL_MS,
    () => servers.list.filter((server) => server.token),
    async (server, signal, current) => {
      const status = await getStatusFor(server, signal)
      if (current()) this.byServer[server.id] = status.name
    },
  )

  start() {
    this.#poll.start()
  }

  stop() {
    this.#poll.stop()
  }

  /// Fetches immediately after login instead of waiting for the interval.
  refresh() {
    return this.#poll.refresh()
  }
}

export const serverNames = new ServerNamesStore()
