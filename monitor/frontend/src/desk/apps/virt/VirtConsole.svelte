<script lang="ts">
  import { Button, Card, Input, Spinner } from '../../lk'
  import VncViewer from '../../../components/VncViewer.svelte'
  import { api } from '../../../lib/api'
  import { RelayChannel, parseControl } from '../../../lib/desktop.svelte'
  import { theme } from '../../../lib/theme.svelte'
  import { terminalTheme } from '../../../lib/xterm'
  import { openConsoleSocket, resizeMessage } from '../../../lib/virtConsole'
  import { virtErrorText } from '../../../lib/virt'
  import { onDestroy } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { VirtConsoleKind, VirtGuest } from '../../../types'

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
  let term: import('@xterm/xterm').Terminal | null = $state.raw(null)

  $effect(() => {
    // The desk's mode or theme changed: the console follows, as Terminal does.
    void theme.revision
    if (term) term.options.theme = terminalTheme()
  })
  let resizeObserver: ResizeObserver | null = null

  onDestroy(() => close())

  function close() {
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
    phase = 'opening'
    error = ''
    command = null
    try {
      const answer = await api.virtConsole(guest.id, kind, sudoPassword ?? undefined)
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
      socket = opened
      if (kind === 'vnc') {
        channel = new RelayChannel(opened)
        phase = 'open'
      } else {
        phase = 'open'
        await attachTerminal(opened)
      }
    } catch (e) {
      phase = 'failed'
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function attachTerminal(ws: WebSocket) {
    const [{ Terminal }, { FitAddon }] = await Promise.all([
      import('@xterm/xterm'),
      import('@xterm/addon-fit'),
      import('@xterm/xterm/css/xterm.css'),
    ])
    term = new Terminal({
      cursorBlink: true,
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
      if (phase === 'open') {
        phase = 'failed'
        if (!error) error = $LL.virtConsoleEnded()
      }
    }
    if (host && typeof ResizeObserver !== 'undefined') {
      resizeObserver = new ResizeObserver(() => fit.fit())
      resizeObserver.observe(host)
    }
    await new Promise((r) => requestAnimationFrame(r))
    fit.fit()
    ws.send(resizeMessage(term.cols, term.rows))
    term.focus()
  }

  function ended(message: string | null) {
    channel = null
    phase = message ? 'failed' : 'idle'
    error = message ?? ''
  }
</script>

<Card class="space-y-[13px]">
  <div class="flex flex-wrap items-center justify-between gap-[9px]">
    <p class="text-[13px] font-semibold">{kind === 'vnc' ? $LL.virtConsoleVnc() : $LL.virtConsoleText()}</p>
    <div class="flex items-center gap-[9px]">
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
    <div class="flex flex-wrap items-center gap-[9px]">
      <Input class="w-56" label={$LL.virtConsolePassword()} type="password" autocomplete="off" bind:value={typedPassword} />
      <p class="text-[12px] text-(--text-secondary)">{$LL.virtConsolePasswordHint()}</p>
    </div>
  {/if}

  {#if error}
    <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p>
  {/if}

  {#if command}
    <p class="text-[12px] text-(--text-secondary)">{$LL.virtConsoleCommand()}</p>
    <pre class="overflow-x-auto rounded-[9px] bg-(--surface-terminal) p-[11px_15px] lk-mono text-[13px]">{sudoPassword ? `sudo ${command}` : command}</pre>
  {/if}

  {#if kind === 'vnc' && channel}
    <div class="aspect-video w-full overflow-hidden rounded-[13px] bg-(--surface-terminal)">
      <VncViewer {channel} username={null} password={vncPassword} viewOnly={false} shared={true} onend={ended} />
    </div>
  {:else if kind === 'text'}
    <div class="h-96 w-full overflow-hidden rounded-lg {phase === 'open' ? '' : 'hidden'}" bind:this={host}></div>
  {/if}
</Card>
