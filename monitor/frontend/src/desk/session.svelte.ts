/// Keeps one desk's windows where its storage keeps them: loads them once,
/// saves each change after a pause, and settles with another tab of the same
/// browser through the revision the agent checks.
///
/// The rule between two tabs: the one being used wins. A save refused because
/// another tab moved the revision is made again over it when this tab has
/// focus, and takes the other's windows when it has not; an event saying the
/// other saved is taken only by a tab not in use.

import type { DeskStorage } from './storage'
import type { WindowManager } from './windows.svelte'

export const SAVE_DELAY_MS = 400

export class SessionSync {
  /// `loading` until the first load answers; `failed` keeps the desk usable,
  /// unsaved.
  status = $state<'loading' | 'ready' | 'failed'>('loading')

  #windows: WindowManager
  #storage: DeskStorage
  #device: string
  #serverId: string | null
  #revision = 0
  #timer: ReturnType<typeof setTimeout> | null = null
  #saving = false
  #again = false
  #closed = false
  #inUse: () => boolean

  constructor(
    windows: WindowManager,
    storage: DeskStorage,
    device: string,
    serverId: string | null,
    inUse: () => boolean = () => document.hasFocus() && !document.hidden,
  ) {
    this.#windows = windows
    this.#storage = storage
    this.#device = device
    this.#serverId = serverId
    this.#inUse = inUse
  }

  get revision(): number {
    return this.#revision
  }

  async load() {
    try {
      const session = await this.#storage.loadSession(this.#device)
      if (this.#closed) return
      this.#revision = session.revision
      this.#windows.hydrate(session.windows)
      this.status = 'ready'
    } catch {
      if (!this.#closed) this.status = 'failed'
    }
  }

  /// A change worth saving happened; saved after [SAVE_DELAY_MS] of quiet.
  schedule() {
    if (this.#closed || this.status !== 'ready') return
    if (this.#timer) clearTimeout(this.#timer)
    this.#timer = setTimeout(() => {
      this.#timer = null
      void this.flush()
    }, SAVE_DELAY_MS)
  }

  /// Saves now. One save at a time; a change made during one is saved after.
  async flush() {
    if (this.#closed) return
    if (this.#saving) {
      this.#again = true
      return
    }
    this.#saving = true
    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        const result = await this.#storage.saveSession(
          this.#device,
          this.#revision,
          this.#windows.serialize(this.#serverId),
        )
        if (result.ok) {
          this.#revision = result.revision
          break
        }
        this.#revision = result.current.revision
        if (!this.#inUse()) {
          this.#windows.hydrate(result.current.windows)
          break
        }
      }
    } catch {
      // Unreachable or refused: the next change tries again.
    } finally {
      this.#saving = false
    }
    if (this.#again) {
      this.#again = false
      await this.flush()
    }
  }

  /// Another tab saved [revision] for [device].
  async remoteChanged(device: string, revision: number) {
    if (device !== this.#device || revision <= this.#revision || this.#inUse()) return
    await this.load()
  }

  /// Saves what is pending, then stops: the desk is going away.
  async close() {
    const pending = this.#timer !== null
    if (this.#timer) clearTimeout(this.#timer)
    this.#timer = null
    if (pending && this.status === 'ready') await this.flush()
    this.#closed = true
  }
}
