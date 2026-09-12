# IronRDP client

Reusable RDP client engine library built on top of the IronRDP crates suite.

This crate is **library-only**: it exposes the `Config`, the `RdpClient`
runtime, input/output event types, the WebSocket transport, and the session driver. It is
consumed by `ironrdp-viewer` (the portable GUI client binary) and by any other embedder
(for example, a headless agent).

The library is winit-agnostic. Output events are emitted on a bounded
`tokio::sync::mpsc::Sender<RdpOutputEvent>` channel: the embedder is responsible
for consuming them and dispatching them to whatever event loop or runtime it wishes.

For the end-user RDP client binary, see [`ironrdp-viewer`](../ironrdp-viewer).

This crate is part of the [IronRDP] project.

[IronRDP]: https://github.com/Devolutions/IronRDP
