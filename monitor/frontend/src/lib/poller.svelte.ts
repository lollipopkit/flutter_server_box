/// Periodic fetcher with reactive data/error/loading state; components call
/// start() in onMount and stop() in onDestroy

export class Poller<T> {
  data = $state<T | null>(null)
  error = $state<string | null>(null)
  loading = $state(true)

  #fetcher: (signal: AbortSignal) => Promise<T>
  #intervalMs: number
  #timer: ReturnType<typeof setTimeout> | undefined
  #controller: AbortController | undefined
  #generation = 0

  constructor(fetcher: (signal: AbortSignal) => Promise<T>, intervalMs = 5000) {
    this.#fetcher = fetcher
    this.#intervalMs = intervalMs
  }

  start() {
    this.stop()
    this.loading = this.data === null
    const generation = ++this.#generation
    void this.#tick(generation)
  }

  reset() {
    this.data = null
    this.error = null
    this.loading = true
  }

  stop() {
    this.#generation += 1
    clearTimeout(this.#timer)
    this.#timer = undefined
    this.#controller?.abort()
    this.#controller = undefined
  }

  async #tick(generation: number) {
    const controller = new AbortController()
    this.#controller = controller
    try {
      const data = await this.#fetcher(controller.signal)
      if (generation !== this.#generation) return
      this.data = data
      this.error = null
    } catch (e) {
      if (controller.signal.aborted || generation !== this.#generation) return
      this.error = e instanceof Error ? e.message : String(e)
    } finally {
      if (generation === this.#generation) {
        this.#controller = undefined
        this.loading = false
        this.#timer = setTimeout(() => void this.#tick(generation), this.#intervalMs)
      }
    }
  }
}
