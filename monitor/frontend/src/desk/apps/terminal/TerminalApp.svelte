<script lang="ts">
  /// A local shell in the desk. The agent opens it without SSH credentials
  /// when the account has the `shell` grant, and rejoins a stored session after
  /// a reload.
  ///
  /// xterm.js is loaded on demand; most visits never open a terminal.

  import { onDestroy, onMount, tick, untrack } from 'svelte'
  import { Button, Card, Dialog, Icon, IconButton, Input, Spinner, StatusBar } from '../../lk'
  import { AppToolbar, type MenuEntry, useIntents, useLifecycle, useMenus, useWindow, WindowFooter } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { isAdmin, machineAccess, terminalAccess, whyText } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { fmtEpochSeconds } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'
  import { queuedSnippet, TYPE_SNIPPET, type QueuedSnippet } from '../../../lib/snippetIntent'
  import { runSteps } from '../../../lib/snippetSteps'
  import { theme } from '../../../lib/theme.svelte'
  import { TerminalSession, type Renderer } from '../../../lib/terminal.svelte'
  import { terminalSurface } from '../../../lib/terminalSurface.svelte'
  import { tmuxIssueText } from '../../../lib/tmux'
  import { mountTerminal, type TerminalHandle } from '../../../lib/xterm'
  import { loadLook } from './look'
  import type { TmuxSession, TmuxView } from '../../../types'

  const win = useWindow()
  // One resume handle per window: each window rejoins its own shell after a
  // reload, and two windows never trade one.
  const session = new TerminalSession({ key: win.id || undefined })

  let host = $state<HTMLDivElement | null>(null)
  /// The mounted xterm, once loaded. Its renderer is what the session writes
  /// through; see `mountTerminal`.
  let terminal = $state<TerminalHandle | null>(null)
  /// The one mount in flight, shared by starts that arrive while xterm loads.
  let mounting: Promise<TerminalHandle | null> | null = null
  let startBusy = $state(false)
  /// Set when the page goes away, so a mount that finishes after it is disposed.
  let destroyed = false

  const CREDENTIAL_KEY = 'terminal.credential'
  onMount(() => {
    // TODO: remove once no tab can still hold a credential from the SSH form (written before 2026-10-07).
    try {
      window.sessionStorage.removeItem(CREDENTIAL_KEY)
    } catch {
      // Nothing to recover from; the old credential simply expires with the tab.
    }
  })

  async function ensureTerminal(): Promise<Renderer | null> {
    if (!terminal) {
      await tick()
      if (!host) throw new Error('the terminal host is not mounted')
      const look = await loadLook(win.storage)
      if (!host) throw new Error('the terminal host is not mounted')
      mounting ??= mountTerminal(host, session, look).then(
        (mounted) => {
          if (destroyed) {
            mounted.dispose()
            return null
          }
          terminal = mounted
          return mounted
        },
        (e: unknown) => {
          mounting = null
          throw e
        },
      )
      return (await mounting)?.renderer ?? null
    }
    return terminal.renderer
  }

  async function startWith(fn: (renderer: Renderer) => Promise<void>) {
    if (startBusy || !fullAccess) return
    startBusy = true
    try {
      const renderer = await ensureTerminal()
      if (renderer && fullAccess) await fn(renderer)
    } catch (e) {
      session.error = e instanceof Error ? e.message : String(e)
    } finally {
      startBusy = false
    }
  }

  /// The look may have changed in Settings while this window was behind:
  /// read again each time it comes to the front.
  const life = useLifecycle()
  $effect(() => {
    if (life.state !== 'active' || !terminal) return
    const t = terminal
    void loadLook(win.storage).then((look) => t.setLook(look))
  })

  $effect(() => {
    // Re-read on every theme change; `theme.current` is the trigger even
    // though the value comes from the document.
    void theme.current
    terminal?.setTheme()
  })

  /// Typing belongs in the shell. It fires when a fresh open or rejoin reaches
  /// `running`, or this pane gets the focus, and never takes focus back from
  /// a field the user is in.
  $effect(() => {
    if (session.phase === 'running' && win.active) terminal?.focus()
  })

  /// The title the shell sets (its prompt's directory, a running program)
  /// names the tab and the window, as a terminal's does.
  $effect(() => {
    const t = terminal
    if (!t) return
    const stop = t.onTitle((title) => win.setTitle(title))
    return () => {
      stop()
      win.setTitle(null)
    }
  })

  function disconnect() {
    session.close()
  }

  async function newSession() {
    session.close()
    terminal?.renderer.reset()
    await startWith((renderer) => session.start(renderer, { kind: 'local' }))
  }

  /// A device coming back from sleep or a dead network should reconnect at
  /// once rather than wait out a backoff scheduled before it went away.
  function wake() {
    if (document.visibilityState === 'visible') session.reconnectNow()
  }

  $effect(() => {
    window.addEventListener('online', wake)
    document.addEventListener('visibilitychange', wake)
    // The last chance to record the resume point exactly.
    const flush = () => session.flush()
    window.addEventListener('pagehide', flush)
    return () => {
      window.removeEventListener('online', wake)
      document.removeEventListener('visibilitychange', wake)
      window.removeEventListener('pagehide', flush)
    }
  })

  onDestroy(() => {
    destroyed = true
    // A closed window ends its shell, which would otherwise hold one of the
    // agent's few session slots until it times out; content unmounted while
    // its window lives on keeps the shell to rejoin.
    if (win.closed) session.close()
    else session.dispose()
    terminal?.dispose()
  })

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// Which terminals this account can open here — see `terminalAccess`.
  const access = $derived(terminalAccess(caps))

  /// The dashboard only offers the entry point when the agent reports a
  /// terminal, but a cached capability or stale tab can still land here.
  let turnedOff = $state(false)
  const fullAccess = $derived(!turnedOff && access.available)
  const canTurnOff = $derived(isAdmin(caps) !== false)

  /// Start once when capabilities say a direct shell is available. Do not gate
  /// on lifecycle: hidden windows keep their shell running like visible ones.
  let autoStarted = false
  $effect(() => {
    if (!fullAccess) return
    untrack(() => {
      if (autoStarted) return
      autoStarted = true
      const resume = session.resumable
      void startWith((renderer) => session.start(renderer, resume ? null : { kind: 'local' }))
    })
  })

  /// Shown the first time shell access is on offer, once per browser. This
  /// explains the security boundary before the shell is used further.
  const NOTICE_KEY = 'terminal.fullAccessNoticeSeen'
  let noticeDismissed = $state(false)
  try {
    noticeDismissed = window.localStorage.getItem(NOTICE_KEY) === '1'
  } catch {
    // The notice can be shown again when storage is unavailable.
  }
  const showNotice = $derived(fullAccess && !noticeDismissed)
  let disabling = $state(false)

  function acknowledgeNotice() {
    try {
      window.localStorage.setItem(NOTICE_KEY, '1')
    } catch {
      // Only costs seeing the notice again.
    }
    noticeDismissed = true
  }

  async function disablePasswordless() {
    disabling = true
    try {
      await api.disablePasswordlessTerminal()
      session.close()
      turnedOff = true
      capabilitiesStore.clear(servers.currentId)
      acknowledgeNotice()
    } catch (e) {
      session.error = e instanceof Error ? e.message : String(e)
    } finally {
      disabling = false
    }
  }

  /// The tmux picker refreshes every time it opens; replies from a previous
  /// machine are discarded if the desk switched servers in the meantime.
  const tmuxOffered = $derived(machineAccess(caps, 'tmux', 'shell'))
  let tmux = $state<TmuxView | null>(null)
  let tmuxLoading = $state(false)
  let tmuxLoadError = $state('')
  let tmuxRequest = 0
  let tmuxOpen = $state(false)
  let tmuxDialogOpen = $state(false)
  let tmuxName = $state('')

  async function loadTmux() {
    const serverId = servers.currentId
    const request = ++tmuxRequest
    tmux = null
    tmuxLoading = true
    tmuxLoadError = ''
    try {
      const view = await api.getTmux()
      if (servers.currentId === serverId && request === tmuxRequest) tmux = view
    } catch (e) {
      if (servers.currentId === serverId && request === tmuxRequest) {
        tmuxLoadError = e instanceof Error ? e.message : String(e)
      }
    } finally {
      if (servers.currentId === serverId && request === tmuxRequest) tmuxLoading = false
    }
  }

  function toggleTmux() {
    tmuxOpen = !tmuxOpen
    if (tmuxOpen) void loadTmux()
  }

  async function attachTmux(s: TmuxSession) {
    tmuxOpen = false
    await startWith((renderer) =>
      session.start(renderer, { kind: 'local' }, { kind: 'tmux', session: s.id }),
    )
  }

  function openNewTmuxDialog() {
    tmuxOpen = false
    tmuxName = ''
    tmuxDialogOpen = true
  }

  /// The name is validated by the agent's shared tmux parser. A refusal comes
  /// back as an issue this page phrases.
  async function newTmuxSession() {
    const name = tmuxName.trim()
    if (name === '') return
    await startWith(async (renderer) => {
      await session.start(renderer, { kind: 'local' }, { kind: 'tmux_new', name })
      tmuxName = ''
      tmuxDialogOpen = false
    })
  }

  /// What to show for the last failure. Tmux refusals are phrased from the
  /// issue the agent sent; an unknown issue falls back to its own message.
  const errorText = $derived(
    session.errorCode === 'invalid_input' && session.issueCode
      ? (tmuxIssueText(session.issueCode) ?? session.error)
      : session.errorCode === 'no_tmux'
        ? $LL.terminalTmuxNoTmux()
        : session.error,
  )

  /// The snippet being typed, and whether the operator stopped it. One object:
  /// a stop belongs to the run in flight.
  let typing = $state<{ name: string; stopped: boolean } | null>(null)
  /// A snippet the Snippets app opened this window for, not typed yet
  /// (`lib/snippetIntent`). Closing the window abandons it.
  let queued = $state<QueuedSnippet | null>(null)
  const queuedName = $derived(queued?.name ?? '')
  useIntents((intent) => {
    if (intent.action !== TYPE_SNIPPET || intent.from !== 'snippets') return
    const snippet = queuedSnippet(intent.data)
    if (snippet) queued = snippet
  })

  $effect(() => {
    // `queued` is the trigger too, so a Run while a shell is up types at once.
    if (session.phase !== 'running' || !queued || typing) return
    untrack(() => void typeQueued())
  })

  /// Types what the snippets page queued. Taken rather than read, so nothing
  /// types it twice. The steps are the agent's (`/snippets/plan`); this sends
  /// bytes and decides nothing about what they mean.
  async function typeQueued() {
    const taken = queued
    queued = null
    if (!taken) return
    typing = { name: taken.name, stopped: false }
    const run = typing
    try {
      await runSteps(
        taken.steps,
        (text) => session.input(text),
        undefined,
        // The shell it started on is still the one on screen, and the
        // operator has not stopped it. A reconnect stops it too.
        () => !run.stopped && session.phase === 'running',
      )
    } finally {
      typing = null
    }
  }

  /// Drops a queued snippet, or stops the one being typed between steps.
  function stopTyping() {
    if (typing) typing.stopped = true
    else queued = null
  }

  /// Whether there is a card to show above the terminal.
  const alerting = $derived(
    Boolean(typing || queuedName || errorText || session.truncated || showNotice),
  )

  useMenus(() => {
    const panes = win.panes
    const items: MenuEntry[] = [
      {
        label: $LL.deskNewWindow(),
        icon: 'select_window',
        disabled: !win.canOpenWindow,
        action: () => win.openWindow(),
      },
    ]
    if (panes) {
      items.push(
        { label: $LL.deskNewTab(), icon: 'add', action: () => panes.newTab() },
        { label: $LL.deskSplitRight(), icon: 'splitscreen_right', shortcut: '⌘D', action: () => panes.split('right') },
        { label: $LL.deskSplitDown(), icon: 'splitscreen_bottom', shortcut: '⇧⌘D', action: () => panes.split('bottom') },
        { label: $LL.deskClosePane(), icon: 'close', action: () => panes.close() },
      )
    }
    items.push(
      { separator: true },
      {
        label: $LL.terminalNewSession(),
        icon: 'restart_alt',
        disabled: !fullAccess || startBusy,
        action: () => void newSession(),
      },
      {
        label: $LL.terminalDisconnect(),
        icon: 'link_off',
        disabled: session.phase !== 'running',
        action: disconnect,
      },
    )
    if (tmuxOffered) {
      items.push({ separator: true })
      items.push({
        label: $LL.terminalTmuxNew(),
        icon: 'view_column',
        disabled: !fullAccess || startBusy,
        action: openNewTmuxDialog,
      })
    }
    return [{ label: $LL.terminalMenuShell(), items }]
  })

  /// Why there is no shell here.
  const noPermissionText = $derived.by(() => {
    if (turnedOff) return whyText('not_granted', $LL)
    return caps?.grants ? whyText(access.why, $LL) : $LL.terminalUnavailable()
  })
