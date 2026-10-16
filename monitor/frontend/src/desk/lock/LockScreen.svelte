<script lang="ts">
  import { shellPrefs } from '../shellPrefs.svelte'
  /// The login screen (the lollipopkit Design System's): a clock over the
  /// chosen instance's wallpaper, and a window with the instances on the left
  /// (where there are several) and, on the right, the chosen one's password
  /// (none when this tab holds its session), or why it cannot be reached.
  ///
  /// The wallpaper is the instance's last, from the copy this browser kept
  /// when it was signed in (`wallpapers.ts`).

  import { tick } from 'svelte'
  import { fade } from 'svelte/transition'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { ApiError, loginTo, testConnection } from '../../lib/api'
  import { normalizeAgentUrl } from '../../lib/agentUrl'
  import { health } from '../../lib/health.svelte'
  import { probe } from '../../lib/probe'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { servers, type ServerEntry } from '../../lib/servers.svelte'
  import AppIcon, { type IconTone } from '../lk/AppIcon.svelte'
  import Button from '../lk/Button.svelte'
  import Icon from '../lk/Icon.svelte'
  import IconButton from '../lk/IconButton.svelte'
  import Indicator from '../lk/Indicator.svelte'
  import Input from '../lk/Input.svelte'
  import Wallpaper from '../shell/Wallpaper.svelte'
  import LockClock from './LockClock.svelte'
  import { dropWallpapers, loadWallpaper, type CachedTheme, type CachedWallpaper } from './wallpapers'
  import type { ThemeWallpaper } from '../themeStyle'

  interface Props {
    /// [serverId] is signed in: show its desk.
    onunlock: (serverId: string) => void
  }

  const { onunlock }: Props = $props()

  type Sel = string | 'new'

  let sel = $state<Sel>(servers.current?.id ?? (servers.empty ? 'new' : (servers.list[0]?.id ?? 'new')))
  let pw = $state('')
  let addr = $state('')
  let err = $state('')
  let busy = $state(false)
  let success = $state(false)
  let editing = $state(false)
  /// The way the last switch went, for the content's slide.
  let dir = $state(1)

  const list = $derived(servers.list)
  const single = $derived(list.length <= 1)
  /// A panel an agent serves holds that one server; nothing to connect.
  const canAdd = $derived(!servers.servedByAgent)
  const inst = $derived(sel === 'new' ? null : (list.find((s) => s.id === sel) ?? null))
  const offline = $derived(!!inst && health.status[inst.id] === false)
  const isNew = $derived(sel === 'new' || !inst)
  const isForm = $derived(!success && !offline)
  /// This tab holds its session: unlocking asks for nothing.
  const unlock = $derived(!isNew && !!inst?.token)
  const cantSubmit = $derived(busy || (!unlock && (!pw || (isNew && !addr.trim()))))

  // ---- names ------------------------------------------------------------

  function name(s: ServerEntry): string {
    return serverNames.byServer[s.id] ?? (s.url === '' ? $LL.thisServer() : host(s.url))
  }

  function host(url: string): string {
    return url.replace(/^https?:\/\//, '').replace(/\/.*$/, '')
  }

  function shownUrl(s: ServerEntry): string {
    return s.url || window.location.origin
  }

  const TONES: IconTone[] = ['berry', 'soft', 'bright', 'pale', 'mist', 'ink']
  function toneOf(text: string): IconTone {
    let h = 0
    for (const ch of text) h = (h * 31 + ch.charCodeAt(0)) >>> 0
    return TONES[h % TONES.length]
  }

  const relative = $derived(new Intl.RelativeTimeFormat($locale, { numeric: 'auto' }))
  function ago(ms: number): string {
    const s = Math.round((ms - Date.now()) / 1000)
    const a = Math.abs(s)
    if (a < 60) return relative.format(s, 'second')
    if (a < 3600) return relative.format(Math.round(s / 60), 'minute')
    if (a < 86400) return relative.format(Math.round(s / 3600), 'hour')
    return relative.format(Math.round(s / 86400), 'day')
  }

  function rowSub(s: ServerEntry): string {
    if (health.status[s.id] === false) return $LL.lockOffline()
    if (s.token) return $LL.lockSignedIn()
    return host(shownUrl(s))
  }

  // ---- wallpaper --------------------------------------------------------

  function lockTheme(t: CachedTheme, url: string | null): ThemeWallpaper {
    return { ground: t.ground, image: url ? { url, opacity: t.opacity, blur: t.blur, tile: t.tile } : null }
  }

  let wallpaper = $state<{ key: string; preset: CachedWallpaper | null; url: string | null } | null>(null)
  $effect(() => {
    const id = inst?.id ?? null
    const key = `${id}`
    let gone = false
    let url: string | null = null
    if (id === null) {
      wallpaper = { key, preset: null, url: null }
      return
    }
    void loadWallpaper(id).then((wp) => {
      if (gone) return
      if (wp && 'image' in wp) url = URL.createObjectURL(wp.image)
      if (wp && 'theme' in wp && wp.theme.image) url = URL.createObjectURL(wp.theme.image)
      wallpaper = { key, preset: wp, url }
    })
    return () => {
      gone = true
      // Revoked once the crossfade has let it go.
      if (url) {
        const old = url
        setTimeout(() => URL.revokeObjectURL(old), 1000)
      }
    }
  })

  // ---- choosing ---------------------------------------------------------

  const order = $derived<Sel[]>([...list.map((s) => s.id), ...(canAdd ? ['new' as const] : [])])

  function pick(next: Sel) {
    if (busy) return
    const at = (x: Sel) => order.indexOf(x)
    dir = at(next) >= at(sel) ? 1 : -1
    sel = next
    pw = ''
    err = ''
    success = false
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return
    if (order.length < 2 || editing) return
    e.preventDefault()
    const at = Math.max(0, order.indexOf(sel))
    pick(order[(at + (e.key === 'ArrowDown' ? 1 : -1) + order.length) % order.length])
  }

  function removeServer(id: string) {
    void dropWallpapers(id)
    servers.remove(id)
    if (sel === id) pick(servers.list[0]?.id ?? 'new')
  }

  // ---- signing in -------------------------------------------------------

  async function finish(id: string) {
    success = true
    await new Promise((r) => setTimeout(r, 450))
    onunlock(id)
  }

  async function submit(e?: Event) {
    e?.preventDefault()
    if (cantSubmit) return
    err = ''
    if (unlock && inst) {
      await finish(inst.id)
      return
    }
    if (isNew) {
      let url: string
      try {
        url = normalizeAgentUrl(addr)
      } catch (error) {
        err = error instanceof Error ? error.message : $LL.deskBadUrl()
        return
      }
      busy = true
      const reachable = await testConnection(url)
      busy = false
      if (!reachable) {
        err = $LL.deskUnreachable()
        return
      }
      servers.add(url)
      const added = servers.list.find((s) => s.id === servers.currentId)
      if (!added) return
      sel = added.id
      addr = ''
      await tick()
      await signIn(added)
      return
    }
    if (inst) await signIn(inst)
  }

  async function signIn(entry: ServerEntry) {
    busy = true
    try {
      const res = await loginTo(entry.url, { password: pw })
      servers.setSession(entry.id, res.token)
      pw = ''
      await finish(entry.id)
    } catch (error) {
      err = error instanceof ApiError && error.status === 401 ? $LL.accessErrReauth() : error instanceof ApiError ? error.message : $LL.deskSignInFailed()
    } finally {
      busy = false
    }
  }

  let retrying = $state(false)
  async function retry() {
    if (!inst) return
    retrying = true
    const id = inst.id
    const reachable = (await probe(inst.url)) === 'healthy'
    health.status[id] = reachable
    if (reachable) servers.markOnline(id)
    retrying = false
  }

  const submitLabel = $derived(
    busy ? (unlock ? $LL.lockUnlocking() : $LL.lockSigningIn()) : unlock ? $LL.deskUnlock() : isNew ? $LL.lockConnectAndSignIn() : $LL.signIn(),
  )

  const headName = $derived(inst ? name(inst) : addr.trim() ? host(addr.trim()) : $LL.lockNewInstance())
  const headUrl = $derived(inst ? shownUrl(inst) : addr.trim() || $LL.lockEnterAddress())

  // ---- motion -------------------------------------------------------------

  const reduce = () =>
    document.querySelector('[data-reduce-motion]') !== null || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches

  function hero(_node: Element) {
    return reduce()
      ? { duration: 150, css: (t: number) => `opacity:${t}` }
      : { duration: 460, easing: (t: number) => 1 + 2.7 * (t - 1) ** 3 + 1.7 * (t - 1) ** 2, css: (t: number) => `opacity:${Math.min(1, t * 1.6)};transform:scale(${0.82 + 0.18 * t})` }
  }

  function rise(_node: Element, { delay = 0 }: { delay?: number } = {}) {
    return reduce()
      ? { duration: 150, css: (t: number) => `opacity:${t}` }
      : { delay, duration: 340, easing: (t: number) => 1 - (1 - t) ** 3, css: (t: number, u: number) => `opacity:${t};transform:translateY(${u * dir * 11}px)` }
  }
</script>

<svelte:window {onkeydown} />

<div class="lk desk-root lock fixed inset-0 z-[200000] overflow-hidden" data-icon-shape={shellPrefs.iconShape} role="main">
  {#key wallpaper?.key}
    <div class="absolute inset-0" transition:fade={{ duration: 700 }}>
      {#if wallpaper?.preset}
        <Wallpaper
          preset={'preset' in wallpaper.preset ? wallpaper.preset.preset : null}
          url={'image' in wallpaper.preset ? wallpaper.url : null}
          fit={wallpaper.preset.fit}
          theme={'theme' in wallpaper.preset ? lockTheme(wallpaper.preset.theme, wallpaper.url) : null}
        />
      {:else}
        <div class="absolute inset-0" style:background="var(--wallpaper)"></div>
      {/if}
    </div>
  {/key}

  <div class="relative flex h-full flex-col items-center overflow-y-auto px-[17px]">
    <LockClock {editing} ondone={() => (editing = false)} />

    <div class="stage" class:stage--editing={editing}>
      <div class="panel" class:panel--single={single}>
        {#if !single}
          <aside class="instances">
            <div class="lk-caps px-[13px] pb-[7px] pt-[13px]">{$LL.lockInstances()}</div>
            <div class="relative flex min-h-0 flex-1 flex-col gap-[2px] overflow-y-auto px-[7px]">
              <Indicator selector=".row--on" class="lock-pill" />
              {#each list as s (s.id)}
                {@const online = health.status[s.id]}
                <div class="group relative">
                  <button class="row" class:row--on={sel === s.id} onclick={() => pick(s.id)}>
                    <AppIcon glyph={s.url === '' ? 'computer' : 'dns'} tone={toneOf(s.id)} size={32} />
                    <span class="flex min-w-0 flex-1 flex-col gap-px text-left">
                      <span class="truncate text-[13px] font-semibold">{name(s)}</span>
                      <span class="truncate text-[11px] text-(--text-tertiary)">{rowSub(s)}</span>
                    </span>
                    <span
                      class="h-[7px] w-[7px] shrink-0 rounded-full"
                      style:background={online === false ? 'var(--text-disabled)' : online ? 'var(--color-success)' : 'var(--text-tertiary)'}
                      title={online === false ? $LL.lockOffline() : $LL.lockOnline()}
                    ></span>
                  </button>
                  {#if canAdd}
                    <button class="remove" aria-label={$LL.removeServer()} title={$LL.removeServer()} onclick={() => removeServer(s.id)}>
                      <Icon name="close" size={12} weight={600} />
                    </button>
                  {/if}
                </div>
              {/each}
            </div>
            {#if canAdd}
              <div class="border-t-[0.5px] border-(--border-hairline) p-[7px]">
                <button class="row row--new" class:row--on={sel === 'new'} onclick={() => pick('new')}>
                  <span class="add-tile"><Icon name="add" size={18} /></span>
                  {$LL.lockConnectNew()}
                </button>
              </div>
            {/if}
          </aside>
        {/if}

        <div class="flex min-w-0 flex-1 items-center justify-center p-[21px]">
          <div class="flex w-full max-w-[300px] flex-col gap-[17px]">
            {#if success}
              <div class="flex flex-col items-center gap-[9px] text-center" in:rise>
                <Icon name="check_circle" fill size={44} color="var(--color-success)" />
                <div class="text-[17px] font-bold">{$LL.lockSignedIn()}</div>
                <div class="text-[13px] text-(--text-secondary)">{$LL.lockOpening({ name: headName })}</div>
              </div>
            {:else}
              {#key sel}
                <div class="flex flex-col items-center gap-[9px] text-center">
                  <span class="relative z-[5] flex" in:hero>
                    <AppIcon glyph={isNew ? 'add' : inst?.url === '' ? 'computer' : 'dns'} tone={isNew ? 'mist' : toneOf(inst?.id ?? '')} size={56} />
                  </span>
                  <div class="flex min-w-0 max-w-full flex-col gap-[3px]" in:rise={{ delay: 50 }}>
                    <div class="truncate text-[21px] font-bold tracking-[-0.01em]">{headName}</div>
                    <div class="lk-mono truncate text-[12px] text-(--text-tertiary)">{headUrl}</div>
                  </div>
                </div>

                <div in:rise={{ delay: 100 }}>
                  {#if isForm}
                    <form class="flex flex-col gap-[9px]" onsubmit={submit}>
                      {#if isNew}
                        <Input
                          size="lg"
                          icon="link"
                          mono
                          aria-label={$LL.serverUrlLabel()}
                          placeholder="https://host:3770"
                          bind:value={addr}
                          oninput={() => (err = '')}
                        />
                      {/if}
                      {#if !unlock}
                        <Input
                          type="password"
                          size="lg"
                          icon="lock"
                          aria-label={$LL.password()}
                          placeholder={$LL.password()}
                          autocomplete="current-password"
                          bind:value={pw}
                          oninput={() => (err = '')}
                          error={err || undefined}
                        />
                      {/if}
                      <Button type="submit" variant="primary" size="lg" block iconRight={busy ? undefined : 'arrow_forward'} disabled={cantSubmit}>
                        {submitLabel}
                      </Button>
                    </form>
                  {:else if offline && inst}
                    <div class="flex flex-col items-center gap-[13px] text-center">
                      <div class="flex flex-col items-center gap-[5px] pb-[4px] pt-[13px]">
                        <Icon name="cloud_off" size={27} color="var(--text-tertiary)" />
                        <div class="text-[13px] font-semibold">{$LL.lockUnreachable()}</div>
                        {#if servers.lastOnline[inst.id]}
                          <div class="text-[12px] text-(--text-tertiary)">{$LL.lockLastOnline({ when: ago(servers.lastOnline[inst.id]) })}</div>
                        {/if}
                      </div>
                      <Button variant="secondary" icon="refresh" disabled={retrying} onclick={retry}>
                        {retrying ? $LL.lockConnecting() : $LL.lockRetry()}
                      </Button>
                    </div>
                  {/if}
                </div>
              {/key}
              {#if single && canAdd && (list.length > 0 || sel !== 'new')}
                <button class="link link--quiet" onclick={() => pick(isNew && list[0] ? list[0].id : 'new')}>
                  {isNew && list[0] ? $LL.lockBackTo({ name: name(list[0]) }) : $LL.lockConnectOther()}
                </button>
              {/if}
            {/if}
          </div>
        </div>
      </div>
    </div>

    <div class="hints">
      {#if !single}
        <span class="flex items-center gap-[5px]"><span class="lk-mono">↑ ↓</span>{$LL.lockSwitchInstance()}</span>
      {/if}
      <span class="flex items-center gap-[5px]"><span class="lk-mono">⏎</span>{$LL.signIn()}</span>
      <div class="tune">
        <IconButton icon="tune" label={$LL.lockClockStyle()} size="lg" active={editing} onclick={() => (editing = !editing)} />
      </div>
    </div>
  </div>
</div>


<style>
  .lock {
    --lock-fg: var(--text-primary);
    --lock-fg2: var(--text-secondary);
    background: var(--ink-90);
    font-family: var(--font-ui);
    color: var(--text-primary);
  }
  .stage {
    position: relative;
    z-index: 1;
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    width: 100%;
    padding: var(--space-34) 0 var(--space-21);
    transition: opacity 220ms;
  }
  .stage--editing {
    opacity: 0.35;
    pointer-events: none;
  }
  .panel {
    display: flex;
    gap: var(--space-7);
    width: 100%;
    max-width: 760px;
    height: 440px;
    padding: var(--space-7);
    box-sizing: border-box;
    border-radius: var(--radius-window);
    background: var(--surface-window);
    box-shadow:
      var(--shadow-window),
      inset 0 0 0 0.5px var(--border-glass);
  }
  .panel--single {
    max-width: 380px;
    height: auto;
  }
  .instances {
    display: flex;
    width: 244px;
    flex-shrink: 0;
    flex-direction: column;
    border-radius: var(--radius-md);
    background: var(--glass-sidebar);
    -webkit-backdrop-filter: var(--blur-sidebar);
    backdrop-filter: var(--blur-sidebar);
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
  }
  .row {
    display: flex;
    width: 100%;
    box-sizing: border-box;
    align-items: center;
    gap: var(--space-9);
    padding: var(--space-7);
    border: 0;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--text-primary);
    font: inherit;
    cursor: default;
    transition: background-color var(--dur-fast);
  }
  .row:hover {
    background: var(--fill-hover);
  }
  /* In the list the chosen row is marked by the one indicator gliding to it
     (the design system's selection motion); the new-instance row has its own. */
  :global(.lock-pill) {
    position: absolute;
    border-radius: var(--radius-sm);
    background: var(--surface-selected);
    pointer-events: none;
    transition: opacity 200ms;
  }
  :global(.lock-pill--glide) {
    transition:
      transform var(--dur-indicator) var(--ease-indicator),
      height var(--dur-indicator) var(--ease-indicator),
      opacity 200ms;
  }
  .row--on,
  .row--on:hover {
    background: transparent;
  }
  .row--new.row--on,
  .row--new.row--on:hover {
    background: var(--surface-selected);
  }
  .row--new {
    color: var(--color-accent-text);
    font-size: 13px;
    font-weight: 600;
  }
  .add-tile {
    display: flex;
    width: 32px;
    height: 32px;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius-icon);
    box-shadow: inset 0 0 0 1px var(--border-strong);
  }
  .remove {
    position: absolute;
    top: 50%;
    right: 20px;
    display: none;
    width: 18px;
    height: 18px;
    place-items: center;
    padding: 0;
    border: 0;
    border-radius: 50%;
    background: var(--surface-raised);
    box-shadow: var(--shadow-thumb);
    color: var(--text-secondary);
    transform: translateY(-50%);
  }
  .group:hover .remove,
  .remove:focus-visible {
    display: grid;
  }
  .link {
    align-self: center;
    padding: var(--space-3) var(--space-7);
    border: 0;
    border-radius: var(--radius-xs);
    background: none;
    color: var(--color-accent-text);
    font: inherit;
    font-size: 12px;
    cursor: default;
  }
  .link:hover {
    background: var(--fill-hover);
  }
  .link--quiet {
    color: var(--text-tertiary);
  }
  .link--quiet:hover {
    color: var(--text-secondary);
  }
  .hints {
    position: relative;
    z-index: 1;
    display: flex;
    align-self: stretch;
    min-height: 44px;
    align-items: center;
    justify-content: center;
    gap: var(--space-13);
    padding: 0 0 var(--space-13);
    color: var(--lock-fg2);
    font-size: 12px;
  }
  .tune {
    position: absolute;
    right: 4px;
    bottom: var(--space-13);
    border-radius: 50%;
    background: var(--glass-dock);
    -webkit-backdrop-filter: var(--blur-dock);
    backdrop-filter: var(--blur-dock);
    box-shadow: inset 0 0 0 0.5px var(--border-glass);
  }
  /* A phone: the instances above the sign-in, not beside it. */
  @media (max-width: 640px) {
    .panel {
      flex-direction: column;
      height: auto;
    }
    .instances {
      width: auto;
      max-height: 196px;
    }
  }
</style>
