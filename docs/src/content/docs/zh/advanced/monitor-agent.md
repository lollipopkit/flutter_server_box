---
title: Monitor Agent
description: 通过 Monitor agent 访问服务器
---

Server Box Monitor 是安装在服务器上的轻量级监控服务。App 通过 HTTP 与它通信，因此可以在不开放 SSH 端口的情况下访问服务器。Monitor agent 也是推送告警、主屏幕小组件和 Watch App 获取数据的基础；这些功能可以在 App 未打开时继续工作。

## 选择 SSH 还是 Monitor agent

| | SSH | Monitor agent |
|---|---|---|
| 需要在服务器上安装额外软件 | 否 | 是 |
| 查看状态和图表 | 支持 | 支持 |
| 查看 App 连接前的历史数据 | 不支持 | 支持 |
| 终端、命令和文件浏览 | 支持 | 取决于 agent 开启的功能 |
| SFTP 传输和端口转发 | 支持 | 不支持 |
| 推送告警、主屏幕小组件和 Watch App | 不支持 | 支持 |

通常直接使用 SSH 即可。以下情况适合使用 Monitor agent：SSH 端口从当前网络不可达；希望在打开 App 前就有历史图表；或者希望接收服务器告警。

两种方式可以同时使用：服务器可以在 App 中配置 SSH，同时运行 Monitor agent 为主屏幕小组件和 Watch App 提供数据。

## 安装 Monitor agent

如果仓库已有 `monitor-v*` release，可以从发布页下载；否则请自行构建。发布 workflow 需要手动触发。未发布版本或离线安装时，请使用本地构建包和 `SBM_INSTALL_PKG`。

安装脚本会自动识别 init 系统：

```sh
# systemd：安装为 `systemctl --user` 服务，以当前用户运行
./install.sh install

# 没有可下载的 release，或进行离线安装
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install

# OpenRC（Alpine）：写入 /etc/init.d 需要 root，但 agent 仍以执行 sudo 前的用户运行
sudo ./install.sh install
```

默认情况下，agent 以普通用户运行。这样可以限制 `full_access` 开启时的权限范围，详见[权限开关](#权限开关)。

配置文件位于二进制文件旁边的 `config.toml`。所有配置项都在 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml) 中说明。agent 默认监听 `0.0.0.0:3770`；如果存在 `frontend/dist`，还会在该地址提供网页面板。

如果 agent 需要从其他设备访问，请使用 HTTPS：可以配置内置 TLS（`[server.tls]`），也可以放在反向代理后面。App 支持自签名证书，但必须由你明确开启相关选项。

## 在 App 中添加

1. 点击 **+** 添加服务器。
2. 打开 **Monitor HTTP** 开关。
3. 填写：
   - **URL**：例如 `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**：agent 网页面板的登录凭据
   - **Monitor Ignore certificate**：仅在使用自签名证书时开启
4. 保存配置。

通过 Monitor HTTP 添加的服务器**不包含 SSH 凭据**。除了 agent 明确提供的功能外，App 没有其他方式访问这台服务器。

## 权限开关

agent 会通过 `GET /api/v1/capabilities` 告诉 App 当前允许的功能，App 只显示这些功能。网页面板中的文件 API 和终端默认关闭，只能由运维人员在 `config.toml` 中开启。

**状态、图表和历史数据**只需要面板登录凭据。

**`full_access`** 允许已登录用户直接获得 agent 所属用户的 shell，并执行命令。因此，进程、systemd 单元、容器、代码片段、电源控制和终端等功能都依赖它。

`full_access` 只有一个开关：能获得 shell 的用户也能在 shell 中执行任意命令，因此无法通过单独关闭“命令”来缩小权限范围。Linux 默认开启，macOS 和 Windows 默认关闭。面板可以关闭它，但不能重新开启；重新开启必须修改配置文件。

**面板密码等同于 agent 用户的 shell 访问权限。** 因此 `install.sh` 默认以普通用户运行 agent。如果确实需要以 root 用户运行，请关闭 `full_access`。

**`[remote_access.fs]`** 提供文件浏览，访问范围限制在 `roots` 指定的目录中。它独立于 `full_access`，因为文件 API 只授予目录范围内的访问，而 `full_access` 授予的是 shell。`roots` 没有默认值；启用文件 API 时必须明确指定目录。

agent 会将请求解析为真实路径，跟随 symlink，并拒绝 `..` 路径。解析后的路径必须位于 `roots` 内部，因此指向 `/etc` 的 symlink 也不能绕过限制。将 `roots` 设为 `['/']` 几乎等同于授予 shell，agent 启动时会对此发出警告。

除非配置 `[remote_access.fs] allow_insecure = true`，文件 API 也不会在明文 HTTP 上运行。只设置 `enabled` 和 `roots` 而没有 TLS，它仍然是关闭的。

**`[remote_access.terminal]`** 同时为 App 和网页面板开启终端 endpoint。网页面板终端通过 SSH 连接 `ssh_addr`，权限与对应 SSH 账号相同；App 的无密码终端则在 `full_access` 开启时使用 agent 用户的本地 shell。仅有面板登录凭据并不会自动获得 shell。

除非配置 `[remote_access.terminal] allow_insecure = true`，终端不会在明文 HTTP 上运行，因为第一条消息可能包含 SSH 密码。配置 TLS 或使用同机反向代理即可满足要求。App 还必须针对该服务器开启 **允许不安全 HTTP**；两端的设置都必须开启。

## 不支持的功能

仅配置 Monitor HTTP 的服务器不提供 SFTP 和端口转发。agent 没有把连接中继到 App 指定地址的 endpoint，因此无法承载这两种功能。文件**浏览**可以通过 agent 的文件 API 工作，但它传输的是文件内容，而不是提供任意 TCP 字节流。

如果需要 SFTP 或端口转发，请在 App 中同时为该服务器配置 SSH。

## 小组件、推送和 Watch App

这些功能直接从 Monitor agent 获取数据，不依赖 App 在前台运行：

- **主屏幕小组件**：安装 Monitor agent 后，在 App 中配置服务器；小组件从 App 发布的服务器列表中选择目标，不需要手动填写 URL。
- **Watch App**：只能显示已配置 Monitor agent 的服务器。默认会同步这些服务器，也可以在 iOS 设置中排除指定服务器。
- **推送告警**：在 agent 的 `[[monitoring.rules]]` 和 `[[push]]` 中配置。

## 故障排除

**服务器页面缺少功能按钮。** App 显示的是 agent 声明允许的功能。命令和终端需要 `full_access` 以及 terminal endpoint；文件浏览需要 `[remote_access.fs]` 和 `roots`。修改配置后重启 agent。

**证书错误。** 配置有效的 TLS，将 agent 放在反向代理后，或为该服务器开启 **Monitor Ignore certificate**。

**面板由其他 origin 提供。** 在 `config.toml` 的 `cors_allowed_origins` 或环境变量 `SBM_CORS_ORIGINS` 中明确允许该 origin。

**请求没有响应。** 先确认 agent 正在运行、端口可达，再检查数据库中的 `access_log`。日志记录访问者、时间、来源、访问内容和结果，不记录凭据。
