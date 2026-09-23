<script lang="ts">
  import { Spinner } from '@serverbox/webui'
  import { onMount } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'

  /// The VNC client for one session.
  ///
  /// It is deliberately small: everything that is the agent's — the ticket, the
  /// relay socket, waiting for `ready` — is `lib/desktop.svelte.ts`, and
  /// everything that is the protocol's is noVNC's. What is left here is the
  /// join between them, and the join is one line: the socket is already OPEN
  /// and already accepted, so the client attaches to it rather than dialling,
  /// and from that point the connection is its own to end.
  interface Props {
    /// The relay socket, handed over by `DesktopSession.connect`.
    socket: WebSocket
    /// The password typed for this session, or empty if none was given. It goes
    /// nowhere but to the desktop: the route stores none and the agent keeps
    /// none.
    password: string
    viewOnly: boolean
    shared: boolean
    /// Called once, when the session ends — by the desktop, by the link
    /// dropping, or by this viewer being taken off screen. `null` means the
    /// panel ended it and there is nothing to report.
    onend: (message: string | null) => void
  }

  const { socket, password, viewOnly, shared, onend }: Props = $props()

  let container = $state<HTMLDivElement | null>(null)
  let connecting = $state(true)
  /// An authentication the desktop refused. Read at disconnect time, because
  /// noVNC ends the session either way and this is the only thing that tells
  /// "the password was wrong" from "the link dropped".
  let refused = false
  let client: { disconnect: () => void } | null = null
  /// Set once the session has been reported, so a disconnect raised by the
  /// teardown below cannot report it a second time.
  let ended = false

  function end(message: string | null) {
    if (ended) return
    ended = true
    onend(message)
  }

  onMount(() => {
    let cancelled = false

    void (async () => {
      // Loaded here rather than at the top of the module: a VNC protocol stack
      // is not part of the panel for anyone who never opens a desktop, and this
      // is the same reason xterm is loaded by the terminal.
      const { default: RFB } = await import('@novnc/novnc')
      if (cancelled || !container) return

      const rfb = new RFB(container, socket, {
        // Omitted rather than sent empty: an empty password is a password that
        // is empty, and what "no password was typed" has to mean is that the
        // desktop is asked for one.
        ...(password ? { credentials: { password } } : {}),
        shared,
        viewOnly,
        // Fitted to the space the panel has: a viewer that scrolls is one where
        // part of the desktop is off screen with nothing saying so.
        scaleViewport: true,
      })
      client = rfb

      rfb.addEventListener('connect', () => {
        connecting = false
      })
      rfb.addEventListener('securityfailure', () => {
        refused = true
      })
      rfb.addEventListener('disconnect', (event) => {
        end(
          refused
            ? $LL.desktopPasswordRequired()
            : event.detail?.clean
              ? null
              : $LL.desktopUnreachable(),
        )
      })
    })()

    return () => {
      cancelled = true
      // Left before the client said anything: the page is the one that decided
      // the session is over, so nothing is reported back to it.
      ended = true
      client?.disconnect()
    }
  })
</script>

<div class="relative h-[70vh] min-h-96 w-full overflow-hidden rounded-lg border border-line bg-black">
  <div bind:this={container} class="h-full w-full"></div>
  {#if connecting}
    <div class="absolute inset-0 flex items-center justify-center bg-black/40">
      <Spinner class="w-6 h-6" />
    </div>
  {/if}
</div>
