<script lang="ts">
  import { Button, Card, Input, Spinner } from '../../lk'
  import { errorText } from '../../../lib/errorText'
  import VncViewer from '../../../components/VncViewer.svelte'
  import { api } from '../../../lib/api'
  import { RelayChannel, parseControl } from '../../../lib/desktop.svelte'
  import { theme } from '../../../lib/theme.svelte'
  import { mountTerminal, type TerminalHandle } from '../../../lib/xterm'
  import { openConsoleSocket, resizeMessage } from '../../../lib/virtConsole'
  import { virtErrorText } from '../../../lib/virt'
  import ScreenReaderToggle from '../../../components/ScreenReaderToggle.svelte'
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
  let term: TerminalHandle | null = $state.raw(null)

  $effect(() => {
    // The desk's mode or theme changed: the console follows, as Terminal does.
    void theme.revision
    term?.setTheme()
  })
  /// Rises on every close, so an open still waiting on the agent when the
  /// view closed (or another open began) drops what it gets.
  let attempt = 0

  onDestroy(() => close())

  function close() {
    attempt++
    term?.dispose()
    term = null
    if (socket && socket.readyState !== WebSocket.CLOSED) socket.close()
    socket = null
    channel = null
  }

  async function open() {
    close()
    const mine = attempt
    const gone = () => mine !== attempt
    phase = 'opening'
    error = ''
    command = null
    try {
      const answer = await api.virtConsole(guest.id, kind, sudoPassword ?? undefined)
      if (gone()) return
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
      if (gone()) {
        opened.close()
        return
      }
      socket = opened
      if (kind === 'vnc') {
        channel = new RelayChannel(opened)
        phase = 'open'
      } else {
        phase = 'open'
        await attachTerminal(opened, gone)
      }
    } catch (e) {
      if (gone()) return
      // A socket already open (the terminal chunk failed to load) goes too
      ended(errorText(e))
    }
  }

  async function attachTerminal(ws: WebSocket, gone: () => boolean) {
    if (!host) return
    const encoder = new TextEncoder()
    const send = (data: Uint8Array | string) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(data)
    }
    const handle = await mountTerminal(host, {
      input: (data) => send(encoder.encode(data)),
      resize: (cols, rows) => send(resizeMessage(cols, rows)),
    })
    // Closed while the terminal loaded: `close` ended the socket already.
    if (gone()) {
      handle.dispose()
      return
    }
    term = handle
    ws.onmessage = (event) => {
      if (typeof event.data === 'string') {
        const control = parseControl(event.data)
        if (control?.type === 'error') error = control.message || control.code
        return
      }
      handle.renderer.write(new Uint8Array(event.data as ArrayBuffer), () => {})
    }
    ws.onclose = () => {
      if (!gone() && phase === 'open') {
        phase = 'failed'
        if (!error) error = $LL.virtConsoleEnded()
      }
    }
    send(resizeMessage(handle.renderer.cols, handle.renderer.rows))
    handle.focus()
  }

  /// The console is over, by the Close button or because the viewer ended:
  /// its socket and terminal go with it.
  function ended(message: string | null) {
    close()
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
      {#if kind === 'text'}
        <ScreenReaderToggle />
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
