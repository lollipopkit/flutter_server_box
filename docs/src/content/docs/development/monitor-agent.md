---
title: Monitor Agent API and Access Model
description: Capability reporting, metrics history, and remote access behavior
---

This page documents the API behavior the App relies on when connecting to
Monitor agent. For installation and operator configuration, see
[Monitor Agent](/docs/advanced/monitor-agent/).

## Capability discovery

The App calls `GET /api/v1/capabilities` to learn which features an agent
supports and which remote access features are enabled. The App uses this
response to decide which controls to show. In particular, terminal features
depend on `[remote_access.terminal]` and `full_access`, while file browsing
depends on `[remote_access.fs]` and its configured roots.

Do not infer feature availability from the agent version or configuration
defaults. Use the capabilities response from the running agent.

## Metrics history contract

The capabilities response reports:

- `retention_days`: the configured retention limit from
  `[monitoring.data_retention] metrics_days`.
- `oldest_sample`: the timestamp of the oldest metrics sample currently
  stored.

The App offers preset chart ranges that fit within the later boundary implied
by retention and the oldest sample. It displays both values in the range
picker. Older agents that do not report retention use the fixed chart ranges.

The App can request an exact interval with:

```text
GET /api/v1/metrics/history?from=<epoch-seconds>&to=<epoch-seconds>
```

If `from` precedes the oldest retained sample, the agent returns the available
rows. It does not shift the requested start time or return an error. The chart
represents the missing interval as a gap. The older `?minutes=` parameter
remains supported for agents that predate `from` and `to`.

## Remote access capability model

`full_access` is gated by `[remote_access.terminal] enabled`. It grants
authenticated users access to a shell as the agent process user. The App uses
that grant for process, systemd, container, snippet, power-control, terminal,
and remote desktop features. Remote desktop connects from the agent host to
the target through `/api/v1/stream/ws`; it has no separate permission because
shell access already allows port forwarding.

The setting defaults to enabled on Linux and disabled on macOS and Windows.
The panel can turn it off, but enabling it again requires editing
`config.toml`.

### File API

`[remote_access.fs]` is independent of `full_access`. It grants access only to
the directories listed in `roots`. The agent resolves requested paths,
follows symlinks, rejects `..`, and verifies that the resolved path remains
under a configured root. A symlink cannot be used to escape those roots.
Setting `roots = ["/"]` exposes the complete filesystem and triggers a startup
warning.

The file API is unavailable to plaintext network callers unless
`[remote_access.fs] allow_insecure = true`. Loopback requests, including those
from a same-host reverse proxy, are treated as secure. If neither TLS nor the
opt-in is present for a network caller, capabilities report file access as
unavailable and the App hides the related controls.

### Terminal endpoint

`[remote_access.terminal]` enables terminal access for the App and web panel.
The web-panel terminal connects to `ssh_addr` as an SSH client and uses the
SSH account's permissions. The App terminal uses the agent process user's
local shell when `full_access` is enabled.

The terminal endpoint refuses plaintext HTTP by default because its first
message may contain an SSH password. For a plaintext connection,
`[remote_access.terminal] allow_insecure = true` must be set in the agent, and
the App must also allow insecure HTTP for that server. Loopback requests,
including those from a reverse proxy on the same host, do not require this
opt-in. TLS or a same-host TLS-terminating reverse proxy is preferred.
