/// What each app keeps for itself (`sys.storage`): JSON values by key, per
/// account and server, on the agent (or this browser where the agent cannot).
/// One copy per app is kept in memory once read, so reads after the first
/// do not travel; another tab's writes are seen after a reload.

import type { DeskStorage } from './storage'

export interface AppStorage {
  get(key: string): Promise<unknown>
  /// [value] is any JSON. Refused past 256 KiB for the app's keys and
  /// values together.
  set(key: string, value: unknown): Promise<void>
  remove(key: string): Promise<void>
  keys(): Promise<string[]>
}

const MAX_KEY_BYTES = 128

function checkKey(key: string) {
  const length = new TextEncoder().encode(key).length
  // eslint-disable-next-line no-control-regex
  if (typeof key !== 'string' || length < 1 || length > MAX_KEY_BYTES || /[\u0000-\u001f\u007f-\u009f]/.test(key)) {
    throw new Error('invalidKey')
  }
}

export class AppData {
  #storage: DeskStorage
  #items = new Map<string, Promise<Record<string, unknown>>>()

  constructor(storage: DeskStorage) {
    this.#storage = storage
  }

  for(app: string): AppStorage {
    const items = () => {
      let p = this.#items.get(app)
      if (!p) {
        p = this.#storage.appItems(app)
        // A failed read is tried again next time.
        p.catch(() => this.#items.delete(app))
        this.#items.set(app, p)
      }
      return p
    }
    return {
      get: async (key) => {
        checkKey(key)
        return structuredClone((await items())[key])
      },
      set: async (key, value) => {
        checkKey(key)
        if (value === undefined) throw new Error('invalidValue')
        // Plain JSON only: what the agent stores is what comes back.
        const json = JSON.parse(JSON.stringify(value)) as unknown
        await this.#storage.appPut(app, key, json)
        const current = await items()
        this.#items.set(app, Promise.resolve({ ...current, [key]: json }))
      },
      remove: async (key) => {
        checkKey(key)
        await this.#storage.appRemove(app, key)
        const rest = { ...(await items()) }
        delete rest[key]
        this.#items.set(app, Promise.resolve(rest))
      },
      keys: async () => Object.keys(await items()).sort(),
    }
  }
}
