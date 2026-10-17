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
| `wasm` | `web` 网页包加 `backend.wasm`，即由 agent 运行的 WebAssembly component | 桌面，以及通过 `desk.call()` 和 `desk.job()` 访问自己后端的服务 |

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
| 后端 | `call(fn, args, { sudo })`、`job(fn, args, { sudo, onLine })`、`jobView`、`follow`、`cancelJob`，仅 `wasm` 应用 |
| 链接和电源 | `openUrl(url)` 在新标签页打开 http(s) 页面（frame 内的链接无法打开）；`power('reboot')` 显示桌面自己的重启对话框，需要 `root` 权限 |
| 文字和数字 | `translator(dictionaries, locale)`（与面板相同的 `{value}` 和 `{{one\|other}}` 写法）、`formatBytes`、`formatTime` |

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
| `api` | `2`（`web` 仍接受 `1`） |
| `kind` | `web` 或 `wasm` |
| `title` | 字符串，或按语言给出的翻译（必须有 `en`）；最多 64 个字符 |
| `glyph` | Material Symbols Rounded 名称，例如 `sticky_note_2` |
| `tone` | `berry`、`soft`、`ink`、`sky`、`teal`、`violet`、`amber`、`leaf`、`pale`、`bright` 或 `mist` |
| `permissions` | 见[权限](/docs/zh/advanced/monitor-desk-apps/#权限)。`web` 应用可申请 `notifications` 和 `background`；`wasm` 应用还可申请 `status`、`process` 和 `root` |
| `instances` | 最多可打开的窗口数，1 到 8（默认 1） |
| `size`、`min_size` | `{ "width", "height" }`：首个窗口的大小和允许的最小尺寸 |
| `opens` | `{ "ext": ["md", "txt"], "dirs": false }`：在 Files 的“打开方式”中可打开的文件（`"*"` 表示任意）及是否可打开目录 |
| `keywords` | Spotlight 额外匹配的词 |
| `os` | 应用适用的系统，按 `/etc/os-release` 的 `ID`（`["ubuntu"]`）；agent 的目录只在这些系统上提供它。缺省为任意系统 |

## 打包

`.fsba` 是 gzip 压缩的 tar，包含 `manifest.json`、`ui/`（网页包，入口为
`ui/index.html`）、`backend.wasm`（仅且必须在类型为 `wasm` 时存在），以及可选的
`LICENSE`、`NOTICE`、`README.md` 和 `SIGNATURE`；其他内容不被接受。ServerBox 会为自己的包签名；
没有 agent 认识的签名的包会显示为未知发布者。agent 只接受普通文件和普通相对
路径，最多 2000 个文件，压缩前后都不超过 20 MiB。在 macOS 上运行 `tar` 时需要设置
`COPYFILE_DISABLE=1`，否则会加入 agent 拒绝的 `._` 文件；模板的 `npm run pack` 已经
这样做。

## 后端（`wasm`）

`backend.wasm` 是一个 WebAssembly component（`wasm32-wasip2`）。它的 world 包含
`sbm:app/imports`（[`monitor/wit/app.wit`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/wit/app.wit)），
并导出应用自己的服务。服务用 WIT 描述，类似 gRPC 用 protobuf 描述服务：`api` 是 frame 调用并等待结果的函数，
`jobs` 是较长的任务，由 agent 作为该应用的 job 运行（同一时间只有一个），日志逐行推送给 frame。
每个函数都返回 `result<T, error>`；`error` 是 gRPC 的标准状态码，frame 收到的是 `DeskError`，
应用给出的说明在 `detail` 中。

```wit
package acme:notes;

interface api {
  use sbm:app/types@0.1.0.{error};
  record note { title: string, words: u32 }
  list: func(folder: string) -> result<list<note>, error>;
}

world notes {
  include sbm:app/imports@0.1.0;
  export api;
}
```

```ts
const notes = await desk.call<Note[]>('list', { folder: 'work' })
```

参数按名称组成一个对象传递，值以 JSON 传递：名称使用 camelCase，`variant` 为 `{ tag, val }`，
`option` 为 `null` 或其值，`result` 为 `{ ok }` 或 `{ err }`。agent 在安装时检查 component，
函数的参数或返回值含有 resource 或 stream 时拒绝安装。

agent 使用 wasmtime 运行它，每次调用或 job 使用新的实例；应用需要保留的数据通过 `kv` 保存。
它没有自己的文件、网络和环境变量。宿主函数：

| 函数 | 需要 |
|---|---|
| `log` | — |
| `kv-get`、`kv-set`、`kv-remove` | —（调用账户在该应用下的存储，JSON 文本） |
| `status` | `status` |
| `exec` | `process`：以 agent 的系统账户运行脚本 |
| `exec-root` | `root`，以及桌面为这次调用或 job 询问的 sudo 密码 |
| `job.line`、`job.run-root` | 仅 job：写一行日志；以 root 身份运行脚本，输出逐行写入日志 |

需要 root 时，frame 在请求中带上 `sudo: { title, body, confirmWord? }`；桌面在应用名称下方显示这些文字，
弹出自己的对话框，并把 sudo 密码随请求发给 agent。每次调用最多使用 64 MiB 内存、10 秒自身 CPU 时间，
总时长 60 秒；job 一直运行到返回或被取消。`process` 和 `root` 遵循 agent 的传输规则：需要 HTTPS
或同机调用方，除非设置了 `[remote_access] allow_insecure`。

[`monitor/examples/desk-app-uptime`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/examples/desk-app-uptime)
是一个简单的 Rust 示例（wit-bindgen），
[`monitor/apps/cleanup`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/apps/cleanup)
是一个包含 job 和 root 的完整示例：

```sh
cargo build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/desk_app_uptime.wasm backend.wasm
COPYFILE_DISABLE=1 tar -czf example.uptime.fsba manifest.json backend.wasm ui
```

[`monitor/examples/desk-app-hello`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/examples/desk-app-hello)
是一个无需构建的 `web` 应用。

## 测试

在 **Settings → Apps → Installed** 中安装并批准应用包。每个新包都需要重新
批准，所以一次测试流程是：打包、安装、批准、打开。移除应用会清除它保存的数据。
