---
title: Monitor API 与访问模型
description: Capability 上报、指标历史和 remote access 行为
---

本页说明 App 连接 Monitor 时依赖的 API 行为。安装和配置见
[Monitor](/docs/zh/advanced/monitor-agent/)。

## 协议版本

App 和 Monitor 使用同一个协议版本号（`sbm_parser::protocol`）。只有 API 发生破坏性变化时才会递增，例如删除或重命名字段、改变字段含义或删除 route。新增功能不改变协议版本，而是列在 `features` 中。

- `GET /api/v1/health` 不需要登录，返回 `protocol` 和 `min_client_protocol`，不返回发布版本（发布版本在 `/capabilities` 中）。没有这两个字段的 Monitor 视为协议 1。
- 每个请求都带有 `X-SBM-Protocol: <n>`，没有这个 header 的请求视为协议 1。客户端低于 `min_client_protocol` 时，Monitor 返回 `426` 和 `{"error": "client_too_old", "protocol", "min_client_protocol"}`。`/health`、preflight 和 WebSocket upgrade 不检查；upgrade 之前的 `/ws-ticket` 请求会检查。
- App 登录前先读取 `/health`。Monitor 的协议版本过旧时，App 会提示更新 Monitor；如果 Monitor 要求更高版本的协议，则会提示更新 App。
- 双方都至少支持上一个协议版本：Monitor 按旧版客户端的格式回应它，App 仍能读取旧版 Monitor。

## Capability discovery

App 通过 `GET /api/v1/capabilities` 查询 Monitor 支持的功能，以及当前调用者能否使用它们。返回内容包括：

- `access`：`ok`，为 false 时还带有 `why`。`insecure_transport` 表示请求需要 TLS、loopback 调用方或 `[remote_access] allow_insecure`。watch token 的 `access` 是 `{"ok": false}`。
- `features`：Monitor 提供的机器管理 endpoint，例如 `power`。名称在列表中且 `access.ok` 时，客户端才提供对应页面。`container_exec`、`iperf` 和 `tmux` 是终端的 target，不是页面；各自只在列出时提供。`alerts`、`audit` 和 `live` 对应 Monitor 标签页的各部分（`GET /alerts`、`GET /audit`、`/live*`），`desk` 对应其中的通知。`update` 对应 `GET /update`：Monitor 的版本、读到的最新 release（`?check=1` 重新读取）、`outdated`、安装方式（`install`：`script`、`container`、`nix`、`other`），`script` 时还有用于更新的 `command`、启动更新是否需要 sudo 密码，以及上一次更新的 `run`（状态和输出）。`POST /update/run` 在 Monitor 之外启动更新，更新不受 Monitor 重启影响。

不要仅根据 Monitor 版本或默认配置推断功能是否可用；应读取运行中 Monitor
返回的 capabilities。

## 指标历史 API

Capabilities response 会报告：

- `retention_days`：`[monitoring.data_retention] metrics_days` 中配置的数据保留上限。
- `oldest_sample`：当前实际保存的最早一条指标样本的时间。

App 只提供符合数据保留限制和最早样本时间的图表 preset，并在时间范围选择器中显示这两个值。较旧且不报告 retention 的 Monitor 仍使用固定图表范围。

App 可通过以下 endpoint 请求精确时间段：

```text
GET /api/v1/metrics/history?from=<epoch-seconds>&to=<epoch-seconds>
```

如果 `from` 早于最早保留样本，Monitor 会返回现存记录，不会平移请求的开始时间，也不会报错。图表会将缺少数据的时间显示为空档。没有 `from` 时，`?minutes=` 指定窗口长度（默认 60 分钟，最少 5 分钟，最多 7 天），结束时间为 `to` 或当前时间。App 每次请求都会携带 `minutes`，因此不支持 `from` 和 `to` 的旧版 Monitor 仍能处理请求。

## 访问模型

Monitor 只有一个账号，只用密码登录；它可以做 Monitor 运行所用的系统账户能做的一切。没有角色、权限或文件 roots。Monitor、Web 面板和 App 共用下面的约定。

读取状态、指标、历史、velocity、capabilities 和卡片顺序，需要登录或 watch token。watch token 不能做其他任何事；其他 endpoint 对它返回 `401`。

### 登录和密码

| Endpoint | 请求体 |
|---|---|
| `POST /api/v1/login` | `password`、`device`（可选）、`name`（可选）；`username` 字段会被忽略。返回 `token`；如果 Monitor 不认识该设备，还会返回新的 `device` token |
| `PUT /api/v1/me/password` | `current_password`、`new_password`（至少 8 个字符）；返回 `204` |

客户端会按 Monitor 保存 `device` token（App 保存在 Keychain 或 Keystore，面板保存在 `localStorage`），并在之后每次登录时发送。`name` 是设备在 `GET /live` 中显示的名称；未提供时使用 User-Agent，最多 80 个字符，并会丢弃控制字符。每次登录，无论成功或被拒绝，都会写入 audit（`login`、地址，以及 `device known`、`new device`、`wrong password` 或 `throttled`）；其中不保存密码或 token。

