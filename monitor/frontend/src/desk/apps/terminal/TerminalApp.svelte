<script lang="ts">
  /// In-browser terminal.
  ///
  /// The agent connects to the local sshd on our behalf, so this asks for SSH
  /// credentials rather than reusing the panel session: a session here has the
  /// privileges of that SSH account, and the panel password alone grants none.
  ///
  /// xterm.js is loaded on demand — it is by far the heaviest thing the panel
  /// could ship, and most visits never open a terminal.

  import { onDestroy, tick, untrack } from 'svelte'
  import { SquareTerminal, Unplug } from '@lucide/svelte'
  import { Button, Card, IconButton, Input, Spinner } from '@serverbox/webui'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import { useWindow } from '../../deskState.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { isAdmin, machineAccess, terminalAccess, whyText } from '../../../lib/access'
  import { api } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { fmtEpochSeconds } from '../../../lib/format'
  import { displayName, servers } from '../../../lib/servers.svelte'
  import { snippetRun } from '../../../lib/snippetRun.svelte'
  import { runSteps } from '../../../lib/snippetSteps'
  import { theme } from '../../../lib/theme.svelte'
  import { TerminalSession, type Credential, type Renderer } from '../../../lib/terminal.svelte'
  import { terminalSurface } from '../../../lib/terminalSurface.svelte'
  import { tmuxIssueText } from '../../../lib/tmux'
  import { mountTerminal, type TerminalHandle } from '../../../lib/xterm'
  import type { TmuxSession, TmuxView } from '../../../types'

  const win = useWindow()
  // One resume handle per window: each window rejoins its own shell after a
  // reload, and two windows never trade one.
  const session = new TerminalSession({ key: win.id || undefined })

  let host = $state<HTMLDivElement | null>(null)
  let authKind = $state<'password' | 'key' | 'interactive'>('password')
  let user = $state('')
  let password = $state('')
  let pem = $state('')
  let passphrase = $state('')
  let remember = $state(false)
  let answers = $state<string[]>([])

  /// The mounted xterm, once loaded. Its renderer is what the session writes
  /// through; see `mountTerminal`.
  let terminal = $state<TerminalHandle | null>(null)
  /// Whether the surface the terminal mounts on is in the layout. False until
  /// the first mount: before that the connect form is the whole window, and
  /// the empty surface would otherwise sit under it. Once true it stays true
  /// for the window's life — what a closed session last drew remains on screen
  /// and is worth copying out of.
  let showSurface = $state(false)
  /// A start in flight. The form stays up until the session has a phase of
  /// its own (see `formShown`), rather than giving way to the surface the
  /// moment the mount begins.
  let startBusy = $state(false)

  const CREDENTIAL_KEY = 'terminal.credential'

  /// Credentials live in memory by default. "Remember" upgrades that to
  /// `sessionStorage` — gone when the tab closes — and never to
  /// `localStorage`, which would put an SSH password on disk for any later
  /// visitor or XSS to read.
  function loadRemembered(): { user: string; password: string } | null {
    try {
      const raw = window.sessionStorage.getItem(CREDENTIAL_KEY)
      return raw ? (JSON.parse(raw) as { user: string; password: string }) : null
    } catch {
      return null
    }
  }

  const remembered = loadRemembered()
  if (remembered) {
    user = remembered.user
    password = remembered.password
    remember = true
  }

  function rememberCredential() {
    try {
      if (remember && authKind === 'password') {
        window.sessionStorage.setItem(CREDENTIAL_KEY, JSON.stringify({ user, password }))
      } else {
        window.sessionStorage.removeItem(CREDENTIAL_KEY)
      }
    } catch {
      // Only costs the convenience, never correctness
    }
  }

  /// The one mount in flight. Shared, so a second press while xterm loads
  /// waits for the same terminal rather than opening another into the host.
  let mounting: Promise<TerminalHandle | null> | null = null
  /// Set when the page goes away, so a mount that finishes after it is
  /// disposed rather than kept by a page nothing shows.
  let destroyed = false

  /// The renderer, or `null` once the page has gone: the caller then has no
  /// session to start.
  async function ensureTerminal(): Promise<Renderer | null> {
    if (!terminal) {
      // The surface is rendered by `showSurface`, so putting it in the layout
      // and waiting for that render is what makes `host` exist to mount on.
      showSurface = true
      await tick()
      if (!host) throw new Error('the terminal host is not mounted')
      mounting ??= mountTerminal(host, session).then(
        (mounted) => {
          if (destroyed) {
            mounted.dispose()
            return null
          }
          terminal = mounted
          return mounted
        },
        (e: unknown) => {
          // A failed load may be retried by the next press.
          mounting = null
          throw e
        },
      )
      return (await mounting)?.renderer ?? null
    }
    return terminal.renderer
  }

  /// Runs a start with the renderer it needs. The connect form stays where it
  /// is for the whole attempt — loading xterm, opening the socket — so the
  /// window does not jump to an empty surface before there is a session to
  /// draw on it.
  async function startWith(fn: (renderer: Renderer) => Promise<void>) {
    startBusy = true
    try {
      const renderer = await ensureTerminal()
      if (!renderer) return
      await fn(renderer)
    } finally {
      startBusy = false
    }
  }

  $effect(() => {
    // Re-read on every theme change; `theme.current` is the trigger even
    // though the value comes from the document
    void theme.current
    terminal?.setTheme()
  })

  /// Typing belongs in the shell, not in the credentials form above it.
  /// `session.phase` is the only thing this reads, so it fires on the
  /// transition into `running` — a fresh open and a reattach both go through
  /// it — and never takes focus back from a field the user is in.
  $effect(() => {
    if (session.phase === 'running') terminal?.focus()
  })

  function credential(): Credential {
    switch (authKind) {
      case 'password':
        return { kind: 'password', password }
      case 'key':
        return { kind: 'key', pem, passphrase: passphrase || undefined }
      case 'interactive':
        return { kind: 'interactive' }
    }
  }

  async function connect() {
    await startWith(async (renderer) => {
      rememberCredential()
      await session.start(renderer, user, credential())
      // Held only as long as the form needed it
      password = ''
      pem = ''
      passphrase = ''
    })
  }

  /// Rejoins the session a previous connection left behind, without asking for
  /// credentials again — the agent still has an authenticated shell.
  async function resume() {
    await startWith((renderer) => session.start(renderer, user, null))
  }

  function submitAnswers() {
    session.answer(answers)
    answers = []
  }

  function disconnect() {
    session.close()
  }

  /// A device coming back from sleep or a dead network should reconnect at
  /// once rather than wait out a backoff scheduled before it went away.
  function wake() {
    if (document.visibilityState === 'visible') session.reconnectNow()
  }

  $effect(() => {
    window.addEventListener('online', wake)
    document.addEventListener('visibilitychange', wake)
    // The last chance to record the resume point exactly
    window.addEventListener('pagehide', () => session.flush())
    return () => {
      window.removeEventListener('online', wake)
      document.removeEventListener('visibilitychange', wake)
    }
  })

  onDestroy(() => {
    destroyed = true
    // Leaving the terminal abandons a snippet not yet typed: the Run press
    // opened this page for it, so closing the page is the answer.
    snippetRun.clear(win.id)
    session.dispose()
    terminal?.dispose()
  })

  const busy = $derived(
    session.phase === 'connecting' || session.phase === 'authenticating',
  )
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// Which terminals this account can open here — see `terminalAccess`.
  const access = $derived(terminalAccess(caps))

  /// The dashboard only offers the entry point when the agent reports the
  /// terminal available, but a cached capability or a stale tab can still land
  /// here — better to explain why than to present a form that can't connect.
  const available = $derived(access.available)

  /// Whether the connect form is what the window shows: no terminal to offer
  /// here, or no session and none being started. False while one is in flight,
  /// so pressing Connect swaps the form for the terminal in one step.
  const formShown = $derived(
    !available ||
      ((session.phase === 'idle' || session.phase === 'closed') && !startBusy),
  )

  /// Whether this agent takes a tmux target: it lists the feature and the
  /// account holds `shell`. The rail's "Open directly" card is where that is
  /// offered, and the sessions join it.
  const tmuxOffered = $derived(machineAccess(caps, 'tmux', 'shell'))
  /// The sessions, once read. Null where the agent does not offer them, or
  /// where the listing could not be read — an empty block says less than none.
  let tmux = $state<TmuxView | null>(null)
  /// The name a new session is created with.
  let tmuxName = $state('')

  $effect(() => {
    if (!tmuxOffered) {
      tmux = null
      return
    }
    const serverId = servers.currentId
    // Cleared rather than left showing the previous machine's sessions while
    // this one's are read.
    tmux = null
    void api.getTmux().then(
      (view) => {
        if (servers.currentId === serverId) tmux = view
      },
      () => {
        if (servers.currentId === serverId) tmux = null
      },
    )
  })

  /// Attaches to a session that already exists. It is the page's own session
  /// store, so a reconnect rejoins the same tmux client.
  async function attachTmux(s: TmuxSession) {
    await startWith((renderer) =>
      session.start(renderer, '', { kind: 'local' }, { kind: 'tmux', session: s.id }),
    )
  }

  /// Attaches to `tmuxName`, creating it when it does not exist. Sent rather
  /// than checked here: the rules are `sbm_parser::tmux`'s, and a refusal comes
  /// back as an issue this page phrases.
  async function newTmuxSession() {
    const name = tmuxName.trim()
    if (name === '') return
    await startWith(async (renderer) => {
      await session.start(renderer, '', { kind: 'local' }, { kind: 'tmux_new', name })
      tmuxName = ''
    })
  }

  /// What to show for the last failure. A tmux refusal is phrased from the
  /// issue the agent sent — an issue code this build does not know falls back
  /// to the agent's own message, which is better than showing the code —
  /// and `no_tmux` likewise, since the machine's own message names a remedy
  /// the operator has, not the reader.
  const errorText = $derived(
    session.errorCode === 'invalid_input' && session.issueCode
      ? (tmuxIssueText(session.issueCode) ?? session.error)
      : session.errorCode === 'no_tmux'
        ? $LL.terminalTmuxNoTmux()
        : session.error,
  )

  /// Set once this session has turned it off, so the UI updates before the
  /// capabilities cache is refetched. The agent's answer stays the source of
  /// truth — the panel can narrow it, never widen it.
  let turnedOff = $state(false)
  const fullAccess = $derived(!turnedOff && access.direct)
  /// Turning it off is an administrator's request: with roles it takes the
  /// shell away from every role, not just this session's.
  const canTurnOff = $derived(isAdmin(caps) !== false)

  /// Shown the first time access without SSH is on offer, once per
  /// browser: it changes what the panel password is worth, and silently
  /// handing out a shell would be the wrong kind of convenient.
  const NOTICE_KEY = 'terminal.fullAccessNoticeSeen'
  let noticeDismissed = $state(window.localStorage.getItem(NOTICE_KEY) === '1')
  const showNotice = $derived(fullAccess && !noticeDismissed)
  let disabling = $state(false)

  function acknowledgeNotice() {
    try {
      window.localStorage.setItem(NOTICE_KEY, '1')
    } catch {
      // Only costs seeing the notice again
    }
    noticeDismissed = true
  }

  async function disablePasswordless() {
    disabling = true
    try {
      await api.disablePasswordlessTerminal()
      turnedOff = true
      capabilitiesStore.clear(servers.currentId)
      acknowledgeNotice()
    } catch (e) {
      session.error = e instanceof Error ? e.message : String(e)
    } finally {
      disabling = false
    }
  }

  /// Opens a shell with no credentials at all.
  async function openPasswordless() {
    await startWith((renderer) => session.start(renderer, '', { kind: 'local' }))
  }

  /// The snippet being typed, and whether the operator stopped it. One object:
  /// a stop belongs to the run in flight.
  let typing = $state<{ name: string; stopped: boolean } | null>(null)
  /// A snippet whose Run press landed here before there was a shell.
  const queuedName = $derived(snippetRun.for(win.id)?.name ?? '')

  $effect(() => {
    // `waiting` is the trigger too, so a Run while a shell is up types at once.
    const queued = snippetRun.for(win.id)
    if (session.phase !== 'running' || !queued || typing) return
    untrack(() => void typeQueued())
  })

  /// Types what the snippets page queued. Taken rather than read, so nothing
  /// types it twice. The steps are the agent's (`/snippets/plan`); this sends
  /// bytes and decides nothing about what they mean.
  async function typeQueued() {
    const taken = snippetRun.take(win.id)
    if (!taken) return
    typing = { name: taken.name, stopped: false }
    const run = typing
    try {
      await runSteps(
        taken.steps,
        (text) => session.input(text),
        undefined,
        // The shell it started on is still the one on screen, and the
        // operator has not stopped it. A reconnect stops it too: the rest of
        // a script waiting on `${sleep}` was not written for an outage.
        () => !run.stopped && session.phase === 'running',
      )
    } finally {
      typing = null
    }
  }

  /// Drops a queued snippet, or stops the one being typed — between steps, so
  /// a keystroke in flight lands and the next does not.
  function stopTyping() {
    if (typing) typing.stopped = true
    else snippetRun.clear(win.id)
  }

  /// Whether there is a card to show above the terminal. One flag, so the
  /// strip they live in is not a band of empty padding when there is none.
  const alerting = $derived(
    Boolean(typing || queuedName || errorText || session.truncated) ||
      session.phase === 'prompting',
  )
