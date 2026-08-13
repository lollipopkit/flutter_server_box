<script lang="ts">
  /// In-browser terminal.
  ///
  /// The agent connects to the local sshd on our behalf, so this asks for SSH
  /// credentials rather than reusing the panel session: a session here has the
  /// privileges of that SSH account, and the panel password alone grants none.
  ///
  /// xterm.js is loaded on demand — it is by far the heaviest thing the panel
  /// could ship, and most visits never open a terminal.

  import { onDestroy } from 'svelte'
  import { Unplug } from '@lucide/svelte'
  import { Button, Card, IconButton, Input, Spinner } from '@serverbox/webui'
  import PageHeader from '../components/PageHeader.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { api } from '../lib/api'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { layout } from '../lib/layout.svelte'
  import { servers } from '../lib/servers.svelte'
  import { theme } from '../lib/theme.svelte'
  import { TerminalSession, type Credential, type Renderer } from '../lib/terminal.svelte'

  const session = new TerminalSession()

  let host = $state<HTMLDivElement | null>(null)
  let authKind = $state<'password' | 'key' | 'interactive'>('password')
  let user = $state('')
  let password = $state('')
  let pem = $state('')
  let passphrase = $state('')
  let remember = $state(false)
  let answers = $state<string[]>([])

  /// The xterm instance and its fit addon, once loaded.
  let term: import('@xterm/xterm').Terminal | null = null
  let fit: import('@xterm/addon-fit').FitAddon | null = null
  let decoder: TextDecoder | null = null
  let resizeObserver: ResizeObserver | null = null

  const CREDENTIAL_KEY = 'terminal.credential'

  /// Waits for the browser to have laid out. `requestAnimationFrame` runs
  /// after style and layout for the coming frame, which is the earliest point
  /// a flex-derived height can be measured.
  const nextFrame = () =>
    new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))

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

  async function ensureTerminal(): Promise<Renderer> {
    if (!term) {
      // The stylesheet comes along in the same dynamic chunk, so it is
      // fetched with the terminal rather than on every panel load
      const [{ Terminal }, { FitAddon }] = await Promise.all([
        import('@xterm/xterm'),
        import('@xterm/addon-fit'),
        import('@xterm/xterm/css/xterm.css'),
      ])
      term = new Terminal({
        convertEol: false,
        cursorBlink: true,
        fontSize: 13,
        fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
        theme: terminalTheme(),
      })
      fit = new FitAddon()
      term.loadAddon(fit)
      if (host) term.open(host)
      decoder = new TextDecoder()

      term.onData((data) => session.input(data))
      term.onResize(({ cols, rows }) => session.resize(cols, rows))

      if (host && typeof ResizeObserver !== 'undefined') {
        resizeObserver = new ResizeObserver(() => fit?.fit())
        resizeObserver.observe(host)
      }

      // Fitted a frame later, not inline with open(): the host's height comes
      // from flex sizing, which the browser has not resolved yet in this tick.
      // Measuring now would see zero and leave the terminal at its default 24
      // rows — the size then sent to the shell as well, so it would not just
      // look wrong, it would wrap wrong.
      await nextFrame()
      fit.fit()
    }

    const instance = term
    const streamDecoder = decoder
    return {
      write(data, done) {
        // Decoded with `stream: true` so a multi-byte character split across
        // two frames isn't rendered as replacement characters
        instance.write(streamDecoder?.decode(data, { stream: true }) ?? '', done)
      },
      reset() {
        instance.reset()
      },
      get cols() {
        return instance.cols
      },
      get rows() {
        return instance.rows
      },
    }
  }

  /// Resolved from the document, not from `theme.current`: the store's
  /// 'system' setting is decided by a media query at paint time, so the class
  /// on <html> is the only place the answer actually exists.
  function isDark(): boolean {
    const cls = document.documentElement.classList
    if (cls.contains('dark')) return true
    if (cls.contains('light')) return false
    return window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false
  }

  function terminalTheme() {
    return isDark()
      ? { background: '#0b0f14', foreground: '#d7dce2', cursor: '#d7dce2' }
      : { background: '#ffffff', foreground: '#1f2933', cursor: '#1f2933' }
  }

  $effect(() => {
    // Re-read on every theme change; `theme.current` is the trigger even
    // though the value comes from the document
    void theme.current
    if (term) term.options.theme = terminalTheme()
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
    const renderer = await ensureTerminal()
    rememberCredential()
    await session.start(renderer, user, credential())
    // Held only as long as the form needed it
    password = ''
    pem = ''
    passphrase = ''
  }

  /// Rejoins the session a previous connection left behind, without asking for
  /// credentials again — the agent still has an authenticated shell.
  async function resume() {
    const renderer = await ensureTerminal()
    await session.start(renderer, user, null)
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
    resizeObserver?.disconnect()
    session.dispose()
    term?.dispose()
  })

  const busy = $derived(
    session.phase === 'connecting' || session.phase === 'authenticating',
  )
  const showForm = $derived(session.phase === 'idle' || session.phase === 'closed')

  /// The dashboard only offers the entry point when the agent reports the
  /// terminal available, but a cached capability or a stale tab can still land
  /// here — better to explain why than to present a form that can't connect.
  const available = $derived(
    capabilitiesStore.byServer[servers.currentId]?.remote_access?.terminal !== false,
  )

  /// Set once this session has turned it off, so the UI updates before the
  /// capabilities cache is refetched. The agent's answer stays the source of
  /// truth — the panel can narrow it, never widen it.
  let turnedOff = $state(false)
  const fullAccess = $derived(
    !turnedOff &&
      capabilitiesStore.byServer[servers.currentId]?.remote_access?.full_access === true,
  )

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
    const renderer = await ensureTerminal()
    await session.start(renderer, '', { kind: 'local' })
  }
