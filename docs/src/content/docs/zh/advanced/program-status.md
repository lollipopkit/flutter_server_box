---
title: 程序状态
description: 查看终端中的程序何时正在等待你、已完成或执行失败
---

终端中运行的程序可以向 Server Box 报告自身状态：正在运行、等待你操作、已完成或执行失败。Server Box 会在终端名称旁显示状态；终端当前不可见时，也会发送通知。

服务器无需安装任何内容。程序只需向输出写入一段简短的 escape sequence，Server Box 就能通过 SSH、Monitor agent 的终端或本机终端接收它，就像接收其他终端输出一样。

## Server Box 读取的内容

| Sequence | 发送方 | 表示的状态 |
|---|---|---|
| OSC 7501 | 支持[程序状态协议](https://gist.github.com/mitchellh/7acae3abd8355c1c00287d67e96c913a)的程序 | `idle`、`working`（含进度）、`done`、`blocked`（等待批准、回答或登录）或 `error`，并附带标题和消息 |
| OSC 9;4 | systemd、winget 和其他显示进度条的程序 | 进度、失败、暂停 |
| OSC 133 | 集成了 shell integration 的 shell，例如 fish 4 | 命令已启动，或已结束并返回退出码 |

## 显示位置

- **终端名称前的状态点**：显示在终端标签页切换器、终端列表和侧边栏中。程序等待你操作时显示橙色，失败时显示红色，完成时显示绿色，运行时显示强调色（报告进度时显示为圆环）。程序仅处于空闲状态时不显示状态点。
- **终端栏中的状态按钮**：列出所有报告，首先是终端自身 shell 的报告，其后是每个 tmux pane 的报告。已完成或失败的报告会保留，直到程序更新报告或你在此处清除报告。
- **tmux**：窗口标记使用其 pane 中优先级最高的状态颜色；pane 菜单会显示各 pane 的报告。即使 pane 当前不在屏幕上，也会读取其报告。
- **通知**：终端当前不可见时，例如显示其他标签页或 App 在后台运行，程序开始等待、完成或失败时会显示通知。运行时间达到 30 秒的命令结束时也会显示通知。点击通知可打开对应终端。可在 **设置 → SSH → 程序需要你时通知** 中关闭此功能。
- Android 上的**持续通知**和 iOS 上的 **Live Activity** 会显示 session 中程序报告的状态，而不是地址。
- **Agent** 会结合屏幕内容读取这些报告，因此可以判断程序正在等待回答。
- **Monitor agent 的 Web panel** 会在终端上方显示优先级最高的报告。

## 在自有脚本中报告状态

报告格式为 `ESC ] 7501 ; key=value:key=value ESC \`，其中 `msg` 和 `title` 使用 base64 编码：

```sh
status() {
  printf '\e]7501;state=%s:msg=%s\e\\' "$1" "$(printf '%s' "$2" | base64 | tr -d '\n')"
}

status working 'Backing up /srv'
# ...
status done 'Backup finished'
```

`state=clear` 会移除报告。程序的 shell 显示下一个 prompt（启用了 shell integration 时）或 session 结束时，`working` 和 `blocked` 报告会被移除；`done` 和 `error` 报告会保留。多个报告、同一程序的报告 `id` 等完整规则见[规范](https://gist.github.com/mitchellh/7acae3abd8355c1c00287d67e96c913a)。

## tmux

Server Box 以 control mode 连接 tmux，tmux 会原样传递每个 pane 的输出，因此 tmux pane 中的报告无需额外设置。

Monitor agent 的 Web panel 会连接普通 tmux client。tmux 会丢弃它不识别的 sequence，因此只有启用 `allow-passthrough`（`set -g allow-passthrough on`），且程序为 tmux 封装报告（`ESC P tmux; …  ESC \`，并将其中每个 `ESC` 加倍）时，报告才会传到 panel。

程序查询终端是否支持报告（`OSC 7501 ; ?`）时，通过 tmux 无法收到应答，因为 tmux 会先响应后续查询。程序仍可发送报告。
