# Web app manifest reference

`store/apps/<publisher>.<name>/manifest.toml`, schema 1. The JSON Schema is
`docs/schemas/monitor-app.schema.json`; the agent's reader is
`monitor/src/stacks/manifest.rs`. Unknown tables and fields are errors.

## Folder

```
store/apps/<publisher>.<name>/
  manifest.toml        required
  compose.yaml         the compose files `[compose] files` names
  hwaccel.yml …        any other file a compose file uses (`extends`)
  app.Dockerfile       a Dockerfile a service is built from (`build:`)
```

Plain files only (no folders, no links), names `[A-Za-z0-9][A-Za-z0-9._-]*`,
UTF-8, at most 256 KiB each, 1 MiB and 32 files in all. Every file but the
manifest is copied into the stack's directory, so compose files refer to each
other by bare name.

## Top level

| Field | Type | Notes |
|---|---|---|
| `schema` | `1` | |
| `publisher` | string | `^[a-z][a-z0-9_]{1,23}$`: who makes the service (`futo`) |
| `name` | string | `^[a-z][a-z0-9_]{0,23}$`: the app's name within its publisher (`immich`) |
| `project` | string | The upstream project's name as shown (`Immich`), 1–64 characters |

The app's id is `<publisher>.<name>` (`futo.immich`), never written in the
file: the folder's name, the panel's and the API's name for the app. The
compose project is `sbm-<publisher>-<name>`. Every app has one, the panel's
own (`serverbox.*`) and desk packages too.
| `version` | string | The upstream release the files pin |
| `developer` | string | Optional: who makes the service (`Immich (FUTO)`), 1–128 characters. Shown in the confirmation before deploying |
| `homepage`, `source` | https URL | `source` is where the service's code is |
| `glyph` | string | Material Symbols Rounded name |
| `tone` | enum | `berry soft ink sky teal violet amber leaf pale bright mist` |
| `categories` | enum[] | `photos media files documents productivity development ai home network monitoring security tools` |
| `recommended` | bool | Optional, off by default: a few apps the desk's first-run guide offers. Leave it out of an app you are adding |
| `notices` | enum[] | What the deploy dialog points out, below |
| `title`, `description` | text | Translations by locale (`en` required; `zh`, `zh-TW`, …). `title` names the window: the project's own name (`Immich`), `en` only |

### What the admin confirms

Before deploying, the panel shows the project (`name`, `developer`,
`version`, `homepage`, `source`), its licence, the images the compose files
will pull with the chosen settings, the data folders, the port and the
notices, and says the service is third-party. The admin ticks that they
understand this installs third-party software (always) and that they accept
the licence (when `license.accept`); the agent refuses a deploy without
either.

### `notices`

The agent shows these as plain notices; nothing is refused. List what the
compose files do:

| Notice | When |
|---|---|
| `pullsImages` | Always, for images from a registry |
| `buildsImages` | A service is built from a Dockerfile in the package (`build:`); required then |
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

`jobs` (optional): services that run once and exit, such as a database
migration. The agent watches every deployed app's containers and tells the
admin when one stops; a job exited with 0 is done, not down. Give services a
`healthcheck` where the image allows: the panel shows it as the app's
health.

### Building an image

Only when no maintained image exists (upstream publishes none, or the one there
is sits on an end-of-life base). A service then names a Dockerfile of the
package and a `localhost/` image:

```yaml
  app:
    image: localhost/<publisher>-<name>:${APP_VERSION}
    build:
      context: .
      dockerfile: app.Dockerfile
      args:
        APP_VERSION: ${APP_VERSION}
```

- `build:` is a mapping naming `dockerfile:`, a file of the package;
  `context` is `.` or left out. `additional_contexts` and `dockerfile_inline`
  are refused.
