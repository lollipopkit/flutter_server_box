<script lang="ts">
  /// The login screen (the lollipopkit Design System's): a clock over the
  /// chosen instance's wallpaper, and a window with the instances on the left
  /// (where there are several) and, on the right, the chosen one's saved
  /// accounts, a sign-in form, or why it cannot be reached.
  ///
  /// The wallpaper is the chosen account's, or the instance's last, from the
  /// copy this browser kept when it was signed in (`wallpapers.ts`).

  import { tick } from 'svelte'
  import { fade } from 'svelte/transition'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { ApiError, loginTo, testConnection } from '../../lib/api'
  import { normalizeAgentUrl } from '../../lib/agentUrl'
  import { health } from '../../lib/health.svelte'
  import { probe } from '../../lib/probe'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { servers, type ServerAccount, type ServerEntry } from '../../lib/servers.svelte'
  import AppIcon, { type IconTone } from '../lk/AppIcon.svelte'
  import Button from '../lk/Button.svelte'
  import Checkbox from '../lk/Checkbox.svelte'
  import Icon from '../lk/Icon.svelte'
  import IconButton from '../lk/IconButton.svelte'
  import Input from '../lk/Input.svelte'
  import Wallpaper from '../shell/Wallpaper.svelte'
  import LockClock from './LockClock.svelte'
  import { dropWallpapers, loadWallpaper, type CachedWallpaper } from './wallpapers'

  interface Props {
    /// [serverId] is signed in: show its desk.
    onunlock: (serverId: string) => void
  }

  const { onunlock }: Props = $props()

  type Sel = string | 'new'

  let sel = $state<Sel>(servers.current?.id ?? (servers.empty ? 'new' : (servers.list[0]?.id ?? 'new')))
  let acct = $state(0)
  let other = $state(false)
  let user = $state('')
  let pw = $state('')
  let addr = $state('')
  let remember = $state(true)
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
  const accounts = $derived(inst ? servers.accountsOf(inst.id) : [])
  const offline = $derived(!!inst && health.status[inst.id] === false)
  const isNew = $derived(sel === 'new' || !inst)
  const isAccounts = $derived(!success && !offline && !isNew && accounts.length > 0 && !other)
  const isForm = $derived(!success && !offline && (isNew || accounts.length === 0 || other))
  const account = $derived<ServerAccount | null>(isAccounts ? (accounts[acct] ?? accounts[0] ?? null) : null)
  const unlock = $derived(!!account?.signedIn)
  const cantSubmit = $derived(
    busy ||
      (isAccounts && !unlock && !pw) ||
      (isForm && (!user.trim() || !pw || (isNew && !addr.trim()))),
  )

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

  interface Avatar {
    initial: string
    size: number
    x: number
    y: number
    z: number
    tone: IconTone
    ring: boolean
  }

  /// One account's initial, or two overlapping (the one in front last).
  function avatars(of: ServerAccount[], box: number, front = 0): Avatar[] {
    if (of.length === 0) return []
    const mk = (a: ServerAccount, size: number, x: number, y: number, z: number, ring: boolean): Avatar => ({
      initial: a.username.slice(0, 1).toUpperCase() || '?',
      size,
      x,
      y,
      z,
      tone: toneOf(a.username),
      ring,
    })
    if (of.length === 1) return [mk(of[0], box, 0, 0, 1, false)]
    const size = Math.round(box * 0.72)
    const lead = of[front] ?? of[0]
    const back = of.find((a) => a !== lead) ?? of[1]
    return [mk(back, size, 0, 0, 1, false), mk(lead, size, box - size, box - size, 2, true)]
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
    const signed = servers.accountsOf(s.id).find((a) => a.signedIn)
    if (signed) return $LL.lockAccountSignedIn({ user: signed.username })
    return host(shownUrl(s))
  }

  function accountHint(a: ServerAccount): string {
    if (a.signedIn) return a.lastLogin ? $LL.lockSignedInAgo({ when: ago(a.lastLogin) }) : $LL.lockSignedIn()
    return a.lastLogin ? $LL.lockLastSignIn({ when: ago(a.lastLogin) }) : ''
  }

  // ---- wallpaper --------------------------------------------------------

  let wallpaper = $state<{ key: string; preset: CachedWallpaper | null; url: string | null } | null>(null)
  $effect(() => {
    const id = inst?.id ?? null
    const username = account?.username ?? null
    const key = `${id}\n${username}`
    let gone = false
    let url: string | null = null
    if (id === null) {
      wallpaper = { key, preset: null, url: null }
      return
    }
    void loadWallpaper(id, username).then((wp) => {
      if (gone) return
      if (wp && 'image' in wp) url = URL.createObjectURL(wp.image)
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
    acct = 0
    other = false
    user = ''
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

  function forgetAccount(a: ServerAccount) {
    if (!inst) return
    void dropWallpapers(inst.id, a.username)
    servers.forget(inst.id, a.username)
    acct = 0
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
    if (isAccounts && account && inst) {
      if (unlock) {
        if (servers.useAccount(inst.id, account.username)) await finish(inst.id)
        return
      }
      await signIn(inst, account.username, true)
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
      await signIn(added, user.trim(), remember)
      return
    }
    if (inst) await signIn(inst, user.trim(), remember)
  }

  async function signIn(entry: ServerEntry, username: string, keep: boolean) {
    busy = true
    try {
      const res = await loginTo(entry.url, { username, password: pw })
      servers.signIn(entry.id, username, res.token, keep)
      pw = ''
      await finish(entry.id)
    } catch (error) {
      err = error instanceof ApiError && error.status === 401 ? $LL.lockWrongCredentials() : error instanceof ApiError ? error.message : $LL.deskSignInFailed()
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

<div class="lk desk-root lock fixed inset-0 z-[200000] overflow-hidden" role="main">
  {#key wallpaper?.key}
    <div class="absolute inset-0" transition:fade={{ duration: 700 }}>
      {#if wallpaper?.preset}
        <Wallpaper
          preset={'preset' in wallpaper.preset ? wallpaper.preset.preset : null}
          url={wallpaper.url}
          fit={wallpaper.preset.fit}
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
            <div class="flex min-h-0 flex-1 flex-col gap-[2px] overflow-y-auto px-[7px]">
              {#each list as s (s.id)}
                {@const of = servers.accountsOf(s.id)}
                {@const online = health.status[s.id]}
                <div class="group relative">
                  <button class="row" class:row--on={sel === s.id} onclick={() => pick(s.id)}>
                    {#if of.length}
                      {@render stack(avatars(of, 32), 32)}
                    {:else}
                      <AppIcon glyph={s.url === '' ? 'computer' : 'dns'} tone={toneOf(s.id)} size={32} />
                    {/if}
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
                    {#if accounts.length && !isNew}
                      {@render stack(avatars(accounts, 56, isAccounts ? acct : 0), 56)}
                    {:else}
                      <AppIcon glyph={isNew ? 'add' : inst?.url === '' ? 'computer' : 'dns'} tone={isNew ? 'mist' : toneOf(inst?.id ?? '')} size={56} />
                    {/if}
                  </span>
                  <div class="flex min-w-0 max-w-full flex-col gap-[3px]" in:rise={{ delay: 50 }}>
                    <div class="truncate text-[21px] font-bold tracking-[-0.01em]">{headName}</div>
                    <div class="lk-mono truncate text-[12px] text-(--text-tertiary)">{headUrl}</div>
                  </div>
                </div>

                <div in:rise={{ delay: 100 }}>
                  {#if isAccounts}
                    <form class="flex flex-col gap-[13px]" onsubmit={submit}>
                      <div class="accounts">
                        {#each accounts as a, i (a.username)}
                          <div class="group relative">
                            <button
                              type="button"
                              class="account"
                              class:account--on={acct === i}
                              onclick={() => {
                                if (busy) return
                                acct = i
                                pw = ''
                                err = ''
                              }}
                            >
                              <span class="initial" style:background="var(--icon-{toneOf(a.username)}-bg)" style:color="var(--icon-{toneOf(a.username)}-fg)">
                                {a.username.slice(0, 1).toUpperCase() || '?'}
                              </span>
                              <span class="flex min-w-0 flex-1 flex-col gap-px text-left">
                                <span class="truncate text-[13px] font-semibold">{a.username}</span>
                                {#if accountHint(a)}<span class="truncate text-[12px] text-(--text-tertiary)">{accountHint(a)}</span>{/if}
                              </span>
                              {#if acct === i}<Icon name="check" size={17} weight={600} color="var(--color-accent-text)" />{/if}
                            </button>
                            <button
                              type="button"
                              class="remove remove--account"
                              aria-label={$LL.lockForgetAccount()}
                              title={$LL.lockForgetAccount()}
                              onclick={() => forgetAccount(a)}
                            >
                              <Icon name="close" size={12} weight={600} />
                            </button>
                          </div>
                        {/each}
                      </div>
                      {#if !unlock}
                        <Input
                          type="password"
                          size="lg"
                          icon="lock"
                          aria-label={$LL.password()}
                          placeholder={account ? $LL.lockPasswordOf({ user: account.username }) : $LL.password()}
                          autocomplete="current-password"
                          bind:value={pw}
                          oninput={() => (err = '')}
                          error={err || undefined}
                        />
                      {/if}
                      <Button type="submit" variant="primary" size="lg" block iconRight={busy ? undefined : 'arrow_forward'} disabled={cantSubmit}>
                        {submitLabel}
                      </Button>
                      <button type="button" class="link" onclick={() => ((other = true), (pw = ''), (err = ''))}>{$LL.lockOtherUser()}</button>
                    </form>
                  {:else if isForm}
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
                      <Input
                        size="lg"
                        icon="person"
                        aria-label={$LL.username()}
                        placeholder={$LL.username()}
                        autocomplete="username"
                        bind:value={user}
                        oninput={() => (err = '')}
                      />
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
                      <div class="flex items-center pb-[4px] pt-[2px]">
                        <Checkbox label={$LL.lockRemember()} bind:checked={remember} />
                      </div>
                      <Button type="submit" variant="primary" size="lg" block iconRight={busy ? undefined : 'arrow_forward'} disabled={cantSubmit}>
                        {submitLabel}
                      </Button>
                      {#if !isNew && accounts.length > 0}
                        <button type="button" class="link mt-[4px]" onclick={() => ((other = false), (user = ''), (pw = ''), (err = ''))}>
                          {$LL.lockSavedAccounts()}
                        </button>
                      {/if}
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

{#snippet stack(of: Avatar[], box: number)}
  <span class="relative shrink-0" style:width="{box}px" style:height="{box}px">
    {#each of as v, i (i)}
      <span
        class="avatar"
        style:left="{v.x}px"
        style:top="{v.y}px"
        style:z-index={v.z}
        style:width="{v.size}px"
        style:height="{v.size}px"
        style:font-size="{Math.round(v.size * 0.42)}px"
        style:background="var(--icon-{v.tone}-bg)"
        style:color="var(--icon-{v.tone}-fg)"
        style:box-shadow={v.ring ? '0 0 0 2px var(--surface-window)' : null}>{v.initial}</span
      >
    {/each}
  </span>
{/snippet}

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
    backdrop-filter: var(--blur-sidebar);
    -webkit-backdrop-filter: var(--blur-sidebar);
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
  .row--on,
  .row--on:hover {
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
    border-radius: 23%;
    box-shadow: inset 0 0 0 1px var(--border-strong);
  }
  .avatar {
    position: absolute;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    font-weight: 700;
  }
  .accounts {
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border-radius: var(--radius-card);
    background: var(--surface-card);
  }
  .accounts > .group + .group .account {
    border-top: 0.5px solid var(--border-hairline);
  }
  .account {
    display: flex;
    width: 100%;
    min-height: 44px;
    box-sizing: border-box;
    align-items: center;
    gap: var(--space-9);
    padding: var(--space-9) var(--space-11);
    border: 0;
    background: transparent;
    color: var(--text-primary);
    font: inherit;
    cursor: default;
  }
  .account:hover {
    background: var(--fill-hover);
  }
  .account--on,
  .account--on:hover {
    background: var(--surface-selected);
  }
  .initial {
    display: flex;
    width: 28px;
    height: 28px;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    font-size: 13px;
    font-weight: 700;
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
  .remove--account {
    right: 34px;
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
    backdrop-filter: var(--blur-dock);
    -webkit-backdrop-filter: var(--blur-dock);
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
