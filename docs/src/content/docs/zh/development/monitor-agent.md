---
title: Monitor Agent API 与访问模型
description: Capability 上报、指标历史和 remote access 行为
---

本页说明 App 连接 Monitor agent 时依赖的 API 行为。安装和配置见
[Monitor Agent](/docs/zh/advanced/monitor-agent/)。

## 协议版本

App 和 agent 之间只比较一个数字：协议版本（`sbm_parser::protocol`）。只有 API 发生破坏性变化时才增加，例如删除或重命名字段、改变字段含义、删除 route。新增功能不改变协议版本，而是列在 `features` 中。

- `GET /api/v1/health` 不需要登录，返回 `protocol` 和 `min_client_protocol`，不返回发布版本（发布版本在 `/capabilities` 中）。没有这两个字段的 agent 视为协议 1。
- 每个请求都带有 `X-SBM-Protocol: <n>`，没有这个 header 的请求视为协议 1。客户端低于 `min_client_protocol` 时，agent 返回 `426` 和 `{"error": "client_too_old", "protocol", "min_client_protocol"}`。`/health`、preflight 和 WebSocket upgrade 不检查；upgrade 之前的 `/ws-ticket` 请求会检查。
- App 登录前先读取 `/health`：agent 低于 App 支持的范围时提示更新 agent，agent 不再支持 App 时提示更新 App。
- 双方都至少支持上一个协议版本：agent 按旧版客户端的格式回应它，App 仍能读取旧版 agent。

## Capability discovery

App 通过 `GET /api/v1/capabilities` 查询 agent 支持的功能，以及当前登录账号可以使用的功能。返回内容针对调用者：

- `me`：`username`、`role` 和 `admin`。watch token 没有 `me`。
- `grants`：`shell`、`ssh_terminal`、`files`、`connect` 和 `listen` 各一项，带有 `ok`，不可用时还带有 `why`：`not_granted`（角色没有这项权限）、`insecure_transport`（需要 TLS、loopback 调用方或 `[remote_access] allow_insecure`）、`not_configured`（`files` 没有配置 `roots`）。每项权限还带有它的选项：`files.mode`、`connect.allow`、`listen.public` 和 `listen.ports`。watch token 的每项权限都是 `not_granted`。
- `remote_access`：角色功能之前的 agent 上报的布尔值，由 `grants` 推导出来，供旧版 App 使用（`terminal` 对应 `ssh_terminal` 或 `shell`，`full_access` 对应 `shell`，`stream` 对应 `connect`）。存在 `grants` 时，App 读取 `grants`。

TODO：最低支持版本的 App 改为读取 `grants` 后，删除旧版 `remote_access` response。

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

如果 `from` 早于最早保留样本，agent 会返回现存记录，不会平移请求的开始时间，也不会报错。图表会将缺少数据的时间显示为空档。没有 `from` 时，`?minutes=` 指定窗口长度（默认 60 分钟，最少 5 分钟，最多 7 天），结束时间为 `to` 或当前时间。App 每次请求都会携带 `minutes`，因此不支持 `from` 和 `to` 的旧版 agent 仍能处理请求。

## 访问模型

每个账号属于一个角色，角色带有若干权限。完整的约定（包括每个请求和响应的格式）见仓库中的 [docs/dev/monitor-permissions.md](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/monitor-permissions.md)。

| 权限 | Endpoint |
|---|---|
| `shell` | `POST /api/v1/exec`、App 终端（`/api/v1/terminal/ws` 上的本地 PTY）、执行自定义命令 |
| `ssh_terminal` | `/api/v1/terminal/ws` 上的网页面板终端，使用 SSH 凭据登录 `ssh_addr` |
| `files` | `/api/v1/fs/*`；`mode = "read"` 时只允许 `roots`、`list`、`stat` 和 `read` |
| `connect` | `/api/v1/stream/ws` 上的 `open`，按 `allow` 检查 |
| `listen` | `/api/v1/listen/ws`，以及 `/api/v1/stream/ws` 上的 `accept` |

读取状态、指标、历史、velocity、capabilities 和卡片顺序，只需要任意账号或 watch token。watch token 不能做其他任何事。

### 账号和角色

除两个 `/me` endpoint 任何账号都可以调用外，下列 endpoint 只有 `admin` 角色的账号可以调用：