- The image is `localhost/…` exactly when it is built: the agent pulls every
  other image (`pull --ignore-buildable`), then builds (`build --pull`, so an
  update gets the base's fixes), then starts.
- The context is the stack's folder, which holds the env file: the agent writes
  a `.dockerignore` of `*` there, so nothing of it reaches the build. A file
  the image needs goes inline (`COPY <<EOF /path`), and no package file may be
  named `*.dockerignore`.
- `notices` carries `buildsImages`. The deploy dialog lists the built images
  apart, and the `FROM` images among those pulled.
- The Dockerfile pins its base (`alpine:3.24`, the newest release), downloads
  over HTTPS only, and checks every download against a SHA-256 written in the
  Dockerfile.

## `[web]`

| Field | Notes |
|---|---|
| `port` | The key of the `port` setting the window reaches (the agent connects to it on loopback) |
| `path` | Where the window opens, default `/` |
| `basic_auth` | `true` when the service asks for HTTP basic auth (Transmission): a browser cannot answer that inside the desk's frame, so the agent's proxy sends `[login]`'s `user` and `password` itself, server side. Needs both in `[login]`; a direct visit to the published port still asks |

## `[login]`

How the admin signs in the first time; the panel shows it in the app's
details, the password only when the admin asks (and re-enters their own).

| Field | Notes |
|---|---|
| `user` | Optional: the account the service is seeded with |
| `password` | Optional: the env name of a `[[secrets]]` entry holding its password |
| `note` | Optional text: anything else, such as "create the first account in the browser" |

At least one field. Seed the admin from env or config where the service
allows it, so the first sign-in needs no wizard; where it only makes its
first account in the browser, leave out `user`/`password` and say so in
`note`.

## `[[mcp]]`

The app's MCP servers (Streamable HTTP), which Agent mode connects to once
the app is deployed. At most 4.

| Field | Notes |
|---|---|
| `port` | The key of the TCP port setting it listens on; Agent mode reaches it at `http://127.0.0.1:<port><path>` |
| `path` | Its URL path (`/api/mcp`, `/mcp`) |
| `publisher` | `builtin` (the service's own), `official` (its makers, apart from it) or `community` (third-party code holding the service's credential; the deploy dialog says so) |
| `service` | A sidecar's compose service; not for `builtin` |
| `source` | Where a sidecar's code is (https); not for `builtin` |
| `auth` | Optional: `header` (default `Authorization`), `scheme` (`Bearer`), and one of `secret` (a `[[secrets]]` entry: connects on its own), `asked` (text: where the admin makes a token once the service is set up) or `oauth = true` |

A sidecar joins the app's compose file:

- its image pinned by digest (`ghcr.io/…/mcp@sha256:…`), so what holds the
  credential never changes under the app;
- its own port setting, published on `127.0.0.1` alone
  (`"127.0.0.1:${MCP_PORT}:8080"`): it answers anyone who reaches it with the
  service's credential;
- the service by its compose name on the stack's network
  (`http://app:8080`), and the credential from the env file.

Prefer a credential the agent knows at deploy (`secret`: a key the service
reads from env, a password it is seeded with); `asked` when only the service
can make one.

## The env file

The agent writes `.env` in the stack's directory and runs
`docker compose --env-file .env`. Every value is written single-quoted
(`NAME='value'`), so no value may contain `'`, a line break or NUL. Each env
name is set by exactly one of:

- `[env]`: fixed values (`IMAGE_TAG = "v1.2.3"`).
- `[[secrets]]`: `env`, `length` (16–128, default 32). Generated once
  (alphanumeric), kept across updates, never shown in the panel.
- `[[settings]]`: what the deploy dialog asks, below.

The agent also writes, for every app (a manifest uses them and never sets
them):

| Name | Value |
|---|---|
| `SBM_UID`, `SBM_GID` | The owner of the shared folder (`{shared}`): run as them (`PUID`/`PGID`, or `user: "${SBM_UID}:${SBM_GID}"`), so what one app writes the others read |
| `SBM_TZ` | The host's time zone (IANA name), for `TZ` |
| `SBM_RENDER_GID` | The group of the GPU render node (`/dev/dri/renderD128`), `SBM_GID` without one: `group_add` it for a service that is not root and is given `/dev/dri` |

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
| `default` | Absolute, `{stack}/…` (the stack's own directory) or `{shared}/…` (the folder every app shares, `[stacks] shared_dir`) |
| `data` | `true` when it holds the service's data: removed only when the admin asks. Never for `{shared}` |

The shared folder's subfolders, so a downloader's files are a media
server's library: `downloads`, `media/movies`, `media/tv`, `music`, `books`,
`comics`, `documents`. Mount them `:ro` where the app only reads.

### `port`

| Field | Notes |
|---|---|
| `env` | Gets the port number |
| `default` | 1–65535; the dialog offers the next free one when it is taken |
| `protocol` | `tcp` (default), `udp` or `both`: which the port is checked for. The window's port (`[web] port`) is TCP |

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
