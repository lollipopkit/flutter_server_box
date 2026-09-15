---
title: Remote desktop (RDP and VNC)
description: Reach graphical desktops through a Server Box SSH connection
---

Server Box includes RDP and VNC clients on Android, iOS, Linux, macOS, and Windows. Every remote desktop connection travels through the SSH connection already configured for the server. The RDP or VNC port does not need to be exposed to the network where Server Box is running.

## Configure a desktop

1. Configure SSH for the server. A Monitor-only server cannot open a remote desktop because the Monitor HTTP API does not relay arbitrary TCP streams.
2. Open the server detail page and select **Remote desktop**.
3. Add one or more profiles. Profile names are unique within that server.
4. Select a profile to open it in the **Remote desktop** tab. Opening the same profile again focuses its existing session instead of creating a duplicate.

The target host is resolved from the SSH server's network, not from the phone or computer running Server Box. The defaults are therefore useful when the desktop service runs on the SSH server itself:

| Protocol | Default target |
|---|---|
| RDP | `127.0.0.1:3389` |
| VNC | `127.0.0.1:5900` |

An internal hostname or address reachable only from the SSH server also works. SSH passwords, keys, keyboard-interactive authentication, jump servers, and `ProxyCommand` use the same connection path as the terminal and port-forward features.

Passwords are not saved by default. A password entered when a session starts remains in memory for that session and its reconnect attempts. When **Save password** is enabled, it is stored in Server Box's encrypted database and is included in encrypted backup and sync data. Remote desktop passwords are never included in a server QR-code share.

## Certificate verification for RDP

Server Box first asks the platform trust store to validate the RDP server certificate. A publicly trusted certificate whose name matches the configured target proceeds without another prompt.

For a self-signed certificate, an unknown issuer, or a name mismatch, Server Box stops before sending credentials and displays the certificate identity and SHA-256 fingerprint:

1. Verify the fingerprint through a separate trusted channel.
2. Choose **Trust and reconnect** to pin it to this profile.
3. Later connections accept only the same fingerprint.
4. If the certificate changes, Server Box blocks the connection and displays both fingerprints. Choose **Replace trust** only after verifying the server again.

Changing a profile's protocol, target host, or target port clears its saved certificate fingerprint. Logs and diagnostics exclude passwords, clipboard text, and certificate bodies.

## Sessions and controls

The Remote desktop tab retains several simultaneous RDP and VNC sessions. Wide windows show a session list beside the current desktop. Narrow windows use the session name at the top to open the switcher.

The viewer provides fit-to-window, 1:1, fixed zoom levels, full screen, reconnect, close, view-only mode, clipboard send, the soft keyboard, and Ctrl+Alt+Delete. Desktop platforms support physical keyboard input, left/middle/right mouse buttons, and scrolling. Losing keyboard focus releases held RDP keys.

Mobile devices start in touchpad mode: move one finger to move the pointer, tap to click, tap with two fingers to right-click, drag with two fingers to scroll, and pinch to zoom. Direct-pointer mode maps the touched point directly to the remote desktop.

RDP text clipboard data is synchronized in both directions. RFB's classic clipboard is Latin-1; Server Box rejects VNC clipboard text containing characters that cannot be represented instead of corrupting it.

RDP adjusts the remote resolution after the viewport has been stable for 300 ms. VNC uses the size supplied by the server. Hidden sessions stop sending frames across the Rust/Flutter boundary and publish their newest complete frame when shown again.

## Reconnection

Transport failures retry after 1, 2, and 5 seconds. Each attempt confirms the SSH client and creates a new loopback-only tunnel. Authentication failures, rejected certificates, and invalid configuration do not retry automatically.

Desktop platforms and Android use the app's existing background behavior where the operating system permits it. iOS can suspend network work in the background; Server Box checks the session after returning to the foreground and reconnects when necessary.

## Protocol scope

The first release intentionally supports a focused subset:

- RDP uses TCP, TLS, CredSSP/NLA, graphics, keyboard and pointer input, dynamic resolution, and text CLIPRDR. Username/password authentication with an optional domain primarily uses NTLM; Kerberos is not guaranteed.
- VNC supports RFB 3.3, 3.7, and 3.8 with None or classic VNC Authentication. Classic passwords are limited to eight ASCII bytes. Raw, CopyRect, ZRLE, Tight, Tight JPEG, cursor, and desktop-size updates are supported.
- VNC does not yet support VeNCrypt, SASL, Apple Remote Desktop authentication, or RealVNC proprietary authentication.
- Audio, microphone, multiple monitors, RemoteApp, RDP Gateway, UDP transport, and file, disk, printer, USB, or smart-card redirection are not included.
- Rendering uses a cross-platform Flutter BGRA image path. Native texture renderers can replace this layer later without changing the session API.

## Implementation and building

The protocol engine is part of the existing `sbm_ffi` Rust library:

- [IronRDP 0.17](https://github.com/Devolutions/IronRDP), MIT OR Apache-2.0
- [vnc-rs 0.5.3](https://github.com/HsuJv/vnc-rs), MIT OR Apache-2.0

Only the required IronRDP features are enabled. The repository carries `ironrdp-client`, `ironrdp-connector`, and `ironrdp-tls` under `third_party/`. IronRDP 0.17's published dependency graph pins pre-release RustCrypto packages that conflict with the stable crypto stack used by the SSH implementation. The vendored crates keep the IronRDP APIs and versions while updating only that dependency path. Their upstream MIT and Apache-2.0 license files are preserved beside the sources.

Run Flutter Rust Bridge generation and the normal Flutter code generation after changing the FFI API. `cargo test --workspace` exercises protocol code. The ignored `frame_backpressure_stays_bounded_at_1080p` test is a 60-second stress test and should be run explicitly before release.

Windows can build and verify Windows and Android artifacts. Final iOS and macOS links require an Apple build host, and final Linux linking requires a Linux build host. Keyboard, pointer, rotation, full-screen, background recovery, and real RDP/VNC servers still need platform-specific device testing before a release.
