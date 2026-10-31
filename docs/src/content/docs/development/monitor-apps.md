---
title: Developing Monitor Apps
description: Build and test web apps for the Monitor agent
---

Monitor apps are Docker Compose packages under `store/apps/<publisher>.<name>/`.
The agent reads their `manifest.toml` and Compose files, and the desk shows
installed apps in a window.

Start with the [`serverbox-webapp` skill](https://github.com/lollipopkit/flutter_server_box/blob/main/.claude/skills/serverbox-webapp/SKILL.md)
when creating or changing an app. Its
[manifest reference](https://github.com/lollipopkit/flutter_server_box/blob/main/.claude/skills/serverbox-webapp/references/manifest.md)
describes each field. The editor schema is
[`docs/schemas/monitor-app.schema.json`](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/schemas/monitor-app.schema.json);
the skill's `scripts/validate.py` also checks rules that the schema cannot
express, and can run Compose validation.

To try an app on a development agent, place its package in a directory and set
`[stacks] local_apps` in that agent's `config.toml` to the directory containing
the `<publisher>.<name>/` folder. For example:

```toml
[stacks]
local_apps = "/srv/sbm-apps"
```

Restart the agent after changing a local package. The App Store reads the local
catalog entry, so you can install it and test the deploy flow without adding it
to the shipped catalog. For a package at `store/apps/example.web`, validate it
from the repository root with:

```sh
python3 .claude/skills/serverbox-webapp/scripts/validate.py store/apps/example.web --compose
```
