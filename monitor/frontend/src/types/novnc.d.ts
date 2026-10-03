/// noVNC ships no types. Declared here for what the panel uses of it: the
/// constructor, four options and four events (`components/VncViewer.svelte`).
/// The package exports `./core/rfb.js` alone, as `@novnc/novnc`.
declare module '@novnc/novnc' {
  export interface RfbOptions {
    credentials?: { username?: string; password?: string; target?: string }
    /// `false` asks the desktop for a private session.
    shared?: boolean
  }

  /// Anything with WebSocket's shape: `send`, `close`, `binaryType`, the four
  /// `on…` handlers, `protocol`, `readyState`. An already-open one is
  /// attached as it is.
  export interface RawChannel {
    send(data: ArrayBufferLike | ArrayBufferView | Blob | string): void
    close(): void
    binaryType: BinaryType
    readonly protocol: string
    readonly readyState: number | string
    onopen: ((e: Event) => void) | null
    onmessage: ((e: MessageEvent) => void) | null
    onclose: ((e: CloseEvent) => void) | null
    onerror: ((e: Event) => void) | null
  }

  export default class RFB {
    constructor(target: Element, urlOrChannel: string | RawChannel, options?: RfbOptions)
    viewOnly: boolean
    /// Fit the desktop to the element rather than scrolling it.
    scaleViewport: boolean
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
  }
}
