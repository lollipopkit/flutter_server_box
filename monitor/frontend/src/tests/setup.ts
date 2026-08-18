// Node >= 22 defines an (undefined) experimental global localStorage without
// --localstorage-file, and vitest's global population skips keys that already
// exist — so jsdom's Storage never lands. Install an in-memory shim on both
// globalThis and window before anything imports the stores.
class MemStorage implements Storage {
  #map = new Map<string, string>()
  get length() {
    return this.#map.size
  }
  key(i: number) {
    return [...this.#map.keys()][i] ?? null
  }
  getItem(k: string) {
    return this.#map.get(k) ?? null
  }
  setItem(k: string, v: string) {
    this.#map.set(k, String(v))
  }
  removeItem(k: string) {
    this.#map.delete(k)
  }
  clear() {
    this.#map.clear()
  }
}

const storage = new MemStorage()
Object.defineProperty(globalThis, 'localStorage', { value: storage, configurable: true })
Object.defineProperty(window, 'localStorage', { value: storage, configurable: true })

// Locale bootstrap must follow the storage shim (init reads window.localStorage)
await import('../i18n/init')

export {}