</script>

<AppToolbar>
  {#snippet actions()}
    <!-- Unplug rather than a power symbol: next to a server's terminal,
         "power off" reads as an offer to shut the machine down -->
    {#if session.phase === 'running'}
      <IconButton label={$LL.terminalDisconnect()} onclick={disconnect}>
        <Unplug class="w-4 h-4" />
      </IconButton>
    {/if}
  {/snippet}
</AppToolbar>

<!-- One choice of the authentication segmented control. -->
{#snippet authTab(kind: 'password' | 'key' | 'interactive', label: string)}
  <button
    type="button"
    class="cursor-pointer rounded-md px-3 py-1 text-xs font-medium transition-colors {authKind ===
    kind
      ? 'bg-[var(--desk-accent)] text-[var(--desk-accent-fg)]'
      : 'text-muted-fg hover:text-fg'}"
    aria-pressed={authKind === kind}
    onclick={() => (authKind = kind)}
  >
    {label}
  </button>
{/snippet}

<!-- The window's body. The connect form is a centred card until there is a
     session; from there the terminal takes everything the toolbar leaves,
     edge to edge. `flex-1` in the window body's column: the toolbar is a
     sibling in flow, so a full-height main would run past the window's
     bottom edge. -->
<main
  class="relative flex min-h-0 flex-1 flex-col bg-bg text-fg"
  style:background-color={showSurface && !formShown ? terminalSurface.current : undefined}
>
  <!-- Said, because keystrokes that arrive unasked would otherwise look like a
       fault. Above the terminal rather than over it: a banner that covered
       output would hide what it is telling you about. -->
  {#if alerting}
    <div class="shrink-0 space-y-2 p-3 pb-0 @3xl:p-4 @3xl:pb-0">
      {#if typing || queuedName}
        <Card class="flex flex-wrap items-center justify-between gap-3">
          <p class="text-sm text-fg">
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

      {#if session.phase === 'prompting'}
        <Card class="space-y-3">
          {#if session.instructions}
            <p class="text-sm text-muted-fg">{session.instructions}</p>
          {/if}
          {#each session.prompts as prompt, i (i)}
            <div class="space-y-1">
              <span class="text-sm text-muted-fg">{prompt.prompt}</span>
              <Input bind:value={answers[i]} type={prompt.echo ? 'text' : 'password'} />
            </div>
          {/each}
          <Button onclick={submitAnswers}>{$LL.terminalSubmit()}</Button>
        </Card>
      {/if}

      {#if errorText}
        <Card class="border-danger/40 bg-danger/5">
          <p class="text-sm text-danger">{errorText}</p>
        </Card>
      {/if}

      {#if session.truncated}
        <Card class="border-warning/40 bg-warning/5">
          <p class="text-sm text-muted-fg">{$LL.terminalOutputLost()}</p>
        </Card>
      {/if}
    </div>
  {/if}

  {#if formShown}
    <!-- Centred in what the window has: the surface below takes the rest once
         there is one, so a session's last screen stays on show. -->
    <div class="min-h-0 overflow-auto {showSurface ? 'max-h-[55%] shrink-0' : 'flex-1'}">
      <div class="flex min-h-full justify-center p-3 @3xl:p-6">
        <div class="my-auto w-full max-w-xl space-y-3">
          {#if !showSurface}
            <div class="flex items-center gap-3 px-1 pb-1">
              <span class="grid h-10 w-10 shrink-0 place-items-center rounded-xl border border-line bg-surface shadow-xs">
                <SquareTerminal class="h-5 w-5 text-[var(--desk-accent)]" />
              </span>
              <div class="min-w-0">
                <h1 class="font-display text-base font-semibold text-fg-strong">{$LL.terminal()}</h1>
                <p class="truncate text-xs text-muted-fg">{servers.current ? displayName(servers.current) : servers.currentId}</p>
              </div>
            </div>
          {/if}
          {#if !available}
            <Card>
              <!-- With roles the agent says why; before them, the one reason
                   there was is the config switch. -->
              <p class="text-sm text-muted-fg">
                {caps?.grants ? whyText(access.why, $LL) : $LL.terminalUnavailable()}
              </p>
            </Card>
          {:else}
            {#if showNotice}
              <Card class="space-y-3 border-warning/40 bg-warning/5">
                <h2 class="text-[0.95rem] font-semibold font-display text-fg-strong">
                  {$LL.terminalPasswordlessNoticeTitle()}
                </h2>
                <p class="text-[0.8rem] leading-relaxed text-muted-fg">
                  {caps?.grants ? $LL.terminalPasswordlessNoticeBodyRoles() : $LL.terminalPasswordlessNoticeBody()}
                </p>
                <div class="flex flex-wrap gap-2">
                  <Button variant="secondary" onclick={acknowledgeNotice}>
                    {$LL.terminalPasswordlessKeep()}
                  </Button>
                  {#if canTurnOff}
                    <Button variant="danger" onclick={disablePasswordless} disabled={disabling}>
                      {#if disabling}<Spinner class="w-4 h-4" />{/if}
                      {$LL.terminalPasswordlessDisable()}
                    </Button>
                  {/if}
                </div>
              </Card>
            {/if}

            {#if fullAccess}
              <Card class="space-y-3">
                <p class="text-[0.8rem] leading-relaxed text-muted-fg">
                  {$LL.terminalPasswordlessHint()}
                </p>
                <Button onclick={openPasswordless} disabled={busy}>
                  {#if busy}<Spinner class="w-4 h-4" />{/if}
                  {$LL.terminalOpenDirectly()}
                </Button>

                {#if tmux?.available}
                  <div class="space-y-2 border-t border-line pt-3">
                    <p class="text-xs font-semibold tracking-wide text-muted-fg uppercase">
                      {$LL.terminalTmuxSessions()}
                    </p>
                    {#if tmux.error}
                      <!-- The listing failed: said, because an empty list would
                           read as this machine having no sessions. -->
                      <p class="text-sm text-danger">{$LL.terminalTmuxListFailed()}</p>
                      <p class="text-xs text-muted-fg break-all">{tmux.error}</p>
                    {/if}
                    {#each tmux.sessions as s (s.id)}
                      <div
                        class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-xl border border-line bg-soft/50 px-3 py-2"
                      >
                        <!-- A dot, like every other status in the panel: filled
                             while the session has a client attached. -->
                        <span
                          class="h-1.5 w-1.5 shrink-0 rounded-full {s.attached
                            ? 'bg-success'
                            : 'bg-faint-fg'}"
                          title={s.attached ? $LL.terminalTmuxAttached() : $LL.terminalTmuxDetached()}
                        ></span>
                        <span class="min-w-0 flex-1 truncate text-sm font-medium text-fg-strong">
                          {s.name}
                        </span>
                        <span class="text-xs text-muted-fg">
                          {$LL.terminalTmuxWindows({ count: s.windows })}
                        </span>
                        <!-- Epoch seconds from tmux, in the viewer's locale;
                             nothing when tmux had no value for it. -->
                        {#if s.activity !== null}
                          <span class="text-xs text-faint-fg">{fmtEpochSeconds(s.activity)}</span>
                        {/if}
                        <Button size="sm" variant="secondary" onclick={() => attachTmux(s)}>
                          {$LL.terminalTmuxAttach()}
                        </Button>
                      </div>
                    {/each}

                    <div class="flex items-center gap-2">
                      <div class="flex-1">
                        <Input bind:value={tmuxName} placeholder={$LL.terminalTmuxNewName()} />
                      </div>
                      <Button onclick={newTmuxSession} disabled={busy || tmuxName.trim() === ''}>
                        {$LL.terminalTmuxCreate()}
                      </Button>
                    </div>
                  </div>
                {/if}
              </Card>
            {/if}

            {#if access.ssh}
              <Card class="space-y-4">
                <p class="text-[0.8rem] leading-relaxed text-muted-fg">
                  {$LL.terminalCredentialsHint()}
                </p>

                <div class="space-y-1.5">
                  <span class="block text-xs font-semibold tracking-wide text-muted-fg uppercase">
                    {$LL.terminalAuthMethod()}
                  </span>
                  <!-- A segmented control, the panel's shape for two or three
                       exclusive choices; the accent marks the one in force. -->
                  <div class="flex w-fit rounded-lg border border-line bg-soft p-0.5">
                    {@render authTab('password', $LL.password())}
                    {@render authTab('key', $LL.terminalPrivateKey())}
                    {@render authTab('interactive', $LL.terminalInteractive())}
                  </div>
                </div>

                <div class="space-y-1.5">
                  <span class="block text-xs font-semibold tracking-wide text-muted-fg uppercase">
                    {$LL.terminalSshUser()}
                  </span>
                  <Input bind:value={user} placeholder="root" autocomplete="username" />
                </div>

                {#if authKind === 'password'}
                  <div class="space-y-1.5">
                    <span class="block text-xs font-semibold tracking-wide text-muted-fg uppercase">
                      {$LL.password()}
                    </span>
                    <Input bind:value={password} type="password" autocomplete="current-password" />
                  </div>
                  <label class="flex items-center gap-2 text-sm text-muted-fg">
                    <input type="checkbox" bind:checked={remember} />
                    {$LL.terminalRememberForTab()}
                  </label>
                {:else if authKind === 'key'}
                  <label class="block space-y-1.5">
                    <span class="block text-xs font-semibold tracking-wide text-muted-fg uppercase">
                      {$LL.terminalPrivateKey()}
                    </span>
                    <textarea
                      bind:value={pem}
                      rows="6"
                      spellcheck="false"
                      class="w-full rounded-lg border border-line bg-surface px-3 py-2 font-mono text-xs text-fg"
                      placeholder="-----BEGIN OPENSSH PRIVATE KEY-----"
                    ></textarea>
                  </label>
                  <div class="space-y-1.5">
                    <span class="block text-xs font-semibold tracking-wide text-muted-fg uppercase">
                      {$LL.terminalPassphrase()}
                    </span>
                    <Input bind:value={passphrase} type="password" />
                  </div>
                {:else}
                  <p class="text-sm text-muted-fg">{$LL.terminalInteractiveHint()}</p>
                {/if}

                <div class="flex items-center gap-2">
                  <Button onclick={connect} disabled={busy || !user}>
                    {#if busy}<Spinner class="w-4 h-4" />{/if}
                    {$LL.terminalConnect()}
                  </Button>
                  {#if session.resumable}
                    <Button variant="ghost" onclick={resume}>{$LL.terminalResume()}</Button>
                  {/if}
                </div>
              </Card>
            {/if}
          {/if}
        </div>
      </div>
    </div>
  {/if}

  {#if showSurface}
    <!-- Positioned rather than `h-full`: a percentage height against a flex
         item is only definite because browsers special-case it, and xterm
         sizes itself from what it measures here. `inset-0` against the
         positioned parent is unambiguous.
         Kept mounted across reconnects: what is on screen is still the last
         thing the user saw, and may be worth copying out of -->
    <div class="relative min-h-0 flex-1">
      <!-- The terminal's own background: the rows are whole cells, so the
           strip left below the last one is filled with this rather than with
           a colour of its own, like the target dialogs'. -->
      <div
        bind:this={host}
        class="absolute inset-0 overflow-hidden"
        style="background-color: {terminalSurface.current}"
      ></div>

      {#if session.phase === 'reconnecting'}
        <div
          class="absolute inset-0 flex items-center justify-center gap-2 bg-bg/70 backdrop-blur-[1px]"
        >
          <Spinner class="w-5 h-5" />
          <span class="text-sm text-fg-strong">{$LL.terminalReconnecting()}</span>
        </div>
      {/if}
    </div>
  {/if}
</main>
