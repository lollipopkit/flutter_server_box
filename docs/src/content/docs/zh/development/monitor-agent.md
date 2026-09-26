---
title: Monitor Agent API 与访问模型
description: Capability 上报、指标历史和 remote access 行为
---

本文记录 App 连接 Monitor agent 时依赖的 API 行为。安装和运维配置见
[Monitor Agent](/docs/zh/advanced/monitor-agent/)。

## Capability discovery

App 通过 `GET /api/v1/capabilities` 查询 agent 支持的功能及 remote access
开关状态，并据此决定显示哪些控件。终端功能取决于
`[remote_access.terminal]` 和 `full_access`；文件浏览取决于
`[remote_access.fs]` 及其 roots 配置。

不要仅根据 agent 版本或默认配置推断功能是否可用；应读取运行中 agent
返回的 capabilities。

## 指标历史 API

Capabilities response 会报告：

- `retention_days`：`[monitoring.data_retention] metrics_days` 中配置的数据保留上限。
- `oldest_sample`：当前实际保存的最早一条指标样本的时间。

App 只提供符合数据保留限制和最早样本时间的图表 preset，并在时间范围选择器中显示这两个值。较旧且不报告 retention 的 agent 仍使用固定图表范围。

App 可通过以下 endpoint 请求精确时间段：

```text
GET /api/v1/metrics/history?from=<epoch-seconds>&to=<epoch-seconds>
```

如果 `from` 早于最早保留样本，agent 会返回现存记录，不会平移请求的开始时间，也不会报错。图表会将缺少数据的时间显示为空档。旧版 agent 仍支持 `?minutes=` 参数，以兼容尚不支持 `from` 和 `to` 的版本。

## Remote access capability model

`full_access` 受 `[remote_access.terminal] enabled` 控制，授权登录用户以 agent 进程账户访问 shell。App 的进程、systemd、容器、snippet、电源控制、终端和 remote desktop 功能都依赖此授权。Remote desktop 通过 `/api/v1/stream/ws` 从 agent 主机连接目标；它没有独立权限，因为 shell 本身已允许端口转发。

该设置在 Linux 上默认开启，在 macOS 和 Windows 上默认关闭。面板可以关闭它；重新开启必须修改 `config.toml`。

### File API

`[remote_access.fs]` 独立于 `full_access`，只授权访问 `roots` 中列出的目录。agent 会解析请求路径、跟随 symlink、拒绝 `..`，并确认解析后的路径仍位于配置的 root 中，因此 symlink 不能用于越界访问。设置 `roots = ["/"]` 会开放整个文件系统，并在启动时产生 warning。

File API 默认拒绝来自网络的明文 HTTP 请求。只有设置 `[remote_access.fs] allow_insecure = true` 才会接受这类请求；loopback 请求（包括同机 reverse proxy）会按安全连接处理。如果网络请求既没有 TLS，也未显式允许不安全连接，capabilities 会报告文件访问不可用，App 会隐藏相关控件。

### Terminal endpoint

`[remote_access.terminal]` 为 App 和网页面板启用 terminal access。网页面板作为 SSH client 连接 `ssh_addr`，使用对应 SSH 账户的权限。启用 `full_access` 后，App terminal 使用 agent 进程账户的本地 shell。

Terminal endpoint 默认拒绝明文 HTTP，因为首条消息可能包含 SSH password。明文连接必须同时满足 agent 中的 `[remote_access.terminal] allow_insecure = true` 和 App 针对该服务器开启不安全 HTTP。来自 loopback 的请求（包括同机 reverse proxy）无需此选项。建议使用 TLS，或由同机 reverse proxy 终止 TLS。
