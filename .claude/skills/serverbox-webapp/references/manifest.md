# Web app manifest reference

`store/apps/<id>/manifest.toml`, schema 1. The JSON Schema is
`docs/schemas/monitor-app.schema.json`; the agent's reader is
`monitor/src/stacks/manifest.rs`. Unknown tables and fields are errors.

## Folder

```
store/apps/<id>/
  manifest.toml        required
  compose.yaml         the compose files `[compose] files` names
  hwaccel.yml …        any other file a compose file uses (`extends`)
```

Plain files only (no folders, no links), names `[A-Za-z0-9][A-Za-z0-9._-]*`,
UTF-8, at most 256 KiB each, 1 MiB and 32 files in all. Every file but the
manifest is copied into the stack's directory, so compose files refer to each
other by bare name.

## Top level

| Field | Type | Notes |
|---|---|---|
| `schema` | `1` | |
| `id` | string | `^[a-z][a-z0-9-]{0,31}$`, equal to the folder's name. The compose project is `sbm-<id>` |
| `name` | string | The upstream project's name, 1–64 characters |
| `version` | string | The upstream release the files pin |
| `homepage`, `source` | https URL | `source` is where the service's code is |
| `glyph` | string | Material Symbols Rounded name |
| `tone` | enum | `berry soft ink sky teal violet amber leaf pale bright mist` |
| `categories` | enum[] | `photos media files documents productivity development ai home network monitoring security tools` |
| `notices` | enum[] | What the deploy dialog points out, below |
| `title`, `description` | text | Translations by locale (`en` required; `zh`, `zh-TW`, …). `title` names the window |

### `notices`

The agent shows these as plain notices; nothing is refused. List what the
compose files do:

| Notice | When |
|---|---|
| `pullsImages` | Always, for images from a registry |
| `bindsPaths` | A bind mount of a setting's path |
| `mountsHostFiles` | A bind mount of a host file or directory (`/etc/localtime`, `/usr/lib/wsl`) |
| `gpuDevices` | Devices or GPU reservations (`/dev/dri`, `driver: nvidia`) |
| `publishesPort` | A published port |
| `privileged` | `privileged: true` or `security_opt` unconfined |
| `hostNetwork` | `network_mode: host` |
| `dockerSocket` | The Docker socket is mounted |

## `[license]`

| Field | Notes |
|---|---|
| `spdx` | SPDX id (`AGPL-3.0`, `MIT`, …) |
| `url` | The licence text at the pinned version |
| `accept` | `true`: the admin must accept it before deploying. Use it for copyleft and anything with terms worth reading |

## `[requirements]`

All optional: `memory_min_mib`, `memory_recommended_mib`, `cores_min`, `arch`
(`amd64 arm64 arm`), `os` (`linux macos windows`). The agent compares them with
the machine and says what does not fit.

## `[compose]`

`files`: compose files in merge order (`-f` each). Leave out `name:` and
`container_name:`: the agent names the project, and a fixed container name
collides with a copy the user already runs.

## `[web]`

| Field | Notes |
|---|---|
| `port` | The key of the `port` setting the window reaches (the agent connects to it on loopback) |
| `path` | Where the window opens, default `/` |

## The env file

The agent writes `.env` in the stack's directory and runs
`docker compose --env-file .env`. Every value is written single-quoted
(`NAME='value'`), so no value may contain `'`, a line break or NUL. Each env
name is set by exactly one of:

- `[env]`: fixed values (`IMAGE_TAG = "v1.2.3"`).
- `[[secrets]]`: `env`, `length` (16–128, default 32). Generated once
  (alphanumeric), kept across updates, never shown in the panel.
- `[[settings]]`: what the deploy dialog asks, below.

Every variable a compose file needs (`${NAME}`, `$NAME`, `${NAME:?…}`) must be
set; `${NAME:-default}` and `${NAME-default}` may stay unset. `$$` is a literal
`$`. A container reads the env file only when its service says
`env_file: [.env]`.

## `[[settings]]`

Every setting has `key` (`^[a-z][a-z0-9_]{0,31}$`, unique), `type`, `label`
(text) and optional `help` (text).

### `path`

| Field | Notes |
|---|---|
| `env` | Gets the absolute path |
| `default` | Absolute, or `{stack}/…` (the stack's own directory) |
| `data` | `true` when it holds the service's data: removed only when the admin asks |

### `port`

| Field | Notes |
|---|---|
| `env` | Gets the port number |
| `default` | 1024–65535; the dialog offers the next free one when it is taken |

Publish it as `'${BIND}:${PORT}:<container port>'` with a `bool` setting for
`BIND`, so the default is loopback only (the window still reaches it).

### `bool`

| Field | Notes |
|---|---|
| `default` | `true`/`false` |
| `on`, `off` | Env values for each state; both set the same names |

### `choice`

| Field | Notes |
|---|---|
| `default` | One of the option values |
| `options` | At least two: `value` (`[A-Za-z0-9._-]`), `label` (text), `env` (every option sets the same names), optional `suggest` |

`suggest = { gpu = "nvidia" | "amd" | "intel", wsl = true | false }`: the first
option whose conditions all match the machine becomes the dialog's default.
Order options from most to least specific.

### `text`

| Field | Notes |
|---|---|
| `env` | Gets the text |
| `pattern` | A regular expression the whole value must match |
| `default` | Optional; must match |
| `optional` | `true`: left out of the env file when empty |
