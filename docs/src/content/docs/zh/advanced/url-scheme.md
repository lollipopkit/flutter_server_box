---
title: 链接(serverbox://)
description: 通过链接打开服务器、功能、标签页或代码片段
---

ServerBox 支持在 iOS、macOS 和 Android 上打开 `serverbox://` 链接。你可以从快捷指令、启动器、笔记或网页中使用这些链接。

Windows 和 Linux 不支持这些链接。

## 获取链接

- **服务器**：在列表中长按（或右键点击）服务器 → **复制链接**。
- **代码片段**：打开代码片段 → 顶栏的链接按钮。

服务器和代码片段用 id 标识，不用名称：名称可以重复，也可能被修改。

## 链接格式

| 链接 | 打开 |
| --- | --- |
| `serverbox://server/<id>` | 服务器页面 |
| `serverbox://server/<id>/<function>` | 服务器的某个功能 |
| `serverbox://tab/<tab>` | 某个标签页 |
| `serverbox://snippet/<id>` | 代码片段，打开后选择服务器 |
| `serverbox://snippet/<id>?server=<id>` | 代码片段，在指定服务器上 |
| `serverbox://add-server?host=…&port=…&user=…&name=…` | 预填好的新增服务器表单 |

`<function>` 可选：`terminal`、`files`、`container`、`process`、`snippet`、`iperf`、`systemd`、`portForward`、`power`、`users`、`scheduledTasks`、`remoteDesktop`、`firewall`。

`<tab>` 可选：`server`、`ssh`、`file`、`snippet`、`agent`、`benchmark`、`remoteDesktop`、`virt`。

`add-server` 只有 `host` 是必填的。

## 链接能做什么

任何网页或 App 都可以打开链接。链接触发的操作与在 App 中点击相同，也会经过相同的确认步骤：

- 代码片段运行前一定会显示内容并要求确认。
- `add-server` 只会预填表单，保存前不会创建服务器。链接不接受密码或私钥，因为链接可能留在浏览器历史记录或剪贴板管理器中。
- 电源操作运行前会询问，与服务器页面上的行为一致。

App 处于锁定状态时，链接会等到解锁后再处理。
