<script lang="ts">
  import { Spinner } from '@serverbox/webui'
  import { onMount } from 'svelte'
  import type { UserInteraction } from '@devolutions/iron-remote-desktop'
  import { LL } from '../i18n/i18n-svelte'
  import { rdpFailureSentence, rdpFailureText } from '../lib/rdpFailure'
  import type { RdpEndpoint } from '../lib/desktop.svelte'
  import type { DesktopTarget } from '../types'
  import type { IronRemoteDesktopReadyDetail } from '../types/ironrdp'

  /// The RDP client for one session.
  ///
  /// Like `VncViewer`, everything that is the agent's is
  /// `lib/desktop.svelte.ts` and everything that is the protocol's is IronRDP's.
  /// What is left is the join between them, and it is not one line the way the
  /// VNC one is: an RDP client opens the socket itself, because its ticket
  /// travels inside the first PDU it writes rather than on the upgrade. So this
  /// component builds the element, hands it the backend module before it is in
  /// the document, and asks it for a session once it says its canvas exists.
  interface Props {
    /// Where the agent's RDP endpoint is, and how to get the ticket to carry
    /// there — asked for once this viewer is ready to dial, not when the route
    /// was opened.
    endpoint: RdpEndpoint
    /// The route the session is on: the address the agent dials, and the fields
    /// the client signs in with.
    target: DesktopTarget
    /// The password typed for this session, empty when none was given. It goes
    /// nowhere but to the server: the route stores none and the agent keeps none.
    password: string
    /// Called once, when the session is up — the point at which this store's
    /// `connecting` is over, which only the client can say for this protocol.
    onconnect: () => void
    /// Called once, when the session ends — by the server, by the link dropping,
    /// or by this viewer being taken off screen. `null` means the panel ended it
    /// and there is nothing to report.
    onend: (message: string | null) => void
  }

  const { endpoint, target, password, onconnect, onend }: Props = $props()

  let container = $state<HTMLDivElement | null>(null)
  let connecting = $state(true)
  /// The live session, kept only so the teardown below can shut it down. Every
  /// other call goes through the interaction object.
  let interaction: UserInteraction | null = null
  /// Set once the session has been reported, so a shutdown raised by the
  /// teardown cannot report it a second time.
  let ended = false

  function end(message: string | null) {
    if (ended) return
    ended = true
    onend(message)
  }

  /// What the agent is asked to dial. The port is written out rather than left
  /// to the protocol's default so that a route's own port is the one used — the
  /// agent resolves this string itself and cannot know what the client meant.
  function destinationOf(route: DesktopTarget): string {
    return `${route.host}:${route.port}`
  }

  function messageOf(e: unknown): string {
    return e instanceof Error ? e.message : String(e)
  }

  async function open(ui: UserInteraction) {
    // Minted here, not where the route was opened: the ticket is single-use and
    // good for about thirty seconds, and everything above this line — the
    // client's wasm, this element, its canvas — is seconds of work that a slow
    // link turns into a minute. A ticket minted at the route would be spent
    // before the socket it belongs to exists.
    let ticket: string
    try {
      ticket = await endpoint.ticket()
    } catch (e) {
      // The agent refusing to mint, which its own message is the whole answer
      // for ("full access not available" and the like). Phrased as a client
      // failure it would become the generic unreachable, and the reason would
      // be lost.
      if (ended) return
      end(messageOf(e))
      return
    }
    if (ended) return

    const builder = ui
      .configBuilder()
      .withDestination(destinationOf(target))
      .withProxyAddress(endpoint.proxyUrl)
      .withAuthToken(ticket)
      // Required by the client and required for RDP: it signs in, so a route
      // with no user name cannot open a session and the page says so before
      // getting here.
      .withUsername(target.username ?? '')
      // An empty password is a real one and is sent as such: the client sends
      // the credentials it was given, and a server that wants none is entitled
      // to get none. Omitted only where "none" and "empty" differ.
      .withPassword(password)
    // A domain is what a Windows account may need, and an empty one is not a
    // domain — so it is omitted rather than sent empty, the way the VNC viewer
    // omits its password.
    if (target.domain) builder.withServerDomain(target.domain)

    try {
      const session = await ui.connect(builder.build())
      if (ended) return
      connecting = false
      onconnect()
      // Resolves on a graceful disconnect — the server saying goodbye, or the
      // teardown below shutting the session down — and rejects when the link
      // went away, which is the same pair noVNC reports as `clean`.
      await session.run()
      end(null)
    } catch (e) {
      if (ended) return
      end(rdpFailureSentence(rdpFailureText(e)))
    }
  }

  onMount(() => {
    let cancelled = false

    void (async () => {
      // Loaded here rather than at the top of the module: the RDP client is a
      // wasm module of several megabytes, and nobody who never opens an RDP
      // route should download it — the reason noVNC and xterm are loaded where
      // they are used too. Its types are the packages' own, and only the
      // element is declared here.
      const { Backend, init } = await import('@devolutions/iron-remote-desktop-rdp')
      // Imported for its side effect: this is the module that registers
      // `<iron-remote-desktop>`, and the element has to be defined before one
      // can be created.
      await import('@devolutions/iron-remote-desktop')
      // The backend's wasm module, which resolves before any of it can be used.
      // Debug in a dev build and silent in a shipped one: what it logs is the
      // client's own account of a connection, which is the only account there
      // is when a session does not come up.
      await init(import.meta.env.DEV ? 'DEBUG' : 'OFF')
      if (cancelled || !container) return

      const element = document.createElement('iron-remote-desktop')
      // Set before the element is attached: the component reads this property
      // once, as it initializes, so an element already in the document would be
      // left with no backend and no way to be given one.
      element.module = Backend
      // Fitted to the space the panel has, the way the VNC viewer is: a desktop
      // drawn at its own size in a smaller box is one with part of it off screen.
      element.setAttribute('scale', 'fit')
      element.setAttribute('flexcenter', 'true')
      // Its canvas is what a session draws into and it does not exist until
      // this fires, so a session asked for earlier has nowhere to go.
      element.addEventListener('ready', (event) => {
        if (cancelled) return
        const ready = event as CustomEvent<IronRemoteDesktopReadyDetail>
        interaction = ready.detail.irgUserInteraction
        void open(interaction)
      })
      // Outside Svelte's knowledge on purpose: the backend module has to be on
      // the element before it is in the document, and the component reads that
      // property once, as it initializes — which a `{@html}` or a
      // `<svelte:element>` cannot do. Nothing here is ever updated by the
      // runtime, so there is no expected DOM for it to disagree with.
      // eslint-disable-next-line svelte/no-dom-manipulating
      container.appendChild(element)
    })()

    return () => {
      cancelled = true
      // Left before the session ended: the page is the one that decided it is
      // over, so nothing is reported back to it.
      ended = true
      interaction?.shutdown()
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

<p class="text-xs text-muted-fg">{$LL.desktopRdpPlaintext()}</p>
