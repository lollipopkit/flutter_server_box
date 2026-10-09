/// What the server and the desk's apps told this desk: the notification
/// centre's list, its unread count, and the banner a new one shows for a
/// moment. The server's are kept by the agent; an app's (`sys.notify`) last
/// as long as the page.

import { systemPrefs } from './sys/systemPrefs.svelte'
import type { DeskNotification } from './deskApi'
import type { DeskStorage } from './storage'

export const BANNER_MS = 4200
const DND_KEY = 'desk.dnd'

/// What an app says through `sys.notify`.
export interface AppNotice {
  title: string
  body?: string
  level?: DeskNotification['level']
}

const MAX_LOCAL = 100
const MAX_TITLE = 200
const MAX_BODY = 2000

export class DeskNotifications {
  #remote = $state<DeskNotification[]>([])
  #remoteUnread = $state(0)
  #local = $state<DeskNotification[]>([])
  #nextLocal = -1
  /// The one on screen as a banner, if any.
  banner = $state<DeskNotification | null>(null)
  /// Do not disturb: kept, counted, not shown as banners. This browser's.
  dnd = $state(readDnd())

  #storage: DeskStorage
  #bannerTimer: ReturnType<typeof setTimeout> | null = null

  constructor(storage: DeskStorage) {
    this.#storage = storage
  }

  /// Newest first.
  get list(): DeskNotification[] {
    return [...this.#local, ...this.#remote].sort((a, b) => b.created_at.localeCompare(a.created_at) || b.id - a.id)
  }

  get unread(): number {
    return this.#remoteUnread + this.#local.filter((n) => !n.read).length
  }

  async load() {
    try {
      const { notifications, unread } = await this.#storage.notifications()
      this.#remote = notifications
      this.#remoteUnread = unread
    } catch {
      // Kept as it was; the next event or opening the centre tries again.
    }
  }

  /// One the event stream brought.
  arrived(n: DeskNotification) {
    if (this.#remote.some((x) => x.id === n.id)) return
    this.#remote = [n, ...this.#remote].slice(0, 200)
    if (!n.read) this.#remoteUnread++
    if (!this.dnd && systemPrefs.value.banners) this.#show(n)
  }

  /// One an app posted. Its `source` is `app:<appId>`; ids are negative, so
  /// they never meet the agent's.
  posted(appId: string, notice: AppNotice): DeskNotification {
    const n: DeskNotification = {
      id: this.#nextLocal--,
      // eslint-disable-next-line svelte/prefer-svelte-reactivity -- read once, never kept
      created_at: new Date().toISOString(),
      level: notice.level === 'warning' || notice.level === 'critical' ? notice.level : 'info',
      source: `app:${appId}`,
      subject: String(notice.title).slice(0, MAX_TITLE),
      body: String(notice.body ?? '').slice(0, MAX_BODY),
      read: false,
    }
    this.#local = [n, ...this.#local].slice(0, MAX_LOCAL)
    if (!this.dnd && systemPrefs.value.banners) this.#show(n)
    return n
  }

  async markRead(id: number) {
    const local = this.#local.find((x) => x.id === id)
    if (local) {
      local.read = true
      return
    }
    const n = this.#remote.find((x) => x.id === id)
    if (!n || n.read) return
    n.read = true
    this.#remoteUnread = Math.max(0, this.#remoteUnread - 1)
    await this.#storage.markRead({ ids: [id] }).catch(() => {})
  }

  async markAllRead() {
    for (const n of this.#local) n.read = true
    for (const n of this.#remote) n.read = true
    this.#remoteUnread = 0
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
