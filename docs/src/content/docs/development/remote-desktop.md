---
title: Remote Desktop Development
description: Protocol implementation, code generation, and platform validation
---

## Protocol engine

The RDP and VNC protocol engine is part of the existing `sbm_ffi` Rust library:

- [IronRDP 0.17](https://github.com/Devolutions/IronRDP), MIT OR Apache-2.0
- [vnc-rs 0.5.3](https://github.com/HsuJv/vnc-rs), MIT OR Apache-2.0

Only the required IronRDP features are enabled. The `third_party/ironrdp`
submodule points to the `serverbox` branch of the
[lollipopkit/IronRDP fork](https://github.com/lollipopkit/IronRDP). That branch
keeps the IronRDP 0.17 APIs and crate versions while carrying Server Box's
transport, certificate-trust, and dependency-compatibility changes. Update the
fork first, then pin the resulting commit in this repository.

Rendering currently uses a cross-platform Flutter BGRA image path. A native
texture renderer can replace it later without changing the session API.

## Related guides

When changing the FFI API, follow the repository's
[code generation guide](/docs/development/codegen/). For the test suites and
platform build process, see [Testing](/docs/development/testing/) and
[Building](/docs/development/building/).
