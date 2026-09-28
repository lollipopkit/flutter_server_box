---
title: Remote Desktop (RDP and VNC)
description: Connect to graphical desktops through SSH or Monitor agent
---

Server Box includes RDP and VNC clients for Android, iOS, Linux, macOS, and
Windows. It reaches desktops through an existing server connection: SSH or a
Monitor agent with `remote_access.full_access` enabled. You do not need to
expose the desktop port to the network where Server Box runs.

## Set up a connection

1. Set up the server connection in Server Box with SSH or a Monitor agent that
   has `remote_access.full_access` enabled. If both are available, the server's
   **Try first** preference determines which connection is tried first; Server
   Box falls back to the other if it fails.
2. Open the **Remote desktop** tab and choose the server, or open the feature
   from that server's detail page.
3. Add a profile for the desktop. Profile names must be unique on that server.
4. Select **Connect** to open or return to a session. Use **Edit** to change a
   profile; **Test** in the editor connects with the current form values and
   replaces that profile's existing session.

The desktop address is resolved from the server's network, not from the phone
or computer running Server Box. The default targets are:

| Protocol | Default target |
| --- | --- |
| RDP | `127.0.0.1:3389` |
| VNC | `127.0.0.1:5900` |

These defaults work when the desktop service runs on the server itself. You can
also enter an internal address reachable from that server. SSH connections use
the same authentication and jump-server settings as terminal and port
forwarding connections. With Monitor agent, the agent connects from its own
machine as the account it runs under; this requires
`remote_access.full_access`. A plaintext HTTP connection to a Monitor agent is
used only when that connection is to a loopback address.

Passwords are not saved unless **Save password** is enabled. A password entered
for a session stays in memory for that session and its reconnect attempts.
Saved passwords are stored in Server Box's encrypted database and included in
encrypted backups and sync data. They are not included in server QR-code shares.

## Verify an RDP certificate

Server Box first checks the RDP certificate against the platform trust store.
If the certificate is trusted and its name matches the target, the connection
continues without a prompt.

For a self-signed certificate, unknown issuer, or name mismatch, Server Box
stops before sending credentials and shows the certificate identity and
SHA-256 fingerprint:

1. Verify the fingerprint through a separate trusted channel.
2. Select **Trust and reconnect** to trust that certificate for this profile.
3. Later connections accept only the same fingerprint.
4. If the certificate changes, the connection is blocked. Verify the new
   fingerprint before selecting **Replace trust**.

Changing a profile's protocol, target host, or target port clears its saved
certificate trust. Logs and diagnostics do not include passwords, clipboard
text, or certificate contents.

## Use sessions and controls

The **Remote desktop** tab can keep several RDP and VNC sessions open. On wide
windows, the session list appears beside the current desktop and can be resized
or collapsed. On narrow windows, select the session name at the top to switch
sessions.

The viewer offers fit-to-window, 1:1 and fixed zoom levels, full screen,
reconnect, close, view-only mode, clipboard send, a soft keyboard, and
Ctrl+Alt+Delete. Desktop platforms also support physical keyboards, all three
mouse buttons, and scrolling. When keyboard focus leaves the viewer, held RDP
keys are released.

On phones and tablets, touchpad mode is enabled by default: move one finger to
move the pointer, tap to click, use two fingers to right-click or scroll, and
pinch to zoom. Direct-pointer mode maps each touch to the corresponding point
on the remote desktop.

RDP synchronizes text clipboard data in both directions. Classic VNC clipboard
text uses Latin-1; Server Box rejects text that cannot be represented rather
than sending corrupted characters. RDP can adjust the remote resolution to the
viewer. VNC uses the dimensions provided by its server.

## Connection recovery

After a transport failure, Server Box retries after 1, 2, and 5 seconds. Each
attempt checks the connection again and creates a new temporary tunnel that
listens only on a local loopback address. Authentication failures, rejected
certificates, and invalid profile settings are not retried automatically.

Desktop platforms and Android use the app's existing background behavior when
the operating system allows it. iOS may suspend network activity in the
background; Server Box checks the session and reconnects if needed when you
return to the app.

## Supported protocols and limits

- **RDP:** TCP, TLS, CredSSP/NLA, graphics, keyboard and pointer input, dynamic
  resolution, and text CLIPRDR are supported. Username/password authentication
  with an optional domain primarily uses NTLM; Kerberos is not guaranteed.
- **VNC:** RFB 3.3, 3.7, and 3.8 are supported with None or classic VNC
  Authentication. Classic VNC passwords are limited to eight ASCII bytes.
  Supported updates include Raw, CopyRect, ZRLE, Tight, Tight JPEG, cursor, and
  desktop size.
- VNC does not support VeNCrypt, SASL, Apple Remote Desktop authentication, or
  RealVNC proprietary authentication.
- Audio, microphone, multiple monitors, RemoteApp, RDP Gateway, UDP transport,
  and file, disk, printer, USB, or smart-card redirection are not supported.

For protocol implementation, dependencies, code generation, and platform
validation, see the [remote desktop development notes](/docs/development/remote-desktop/).
