---
title: App MCP
description: 通过 MCP client 访问 ServerBox 管理的所有服务器，工具和 token 模型与 Monitor 一致
---

App 提供的 MCP server 与 [Monitor](/zh/development/monitor-agent/#api-tokens-and-mcp) 是同一套实现，覆盖 App 能连接的每台服务器：工具、返回结构、token 格式和 scope 都相同。针对某台服务器的工具都带 `host` 参数，取值为 `list` 返回的 id。

## 设置

打开 **设置 → AI → MCP Server**。选择 **新建 token**，填写名称并选择 scope，然后保存显示的 token：它只显示一次。打开开关后，以 Bearer 凭据连接 `http://127.0.0.1:49762/mcp`。删除 token 即撤销，下一次请求就会被拒绝。

选择 **监听** 可修改地址和端口。**全部** 监听通配地址，**局域网** 监听 Wi-Fi、以太网或 Tailscale 等 VPN 接口上的某个 IP，**本机** 监听回环地址。局域网会保存所选 IP；网络分配了新地址时需要重新选择。**自定义** 接受 `[::]:49762` 这样的地址和端口。

回环地址使用 HTTP。局域网和通配监听要求 TLS：把 PEM 证书链和私钥放在注册表旁边，文件名在注册表文件名后加 `.crt` 和 `.key`（默认为 `app-mcp.json.crt` 和 `app-mcp.json.key`）。iOS 上需要把两者放进同一个无密码的 PKCS#12 文件，后缀为 `.p12`。请限制私钥的访问权限，并使用证书中的域名或 IP 连接。也可以只监听回环地址，通过经过认证的 SSH 隧道访问。

stdio client 可运行 `python3 /absolute/path/to/scripts/app-mcp-stdio.py`，并在 `SERVERBOX_MCP_TOKEN` 中提供 token。目标不是 `127.0.0.1:49762` 时，设置 `SERVERBOX_MCP_HOST` 和 `SERVERBOX_MCP_PORT`。bridge 会校验远程 HTTPS 证书；使用私有 CA 时，把 `SSL_CERT_FILE` 设为其 PEM 文件。要连接回环 IP 上的 TLS 监听，设置 `SERVERBOX_MCP_SCHEME=https`。

## Token 和 scope

token 为 `sbt_` 加 64 位十六进制字符，注册表文件中只保存它的 BLAKE3 摘要（默认是 App 文档目录下的 `app-mcp.json`；桌面自动化在没有保存监听设置时可用 `SERVERBOX_MCP_POLICY` 指定其他文件）。每次请求都会重新读取注册表，因此可以手动编辑：

```json
{
  "policy": {
    "scopes": ["read", "exec", "service"],
    "commands": { "mode": "allow_all", "deny": ["rm -rf *"] }
  },
  "tokens": [
    {
      "id": "<token 的小写 BLAKE3 摘要>",
      "name": "Desktop",
      "scopes": ["read"],
      "commands": { "mode": "allowlist", "allow": ["uptime", "df *"] },
      "created_at": 0
    }
  ]
}
```

省略 `scopes` 表示拥有全部 scope，包括以后版本新增的 scope。token 的权限是它自己的 scope 与 policy scope 的交集；`run_command` 需要同时通过两层命令规则。命令规则使用 Agent 的匹配语法，与 Monitor 相同。

| Scope | 工具 |
| --- | --- |
| `read` | `list`、`machine_capabilities`、`processes`、`services`、`containers`、`tmux`、`app_settings` |
| `exec` | `run_command` |
| `process` | `kill_process` |
| `service` | `service_action` |
| `container` | `container_action` |
| `settings` | `app_setting_set` |

## 工具

`list` 返回每台服务器的 id、名称、是否已连接以及连接方式（`ssh`、`monitor`、`local`）。id 是 App 内部服务器 id 的摘要。开启 **设置 → AI → 在本机执行命令** 后，列表中会包含本机。

调用经由 App 自己的连接方式到达服务器：SSH（复用已打开的连接，或按保存的配置连接，包括跳板机和 `ProxyCommand`）、Monitor 或本机。需要确认主机密钥、输入私钥 passphrase 或回答 keyboard-interactive 问题时，调用会失败，且不计入该服务器的重连次数限制；在 App 中连接这台服务器后再调用即可。

`processes`、`services`、`containers`、`tmux`、`kill_process`、`service_action` 和 `container_action` 的参数和返回结构与 Monitor 相同。`machine_capabilities` 返回服务器的平台和连接方式；App 尚未读取过该服务器时，会先探测平台。

`run_command` 接受 `host` 和 `command`，返回 `exit_code`、`stdout`、`stderr`、`truncated` 和 `timed_out`。命令在该账户自己的 shell 中执行。输出最多保留 256 KiB，命令超过 30 秒会被终止；Monitor 还会应用它自己的限制。

`app_settings` 列出 App 可编辑的设置及当前值。`app_setting_set` 接受 `key` 和类型匹配的 `value`（见工具的输入 schema），写入与设置页相同的存储。例如把 `editorFontSize` 设为 `15.5`、`motionPref` 设为 `"reduce"`、`trayMetrics` 设为 `["cpu", "disk"]`，或把 `keybindings` 设为 `{"settings.search": "Ctrl+Shift+F"}`。数组和映射会整体替换原设置。
