---
title: Desk 应用参考
description: Desk 应用与 Monitor 面板 Desk 之间的约定，包括沙箱、Manifest、生命周期、Bridge 协议、UI、权限、软件包和 wasm 后端
---

本页说明第三方 Desk 应用所依据的约定。从模板开始并打包安装的流程见
[开发 Desk 应用](/docs/zh/development/desk-apps/)。客户端库
`serverbox-desk` 实现了下述协议；其中的 `protocol.ts` 是消息结构的唯一来源。

## 应用类型与沙箱

| 类型 | 代码 | 运行位置 | 可访问内容 |
|---|---|---|---|
| `web` | 安装在 Monitor 上的静态软件包（HTML、JavaScript、CSS） | 沙箱 iframe | 只能通过消息 bridge 访问 Desk。不能访问 Monitor API 或网络 |
| `wasm` | `web` 软件包加 WebAssembly component（API 2） | 前端：沙箱 iframe。后端：Monitor 的 wasmtime runtime | Desk，以及通过 `call` 和 `job` 访问自身后端服务。后端只能通过其权限允许的 host function 访问机器 |

第三方应用不会在面板自身的页面中运行：其中的代码可能读取会话 token，并以当前登录账号的身份执行操作。frame 使用
`sandbox="allow-scripts"`，不带 `allow-same-origin`，因此运行在不透明 origin 中。Monitor 提供已安装软件包时会附带
`Content-Security-Policy: sandbox allow-scripts allow-forms; default-src 'self'; connect-src 'none'`，
因此即使直接打开软件包，也仍处于沙箱中。

沙箱不能阻止应用发送它读取到的内容：`connect-src 'none'` 会阻止请求，但 frame 可以导航到任意 URL；在 Chromium 中，WebRTC 也不受 `connect-src` 限制。因此，Desk 只通过交给 frame 首个页面的 `MessagePort` 与应用通信；frame 加载其他页面时，Desk 会关闭 bridge 并移除 frame，因此应用导航到的页面不能再以应用身份操作。**获准的应用可以读取其权限允许的所有内容**，批准对话框会说明这一点。

## Manifest

软件包中的 `manifest.json`。

