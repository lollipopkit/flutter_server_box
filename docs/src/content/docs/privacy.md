---
title: Privacy Policy
description: What Server Box stores, what it sends, and how to control those choices
---

Last updated: 2026-08-30.

Server Box is a client for the servers you configure. It has no user account and
no developer-operated relay for SSH, SFTP, or Monitor traffic. Those connections
go from the app to the endpoint you selected.

The app does make separate requests for diagnostics and for features you use.
Their destinations and payloads are described below. Server Box contains no ads,
advertising identifiers, or cross-app tracking.

## Data stored on this device

| Data | Storage and behavior |
|---|---|
| Server names, addresses, ports, usernames and settings | Encrypted SQLite database |
| SSH passwords, private keys, Monitor and BMC credentials, and the configured AI API key | Encrypted SQLite database; its encryption key is kept in the platform keychain |
| Backup password, WebDAV password and GitHub token | Platform secure storage |
| App logs | Local log files only; the current and previous log are kept for troubleshooting |
| Agent conversations | Local database; they can contain prompts, model responses, command output, selected terminal text and file content |
| Ordinary terminal output | Kept in the active session; the terminal itself does not save it after the session ends |

Agent conversations are deliberately excluded from backups and device sync, but
they remain on this device until you delete them from the conversation history.
An Agent conversation can still be sent to the AI provider you configured; see
[AI requests](#ai-requests).

Backups are created only when you request one. Depending on the options and the
backup format, a backup can contain server settings and credentials, private
keys, snippets, port forwards, container settings, connection history and app
settings. This includes the configured AI endpoint, model and API key when app
settings are included. Agent conversations and device-local bookkeeping are not
included.

A local backup may be unencrypted when no backup password is set. When you set a
backup password, the backup is encrypted before it is written or uploaded.
Automatic remote backup requires a non-empty backup password. After a backup is
sent to iCloud, WebDAV or GitHub Gist, that provider's storage, access and
retention rules also apply.

## Automatic diagnostic data

Automatic diagnostics are the only data Server Box sends to the developer. The
choice is shown on the intro page before the first upload and can be changed at
any time in **Settings → Diagnostic data**.

| Level | What is sent automatically |
|---|---|
| **Nothing** | Nothing. Local logs remain on this device, and you can still prepare a manual report. |
| **Basic information** | Captured crashes and errors, together with the build information and deliberately recorded diagnostic breadcrumbs that provide context for the error. Nothing is sent continuously while the app is operating normally. |
| **Full information** | Everything in Basic, plus performance traces when available and coarse counts of feature use while the app runs. |

The Android default is **Nothing**. The iOS, macOS, Linux and Windows defaults
are **Basic information**. Where automatic diagnostics is available, the intro
page is shown before the first automatic upload.

Changing the level to **Nothing** removes the upload sink immediately; it does
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
- Structured breadcrumbs such as the transport used, the kind of terminal or
  file backend, and whether an operation succeeded

Breadcrumbs are fixed action names with coarse or redacted values. They do not
include terminal output, file contents, passwords or private keys as diagnostic
fields. The app's ordinary log stream is never uploaded at any level.

An error message or stack trace comes from the underlying library and may contain
text that the app did not create. Server details can therefore not be ruled out
for every possible exception. Read any manual report before publishing it, and
do not treat automatic diagnostics as a guarantee that arbitrary exception text
is anonymous.

### What Full information adds

Full information sends performance traces such as how long connecting to a
server or listing a directory took, not the contents of those operations. It
also turns the same structured breadcrumbs into coarse feature-use events, for
example that a terminal was opened or that SFTP was used instead of SCP. These
events do not include prompts, terminal output, file contents, keystrokes or
screen recordings.

Feature-use events are sent only when the build has an analytics endpoint
configured. A random 128-bit install identifier is used to keep one install's
events in order and to keep an experiment assignment stable between launches.
The identifier exists only while Full information is selected: it is created
when Full is enabled, deleted when you leave Full, and stored outside the backup
file. It is not derived from a device identifier, account or hardware value.

When Full information is active and an experiment is configured, the app may ask
which variant applies to this install. Experiments only change wording, order or
a default; they do not decide whether a feature exists, what is stored, or how
a server is reached.

## Redaction and manual crash reports

Structured diagnostic breadcrumbs are made safe before they reach a reporting
sink. They use fixed action names and stand-ins for server-related values rather
than recording a server name, address or username directly.

A manual report is different. After a crash, Server Box can show the previous
run's log and any platform crash or hang trace, replace known configured server
values where it can, copy the result to the clipboard and open a GitHub issue
page. Nothing is posted automatically: you decide whether to copy or submit it,
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

Depending on the operation, a request can contain your prompt, the selected
terminal text, recent conversation history, the configured server name, and
context needed for the Agent to work. After a command or file operation, its
result can be sent in a later request so the model can continue. Command output
or file content may contain secrets even when Server Box did not add them
itself; check what you submit and review the provider's privacy policy.

The API key is stored locally in the encrypted app database. It is sent as a
bearer credential to the endpoint you configure. The endpoint, model and API
key are included in app settings when you choose to include app settings in a
backup. Server Box does not proxy AI requests through a developer service.

## Other network requests

These requests are made only for the corresponding feature and do not carry the
automatic diagnostic payload described above.

| Request | Destination | When and what it carries |
|---|---|---|
| AI request | The endpoint configured by you | When you send an Agent message; see [AI requests](#ai-requests) |
| Backup or sync | iCloud, your WebDAV server, or GitHub Gist | When you create, restore or sync a backup; it carries the selected backup file |
| Update check | `api.github.com` | On launch when automatic update checks are enabled |
| Linux userland manifest | `github.com` | At launch or when the manifest is refreshed; it contains release metadata and signatures |
| Linux userland images | The distribution mirror named by the verified manifest | When you install or update a local Linux environment; the image is checked against the manifest's digest |
| Server logo or distribution mark | The URL configured by you | When a custom logo or mark URL is set; the image provider can receive the request |
| Sponsor link | `cdn.lpkt.cn` | When you open the sponsor link |
| Documentation and issue links | `serverbox.lollipopkit.com` or `github.com` | When you open one of those links |

Connections to your own servers, to a BMC you configured, and to a Monitor
agent you deployed go to those endpoints. They are not routed through the
developer's infrastructure.

## Where diagnostic data goes

Error reports and performance traces go to the Sentry-compatible server operated
by the developer at `sentry.lollipopkit.com`. Full-information feature-use
events go only to an analytics endpoint supplied by the build; a build without
such an endpoint sends no feature-use events.

Diagnostic data is not used for advertising, shared with other companies, or
used to track you across apps or websites. The service may retain reports for as
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
on iOS, and encrypted under an AndroidKeyStore key on Android. The widget's
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
