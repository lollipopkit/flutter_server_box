/// The VNC protocol stack, which ships no types of its own.
///
/// Declared rather than taken from a `@types` package, because what this panel
/// uses of it is a constructor, four options and four events: a full set of
/// declarations here would be a second description of the library and free to
/// drift from it, while the claims this panel actually relies on — that a
/// socket which is already OPEN can be handed over, and that the client takes
/// the connection from there — are what `lib/desktop.svelte.ts` and
/// `components/VncViewer.svelte` are written around.
///
/// The package's `exports` is `./core/rfb.js` alone, so the module has to be
/// named `@novnc/novnc`; a subpath import does not resolve.
declare module '@novnc/novnc' {
  export interface RfbOptions {
    /// Answered before the desktop asks: the password this panel collected, and
    /// nothing else — a route stores no credential.
    credentials?: { username?: string; password?: string; target?: string }
    /// `false` asks the desktop for a private session, which some servers
    /// refuse to give. The route decides it.
    shared?: boolean
    viewOnly?: boolean
    /// Fit the desktop to the element rather than scrolling it.
    scaleViewport?: boolean
  }

  /// `disconnect` carries `{ clean }` — whether the desktop closed the session
  /// or the connection dropped. `securityfailure` and `credentialsrequired`
  /// carry the details of an authentication the desktop refused.
  export default class RFB {
    /// `urlOrChannel` is a URL or an already-OPEN `WebSocket`; given a socket,
    /// the client attaches to it and takes over its handlers.
    constructor(target: Element, urlOrChannel: string | WebSocket, options?: RfbOptions)
    /// Ends the session and closes the socket.
    disconnect(): void
    addEventListener(
      type: 'disconnect',
      listener: (event: CustomEvent<{ clean: boolean }>) => void,
    ): void
    addEventListener(
      type: 'securityfailure',
      listener: (event: CustomEvent<{ status?: number; reason?: string }>) => void,
    ): void
    addEventListener(type: 'connect' | 'credentialsrequired', listener: (event: Event) => void): void
    addEventListener(type: string, listener: (event: Event) => void): void
    removeEventListener(type: string, listener: (event: Event) => void): void
  }
}
