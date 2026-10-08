<script lang="ts">
  import Spinner from '@lollipopkit/desk-ui/Spinner.svelte'
  import { onMount } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { RelayChannel } from '../lib/desktop.svelte'

  /// The VNC client for one session: noVNC attached to a relay channel the
  /// agent has already accepted (`DesktopSession.connect`).
  interface Props {
    channel: RelayChannel
    /// Typed for this session and handed to the desktop only; the agent
    /// stores none.
    username: string | null
    password: string
    viewOnly: boolean
    shared: boolean
    /// Called once, when the session ends on its own; `null` when it ended
    /// cleanly with nothing to report.
    onend: (message: string | null) => void
  }

  const { channel, username, password, viewOnly, shared, onend }: Props = $props()

  let container = $state<HTMLDivElement | null>(null)
  let connecting = $state(true)
  /// Read at disconnect: noVNC ends the session either way, and this is what
  /// tells a refused password from a dropped link.
  let refused = false
  let ended = false

  function end(message: string | null) {
    if (ended) return
    ended = true
    onend(message)
  }

  onMount(() => {
    let cancelled = false
    let client: { disconnect: () => void } | null = null

    void (async () => {
      // Loaded on demand, as the terminal loads xterm.
      const { default: RFB } = await import('@novnc/novnc')
      if (cancelled || !container) return
      const credentials = {
        ...(username ? { username } : {}),
        // Omitted rather than sent empty, so a desktop that wants one asks.
        ...(password ? { password } : {}),
      }
      const rfb = new RFB(container, channel, { credentials, shared })
      // Properties, not constructor options: noVNC ignores them there, and a
      // view-only route would then send input.
      rfb.viewOnly = viewOnly
      rfb.scaleViewport = true
      client = rfb

      rfb.addEventListener('connect', () => (connecting = false))
      rfb.addEventListener('securityfailure', () => (refused = true))
      // Asked for a credential this session was not given: ended rather than
      // left waiting, with the reason on screen.
      rfb.addEventListener('credentialsrequired', () => {
        refused = true
        rfb.disconnect()
      })
      rfb.addEventListener('disconnect', (event) => {
        end(
          refused
            ? $LL.desktopPasswordRefused()
            : (channel.reason ?? (event.detail?.clean ? null : $LL.desktopDropped())),
        )
      })
    })()

    return () => {
      cancelled = true
      // The page ended it: nothing to report back.
      ended = true
      client?.disconnect()
    }
  })
</script>

<div class="relative h-full min-h-72 w-full overflow-hidden rounded-[var(--radius-card)] bg-(--ink-4) shadow-[inset_0_0_0_0.5px_var(--border-hairline)]">
  <div bind:this={container} class="h-full w-full"></div>
  {#if connecting}
    <div class="absolute inset-0 flex items-center justify-center bg-(--scrim)">
      <Spinner size={24} />
    </div>
  {/if}
</div>
