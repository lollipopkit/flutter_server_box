---
title: 开发 Monitor 应用
description: 为 Monitor agent 构建和测试 Web 应用
---

Monitor 应用是位于 `store/apps/<publisher>.<name>/` 下的 Docker Compose 包。agent 会读取其中的
`manifest.toml` 和 Compose 文件，并在桌面中以窗口显示已安装的应用。

创建或修改应用时，请先阅读
[`serverbox-webapp` skill](https://github.com/lollipopkit/flutter_server_box/blob/main/.claude/skills/serverbox-webapp/SKILL.md)。
其中的[manifest 参考](https://github.com/lollipopkit/flutter_server_box/blob/main/.claude/skills/serverbox-webapp/references/manifest.md)
介绍了各个字段。供编辑器使用的 schema 位于
[`docs/schemas/monitor-app.schema.json`](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/schemas/monitor-app.schema.json)。
skill 中的 `scripts/validate.py` 还会检查 schema 无法表达的规则，并可执行 Compose 校验。

要在开发 agent 上试用应用，请将应用包放入某个目录，并在该 agent 的 `config.toml` 中将
`[stacks] local_apps` 指向包含 `<publisher>.<name>/` 文件夹的目录。例如：

```toml
[stacks]
local_apps = "/srv/sbm-apps"
```

修改本地应用包后，请重启 agent。App Store 会读取本地目录条目，因此可以安装并测试部署流程，
无需先将应用加入随 agent 附带的目录。若要校验 `store/apps/example.web`，请在仓库根目录运行：

```sh
python3 .claude/skills/serverbox-webapp/scripts/validate.py store/apps/example.web --compose
```
