---
title: 开发 Desk 应用
description: 使用 serverbox-desk 为 Monitor 面板的桌面开发第三方应用
---

Desk 应用是一个静态网页包，由 Monitor 面板在窗口中的沙箱 frame 里运行。它打包为
`.fsba` 文件，在面板中安装并批准（见 [Desk 应用](/docs/zh/advanced/monitor-desk-apps/)）。
完整设计（包括消息协议）见
[`docs/dev/desk-sys.md`](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/desk-sys.md)。

| 类型 | 包含 | 能访问 |
|---|---|---|
| `web` | 静态网页包（HTML、JavaScript、CSS） | 通过 `serverbox-desk` 访问桌面 |
| `wasm` | `web` 网页包加 `backend.wasm`，即由 agent 运行的 WebAssembly 模块 | 桌面，以及通过 `desk.backend()` 访问自己的后端 |

## 从模板开始

[`monitor/sdk/template`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/sdk/template)
中的模板使用 vite 和 [`serverbox-desk`](https://www.npmjs.com/package/serverbox-desk)
包（Apache-2.0，基于它开发的应用可以使用自己的许可证，包括闭源）。复制该目录后，把依赖
改为已发布的包：

```sh
npm install serverbox-desk
npm run pack   # 构建 dist/ 并生成 <publisher>.<name>.fsba
```

在本仓库中，模板依赖 `file:../serverbox-desk`，需要先运行一次
`npm run build --prefix ../serverbox-desk`。

网页包运行时没有网络访问：所需的一切都必须在包内，URL 必须是相对路径（vite 中设置
`base: './'`）。

## 与桌面通信

```ts
import { connect } from 'serverbox-desk'

const desk = await connect()
await desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
desk.on('action', ({ id }) => {
  if (id === 'refresh') void load()
})
const count = (await desk.storage.get<number>('count')) ?? 0
await desk.storage.set('count', count + 1)
```

桌面把通信通道交给 frame 后，`connect()` 才会完成。返回的对象提供：

| 方面 | 调用 |
|---|---|
| 窗口 | `setTitle`、`setAppName`、`setIcon`、`setBadge`、`setAppState`（窗口恢复时带回的 JSON，最多 16 KiB，不能存放密钥）、`close` |
| 窗口栏 | `toolbar({ title, subtitle, actions })`、`menus([...])`；由桌面绘制，使用时发送 `action` 事件 |
| 通知 | `notify({ title, body, level })`，需要 `notifications` 权限 |
| 存储 | `storage.get/set/remove/keys`：按应用保存在 agent 上的 JSON（每个应用 256 KiB） |
| 其他应用 | `open(appId, { path })` 打开另一个应用，可以带上文件或目录；`handlers(path, kind)` 列出能打开它的应用 |
| 后台 | `keepAlive(reason)`，需要 `background` 权限 |
| 后端 | `backend(method, params)`，仅 `wasm` 应用 |

事件（`desk.on`）：`lifecycle`（`active`、`visible`、`background`、`suspended`）、
`theme`、`locale`、`intent`、`action`。`desk.info` 保存连接时桌面返回的信息：应用和
窗口 id、保存的 `appState`、语言和已授予的权限。被拒绝的调用会抛出 `DeskError`。

## 与桌面外观一致

`connect()` 会把桌面的样式表加载到页面中，让页面跟随桌面的浅色或深色模式，并应用桌面
所选主题的 token。界面应使用它的 class 和 token，而不是自定义颜色：

```html
<div class="lk-card">
  <button class="lk-btn lk-btn--primary">
    <span class="lk-icon" data-icon="play_arrow"></span>Run
  </button>
</div>
```

按钮（`lk-btn` 加 `--primary`、`--secondary`、`--tinted`、`--ghost`、`--destructive`）、
图标按钮（`lk-iconbtn`）、输入框（`lk-input`、`lk-select`）、开关（`lk-switch`）、
卡片（`lk-card`）、徽标、表格（`lk-table`）、设置分组（`lk-setgroup`、`lk-setrow`）和
图标（`lk-icon`，使用 Material Symbols Rounded 名称）见
[设计文档的 UI 部分](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/desk-sys.md#ui-third-party-apps)。
样式表由 agent 提供，不在包内，因此应用只在面板中才能正确显示。
`connect({ style: false })` 不修改页面。

## Manifest

`manifest.json` 位于包的根目录。agent 会拒绝未知字段。

```json
{
  "publisher": "acme",
  "name": "notes",
  "version": "1.0.0",
  "api": 1,
  "kind": "web",
  "title": { "en": "Notes", "zh-CN": "笔记" },
  "glyph": "sticky_note_2",
  "tone": "amber",
  "permissions": ["notifications"],
  "size": { "width": 640, "height": 440 }
}
```

| 字段 | 含义 |
|---|---|
| `publisher`、`name` | 均为 `[a-z][a-z0-9_]*`，最多 24 个字符，publisher 至少 2 个字符。应用 id 为 `<publisher>.<name>`；面板自带应用使用的 `serverbox` 会被拒绝 |
| `version` | 最多 32 个字符 |
| `api` | `1` |
| `kind` | `web` 或 `wasm` |
| `title` | 字符串，或按语言给出的翻译（必须有 `en`）；最多 64 个字符 |
| `glyph` | Material Symbols Rounded 名称，例如 `sticky_note_2` |
| `tone` | `berry`、`soft`、`ink`、`sky`、`teal`、`violet`、`amber`、`leaf`、`pale`、`bright` 或 `mist` |
| `permissions` | 见[权限](/docs/zh/advanced/monitor-desk-apps/#权限)。`web` 应用可申请 `notifications` 和 `background`；`wasm` 应用还可申请 `status`、`files.read` 和 `exec` |
| `instances` | 最多可打开的窗口数，1 到 8（默认 1） |
| `size`、`min_size` | `{ "width", "height" }`：首个窗口的大小和允许的最小尺寸 |
| `opens` | `{ "ext": ["md", "txt"], "dirs": false }`：在 Files 的“打开方式”中可打开的文件（`"*"` 表示任意）及是否可打开目录 |
| `keywords` | Spotlight 额外匹配的词 |

## 打包

`.fsba` 是 gzip 压缩的 tar，包含 `manifest.json`、`ui/`（网页包，入口为
`ui/index.html`）、`backend.wasm`（仅且必须在类型为 `wasm` 时存在），以及可选的
`LICENSE`、`NOTICE` 和 `README.md`；其他内容不被接受。agent 只接受普通文件和普通相对
路径，最多 2000 个文件，压缩前后都不超过 20 MiB。在 macOS 上运行 `tar` 时需要设置
`COPYFILE_DISABLE=1`，否则会加入 agent 拒绝的 `._` 文件；模板的 `npm run pack` 已经
这样做。

## 后端（`wasm`）

agent 使用解释器运行 `backend.wasm`，每次调用使用新的实例，并以 agent 运行所用的系统账户运行。
模块导出 `memory`、`sbm_alloc(len) -> ptr` 和 `sbm_call(ptr, len) -> (ptr << 32) | len`。
每次调用收到 JSON `{ method, params }`，返回
`{ "ok": … }` 或 `{ "error": … }`。模块导入 `sbm.host(ptr, len)` 调用宿主函数，参数为
`{ fn, args }`：

| 函数 | 需要 |
|---|---|
| `log` | — |
| `kv.get`、`kv.set`、`kv.remove`、`kv.keys` | —（该应用自己的存储） |
| `status` | `status` |
| `fs.list`、`fs.read` | `files.read`；每次读取最多 1 MiB |
| `exec` | `exec` |

每次调用都有限制：10 秒、64 MiB 内存、1000 次宿主调用、1 MiB 请求和 4 MiB 返回。同时最多
运行 8 个调用；超出时返回 `busy`。`fs.*` 和 `exec` 还遵循 agent 的传输规则：需要 HTTPS 或
同机调用方，除非设置了 `[remote_access] allow_insecure`。

[`monitor/examples/desk-app-uptime`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/examples/desk-app-uptime)
是一个完整的 Rust 示例：

```sh
cargo build --release --target wasm32-unknown-unknown
cp target/wasm32-unknown-unknown/release/desk_app_uptime.wasm backend.wasm
COPYFILE_DISABLE=1 tar -czf example.uptime.fsba manifest.json backend.wasm ui
```

[`monitor/examples/desk-app-hello`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/examples/desk-app-hello)
是一个无需构建的 `web` 应用。

## 测试

在 **Settings → Apps → Installed** 中安装并批准应用包。每个新包都需要重新
批准，所以一次测试流程是：打包、安装、批准、打开。移除应用会清除它保存的数据。
