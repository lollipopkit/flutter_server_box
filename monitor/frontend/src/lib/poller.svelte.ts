/// Periodic fetcher with reactive data/error/loading state; components call
/// start() in onMount and stop() in onDestroy

export class Poller<T> {
  data = $state<T | null>(null)
  error = $state<string | null>(null)
  loading = $state(true)

  #fetcher: () => Promise<T>
  #intervalMs: number
  #timer: ReturnType<typeof setInterval> | undefined

  constructor(fetcher: () => Promise<T>, intervalMs = 5000) {
    this.#fetcher = fetcher
    this.#intervalMs = intervalMs
  }

  start() {
    void this.#tick()
    this.#timer = setInterval(() => void this.#tick(), this.#intervalMs)
  }

  stop() {
    clearInterval(this.#timer)
  }

  async #tick() {
    try {
      this.data = await this.#fetcher()
      this.error = null
    } catch (e) {
      this.error = e instanceof Error ? e.message : String(e)
    } finally {
      this.loading = false
    }
  }
}
