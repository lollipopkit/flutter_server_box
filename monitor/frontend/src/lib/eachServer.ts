/// Something asked of every server in the list, a few at a time, again every
/// [intervalMs]: what the lock screen and the menubar show of servers other
/// than the one open (reachable, the agent's name for itself). Not while the
/// tab is hidden; at once when it is shown again.

import { forEachConcurrent } from './concurrency'
import type { ServerEntry } from './servers.svelte'

const MAX_CONCURRENT = 4

export class EachServer {
  #timer: ReturnType<typeof setTimeout> | undefined
  #controllers = new Set<AbortController>()
  #generation = 0
  #running = false
  #onVisible = () => {
    if (this.#running && document.visibilityState === 'visible') void this.refresh()
  }

  constructor(
    private readonly intervalMs: number,
    /// The servers to ask, read at each round.
    private readonly entries: () => ServerEntry[],
    /// One server's question; its answer is stored only while [current]
    /// says this round is still the one running.
    private readonly ask: (server: ServerEntry, signal: AbortSignal, current: () => boolean) => Promise<void>,
    /// After a round, with the servers it asked.
    private readonly after?: (asked: ServerEntry[]) => void,
  ) {}

  start() {
    this.stop()
    this.#running = true
    if (typeof document !== 'undefined') document.addEventListener('visibilitychange', this.#onVisible)
    void this.#round(++this.#generation)
  }

  stop() {
    this.#running = false
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', this.#onVisible)
    this.#cancel()
  }

  /// A round now rather than at the next interval (after a sign-in).
  async refresh() {
    this.#cancel()
    await this.#round(++this.#generation)
  }

  #cancel() {
    this.#generation += 1
    clearTimeout(this.#timer)
    this.#timer = undefined
    for (const controller of this.#controllers) controller.abort()
    this.#controllers.clear()
  }

  async #round(generation: number) {
    const current = () => generation === this.#generation
    const asked = this.entries()
    try {
      await forEachConcurrent(asked, MAX_CONCURRENT, async (server) => {
        if (!current()) return
        const controller = new AbortController()
        this.#controllers.add(controller)
        try {
          await this.ask(server, controller.signal, current)
        } catch {
          // The last answer stays rather than flashing "unknown".
        } finally {
          this.#controllers.delete(controller)
        }
      })
      if (current()) this.after?.(asked)
    } finally {
      const hidden = typeof document !== 'undefined' && document.visibilityState === 'hidden'
      if (this.#running && current() && !hidden) {
        this.#timer = setTimeout(() => void this.#round(generation), this.intervalMs)
      }
    }
  }
}