</script>

<PageHeader
  title={$LL.terminal()}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  onback={() => layout.back('dashboard')}
>
  {#snippet actions()}
    <!-- In the header rather than under the terminal: the terminal fills the
         viewport, so a button below it is off-screen exactly when a session
         is running and someone wants to end it -->
    {#if session.phase === 'running'}
      <!-- Unplug rather than a power symbol: next to a server's terminal,
           "power off" reads as an offer to shut the machine down -->
      <IconButton label={$LL.terminalDisconnect()} onclick={disconnect}>
        <Unplug class="w-4 h-4" />
      </IconButton>
    {/if}
  {/snippet}
</PageHeader>

<!-- A column that fills what the sticky 4rem header leaves, so the terminal
     can take the remainder rather than a fixed slice of the viewport -->
<main
  class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-4 flex flex-col min-h-[calc(100vh-4rem)]"
>
  {#if !available}
    <Card>
      <p class="text-sm text-muted-fg">{$LL.terminalUnavailable()}</p>
    </Card>
  {:else if showForm}
    {#if showNotice}
      <Card class="space-y-3 border-warning/40 bg-warning/5">
        <h2 class="text-base font-semibold font-display text-fg-strong">
          {$LL.terminalPasswordlessNoticeTitle()}
        </h2>
        <p class="text-sm text-muted-fg">{$LL.terminalPasswordlessNoticeBody()}</p>
        <div class="flex flex-wrap gap-2">
          <Button variant="secondary" onclick={acknowledgeNotice}>
            {$LL.terminalPasswordlessKeep()}
          </Button>
          <Button variant="danger" onclick={disablePasswordless} disabled={disabling}>
            {#if disabling}<Spinner class="w-4 h-4" />{/if}
            {$LL.terminalPasswordlessDisable()}
          </Button>
        </div>
      </Card>
    {/if}

    {#if fullAccess}
      <Card class="space-y-3">
        <p class="text-sm text-muted-fg">{$LL.terminalPasswordlessHint()}</p>
        <Button onclick={openPasswordless} disabled={busy}>
          {#if busy}<Spinner class="w-4 h-4" />{/if}
          {$LL.terminalOpenDirectly()}
        </Button>
      </Card>
    {/if}

    <Card class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.terminalCredentialsHint()}</p>

      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.terminalAuthMethod()}</span>
        <div class="flex gap-2">
          <Button
            variant={authKind === 'password' ? 'primary' : 'ghost'}
            size="sm"
            onclick={() => (authKind = 'password')}>{$LL.password()}</Button
          >
          <Button
            variant={authKind === 'key' ? 'primary' : 'ghost'}
            size="sm"
            onclick={() => (authKind = 'key')}>{$LL.terminalPrivateKey()}</Button
          >
          <Button
            variant={authKind === 'interactive' ? 'primary' : 'ghost'}
            size="sm"
            onclick={() => (authKind = 'interactive')}>{$LL.terminalInteractive()}</Button
          >
        </div>
      </div>

      <div class="space-y-1">
        <span class="text-sm text-muted-fg">{$LL.terminalSshUser()}</span>
        <Input bind:value={user} placeholder="root" autocomplete="username" />
      </div>

      {#if authKind === 'password'}
        <div class="space-y-1">
          <span class="text-sm text-muted-fg">{$LL.password()}</span>
          <Input bind:value={password} type="password" autocomplete="current-password" />
        </div>
        <label class="flex items-center gap-2 text-sm text-muted-fg">
          <input type="checkbox" bind:checked={remember} />
          {$LL.terminalRememberForTab()}
        </label>
      {:else if authKind === 'key'}
        <label class="block space-y-1">
          <span class="text-sm text-muted-fg">{$LL.terminalPrivateKey()}</span>
          <textarea
            bind:value={pem}
            rows="6"
            spellcheck="false"
            class="w-full rounded-md border border-border bg-bg px-3 py-2 font-mono text-xs"
            placeholder="-----BEGIN OPENSSH PRIVATE KEY-----"
          ></textarea>
        </label>
        <div class="space-y-1">
          <span class="text-sm text-muted-fg">{$LL.terminalPassphrase()}</span>
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

  {#if session.error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{session.error}</p>
    </Card>
  {/if}

  {#if session.truncated}
    <Card class="border-warning/40 bg-warning/5">
      <p class="text-sm text-muted-fg">{$LL.terminalOutputLost()}</p>
    </Card>
  {/if}

  <!-- Takes whatever the cards above leave, down to a floor that keeps the
       terminal usable on a short window -->
  <div class="relative flex-1 min-h-[16rem]">
    <!-- Positioned rather than `h-full`: a percentage height against a flex
         item is only definite because browsers special-case it, and xterm
         sizes itself from what it measures here. `inset-0` against the
         positioned parent is unambiguous.
         Kept mounted across reconnects: what is on screen is still the last
         thing the user saw, and may be worth copying out of -->
    <div bind:this={host} class="absolute inset-0 rounded-md overflow-hidden bg-black/90"></div>

    {#if session.phase === 'reconnecting'}
      <div
        class="absolute inset-0 flex items-center justify-center gap-2 bg-bg/70 backdrop-blur-[1px]"
      >
        <Spinner class="w-5 h-5" />
        <span class="text-sm text-fg-strong">{$LL.terminalReconnecting()}</span>
      </div>
    {/if}
  </div>
</main>
