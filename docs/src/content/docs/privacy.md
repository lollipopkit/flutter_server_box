---
title: Privacy Policy
description: What Server Box stores, what it sends, and how to control those choices
---

Last updated: 2026-09-02.

Server Box is a client for the servers you configure. It has no user account and
no developer-operated relay for SSH, SFTP, or Monitor traffic. Connections to
those services go directly from the app to the endpoint you selected.

The app makes separate network requests for diagnostics and for features you
use. Their destinations and payloads are described below. Server Box contains no
ads, advertising identifiers, or cross-app tracking.

## Data stored on this device

| Data | Storage and behavior |
|---|---|
| Server names, addresses, ports, usernames and settings | Encrypted SQLite database |
| SSH passwords, private keys, Monitor and BMC credentials, and the configured AI API key | Encrypted SQLite database; the database encryption key is kept in the platform keychain |
| Backup password, WebDAV password and GitHub token | Platform secure storage |
| App logs | Local log files only; the current and previous run are retained for troubleshooting |
| Agent conversations | Local encrypted database; they may contain prompts, model responses, command output, selected terminal text and file content |
| Active terminal output | Kept in the active session; the terminal does not retain it after the session ends |

Agent conversations are excluded from backups and device sync. They remain on
this device until you delete them from the conversation history. An Agent
conversation can still be sent to the AI provider you configured; see
[AI requests](#ai-requests).

Backups are created only when you request one. Depending on the options and the
backup format, a backup can contain server settings and credentials, private
keys, snippets, port forwards, container settings, connection history and app
settings. When app settings are included, this also includes the configured AI
endpoint, model and API key. Agent conversations and device-local state are not
included.

A local backup may be unencrypted when no backup password is set. When you set a
backup password, the backup is encrypted before it is written or uploaded.
Automatic remote backup requires a non-empty backup password. After a backup is
sent to iCloud, WebDAV or GitHub Gist, that provider's storage, access and
retention rules also apply.

## Automatic diagnostic data

Automatic diagnostics are the only telemetry sent to the developer's diagnostic
services. The choice is shown on the intro page before the first upload and can
be changed at any time in **Settings → App → Privacy**.

| Level | What is sent automatically |
|---|---|
| **Nothing** | Nothing. Local logs remain on this device, and you can still prepare a manual report. |
| **Basic information** | Captured crashes and errors, with build and platform information and deliberately recorded diagnostic breadcrumbs attached when relevant. Nothing is sent continuously while the app is operating normally. |
| **Full information** | Everything in Basic, plus performance traces when available and coarse feature-use events while the app runs. |

The Android default is **Nothing**. The iOS, macOS, Linux and Windows defaults
are **Basic information**. On builds where automatic diagnostics is available,
the intro page is shown before the first automatic upload.

Changing the level to **Nothing** stops automatic delivery immediately; it does
not wait for the next launch.

### What automatic reports contain

Depending on the platform and the error, an automatic report can contain:

- The error type, message and stack trace
- The app build number, storage schema version and whether the build includes a
  local Linux userland
- Operating-system and kernel information, hardware model, CPU count, memory
  size and app memory use where the platform provides them
- Language, locale and time zone
- Dart and Flutter runtime versions
- Structured diagnostic breadcrumbs such as the transport used, the kind of
  terminal or file backend, and an operation's outcome where it was recorded
- A platform-provided native-crash, ANR or hang reason and trace, where one is
  available

Breadcrumbs use fixed action names and coarse or redacted values. They do not
include terminal output, file contents, passwords or private keys as diagnostic
fields. The app's ordinary log stream is never uploaded at any level.

An error message or stack trace comes from the underlying library and may contain
text that the app did not create. Server details therefore cannot be ruled out
for every possible exception. Automatic diagnostics should not be treated as a
guarantee that arbitrary exception text is anonymous.

The app does not install a native crash signal handler. Instead, when the
platform provides a native-crash, ANR or hang record, Server Box reads it on the
next launch. If automatic diagnostics is enabled, the record can then be sent as
an error report; otherwise it remains available locally and can appear in a
manual report.

### What Full information adds

Full information sends performance traces such as how long connecting to a
server or listing a directory took, not the contents of those operations. It
also turns the same structured breadcrumbs into coarse feature-use events, for
example that a terminal was opened or that SFTP was used instead of SCP. These
events do not include prompts, terminal output, file contents, keystrokes or
screen recordings.

The OpenPanel analytics destination used by this project is written into the
source, as is the error-reporting destination. A build made from unmodified
source by someone else — an F-Droid rebuild, a fork or your own checkout — uses
the same destinations unless its builder changes them. Full information remains
off by default and must be enabled manually; an untouched build sends no
feature-use events until you choose Full information.

Two analytics integrations are implemented, with different identifier behavior:

- The OpenPanel integration used by this project accepts a **per-install
  identifier**. It stores a random 128-bit value on the device — created when
  Full information is enabled, deleted when you leave Full, kept outside the
  backup file, and derived from no device identifier, account or hardware value.
  Its purpose is to link events from the same installation across launches and
  count distinct installations, not to identify a person or a device.
- An Aptabase integration is also implemented, but published builds do not
  configure it. It does not use a persistent installation identifier. Its events
  carry a session ID that rotates after one hour of inactivity, so sessions from
  separate launches cannot be linked.

Depending on the destination, events carry the operating system and version,
the device type and model where available, the app version and build number, and
the locale. They contain no advertising identifier or account identifier.

The analytics service may also derive an approximate location from the IP
address used to connect: a country and city, with representative coordinates
for that city rather than your exact location. For the OpenPanel data used by
this project, that location is stored with the per-install identifier; the IP
address itself is not an event field.

## Redaction and manual crash reports

Structured diagnostic breadcrumbs are made safe when they are created, before
any reporting sink receives them. They use fixed action names and stand-ins for
server-related values rather than recording a server name, address or username
directly.

A manual report is different. After a crash, Server Box can show the previous
run's log and any platform crash or hang trace, replace known configured server
values where it can, copy the result to the clipboard and open a GitHub issue
page. Nothing is posted automatically: you decide whether to paste or submit it,
and you can read the complete text first. This path works at every diagnostic
level, including **Nothing**.

Older log lines, temporary hosts and values the app does not know may still be
present in a manual report. The report is therefore not guaranteed to be
anonymous. Anything pasted into GitHub is public and is covered by
[GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement).

## AI requests

The Agent uses the OpenAI-compatible endpoint configured in **Settings → App →
AI**. The default endpoint can be replaced with another provider. No request is
made until you send an Agent message.

Depending on the operation, a request can contain your prompt, selected terminal
text, recent conversation history, the configured server name and context needed
for the Agent to work. After a command or file operation, its result can be sent
in a later request so the model can continue. Command output and file content may
contain passwords, tokens or other secrets even when Server Box did not add them
itself; check what you submit and review the provider's privacy policy.

The API key is stored locally in the encrypted app database and sent as a bearer
credential only to the endpoint you configure. If app settings are included in a
backup, the endpoint, model and API key are included as well. Server Box does not
proxy AI requests through a developer service.

## Other network requests

These requests are made only for the corresponding feature and do not carry the
automatic diagnostic payload described above.

| Request | Destination | When and what it carries |
|---|---|---|
| AI request | The endpoint configured by you | When you send an Agent message; see [AI requests](#ai-requests) |
| Backup or sync | iCloud, your WebDAV server, or GitHub Gist | When you upload, download or sync a backup; the selected backup file, which may be encrypted |
| Update check | `api.github.com` | On launch when automatic update checks are enabled |
| Linux userland manifest | `github.com` | When the app checks for a newer local Linux release; it contains release metadata and signatures |
| Linux userland image | The distribution mirror or source URL selected by the verified manifest | When you install or update a local Linux environment; the image is checked against the manifest's digest |
| Server logo or distribution mark | The URL configured by you | When a custom logo or mark URL is set; the image provider can receive the request |
| Sponsor link | `cdn.lpkt.cn` | When you open the sponsor link |
| Documentation and issue links | `serverbox.lollipopkit.com` or `github.com` | When you open one of those links |

Connections to your own servers, to a BMC you configured and to a Monitor agent
you deployed go directly to those endpoints. They are not routed through the
developer's infrastructure.

## Where diagnostic data goes

Error reports and performance traces go to the Sentry-compatible server operated
by the developer at `sentry.lollipopkit.com`. In the published/default build,
Full-information feature-use events go to the OpenPanel analytics server at
`diag.lollipopkit.com`. The Aptabase integration is inactive unless a build
supplies its own Aptabase endpoint and app key.

The Sentry and OpenPanel destinations are written into the source, so a build
made from unmodified source reports to them too unless its builder changes them.
Full information is still off by default and requires an explicit choice.

Diagnostic data is not used for advertising, shared with other companies, or
used to track you across apps or websites. The services may retain reports for as
long as they are useful for fixing the problems they describe. To request
removal of a report, open an issue at
[github.com/lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box/issues)
with the approximate time, app version and a short description of the problem.
Do not include passwords, keys or other sensitive content in a public issue.

## Watch app and home-screen widgets

The watch app, its complication, and the iOS and Android home-screen widgets
read a Monitor agent you deployed directly. They use a read-only credential that
Server Box mints for each surface. The credential can reach only the Monitor
metrics endpoints (`/api/v1/status`, `/api/v1/metrics` and
`/api/v1/metrics/history`); it cannot open a shell, execute commands or browse
files.

The credential is kept in the watch's own keychain, in a shared keychain group
on iOS, and encrypted under an AndroidKeyStore key on Android. A widget's
configuration list contains server names and Monitor addresses so you can pick a
server; its credential is kept separately in the platform credential store.
Servers are included automatically when they have a Monitor configuration. On
the watch, you can exclude individual servers in **Settings**; widgets publish
the Monitor-configured servers without a separate exclusion list. Excluding or
deleting a server revokes the watch or widget credential as soon as the app can
contact the Monitor agent.

## Platform stores

App Store and Google Play builds may also be subject to platform reporting.
Apple and Google collect that information under their own policies, not through
Server Box. See [Apple's privacy policy](https://www.apple.com/legal/privacy/)
and [Google's privacy policy](https://policies.google.com/privacy). The F-Droid
build has no store-provided crash-reporting channel, which is one reason its
default diagnostic level is **Nothing**.

## Children

Server Box is a server-administration tool and is not directed at children. It
does not knowingly collect information intended to identify children.

## Changes

If the collection arrangement changes materially, the diagnostics question is
shown again. A previous answer is not treated as consent to a materially
different arrangement.

## Contact

Open an issue at
[github.com/lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box/issues).
