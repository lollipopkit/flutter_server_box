/// The RDP client, which is a web component rather than a module with an API.
///
/// Two packages. `@devolutions/iron-remote-desktop` registers
/// `<iron-remote-desktop>` — a Svelte component compiled into a bundle, so
/// nothing of its own describes the element — and
/// `@devolutions/iron-remote-desktop-rdp` is the backend it is handed. Both
/// ship types for everything that is not the element, and those are imported
/// here rather than restated: what this file adds is the element and the event
/// it answers with, which is the whole of what `components/RdpViewer.svelte`
/// leans on.
///
/// The element is created in script rather than written into the page, because
/// the backend module has to be on it before it is in the document — the
/// component reads that property once, as it initializes.
import type { UserInteraction } from '@devolutions/iron-remote-desktop'
import type { Backend } from '@devolutions/iron-remote-desktop-rdp'

/// The detail of the `ready` event, dispatched once the canvas exists — the
/// point from which a session may be asked for. Exported rather than declared
/// in the global block below, where the element has to be: eslint lints
/// `.svelte` files without a type checker, so a global type reads to it as an
/// undefined name.
export interface IronRemoteDesktopReadyDetail {
  irgUserInteraction: UserInteraction
}

declare global {
  interface IronRemoteDesktopElement extends HTMLElement {
    /// The protocol backend. Read once, as the element initializes, so it has
    /// to be set before the element is attached.
    module: typeof Backend
    /// `fit`, `full` or `real`. Reactive, and the element's own decision to
    /// make: `fit` is what this panel asks for.
    scale: string
    /// Written as `"true"` to log to the console.
    verbose: string
  }

  interface HTMLElementTagNameMap {
    'iron-remote-desktop': IronRemoteDesktopElement
  }
}
