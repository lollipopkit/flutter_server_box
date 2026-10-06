/// What the server told this desk: the notification centre's list, its unread
/// count, and the banner a new one shows for a moment.

import type { DeskNotification } from './deskApi'
import type { DeskStorage } from './storage'

export const BANNER_MS = 4200
const DND_KEY = 'desk.dnd'

export class DeskNotifications {
  list = $state<DeskNotification[]>([])
  unread = $state(0)
  /// The one on screen as a banner, if any.
  banner = $state<DeskNotification | null>(null)
  /// Do not disturb: kept, counted, not shown as banners. This browser's.
  dnd = $state(readDnd())

  #storage: DeskStorage
  #bannerTimer: ReturnType<typeof setTimeout> | null = null

  constructor(storage: DeskStorage) {
    this.#storage = storage
  }

  async load() {
    try {
      const { notifications, unread } = await this.#storage.notifications()
      this.list = notifications
      this.unread = unread
    } catch {
      // Kept as it was; the next event or opening the centre tries again.
    }
  }

  /// One the event stream brought.
  arrived(n: DeskNotification) {
    if (this.list.some((x) => x.id === n.id)) return
    this.list = [n, ...this.list].slice(0, 200)
    if (!n.read) this.unread++
    if (!this.dnd) this.#show(n)
  }

  async markRead(id: number) {
    const n = this.list.find((x) => x.id === id)
    if (!n || n.read) return
    n.read = true
    this.unread = Math.max(0, this.unread - 1)
    await this.#storage.markRead({ ids: [id] }).catch(() => {})
  }

  async markAllRead() {
    for (const n of this.list) n.read = true
    this.unread = 0
    await this.#storage.markRead({ all: true }).catch(() => {})
  }

  setDnd(on: boolean) {
    this.dnd = on
    try {
      window.localStorage.setItem(DND_KEY, on ? '1' : '0')
    } catch {
      // Not kept; on for this page.
    }
    if (on) this.dismissBanner()
  }

  dismissBanner() {
    if (this.#bannerTimer) clearTimeout(this.#bannerTimer)
    this.#bannerTimer = null
    this.banner = null
  }

  close() {
    this.dismissBanner()
  }

  #show(n: DeskNotification) {
    if (this.#bannerTimer) clearTimeout(this.#bannerTimer)
    this.banner = n
    this.#bannerTimer = setTimeout(() => {
      this.#bannerTimer = null
      this.banner = null
    }, BANNER_MS)
  }
}

function readDnd(): boolean {
  try {
    return window.localStorage.getItem(DND_KEY) === '1'
  } catch {
    return false
  }
}
