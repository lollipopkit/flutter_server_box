/// Whether the agent serving this page has a newer panel than the one
/// running: the build writes its id into the page (`__PANEL_BUILD__`) and
/// beside it (`/build.txt`). A page opened before a deploy is told to reload
/// before an app it opens names files the deploy took away.
///
/// Only for a panel the agent serves: a static host (Cloudflare Pages) is
/// deployed on its own, and agents' builds say nothing about it.

import { servers } from './servers.svelte'

const EVERY_MS = 60_000

class PanelBuild {
  /// A newer build is being served.
  stale = $state(false)
  #timer: ReturnType<typeof setInterval> | null = null

  /// Checks now, every minute and when the page comes back; the returned
  /// function stops.
  watch(): () => void {
    if (import.meta.env.DEV || this.#timer) return () => {}
    const check = () => void this.check()
    const onVisible = () => document.visibilityState === 'visible' && check()
    this.#timer = setInterval(check, EVERY_MS)
    document.addEventListener('visibilitychange', onVisible)
    check()
    return () => {
      if (this.#timer) clearInterval(this.#timer)
      this.#timer = null
      document.removeEventListener('visibilitychange', onVisible)
    }
  }

  async check() {
    if (this.stale || !servers.servedByAgent) return
    try {
      const res = await fetch('/build.txt', { cache: 'no-store' })
      if (!res.ok) return
      const served = (await res.text()).trim()
      if (served && served !== __PANEL_BUILD__) this.stale = true
    } catch {
      // Unreachable now: the next check asks again.
    }
  }
}

export const panelBuild = new PanelBuild()
