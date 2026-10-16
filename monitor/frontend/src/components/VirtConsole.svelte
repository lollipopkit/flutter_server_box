<script lang="ts">
  import { Button, Card, Input, Spinner } from '@serverbox/webui'
  import VncViewer from './VncViewer.svelte'
  import { api } from '../lib/api'
  import { RelayChannel, parseControl } from '../lib/desktop.svelte'
  import { theme } from '../lib/theme.svelte'
  import { terminalTheme } from '../lib/xterm'
  import { openConsoleSocket, resizeMessage } from '../lib/virtConsole'
  import { virtErrorText } from '../lib/virt'
  import { onDestroy } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { VirtConsoleKind, VirtGuest } from '../types'

  /// One guest's console, VNC or text, opened when asked and closed with the
  /// view. Everything about where it goes is the agent's; this holds the
  /// socket and draws it.
  interface Props {
    guest: VirtGuest
    kind: VirtConsoleKind
    /// The sudo password a libvirt host was read with, if any.
    sudoPassword: string | null
  }

  const { guest, kind, sudoPassword }: Props = $props()

  let phase = $state<'idle' | 'opening' | 'open' | 'failed'>('idle')
  let error = $state('')
  let channel = $state<RelayChannel | null>(null)
  let vncPassword = $state('')
  let passwordKnown = $state(true)
  let typedPassword = $state('')
  let command = $state<string | null>(null)
  let socket: WebSocket | null = null
  let host = $state<HTMLDivElement | null>(null)
  let term: import('@xterm/xterm').Terminal | null = null
  let resizeObserver: ResizeObserver | null = null
  /// Bumped by every close, so an open still awaiting the agent, the socket or
  /// the xterm import sees it was overtaken and installs nothing.
  let generation = 0

  onDestroy(() => close())

  $effect(() => {
    // `theme.current` is the trigger; the colours are read from the document
    void theme.current
    if (term) term.options.theme = terminalTheme()
  })

  function close() {
    generation++
    resizeObserver?.disconnect()
    resizeObserver = null
    term?.dispose()
    term = null
    if (socket && socket.readyState !== WebSocket.CLOSED) socket.close()
    socket = null
    channel = null
  }

  async function open() {
    close()
    const gen = generation
    phase = 'opening'
    error = ''
    command = null
    try {
      const answer = await api.virtConsole(guest.id, kind, sudoPassword ?? undefined)
      if (gen !== generation) return
      if (answer.error) throw new Error(virtErrorText(answer.error))
      if (answer.command) {
        command = answer.command
        phase = 'idle'
        return
      }
      if (!answer.ticket) throw new Error($LL.virtConsoleFailed())
      vncPassword = answer.vnc_password ?? typedPassword
      passwordKnown = answer.password_known
      const opened = await openConsoleSocket(answer.ticket)
      if (gen !== generation) {
        opened.close()
        return
      }
      socket = opened
      if (kind === 'vnc') {
        channel = new RelayChannel(opened)
        phase = 'open'
      } else {
        phase = 'open'
        await attachTerminal(opened, gen)
      }
    } catch (e) {
      if (gen !== generation) return
      phase = 'failed'
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function attachTerminal(ws: WebSocket, gen: number) {
    const [{ Terminal }, { FitAddon }] = await Promise.all([
      import('@xterm/xterm'),
      import('@xterm/addon-fit'),
      import('@xterm/xterm/css/xterm.css'),
    ])
    // close() already closed the socket this was for
    if (gen !== generation) return
    term = new Terminal({
      cursorBlink: true,
      // As in lib/xterm.ts: whether a screen reader runs cannot be known.
      screenReaderMode: true,
      fontSize: 13,
      fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
      theme: terminalTheme(),
    })
    const fit = new FitAddon()
    term.loadAddon(fit)
    if (host) term.open(host)
    const encoder = new TextEncoder()
    const decoder = new TextDecoder()
    term.onData((data) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(encoder.encode(data))
    })
    term.onResize(({ cols, rows }) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(resizeMessage(cols, rows))
    })
    ws.onmessage = (event) => {
      if (typeof event.data === 'string') {
        const control = parseControl(event.data)
        if (control?.type === 'error') error = control.message || control.code
        return
      }
      term?.write(decoder.decode(new Uint8Array(event.data as ArrayBuffer), { stream: true }))
    }
    ws.onclose = () => {
      if (gen === generation && phase === 'open') {
        phase = 'failed'
        if (!error) error = $LL.virtConsoleEnded()
      }
    }
    if (host && typeof ResizeObserver !== 'undefined') {
      resizeObserver = new ResizeObserver(() => fit.fit())
      resizeObserver.observe(host)
    }
    const opened = term
    await new Promise((r) => requestAnimationFrame(r))
    if (gen !== generation) return
    fit.fit()
    ws.send(resizeMessage(opened.cols, opened.rows))
    opened.focus()
  }

  /// The console is over, by the Close button or because the viewer ended:
  /// its socket and terminal go with it.
  function ended(message: string | null) {
    close()
    phase = message ? 'failed' : 'idle'
    error = message ?? ''
  }
</script>

<Card class="space-y-3">
  <div class="flex flex-wrap items-center justify-between gap-2">
    <p class="text-sm text-fg-strong">{kind === 'vnc' ? $LL.virtConsoleVnc() : $LL.virtConsoleText()}</p>
    <div class="flex items-center gap-2">
      {#if phase === 'opening'}
        <Spinner size="sm" />
      {/if}
      {#if phase === 'open'}
        <Button variant="secondary" size="sm" onclick={() => ended(null)}>{$LL.virtConsoleClose()}</Button>
      {:else}
        <Button size="sm" disabled={phase === 'opening'} onclick={() => void open()}>{$LL.virtConsoleOpen()}</Button>
      {/if}
    </div>
  </div>

  {#if kind === 'vnc' && !passwordKnown && phase !== 'open'}
    <div class="flex flex-wrap items-center gap-2">
      <Input class="w-56" type="password" autocomplete="off" bind:value={typedPassword} placeholder={$LL.virtConsolePassword()} />
      <p class="text-xs text-muted-fg">{$LL.virtConsolePasswordHint()}</p>
    </div>
  {/if}

  {#if error}
    <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
  {/if}

  {#if command}
    <p class="text-xs text-muted-fg">{$LL.virtConsoleCommand()}</p>
    <pre class="overflow-x-auto rounded-lg bg-muted p-2 font-mono text-xs text-fg">{sudoPassword ? `sudo ${command}` : command}</pre>
  {/if}

  {#if kind === 'vnc' && channel}
    <div class="aspect-video w-full overflow-hidden rounded-lg bg-black">
      <VncViewer {channel} username={null} password={vncPassword} viewOnly={false} shared={true} onend={ended} />
    </div>
  {:else if kind === 'text'}
    <div class="h-96 w-full overflow-hidden rounded-lg {phase === 'open' ? '' : 'hidden'}" bind:this={host}></div>
  {/if}
</Card>