| Endpoint | 请求体 |
|---|---|
| `GET /api/v1/me` | 无，返回 `username` 和完整的 `role` |
| `PUT /api/v1/me/password` | `current_password`、`new_password`（至少 8 个字符） |
| `GET /api/v1/users` | 无 |
| `POST /api/v1/users` | `username`、`password`、`role`、`current_password` |
| `PUT /api/v1/users/{username}` | 可选的 `role` 和 `password`，以及 `current_password` |
| `DELETE /api/v1/users/{username}` | `current_password` |
| `GET /api/v1/roles` | 无 |
| `POST /api/v1/roles` | `role`、`current_password` |
| `PUT /api/v1/roles/{name}` | `role`、`current_password` |
| `DELETE /api/v1/roles/{name}` | `current_password` |

`current_password` 是调用者（admin）自己的密码。它与登录共用限流，连续输错会返回 `429 throttled` 和 `Retry-After`。agent 设置（`/settings`、`/push`、`/push/test`、`PUT /card-order`）同样只允许 admin；`PUT /custom-cmds` 还需要可用的 `shell`，因为自定义命令由 agent 执行。

错误格式为 `{"error": "<code>", "message": "..."}`：

| Code | 状态码 | 含义 |
|---|---|---|
| `bad_request` | 400 | 请求体格式不对，包括未知的权限名 |
| `unauthorized` | 401 | 没有有效登录；已删除账号的 token 在所有 endpoint 都会得到它 |
| `forbidden` | 403 | 不是 admin，或角色没有这项权限 |
| `reauth` | 403 | `current_password` 缺失或错误 |
| `not_found` | 404 | 账号或角色不存在 |
| `conflict` | 409 | 名称已存在，或角色仍在使用 |
| `last_admin` | 409 | 修改后将没有任何 admin 账号 |

### 正在进行的会话

修改账号或角色会立即生效。如果终端、relay 或监听所属的账号不再拥有所需权限，会收到 `{"type":"error","code":"permission_revoked"}` 并被关闭。账号缺少所需权限时，WebSocket 请求返回 `forbidden`；`listen` 超出角色的 `public` 或 `ports` 限制时返回 `not_permitted`。旧接口 `DELETE /api/v1/remote-access/full-access` 会从所有角色移除 `shell`、`connect` 和 `listen`，并以 `full_access_disabled` 关闭失去权限的会话。TODO：面板的提示改为直接编辑角色后，删除这个接口。

### 传输安全

所有权限都需要 TLS 或 loopback 调用方（包括同机反向代理），除非设置了 `[remote_access] allow_insecure = true`。TODO：配置不再需要兼容后，删除旧版 `allow_insecure` key。目前 `[remote_access.terminal] allow_insecure` 只覆盖 `shell`、`ssh_terminal`、`connect` 和 `listen`；`[remote_access.fs] allow_insecure` 只覆盖 `files`。App 通过明文连接时，还需要为该服务器开启**允许不安全 HTTP**。条件不满足时，agent 会以 `why: insecure_transport` 上报该权限不可用。

### 连接和监听

`connect.allow` 的每一项是 IP 地址或 CIDR 网段，后面可以跟端口或端口范围；IPv6 写作 `[addr]:port`。连接使用主机名时，agent 会解析主机名，要求解析得到的每个地址都在允许范围内，并连接这些地址。`localhost` 通常同时解析为 `127.0.0.1` 和 `::1`，因此客户端应直接发送目标地址。

除非开启 `public`，`listen` 只绑定 loopback 地址；设置了 `ports` 时，只能绑定范围内的端口。

### File API

`files` 权限只能访问 `[remote_access.fs] roots` 中列出的目录。agent 会解析请求路径、跟随 symlink、拒绝 `..`，并确认解析后的路径仍在已配置的 root 下，因此 symlink 不能用来越过 roots。设置 `roots = ["/"]` 会开放整个文件系统，agent 启动时会发出警告。

### Terminal endpoint

网页面板终端作为 SSH 客户端连接 `ssh_addr`，使用该 SSH 账户的权限，需要 `ssh_terminal`。App 终端使用 agent 进程用户的本地 shell，需要 `shell`。该 endpoint 的第一条消息可能包含 SSH 密码，所以它遵循上面的传输安全规则。
