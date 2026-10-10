---
name: serverbox-webapp
description: Adapt a self-hosted web service (Immich, Jellyfin, Paperless-ngx, Vaultwarden, …) into a ServerBox Monitor web app — a folder in `store/apps/<id>/` with a `manifest.toml` and the Docker Compose files the agent deploys — then validate it and propose it for the catalog. Use this whenever someone wants to add, port, update, fix or validate an app for the Monitor's app catalog, including requests that never say "manifest", such as "add Jellyfin to the monitor", "make the monitor able to install Nextcloud", "bump Immich to the new release", "why does my web app fail validation", or "turn this docker-compose.yml into a monitor app".
---

# ServerBox Monitor web apps

A web app is a web service the Monitor agent deploys with Docker Compose and
the panel's desk shows in a window. Its source is one folder:

```
store/apps/<id>/
  manifest.toml        what it is, its licence, and the env file it needs
  compose.yaml         the compose files the manifest names
  …                    any other file they use (extends)
```

The agent copies the folder (minus the manifest) into the stack's directory,
writes `.env` from the manifest and the deploy dialog's answers, and runs
`docker compose -p sbm-<id> --env-file .env -f …`. The window reaches the
service on loopback at the port setting `[web] port` names.

`store/apps/immich` is the worked example: Immich's release compose file,
adjusted as below, with GPU acceleration choices.

## Workflow

### 1. Start from upstream's compose file

Take the compose file the project publishes **for the release you pin**
(release assets beat `main`). Write down its version, licence and homepage.
If the licence is copyleft or has terms worth reading, set
`[license] accept = true` so the admin accepts it before deploying.

Copying upstream files is fine when their licence allows it (most do); keep a
header comment saying where each file came from, which release, and what was
changed. Files copied unchanged say so.

### 2. Adjust the compose file

- Remove `name:` and every `container_name:` — the agent names the project,
  and fixed names collide with a copy the user already runs.
- Pin images to the release (`image: org/app:${APP_VERSION}` with
  `APP_VERSION` in `[env]`), or by digest for supporting images.
- Turn every value the user should choose into a `${VARIABLE}`: data paths,
  the published port, hardware acceleration. Publish the web port as
  `'${BIND}:${PORT}:<container port>'` so it can stay on loopback.
- Keep upstream's structure otherwise (`extends`, healthchecks,
  `env_file: [.env]`): a later release is then a small diff.

### 3. Write the manifest

Copy `assets/manifest.template.toml` to `store/apps/<id>/manifest.toml`. Its
first line is a schema directive, so editors with Taplo/Even Better TOML/Tombi
check it as you type. Every field is in `references/manifest.md`.

- One `[[settings]]` per thing the deploy dialog should ask, each writing env
  values: `path` (data directories, `default = "{stack}/…"`, `data = true` for
  data), `port`, `bool` (`on`/`off` values), `choice` (options with env values
  and `suggest` for GPUs), `text` (with a `pattern`).
- `[[secrets]]` for passwords the service needs: generated once, never shown.
- `[env]` for fixed values.
- Every env name comes from exactly one of those, and every `${VARIABLE}` a
  compose file needs must be one of them.
- `notices`: what the compose files do that an admin should know (bind
  mounts, devices, published ports, `privileged`, host network, the Docker
  socket). They are shown, never refused — say what is there.
- `title` names the window in the user's words ("Photos"), `name` is the
  upstream project ("Immich"). Don't use upstream logos; `glyph` is a
  Material Symbols name.

### 4. Validate

```sh
python3 <skill>/scripts/validate.py store/apps/<id> --compose
```

It checks the manifest against the published JSON Schema (via
`uvx`/`pipx` `check-jsonschema`; pass `--schema docs/schemas/monitor-app.schema.json`
inside the repository to use the local copy), then the rules only the agent
knows (files, env names, defaults, compose variables), and with `--compose`
runs `docker compose config` over the stack with the defaults' env file.
Fix every error; read the warnings. Inside the repository also run:

```sh
cargo test -p server_box_monitor --lib stacks::
```

which reads every folder in `store/apps/` with the agent's own reader.

### 5. Try it

On a Linux machine with Docker: copy the folder (without the manifest),
write a `.env` like the validator's (`--compose` builds one from the
defaults), `docker compose -p sbm-<id> --env-file .env -f compose.yaml up -d`,
and open the port. Check first-run steps (an admin account to create, a
setup wizard) and mention them in `description` if the window would
otherwise look broken. `docker compose … down` when done.

### 6. Propose it

Open a pull request against `lollipopkit/flutter_server_box` adding the
folder. Say in the description which release it pins, where each file came
from, and that you deployed it (step 5). An update to a new upstream release
changes `version`, the pinned images and whatever the release's compose file
changed.
