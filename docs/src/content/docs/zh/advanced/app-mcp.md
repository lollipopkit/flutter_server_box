---
title: App MCP
description: 通过 MCP client 访问本机、SSH 和 Monitor 主机，运行已保存的命令并修改 App 设置
---

打开 **设置 → AI → MCP Server**，点 **新建 token**，输入名称并保存随后显示的 token。启用服务后，MCP client 即可使用该 token 作为 Bearer 凭据连接到 `http://127.0.0.1:49762/mcp`。所有 token 都可以使用相同的工具和主机。要撤销某个 token，点它旁边的删除按钮，下一次请求起生效。

点 **监听** 可以调整地址和端口。选 **全部** 使用通配地址，选 **局域网** 可以指定 Wi-Fi、以太网或 Tailscale 等 VPN 接口上的一个 IP，选 **本机** 使用 loopback 地址。这些预设会保留当前端口。局域网预设保存的是选中的 IP，网络重新分配地址后需要重新选择。**自定义** 支持直接输入地址和端口，例如 `[::]:49762`。从其他设备连接时，请填写运行 ServerBox 的设备地址，例如 `http://192.168.1.20:49762/mcp`。监听服务使用 HTTP，远程连接请使用可信网络或 TLS 隧道。

使用 stdio 的 client 可以运行 `python3 /absolute/path/to/scripts/app-mcp-stdio.py`，通过环境变量 `SERVERBOX_MCP_TOKEN` 传入 token。如果目标地址与默认的 `127.0.0.1:49762` 不同，通过 `SERVERBOX_MCP_HOST` 和 `SERVERBOX_MCP_PORT` 指定。桌面自动化场景下，如果 App 尚未保存监听设置，可以用 `SERVERBOX_MCP_POLICY` 指定本机的配置文件。文件保存 token 摘要、名称和所有 client 共享的命令预设。例如：

```json
{
  "tokens": {"<token 的小写十六进制 SHA-256 摘要>": "Desktop"},
  "commands": {"uptime": "uptime"}
}
```

调用 `list` 可以查看 SSH、Monitor 和本机目标的 ID，以及可用的命令预设名称。本机目标 `#local` 在桌面端使用系统 shell，在 Android 使用 proot，在 iOS 使用已安装的 iul 环境。

向 `run_command` 传入 `host` 和 `preset`，即可通过主机首选的连接方式执行已保存的命令。SSH 会复用已有连接或使用已保存的配置连接。如果需要确认主机密钥、解锁私钥或回答交互式认证问题，请先在 ServerBox 中连接一次再重试。Monitor 使用自己的认证接口和访问规则。结果包含 stdout、stderr，以及可用时的退出码。stdout 和 stderr 合计最多 256 KiB，SSH 命令通道在 30 秒后关闭。Monitor 使用自己的执行超时，并报告输出截断或超时。删除所有预设后，`run_command` 将从工具列表中隐藏。

### 查看主机状态

以下工具只需传入从 `list` 获取的 `host`。命令在选中的目标上运行，返回 stdout、stderr 和退出状态。如果目标缺少相应程序或服务管理器，工具会返回错误。

| 工具 | 返回内容 |
| --- | --- |
| `machine_capabilities` | App 识别到的平台、已配置的连接方式和该平台可用的检查工具 |
| `machine_status` | 运行时长和负载，Windows 返回上次启动时间 |
| `machine_metrics` | 内存统计 |
| `storage` | 已挂载的文件系统和容量 |
| `processes` | 进程列表 |
| `services` | 系统服务管理器报告的服务 |
| `containers` | Docker 容器 ID、名称和状态 |
| `tmux` | Unix 主机上的 tmux 会话 |

用 `cpu`、`network` 和 `disk_io` 查看其他指标。向 `process_detail` 传入数字类型的 `pid` 可以查看单个进程。用 `images` 列出 Docker 镜像，再将完整镜像 ID 传给 `image_inspect` 或 `image_remove`，可以查看或删除该镜像。

### 修改 App 设置、管理容器和服务

`app_settings` 无需参数，会列出可修改的设置及其当前 JSON 值。`app_setting_set` 接收 `key` 和对应类型的 JSON `value`，写入 App 设置页使用的同一本地存储。两者都无需传入主机 ID。每项设置的类型、可选值和范围见工具的输入 schema。例如，可以将 `editorFontSize` 设为 `15.5`、`serverStatusUpdateInterval` 设为 `4` 秒、`motionPref` 设为 `"reduce"`、`trayMetrics` 设为 `["cpu", "disk"]`，或将 `distNameMap` 设为 `{"arch": "archlinux"}`。列表和映射通常整项替换。

`locale` 接受语言代码，`timeOut` 接受整数秒，`homeTabs` 接受按显示顺序排列的标签页名称。要修改当前平台的一项快捷键，将 `keybindings` 设为单条映射，例如 `{"settings.search":"Ctrl+Shift+F"}`。

向 `container_logs` 或 `container_stats` 传入 `host` 和从 `containers` 获取的容器 ID，可以读取最近 100 行日志或一次资源快照。`container_action` 还需传入 `action`，可选值为 `start`、`stop` 或 `restart`。

在使用 systemd 的 Linux 主机上，将 `services` 返回的单元名（例如 `demo.service`）作为 `key`，连同 `host` 传给 `service_logs`，即可读取最近 100 条 journal 记录。`service_action` 支持 `start`、`stop` 和 `restart`，主机账户需要具备执行相应操作的权限。
