/// One of a backend's jobs as a page follows it: started (with the desk's
/// sudo dialog when it runs as root), its lines as they come, and how it
/// ended; or a job already running when the window opened, followed the same
/// way. One at a time, as the agent runs them.

import { DeskError, type SudoAsk } from 'serverbox-desk'
import { desk } from './desk'

export type JobStatus = 'running' | 'succeeded' | 'failed' | 'cancelled'

export class JobRun {
  /// The function it runs; empty before any.
  fn = $state('')
  status = $state<JobStatus | null>(null)
  lines = $state<string[]>([])

  get running(): boolean {
    return this.status === 'running'
  }

  /// Starts [fn]; its value once it ended well, else undefined (declined in
  /// the sudo dialog, refused, failed or cancelled: said in its lines, or
  /// nothing at all for a decline). [said] words a refusal.
  async start<T>(fn: string, args: Record<string, unknown>, sudo: SudoAsk | undefined, said: (e: unknown) => string): Promise<T | undefined> {
    this.fn = fn
    this.lines = []
    this.status = 'running'
    try {
      const value = await desk.job<T>(fn, args, { sudo, onLine: (l) => this.#line(l) })
      this.status = 'succeeded'
      return value
    } catch (e) {
      if (e instanceof DeskError && e.message === 'declined') {
        this.status = null
        return undefined
      }
      this.#end(e, said)
      return undefined
    }
  }

  /// The job running now, if any, followed until it ends: its function once
  /// it ended well.
  async resume(said: (e: unknown) => string): Promise<string | null> {
    const v = await desk.jobView().catch(() => null)
    if (v?.state !== 'running') return null
    this.fn = v.function
    this.lines = []
    this.status = 'running'
    try {
      await desk.follow({ onLine: (l) => this.#line(l) })
      this.status = 'succeeded'
      return v.function
    } catch (e) {
      this.#end(e, said)
      return null
    }
  }

  cancel() {
    void desk.cancelJob()
  }

  /// Forgets a job that ended.
  dismiss() {
    if (!this.running) this.status = null
  }

  #line(l: string) {
    this.lines = [...this.lines, l].slice(-2000)
  }

  #end(e: unknown, said: (e: unknown) => string) {
    this.status = e instanceof DeskError && e.message === 'cancelled' ? 'cancelled' : 'failed'
    this.#line(`✕ ${said(e)}`)
  }
}
