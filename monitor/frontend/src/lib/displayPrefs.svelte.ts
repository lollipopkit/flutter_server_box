/// How this browser writes times and sizes: a 24- or 12-hour clock, and
/// binary (KiB, 1024) or decimal (KB, 1000) units. Per browser, kept in
/// localStorage; read by `format.ts`, so every figure follows a change.

export type TimeFormat = '24' | '12'
export type SizeUnits = 'iec' | 'si'

const KEY = 'display'

interface Stored {
  time: TimeFormat
  units: SizeUnits
}

function load(): Stored {
  try {
    const raw = JSON.parse(window.localStorage.getItem(KEY) ?? '{}') as Partial<Stored>
    return { time: raw.time === '12' ? '12' : '24', units: raw.units === 'si' ? 'si' : 'iec' }
  } catch {
    return { time: '24', units: 'iec' }
  }
}

class DisplayPrefs {
  #value = $state<Stored>(load())

  get time(): TimeFormat {
    return this.#value.time
  }
  get units(): SizeUnits {
    return this.#value.units
  }

  set(patch: Partial<Stored>) {
    this.#value = { ...this.#value, ...patch }
    try {
      window.localStorage.setItem(KEY, JSON.stringify(this.#value))
    } catch {
      // Private mode: it lasts the tab.
    }
  }
}

export const displayPrefs = new DisplayPrefs()
