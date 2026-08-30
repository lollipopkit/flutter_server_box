---
title: Privacy Policy
description: What Server Box stores, what it sends, and how to turn sending off
---

Server Box connects to your servers directly. There is no account, no backend
that proxies your connections, and no service run by the developer that sees
which machines you manage.

The one exception is diagnostic data, which is described below and can be
switched off entirely.

Last updated: 2026-08-29.

## What never leaves your device

| Data | Where it is kept |
|---|---|
| Server addresses, ports, usernames | Encrypted SQLite database on the device |
| Passwords and private keys | Encrypted SQLite database; the encryption key is in the platform keychain |
| Backup password | Platform keychain |
| Terminal output, command output, file contents | Not stored beyond the running session, and never uploaded |
| SFTP transfers | Between your device and your server only |

Backups are created only when you ask for one, and go where you send them.
A backup is encrypted with the backup password you set.

## Diagnostic data

The only data Server Box sends to the developer, and only at the level you
choose. The choice is presented on an intro page before anything is sent, and
can be changed at any time in **Settings → Diagnostic data**.

| Level | What is sent |
|---|---|
| **Nothing** | Nothing is sent, ever. Reports stay on the device |
| **Basic information** | Crashes and caught errors, with the app version they happened in |
| **Full information** | Everything Basic sends, plus performance traces and a count of which features are used, while the app runs |

The default on Android is **Nothing**. On iOS, macOS, Linux and Windows it is
**Basic information**, and the intro page is shown before the first upload.

Setting the level to **Nothing** stops delivery immediately, not at the next
launch.

### What a report contains

- The error, its message, and the stack trace
- The app build number, whether this build includes a Linux userland, and the
  storage schema version
- Operating system name, version and kernel version; CPU count; total memory;
  the app's memory use
- Language, region and time zone
- Dart and Flutter runtime versions
- An identifier the diagnostics server generates for the install

At **Full information**, it also contains timings for operations such as
connecting to a server or listing a directory — how long each took, not what
was in it — and a count of which features are used: that a terminal was
opened, that a server was saved with an SSH key rather than a password, that
a file browser used SFTP rather than SCP.

Those counts are the same breadcrumbs described above, sent as they happen
rather than held for a crash. They carry an identifier that is **generated at
launch and never stored**, so one run's actions can be read in order and two
runs cannot be connected to each other. That rules out knowing how many people
use the app, or whether anyone came back — which is the cost of not holding a
device identifier.

The app's own log is **never** uploaded, at any level. It is written to be read
by a developer on the device, by code going back years, and some of it formats
a server name straight into the message. It stays on the device, where the Logs
page shows it and the manual report below quotes it.

### What a report does not contain

- Your hostname, IP address, name, email address or any account identifier
- Any advertising identifier
- Passwords, private keys, or the contents of any file
- Terminal output or the output of any command
- Real server names, addresses or usernames — see below

### Redaction

Server names, addresses and usernames are replaced with placeholders at the
moment a line is recorded, not when it is sent. A report says that a connection
to a server on a private network failed, not which server.

This is not a claim that the manual report below is anonymous. Log lines
written by older versions of the app can contain a server name in their message
text, which is why that report shows you the full text to read before you post
it. Uploaded reports carry no log lines at all.

## Reporting a crash by hand

After a crash, Server Box offers to report it. That path sends nothing on its
own: the report is copied to the clipboard and a GitHub issue page is opened.
You paste it, and you see what you are posting first. It works at every
diagnostic level, including **Nothing**, and needs no account with the
developer.

Anything you post to GitHub is public and covered by
[GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement).

## Where diagnostic data goes

To a Sentry-compatible server operated by the developer at
`sentry.lollipopkit.com`. It is not a third-party analytics product, the data
is not shared with anyone, and it is not used for advertising, profiling or
tracking across apps or websites.

Reports are kept only for as long as they are useful for fixing the problem
they describe. To have reports from your install removed, open an issue on
[GitHub](https://github.com/lollipopkit/flutter_server_box/issues) with the
identifier shown in **Settings → Diagnostic data**.

## Other network connections

These are requests the app makes for a feature you used. None of them carries
diagnostic data.

| Request | Goes to | When |
|---|---|---|
| Update check | `api.github.com` | On launch, if automatic update checks are on |
| Linux userland images and their manifest | `github.com` | When you install or update a local Linux environment |
| Server logo images | The URL you configured | When a custom logo URL is set |
| Documentation and issue links | `serverbox.lollipopkit.com`, `github.com` | When you tap them |

Connections to your own servers, and to a Monitor agent you deployed, go to
those machines and nowhere else.

## Watch app and home screen widgets

The watch app, its complication, and the iOS and Android home screen widgets
read a Monitor agent you deployed, directly. They use a read-only credential
the app mints for them, limited to three metrics endpoints. The credential is
stored in the watch's own keychain, in a shared keychain group on iOS, and
encrypted under an AndroidKeyStore key on Android.

Individual servers can be held back in **Settings**, which revokes that
server's credential immediately.

## Platform stores

App Store and Google Play builds are also subject to the store's own reporting.
Apple's crash reports and Google Play's crash reports are collected by the
platform, not by this app, and are governed by Apple's and Google's privacy
policies. The F-Droid build has no such channel, which is why the Android
default is **Nothing**.

## Children

Server Box is a tool for administering servers. It is not directed at children
and collects nothing that would identify one.

## Changes

Material changes to what is collected reset the diagnostics question, so the
intro page is shown again rather than treating an old answer as consent for a
new arrangement.

## Contact

Open an issue at
[github.com/lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box/issues).
