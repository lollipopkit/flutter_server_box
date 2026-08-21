---
title: Monitor Agent
description: 经 agent 而不是 SSH 访问服务器
---

ServerBox Monitor 是安装在服务器上的轻量服务。App 通过 HTTP 与它通信，因此它是
访问该服务器的第二种方式，也是推送告警、桌面小组件和手表 App 的唯一途径。这些
功能都必须在 App 未打开时工作。

## 什么时候用

| | SSH | monitor agent |
|---|---|---|
| 需要在服务器上安装东西 | 否 | 是 |
| 状态与图表 | 支持 | 支持 |
| App 连接之前的历史数据 | 不支持 | 支持 |
| 终端、命令、文件浏览 | 支持 | 仅限 agent 运维方开启的部分 |
| SFTP 传输、端口转发 | 支持 | 不支持 |
| 推送告警、小组件、手表 App | 不支持 | 支持 |

没有特殊理由就用 SSH。以下情况考虑 agent：SSH 端口从你所在的位置不可达；希望打开
App 时图表已经有数据；希望把告警推送到手机。

两者并不冲突：一台机器可以既以 SSH 方式添加，同时又跑一个 agent 给小组件供数。

## 安装 agent

如果仓库已有发布的 `monitor-v*` release，可以从那里下载；否则请自行构建。发布
workflow 需要手动触发，因此未发布版本或离线安装应使用本地包和 `SBM_INSTALL_PKG`。
安装脚本会自行判断 init 系统：

```sh
# systemd: 安装为 `systemctl --user` 服务，以你自己的账号运行
./install.sh install

# 没有发布版本或离线安装
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install

# OpenRC (Alpine): 写 /etc/init.d 需要 root，但 agent 仍以你 sudo 前的账号运行
sudo ./install.sh install
```

它默认以普通账号运行，见 [各个开关授予了什么](#各个开关授予了什么)。

配置文件是二进制旁边的 `config.toml`，所有配置项都在
[`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)
里有说明。agent 默认监听 `0.0.0.0:3770`，并在该地址提供自己的网页面板。

如果 agent 不只在本机可达，请使用 HTTPS：内置 TLS（`[server.tls]`）或反向代理。
App 可以接受自签名证书，但仅在你明确要求时。

## 在 App 中添加

1. 点击 **+** 添加服务器
2. 把表单顶部的选择器从 **SSH** 切到 **Monitor HTTP**
3. 填写：
   - **URL**：例如 `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**：agent 的面板登录凭据
   - **Monitor Ignore certificate**：仅在使用自签名证书时开启

以这种方式添加的服务器**不携带任何 SSH 凭据**。App 没有其他回退途径，除了 agent
允许的范围，你没有给 App 进入这台机器的方式。

## 各个开关授予了什么

agent 会告诉 App 它接受什么，App 只提供这些能力。应用不会显示 agent 会以 403 拒绝的按钮。
文件 API 和 agent 网页面板终端默认关闭，只能由运维方在 `config.toml` 中开启。
`full_access` 仅在 Linux 上默认开启，但 App 的 shell/命令访问还要求
`[remote_access.terminal] enabled = true`，终端能力已开启，
并且请求使用安全传输或终端的显式 `allow_insecure` 选择。网页面板不能扩大这些权限。

**状态、图表和历史数据** 只需要登录。

**`full_access`** 让面板登录直接访问这台机器：一个 shell、一条命令，身份是 agent
所属的账号。App 的进程列表、systemd 单元、容器、snippet、电源控制和终端全都依赖它。

它只有一个开关，而不是每个功能各一个。能打开 shell 的人就能在其中运行任意命令，
因此只开放终端而禁用命令并不能缩小权限范围。

**此时你的面板密码就等于那台机器上的一个 shell。** 这就是 `install.sh` 默认以普通
账号而不是 root 运行 agent 的原因。如果你确实以 root 运行，请关掉 `full_access`。
它在 Linux 上默认开启，macOS 和 Windows 上默认关闭。面板可以关掉它，但永远无法开启。

**`[remote_access.fs]`** 提供文件浏览，范围限制在 `roots` 指定的目录内。它有自己的
开关而不是挂在 `full_access` 下，因为后者意味着「一个 shell」，而它意味着「这几个
目录」。将两者合并会让原本仅限目录的访问获得更大的权限范围。

`roots` 没有默认值。每个请求都会被解析为真实路径，跟随 symlink 并拒绝 `..`。
落在 roots 之外的一律拒绝，因此 root 内指向 `/etc` 的链接不是出口。
`roots = ["/"]` 等同于一个 shell，因为能写 `~/.ssh/authorized_keys` 的人就有 shell；
agent 会在启动时对此告警。

**`[remote_access.terminal]`** 为 agent 自己的网页面板增加浏览器内终端，与 App 使用
的部分无关。agent 作为 SSH 客户端连接它配置的 `ssh_addr`，因此浏览器会话的权限等同
于登录所用的 SSH 账号。除非开了 `full_access`，仅有面板密码不会获得 shell。

除非配置 `[remote_access.terminal] allow_insecure = true`，它不会在明文监听上运行，
因为第一条消息就带着 SSH 密码。配置 TLS 可满足要求，同机反向代理同样可以。

## 得不到什么

**monitor 服务器不提供 SFTP 和端口转发。** agent 没有任何端点可以把连接中继到 App
指定的地址，因此没有东西可以承载它们。文件*浏览*经 agent 自己的文件 API 工作，那是
另一回事：它通过 agent 搬运文件内容，而不是开一条通往某处的流。

这台机器上确实需要 SFTP 或端口转发的话，请以 SSH 方式添加。

## 小组件、推送和手表

这些直接读取 agent，与 App 是否打开无关。

- **桌面小组件** 需要一个以 `/status` 结尾的 URL，见
  [桌面小组件](/docs/zh/advanced/widgets/)
- **手表 App** 自己向 agent 取数据，因此只能显示已配置 agent 的服务器
- **推送告警** 在 agent 上配置，位于 `[[monitoring.rules]]` 和 `[[push]]`

## 故障排除

**服务器页面缺少按钮。** App 显示的就是 agent 声明允许的范围。命令和终端检查
`full_access`，文件检查 `[remote_access.fs]` 及其 `roots`。agent 重启时重新读取配置。

**证书错误。** 配置真实 TLS、把 agent 放到反向代理后面，或为该服务器开启
**Monitor Ignore certificate**。

**面板在另一个 origin 上。** agent 必须显式允许：`config.toml` 里的
`cors_allowed_origins`，或环境变量 `SBM_CORS_ORIGINS`。

**完全没有反应。** 先确认 agent 在运行、端口可达，然后查看数据库里的 `access_log`。
它记录谁在何时从何处打开了什么以及结果如何，但不记录任何凭据。