| 字段 | 含义 |
|---|---|
| `publisher`、`name` | 每个值都符合 `[a-z][a-z0-9_]*`，最多 24 个字符（publisher 至少 2 个字符）。应用 id 为 `<publisher>.<name>`，由它们生成且不会写入文件。id 保持稳定：窗口、dock、图标和应用存储都以此为依据。面板自带应用使用 `serverbox`；没有对应签名的软件包不能使用它 |
| `api` | 应用构建时使用的 Desk API 版本；Desk 会拒绝更高的主版本 |
| `kind` | `web` 或 `wasm` |
| `title`、`keywords` | 显示在 dock、Apps、Spotlight 和 menubar 中。可以是字符串，也可以是按 locale 索引的翻译 |
| `description` | 应用在 App Store 页面上的功能说明（最多 600 个字符）。可以是字符串，也可以是按 locale 索引的翻译 |
| `glyph`、`tone` | 应用图标：Material Symbols Rounded 名称和 Desk 设计系统中的 tone |
| `instances` | 可同时打开的窗口数量（默认 1） |
| `size`、`min_size` | 首个窗口的尺寸和允许的最小尺寸 |
| `permissions` | 见[权限](#权限) |
| `opens` | 应用可打开的文件类型（`{ "ext": ["log", "txt"], "dirs": false }`，`"*"` 表示任意类型）；Files 会在 **打开方式** 中提供该应用 |
| `os` | 可选：`linux`、`macos`、`windows` 或发行版 `/etc/os-release` 中的 `ID`。目录只会在这些系统上提供该软件包 |

## 窗口与生命周期

一个窗口是应用的一个进程，有自己的状态和生命周期。关闭窗口会结束该进程。

| 状态 | 时机 | 应用行为 | Desk 行为 |
|---|---|---|---|
| `active` | 前台窗口 | 所有功能 | menubar 显示应用菜单；应用快捷键生效 |
| `visible` | 窗口可见但不在前台 | 所有功能 | — |
| `background` | 窗口最小化、Desk 锁定或浏览器标签页隐藏 | 停止绘制（动画、图表、用于显示的轮询）；保留所需的会话 | 不渲染窗口内容；frame 保留 |
| `suspended` | 后台运行关闭时处于 `background` | — | 5 秒后移除内容：socket 和 timer 结束。窗口仍保留；恢复时应用会重新启动，并通过 `appState` 恢复状态 |

默认开启后台运行。所有者可在 **设置 → 应用** 中为 Desk 或单个应用关闭此功能；第三方应用还需要
`background` 权限。`keepAlive(reason)` 可使处于 `background` 的应用暂不挂起，直到调用释放，最多 10 分钟（例如上传期间）。控制中心会列出后台运行的应用。

应用应在状态变化时调用 `setAppState` 保存恢复所需的数据，而不是等到挂起时再保存：浏览器标签页冻结后可能在没有代码运行的情况下被挂起。数据最多为 16 KiB JSON，不能包含密钥。

## Bridge

Desk 会通过 `MessagePort` 向 frame 的首个页面发送 `{ sbm: 1, event: 'connect' }`。frame 在该 port 上发送调用 `{ sbm: 1, id, call, args }`，并接收 `{ sbm: 1, re, ok, value | error, message? }`（`message` 是后端自己的错误说明）。Desk 会发送 `{ sbm: 1, event, data }` 事件，并在 frame 发送 `hello` 前暂存。Desk 只监听这个 port，并检查每条消息的结构和大小：每条消息最多 1 MiB，最多 32 个并发调用，`appState` 最多 16 KiB，每 10 秒最多 3 次 `open` 调用。

| 调用 | 功能 |
|---|---|
| `hello` | 返回应用和窗口 id、`appState`、生命周期状态、主题、locale、已授予的权限和 `ui.stylesheet` |
| `setTitle`、`setAppName`、`setIcon`、`setBadge`、`setAppState`、`close` | 设置窗口标题、应用名称、图标（`{ glyph, tone }`）和徽标，保存应用状态，关闭窗口 |
| `toolbar` `{ title, subtitle, actions }`、`menus` `{ menus }` | 应用描述内容，由 Desk 绘制；使用时发送 `action { id }`。菜单项可以带 `shortcut`（如 `⌘⇧N`），仅当前台窗口时生效；优先处理 Desk 自身快捷键 |
| `sidebar` `{ sections: [{ title?, items: [{ id, label, icon?, trailing? }] }], selected? }` | 窗口内缩进式侧边栏（窄窗口中会折叠）；选择条目时发送 `navigate { id }`。没有 section 时不显示侧边栏 |
| `notify` `{ title, body, level }` | 显示横幅（勿扰模式除外）并在通知中心添加一条记录；点击后会将窗口置于前台。需要 `notifications` |
| `storage.get`、`storage.set`、`storage.remove`、`storage.keys` | 应用自己的存储：按 key 保存 JSON，按应用和服务器隔离。每个应用最多 256 KiB，所有应用合计最多 4 MiB；key 最长 128 字节 |
| `open` `{ appId, newWindow, intent }` | 打开另一个应用。应用只能传递 `open` 类型的路径 intent |
| `handlers` `{ path, kind }` | 返回可以打开指定路径的应用 |
| `keepAlive`、`release` `{ token, reason }` | 见[窗口与生命周期](#窗口与生命周期)。需要 `background` |
| `backend.call`、`backend.job` `{ function, args, sudo? }` | 调用后端的 `api` 函数（返回 `{ value }`）或一个 `jobs`（返回 job 视图）。带有 `sudo`（`{ title, body, confirmWord? }`，纯文本且长度有限制）时，Desk 会先显示自己的对话框并标明应用名称；sudo 密码随请求从 Desk 发送给 Monitor，不会交给 frame。关闭对话框会返回 `declined` |
| `backend.jobView` `{ since }`、`backend.cancel` | 查看应用正在运行或最近一次 job（从 `since` 开始读取日志行，随后返回 `value` 或 `error`），或要求 job 停止 |
| `openUrl` `{ url }` | 在独立标签页中打开 http(s) 页面（frame 没有弹出窗口权限）；计入 `open` 调用限额 |
| `power` `{ action }` | 打开 Desk 自己的重启和关机对话框，由用户在其中确认。需要 `root`；计入 `open` 调用限额 |
| `openStack` `{ id, model?, backend? }` | 在窗口上方的 sheet 中打开 Desk 自带的模型服务器 stack 页面（`ollama.ollama`、`ggml.llama_cpp`、`vllm.vllm`、`sglang.sglang`）；未部署时可选择模型和 backend，用户在其中输入密码确认。sheet 关闭后返回。需要 `process`；同一时间只能打开一个 |

事件包括：`lifecycle`、`theme`、`locale`、`intent`（`{ action, data, from }`）、`action`、`navigate`。intent 带有由 Desk 设置的 `from`；只应处理来自预期应用的 intent。

## UI

已安装应用使用 Desk 的设计系统绘制，无需将其代码打包携带。应用获取的是接口——class 和 token，而不是实现代码；为兼容应用，class 和 token 会保持稳定；更名后旧名称至少会继续工作一个 release。

- **提供方式。** Monitor 在 `/desk-app/` 提供设计系统的 stylesheet 和 fonts（所有应用共用同一个 URL，任意 origin 均可访问；fonts 设置为 immutable）。`hello` 会通过 `ui.stylesheet` 返回 stylesheet 地址。
- **`connect()`**：`serverbox-desk` 会先将 stylesheet 插入 `<head>`（应用自己的样式优先），并等待加载完成（最多 5 秒）；给 `<body>` 添加设计系统作用范围使用的 `lk` class；在 `<html>` 上设置模式（`data-theme`）；在 `<body>` 上设置已安装主题的 token；每次收到 `theme` 事件时也会更新。`connect({ style: false })` 不会修改页面。
- **Class**：按钮（`lk-btn` 及 `--primary`、`--secondary`、`--tinted`、`--ghost`、`--destructive`、`--sm`、`--lg`、`--block`），图标按钮（`lk-iconbtn`），表单项（`lk-input`、`lk-select`、`lk-field`），复选框和单选框（`lk-check`、`--radio`、`--on`），开关（`lk-switch`、`--on`），分段控件（`lk-seg`），卡片（`lk-card`、`--raised`、`--glass`、`--interactive`、`--selected`），徽标（`lk-badge`，带 tone），设置分组（`lk-setgroup`、`lk-setrow`），表格（`lk-table`、`lk-table__row`、`--sel`），tooltip（`lk-tip`），统计卡片（`lk-stat`），状态栏（`lk-statusbar`），文本辅助 class `lk-caps`、`lk-mono`、`lk-num`，以及图标：`<span class="lk-icon" data-icon="folder">`（Material Symbols Rounded 名称；可使用 `lk-icon--fill`）。
- **Token**：`--color-*`、`--surface-*`、`--text-*`、`--border-*`、`--fill-*`、`--space-*`、`--radius-*`、`--shadow-*`、`--font-*`、`--dur-*` 和 `--ease-*`。主题只改变 token 的值，不改变其名称。

## 权限

Manifest 列出应用需要的权限。Monitor 会在每次调用时检查权限：应用可执行的操作受已批准权限和传输规则限制（操作需要 TLS 或 loopback 调用方，见
[Monitor API 与访问模型](/docs/zh/development/monitor-agent/#传输安全)）。在这些限制内，应用可以访问 Monitor 的系统账户可访问的内容，但 Monitor 自身的状态除外。

| 权限 | 允许操作 | 传输规则 |
|---|---|---|
| `notifications` | `notify` | — |
| `background` | 后台运行和 `keepAlive` | — |
| `status` | 后端读取状态样本 | — |
| `process` | 后端的 `exec` 和 job 的 `run`：以 Monitor 的系统账户运行脚本 | 是 |
| `root` | 后端的 `exec-root` 和 job 的 `run-root`：以 root 运行脚本，使用 Desk 为该次调用或 job 请求的 sudo 密码 | 是 |
| `providers` | 后端的 `providers` 和 `endpoint`：Agent 模式的 provider，以及每个 provider 的 key | 是 |
| `network` | 后端的 `http`：从 Monitor 发出请求（loopback 直接访问，其余请求使用 Monitor 的 proxy 配置；不跟随 redirect），以及下载文件并通过 SHA-256 校验后写入应用目录 | 是 |

所有者在 **设置 → 应用** 中安装应用并批准。批准会关联软件包（其 SHA-256），并要求再次输入 Monitor 密码；上传软件包时不要求密码，因此**任何新软件包，无论版本或权限如何，都必须再次批准**。移除应用时也会删除其存储的数据。

## 软件包

软件包为 `.fsba` 文件（gzip 压缩的 tar），包含 `manifest.json`、`ui/`（网页包，入口为 `ui/index.html`）、`backend.wasm`（仅 `wasm` 类型需要）和 `LICENSE`。`web` 软件包使用 API 1 或 2，`wasm` 软件包使用 API 2。Monitor 会检查 manifest、文件大小（bundle 20 MiB，backend 20 MiB）和路径（不允许 `..` 或 link），无法编译的 backend 会被拒绝（`invalidBackend`），API 1 的 core module 也会被拒绝（`unsupportedApi`）。

- **签名。** `SIGNATURE`（`{ key, signature }`）是对软件包文件清单 SHA-256 的 ed25519 签名：每个其他文件按路径排序，按 `sha256sum` 格式写为 `<sha256>  <path>`。未知 key 签名或未签名的软件包会被视为来自未知发布者；签名校验失败则拒绝安装（`badSignature`）。签名应用安装后，只能由相同 key 签名的软件包替换（`publisherChanged`）。只有 ServerBox 自己的 key 可以使用 `serverbox` publisher。
- **目录。** App Store 会在 Web 应用旁列出软件包仓库中的应用。从目录安装时，会在一次操作中安装并批准软件包，需要输入密码；手动上传的软件包则需要单独批准。

## 后端（`wasm`）

- `backend.wasm` 是 WebAssembly **component**（WASI 0.2、`wasm32-wasip2`），属于包含 `sbm:app/imports`（仓库中的 `monitor/wit/app.wit`）的 world，并导出应用服务：`api`（一元调用），以及在有需要时导出的 `jobs`。每个函数都返回 `result<T, error>`；`error` 使用 gRPC 标准 code（`invalid-argument`、`not-found`、`already-exists`、`permission-denied`、`failed-precondition`、`unavailable`、`deadline-exceeded`、`cancelled`、`internal`）。
- 应用自己的 WIT 是其类型化约定。frame 指定函数名，并将参数作为一个 JSON object 传入：名称使用 camelCase，`variant` 表示为 `{ tag, val }`，`option` 表示为 `null`，`result` 表示为 `{ ok }` 或 `{ err }`。安装时会拒绝 resource、stream 和嵌套 option。
- Monitor 使用 wasmtime 运行 component：每个软件包只编译一次，每次调用或 job 都创建新 instance（需要持久化的数据通过 `kv` 保存）；不预先打开目录，不提供环境变量、参数或网络。
- **Host function**：`log`；`kv-get`、`kv-set`、`kv-remove`（应用自身存储，JSON 文本）；`home`；`data-dir`（应用自己的目录，权限为 `0700`，不会由 File API 提供，移除应用时删除）；`status`（需要 `status`）；`exec`（需要 `process`，遵守 Monitor 的命令限制）；`exec-root`（需要 `root` 和请求中的 sudo 密码，否则返回 `permission-denied("sudo")`）；`holds-state`、`stack-leftovers`、`web-apps`、`shared-dir`、`stacks` 和 `models-changed`（查询 Monitor 所知的自身状态和 Web 应用；获得 `process` 或 `root` 权限的应用不会获知其他应用）；`http.fetch`、`http.fetch-lines`（按接收顺序读取 body）和 `http.download`（需要 `network`）；`providers` 和 `endpoint`（需要 `providers`）。在 job 中还可用：`line`（写入日志），`run`（以 Monitor 账户身份运行，并将输出流式写入日志），`run-root`（以 root 身份运行）和 `private-file`（将 secret 写入 `0600` 文件，job 结束时删除；脚本通过路径读取，不会将其写入日志、参数或 audit）。host function 执行时会根据传输规则检查权限。
- **限制**：64 MiB 内存；guest 自身 CPU 时间达到 10 秒后 trap（host function 的耗时不计入）；一次调用最多 60 秒；同时最多 8 次调用（超出时返回 `429`）。trap 返回 `422 { error: "trap" }`。
- **调用和 job**：`POST /apps/{id}/call` 和 `POST /apps/{id}/jobs` 接收 `{ function, args, sudo? }`（`sudo` 为 `{ password, remember }`；先尝试密码，错误时返回 `403 sudo_rejected`；`remember` 会在内存中保留密码 15 分钟）。每个应用一次只能运行一个 job（否则返回 `409`），直到 job 返回或调用 `POST /apps/{id}/jobs/cancel`；通过 `GET /apps/{id}/jobs?since=` 读取状态。需要 root 的操作和所有 job 都会以应用名记入 audit。

仓库中的示例：`monitor/examples/desk-app-hello`（`web`）和 `monitor/examples/desk-app-uptime`（`wasm`，Rust component）。