</script>

<AppToolbar>
  {#snippet actions()}
    {#if fullAccess}
      <!-- A tab, as a terminal's + opens; a new window where there are none. -->
      {#if win.panes}
        <IconButton icon="add" label={$LL.deskNewTab()} onclick={() => win.panes?.newTab()} />
      {:else}
        <IconButton icon="add" label={$LL.deskNewWindow()} disabled={!win.canOpenWindow} onclick={() => win.openWindow()} />
      {/if}
    {/if}
    {#if fullAccess && tmuxOffered}
      <div class="relative">
        <IconButton
          icon="view_column"
          label={$LL.terminalTmuxSessions()}
          active={tmuxOpen}
          aria-expanded={tmuxOpen}
          onclick={toggleTmux}
        />
        {#if tmuxOpen}
          <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
          <div class="fixed inset-0 z-40" onclick={() => (tmuxOpen = false)}></div>
          <div
            role="menu"
            aria-label={$LL.terminalTmuxSessions()}
            class="lk-menu absolute right-0 top-full z-50 mt-2 max-h-[320px] w-[320px] max-w-[min(320px,calc(100cqw-24px))] overflow-auto"
            tabindex="-1"
            onkeydown={(e) => {
              if (e.key === 'Escape') tmuxOpen = false
            }}
          >
            {#if tmuxLoading}
              <div class="flex items-center gap-[7px] px-[9px] py-[7px] text-[13px] text-(--text-secondary)">
                <Spinner size={16} />
              </div>
            {:else if tmuxLoadError}
              <p class="px-[9px] py-[7px] text-[13px] text-(--color-danger)">{$LL.terminalTmuxListFailed()}</p>
              <p class="lk-mono break-all px-[9px] pb-[7px] text-[12px] text-(--text-tertiary)">{tmuxLoadError}</p>
            {:else if tmux?.error}
              <p class="px-[9px] py-[7px] text-[13px] text-(--color-danger)">{$LL.terminalTmuxListFailed()}</p>
              <p class="lk-mono break-all px-[9px] pb-[7px] text-[12px] text-(--text-tertiary)">{tmux.error}</p>
            {/if}
            {#if tmux && !tmux.available}
              <p class="px-[9px] py-[7px] text-[13px] text-(--text-secondary)">{$LL.terminalTmuxNoTmux()}</p>
            {:else if tmux?.available}
              {#each tmux.sessions as s (s.id)}
                <button
                  type="button"
                  role="menuitem"
                  class="lk-menu__item w-full text-left"
                  onclick={() => void attachTmux(s)}
                >
                  <span class="lk-menu__lead">
                    <span
                      class="h-[7px] w-[7px] shrink-0 rounded-full {s.attached
                        ? 'bg-(--color-success)'
                        : 'bg-(--text-tertiary)'}"
                      title={s.attached ? $LL.terminalTmuxAttached() : $LL.terminalTmuxDetached()}
                    ></span>
                  </span>
                  <span class="lk-menu__label min-w-0 truncate">{s.name}</span>
                  <span class="shrink-0 text-[12px]">{$LL.terminalTmuxWindows({ count: s.windows })}</span>
                  {#if s.activity !== null}
                    <span class="shrink-0 text-[12px] text-(--text-tertiary)">{fmtEpochSeconds(s.activity)}</span>
                  {/if}
                </button>
              {/each}
            {/if}
            {#if tmuxLoading || tmuxLoadError || tmux?.error || !tmux?.available || tmux.sessions.length}
              <div class="my-[5px] border-t border-(--border-hairline)"></div>
            {/if}
            <button
              type="button"
              role="menuitem"
              class="lk-menu__item w-full text-left"
              onclick={openNewTmuxDialog}
            >
              <span class="lk-menu__lead"><Icon name="add" size={16} /></span>
              <span class="lk-menu__label">{$LL.terminalTmuxNew()}</span>
            </button>
          </div>
        {/if}
      </div>
    {/if}
    {#if session.phase === 'running'}
      <!-- Unplug rather than a power symbol: next to a server's terminal,
           "power off" reads as an offer to shut the machine down. -->
      <IconButton icon="link_off" label={$LL.terminalDisconnect()} onclick={disconnect} />
    {/if}
  {/snippet}
</AppToolbar>

<main
  class="relative flex min-h-0 flex-1 flex-col text-(--text-primary)"
  style:background-color={fullAccess ? terminalSurface.current : 'var(--surface-window)'}
>
  {#if alerting}
    <div class="max-h-[40%] shrink-0 space-y-[7px] overflow-auto px-(--content-pad) pb-0 pt-[9px]">
      {#if typing || queuedName}
        <Card class="flex flex-wrap items-center justify-between gap-[9px]">
          <p class="text-[13px] text-(--text-primary)">
            {#if typing}
              {$LL.snippetTyping({ name: typing.name })}
            {:else}
              {$LL.snippetWaiting({ name: queuedName })}
            {/if}
          </p>
          <Button variant="secondary" onclick={stopTyping}>
            {typing ? $LL.snippetStop() : $LL.snippetDiscard()}
          </Button>
        </Card>
      {/if}

      {#if showNotice}
        <Card class="space-y-[9px]">
          <h2 class="text-[15px] font-semibold text-(--text-primary)">
            {$LL.terminalPasswordlessNoticeTitle()}
          </h2>
          <p class="text-[13px] leading-relaxed text-(--text-secondary)">
            {caps?.grants ? $LL.terminalPasswordlessNoticeBodyRoles() : $LL.terminalPasswordlessNoticeBody()}
          </p>
          <div class="flex flex-wrap gap-2">
            <Button variant="secondary" onclick={acknowledgeNotice}>
              {$LL.terminalPasswordlessKeep()}
            </Button>
            {#if canTurnOff}
              <Button variant="destructive" onclick={disablePasswordless} disabled={disabling}>
                {#if disabling}<Spinner size={16} />{/if}
                {$LL.terminalPasswordlessDisable()}
              </Button>
            {/if}
          </div>
        </Card>
      {/if}

      {#if errorText}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
          <Icon name="error" size={17} />
          <p>{errorText}</p>
        </Card>
      {/if}

      {#if session.truncated}
        <Card class="flex items-start gap-[9px] text-[13px] text-(--color-warning)">
          <Icon name="warning" size={17} />
          <p>{$LL.terminalOutputLost()}</p>
        </Card>
      {/if}
    </div>
  {/if}

  {#if fullAccess}
    <!-- Positioned against the flex item so xterm measures exactly the space
         beneath the title bar and alert strip. Its host owns the only scroll. -->
    <div class="relative min-h-0 flex-1" style:background-color={terminalSurface.current}>
      <div
        bind:this={host}
        class="absolute inset-x-[9px] inset-y-[5px] overflow-hidden"
      ></div>

      {#if (startBusy || session.phase === 'connecting' || session.phase === 'authenticating') && !errorText}
        <div class="absolute inset-0 flex items-center justify-center bg-(--surface-window)/70 backdrop-blur-[1px]">
          <Spinner size={20} />
        </div>
      {:else if session.phase === 'reconnecting'}
        <div class="absolute inset-0 flex items-center justify-center gap-[7px] bg-(--surface-window)/70 backdrop-blur-[1px]">
          <Spinner size={20} />
          <span class="text-[13px] text-(--text-primary)">{$LL.terminalReconnecting()}</span>
        </div>
      {/if}
    </div>
  {:else}
    <section class="grid min-h-0 flex-1 place-items-center bg-(--surface-window) px-(--content-pad) text-center">
      <div class="flex flex-col items-center gap-[9px]">
        <Icon name="terminal" size={52} color="var(--text-tertiary)" />
        <p class="text-[13px] text-(--text-secondary)">{noPermissionText}</p>
      </div>
    </section>
  {/if}
</main>

{#if fullAccess && session.phase === 'closed'}
  <WindowFooter>
    <StatusBar>
      <span class="truncate">{$LL.terminalEnded()}</span>
      <span class="flex-1"></span>
      <Button variant="secondary" size="sm" disabled={startBusy} onclick={() => void newSession()}>
        {$LL.terminalNewSession()}
      </Button>
    </StatusBar>
  </WindowFooter>
{/if}

{#if tmuxDialogOpen}
  <Dialog open title={$LL.terminalTmuxNew()} onclose={() => (tmuxDialogOpen = false)}>
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (tmuxDialogOpen = false)}>{$LL.cancel()}</Button>
      <Button disabled={startBusy || tmuxName.trim() === ''} onclick={() => void newTmuxSession()}>
        {#if startBusy}<Spinner size={16} />{/if}
        {$LL.terminalTmuxCreate()}
      </Button>
    {/snippet}
    <Input bind:value={tmuxName} placeholder={$LL.terminalTmuxNewName()} />
  </Dialog>
{/if}
