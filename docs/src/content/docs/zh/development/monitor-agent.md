---
title: Monitor Agent API 与访问模型
description: Capability 上报、指标历史和 remote access 行为
---

本页说明 App 连接 Monitor agent 时依赖的 API 行为。安装和配置见
[Monitor Agent](/docs/zh/advanced/monitor-agent/)。

## 协议版本

App 和 agent 使用同一个协议版本号（`sbm_parser::protocol`）。只有 API 发生破坏性变化时才会递增，例如删除或重命名字段、改变字段含义或删除 route。新增功能不改变协议版本，而是列在 `features` 中。

- `GET /api/v1/health` 不需要登录，返回 `protocol` 和 `min_client_protocol`，不返回发布版本（发布版本在 `/capabilities` 中）。没有这两个字段的 agent 视为协议 1。
- 每个请求都带有 `X-SBM-Protocol: <n>`，没有这个 header 的请求视为协议 1。客户端低于 `min_client_protocol` 时，agent 返回 `426` 和 `{"error": "client_too_old", "protocol", "min_client_protocol"}`。`/health`、preflight 和 WebSocket upgrade 不检查；upgrade 之前的 `/ws-ticket` 请求会检查。
- App 登录前先读取 `/health`。agent 的协议版本过旧时，App 会提示更新 agent；如果 agent 要求更高版本的协议，则会提示更新 App。
- 双方都至少支持上一个协议版本：agent 按旧版客户端的格式回应它，App 仍能读取旧版 agent。

## Capability discovery

App 通过 `GET /api/v1/capabilities` 查询 agent 支持的功能，以及当前调用者能否使用它们。返回内容包括：

- `access`：`ok`，为 false 时还带有 `why`。`insecure_transport` 表示请求需要 TLS、loopback 调用方或 `[remote_access] allow_insecure`。watch token 的 `access` 是 `{"ok": false}`。
- `features`：agent 提供的机器管理 endpoint，例如 `power`。名称在列表中且 `access.ok` 时，客户端才提供对应页面。`container_exec`、`iperf` 和 `tmux` 是终端的 target，不是页面；各自只在列出时提供。`alerts`、`audit` 和 `live` 对应 Monitor 标签页的各部分（`GET /alerts`、`GET /audit`、`/live*`），`desk` 对应其中的通知。`update` 对应 `GET /update`：agent 的版本、读到的最新 release（`?check=1` 重新读取）、`outdated`、安装方式（`install`：`script`、`container`、`nix`、`other`），`script` 时还有用于更新的 `command`、启动更新是否需要 sudo 密码，以及上一次更新的 `run`（状态和输出）。`POST /update/run` 在 agent 之外启动更新，更新不受 agent 重启影响。

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

agent 只有一个账号，只用密码登录；它可以做 agent 运行所用的系统账户能做的一切。没有角色、权限或文件 roots。完整的约定（包括每个请求和响应的格式）见仓库中的 [docs/dev/monitor-permissions.md](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/monitor-permissions.md)。

读取状态、指标、历史、velocity、capabilities 和卡片顺序，需要登录或 watch token。watch token 不能做其他任何事；其他 endpoint 对它返回 `401`。

### 登录和密码

| Endpoint | 请求体 |
|---|---|
| `POST /api/v1/login` | `password`；`username` 字段会被忽略 |
| `PUT /api/v1/me/password` | `current_password`、`new_password`（至少 8 个字符） |

`server_box_monitor password` 在命令行中直接修改数据库中的密码（`--password-env VAR` 从环境变量读取），没有账号时会创建它。

部分修改需要在请求体中再次提供当前密码（`current_password`）：修改密码、部署 Web 应用、修改其设置或移除它、查看它的初始登录信息、恢复或删除容器备份，以及批准或移除 desk 应用。它走登录限流，按来源地址和一个只有已登录调用方共用的计数。缺失或错误时返回 `403 reauth`；连续输错会返回 `429 throttled` 和 `Retry-After`。

错误格式为 `{"error": "<code>", "message": "..."}`：

| Code | 状态码 | 含义 |
|---|---|---|
| `bad_request` | 400 | 请求体格式不对 |
| `unauthorized` | 401 | 没有有效登录、token 签发于最近一次修改密码之前，或 watch token 超出其范围 |
| `forbidden` | 403 | 传输规则拒绝了请求 |
| `reauth` | 403 | `current_password` 缺失或错误 |
| `throttled` | 429 | 失败次数过多 |

### 修改密码

修改密码会注销其他所有访问。修改前签发的面板 token 在所有 endpoint 都返回 `401`，watch token 被删除；在运行中的 agent 里，终端会话、未使用的 ticket、正在运行的 Agent mode 任务、Web 应用窗口、relay 和监听会收到 `{"type":"error","code":"password_changed"}` 并被关闭。在命令行中重置密码无法通知正在运行的 agent，已打开的连接会保持到 agent 重启。

### 传输安全

读取以外的所有操作都需要 TLS 或 loopback 调用方（包括同机反向代理），除非设置了 `[remote_access] allow_insecure = true`。TODO：配置不再需要兼容后，删除旧版 `allow_insecure` key。目前 `[remote_access.terminal] allow_insecure` 和 `[remote_access.fs] allow_insecure` 与它等效。App 通过明文连接时，还需要为该服务器开启**允许不安全 HTTP**。条件不满足时，capabilities 的 `access` 带有 `why: insecure_transport`，对应 endpoint 返回 `forbidden`。

### File API

`/api/v1/fs/*` 可以访问 agent 的系统账户能访问的一切，但不包括 agent 自身的状态：数据库及其 journal 文件、`jwt.secret`、`credentials.key`、`initial-admin-credentials.txt`、`config.toml` 及其备份、`.env`、TLS 证书和私钥、自定义命令目录、blob 存储、stack 的 `.env` 文件和容器备份。这些路径在解析 symlink 后匹配，访问时返回 `403`，不出现在列表中，其所在目录也不能重命名、删除或 chmod。

### Terminal endpoint

App 和网页面板的终端都是以 agent 进程用户身份在 PTY 上运行的本地 shell。agent 不登录 sshd：携带 SSH 凭据的 `open` 会被拒绝。