登录会按来源地址和调用方限流：已知设备（其 token 以 SHA-256 形式保存，自上次使用起保留 180 天，最多保留最近使用的 64 个设备）使用独立计数器；其他客户端共用一个计数器；已登录调用方再次输入密码时，使用这些调用方共用的另一个计数器。因此，未知客户端的失败不会锁定之前登录过的设备。每个地址和设备可有 3 次失败，共享计数器可有 20 次；超过后延迟从 1 秒开始逐次翻倍，最高 5 分钟。修改密码会清除所有设备。

`server_box_monitor password` 在命令行中直接修改数据库中的密码（`--password-env VAR` 从环境变量读取），没有账号时会创建它。

部分修改需要在请求体中再次提供当前密码（`current_password`）：修改密码、部署 Web 应用、修改其设置或移除它、查看它的初始登录信息、恢复或删除容器备份，以及批准或移除 desk 应用。它也受上述登录限流约束。缺失或错误时返回 `403 reauth`；连续输错会返回 `429 throttled` 和 `Retry-After`。

错误格式为 `{"error": "<code>", "message": "..."}`：

| Code | 状态码 | 含义 |
|---|---|---|
| `bad_request` | 400 | 请求体格式不对 |
| `unauthorized` | 401 | 没有有效登录、token 签发于最近一次修改密码之前，或 watch token 超出其范围 |
| `forbidden` | 403 | 传输规则拒绝了请求 |
| `reauth` | 403 | `current_password` 缺失或错误 |
| `throttled` | 429 | 失败次数过多 |
| `not_found` | 404 | 未知的 `/api/v1/*` 路径 |

### 修改密码

修改密码会注销其他所有访问。修改前签发的面板 token 在所有 endpoint 都返回 `401`（同一秒签发的 token 仍然有效，因此修改后立即重新登录可以正常使用），watch token 和 LK Cloud session 都会被删除；在运行中的 Monitor 里，终端会话、未使用的 ticket、正在运行的 Agent mode 任务、Web 应用窗口、relay 和监听会收到 `{"type":"error","code":"password_changed"}` 并被关闭。在命令行中重置密码无法通知正在运行的 Monitor，已打开的连接会保持到 Monitor 重启。

### 传输安全

除只读查询外的所有操作均要求使用 TLS 加密或本机回环（loopback）调用（包括同机部署的反向代理），除非显式配置了 `[remote_access] allow_insecure = true`（为兼容旧版配置，`[remote_access.terminal] allow_insecure` 与 `[remote_access.fs] allow_insecure` 同样等效）。此外，当客户端通过明文 HTTP 连接时，还需在应用内为该服务器开启 **允许不安全 HTTP**。若未满足上述条件，`/capabilities` 接口返回的 `access` 会标记 `why: insecure_transport`，且相关写操作接口均会返回 `403 forbidden`。

### Monitor 标签页 endpoint

| Endpoint | 返回内容 | 规则 |
|---|---|---|
| `GET /api/v1/alerts` | `checked_at`、`alerts`：最近一次检查时每条触发规则的 `rule`、`monitor_type`、`matcher`、`threshold`、`value`、`since`（保存在内存中；重启后会忘记 `since`） | 任意登录 |
| `GET /api/v1/update[?check=1]` | `version`、`latest`、`checked_at`、`error`、`outdated`、`install`、`command`、`needs_password`、`run`。每 12 小时读取一次 release；`check=1` 会重新读取，最多每分钟一次。`run` 包含 `state`（`running`、`done`、`failed`、`interrupted`）、`started_at`、`exit`、`lines` | 任意登录 |
| `POST /api/v1/update/run` | `202`。`needs_password` 时接收 `password`（sudo 密码）；密码错误返回 `403 sudo_password`。若 Monitor 不是通过 `install.sh` 安装，返回 `409 not_script`；更新正在运行时返回 `409 running`。会写入 audit | 传输规则 |
| `GET /api/v1/audit?limit&before&kind&result` | 按时间倒序返回 `entries`（`id`、`timestamp`、`kind`、`action`、`result`、`subject`、`remote_ip`、`ssh_user`、`detail`），以及用于 `before` 的 `next`。未知的 `kind` 或 `result` 返回 `400 invalid_input` | 传输规则 |
| `GET /api/v1/live` | `sessions`、`connections`、`watch_tokens`、`devices` | 传输规则 |
| `DELETE /api/v1/live/{sessions,connections,devices}/{id}` | 返回 `204`；已不存在时返回 `404`。已结束的 session 或 connection 会收到 `ended`；忘记设备不会使其登出，但设备下次登录会按未知客户端计数，并获取新的 token。会写入 audit | 传输规则 |

### File API

`/api/v1/fs/*` 可以访问 Monitor 的系统账户能访问的一切，但不包括 Monitor 自身的状态：数据库及其 journal 文件、`jwt.secret`、`credentials.key`、`initial-admin-credentials.txt`、`config.toml` 及其备份、`.env`、TLS 证书和私钥、自定义命令目录、blob 存储、stack 的 `.env` 文件和容器备份。这些路径在解析 symlink 后匹配，访问时返回 `403`，不出现在列表中，其所在目录也不能重命名、删除或 chmod。

### Terminal endpoint

App 和网页面板的终端都是以 Monitor 进程用户身份在 PTY 上运行的本地 shell。Monitor 不登录 sshd：携带 SSH 凭据的 `open` 会被拒绝。
