# 插件系统

状态：**设计完成，未开工**。2026-09-05。

已定：

- runtime 用 `wasmi` 2.0；ABI 用 Extism v1，host 侧在 wasmi 上实现；UI 是插件返回的 JSON widget 树，宿主渲染（ruxlet 模型）。
- 现有 Dart 功能（PVE、benchmark、process、services、bmc 及其余）逐个移植为插件，移植完成后删除 Dart 实现。
- App Store 构建默认开启在线仓库，依据 App Store Review Guidelines 4.7；build flag `SBM_PLUGIN_REPO` 为退路。

---

## 一、约束

### 1.1 需求

1. 插件用任何能编译到 WASM 的语言编写。
2. 插件能在线安装、卸载、更新。
3. 插件能贡献逻辑与 UI：服务器功能栏的按钮、详情页的卡片、首页的 tab、服务器编辑器里的配置段、设置页的一段。

### 1.2 平台

| 平台 | 约束 | 来源 |
|---|---|---|
| iOS | 第三方 app 没有 JIT，WASM 只能解释执行 | 系统限制 |
| App Store | 2.5.2 禁止下载并执行「引入或改变功能」的代码；4.7 允许 app 提供「不内嵌于二进制的 plug-ins」，附带 4.7.1–4.7.5 | App Store Review Guidelines |
| F-Droid | 允许下载附加组件，条件是显式 opt-in，并向用户说明这绕过了 F-Droid 的检查；`NonFreeAddons` 适用于推广非自由插件的 app | 收录政策第 5 条、Anti-Features |
| 全部 | 插件不能用 Dart 编写：dart2wasm 的产物面向 JS 宿主，不能在 wasmtime / wasmi 里运行 | [dart-lang#53884](https://github.com/dart-lang/sdk/issues/53884) |

### 1.3 一个功能今天接触宿主的位置

PVE 是量过的例子：自身三个文件约 1700 行，另嵌在 15 个文件里。按扩展点归类之后，每个功能接触的是同一组位置：

| 位置 | 文件 | 今天的做法 |
|---|---|---|
| 功能栏按钮 | `data/model/app/menu/server_func.dart`、`view/widget/server_func_btns.dart` | enum 一项；`icon` / `toStr` / `availableWith` 三个 switch；`_onTapMoreBtns` 一个 case。**存储的是 enum index** |
| 详情页卡片 | `data/model/app/server_detail_card.dart`、`view/page/server/detail/view.dart` | enum 一项；`_cardBuildMap` 一项；一个 `_buildXxx`。存储的是 name |
| 首页 tab | `data/model/app/tab.dart`、`view/page/home_tab.dart` | enum 一项（带 `@HiveField`）；`page` / `icon` / `selectedIcon` / `label` 四个 switch |
| 服务器编辑器 | `view/page/server/edit/{edit,widget,actions}.dart` | 每个功能一组 controller、一个 `_buildXxx`、保存时一段拼装 |
| `server` 表上的列 | `data/store/db.dart`、`data/store/server.dart`、`data/model/server/custom.dart`、m004、m006、m017 | `pve_addr` / `pve_ignore_cert` / `pve_pwd`、`bmc_addr` / `bmc_cred_id` / `bmc_cert_sha256` |
| 自有表 | `benchmark_run`、`bmc_credential` | Drift table、migration、`Tables.names`、`Stores` getter 与 GetIt 注册、`BackupV2` 字段各一处 |
| 设置 | `data/store/setting.dart`、`view/page/setting/entries/*.dart`、`SettingsSection` | container 有四个 prop 和一个 section |
| 诊断 | `core/diag.dart` | 一个 `DiagCategory` |
| 生命周期 | `data/provider/pve.dart` 监听 `serverProvider`；`data/provider/server/all.dart:421` 删除时 invalidate | 每个功能各写一遍 |
| 错误类型 | `data/model/app/error.dart` | `PveErr` |
| 连接前置条件 | `server_func_btns.dart` 的 `_ensureExec` / `_ensureSshClient` | 按 case 手动选择 |

`availableWith` 与 `_onTapMoreBtns` 两个 switch 表达同一件事：这个按钮需要哪种 capability。这是 manifest 里 `needs` 字段的依据。

PVE 自身需要宿主提供的东西，是 host function 列表（4.3）的来源：

| PVE 做的事 | 需要宿主给的东西 |
|---|---|
| 开一条 SSH 端口转发（`SSHForwardChannel` + 本地 `ServerSocket.bind`），因为 PVE 的 API 通常不对公网开放 | 经该服务器 SSH 连接建立的 TCP 连接 |
| 登录，处理 2FA challenge | 弹对话框、等用户输入、再继续 |
| 持一个 Dio session，可选忽略证书 | HTTP 客户端与一个安全策略的例外 |
| 按共享刷新间隔轮询 | 定时器与前后台、连接状态 |
| 每个 node / guest 一张卡片，卡片上有操作 | Flutter widget |

---

## 二、总览

| 问题 | 结论 | 章节 |
|---|---|---|
| runtime | `wasmi` 2.0，编进 `crates/sbm_ffi` | 三 |
| 插件与宿主之间的 ABI | Extism ABI v1，host 侧在 wasmi 上实现；10 种语言的官方 PDK 不改即可用 | 四 |
| UI | 插件每次调用返回一棵 JSON widget 树，宿主按固定词汇表构建 Flutter widget，Flutter 的 element tree 做 diff | 五 |
| 权限 | manifest 声明，链接期执行，测试挂真 linker | 六 |
| 存储 | 宿主拥有三张表；插件没有自己的表与 migration | 七 |
| 分发 | Ed25519 签名的 index，机制与 `shellbox-rootfs` 相同；随包一份作为下限 | 八 |
| Dart 插件层 | 没有。只有一种 ABI | — |

一个插件是一个 `.sbp` 包（zip）：`manifest.json`、`plugin.wasm`、`l10n/*.json`、`icon.png`。宿主给它 4.3 的 host function；它给宿主 widget 树和事件处理。

宿主侧代码在 `lib/plugin/`（registry、manifest model、widget 词汇表渲染器、安装页面）与 `crates/sbm_plugin/`；Rust 作者的 SDK 是 `crates/serverbox_plugin_api`（发布到 crates.io，隐藏 ABI，Zed 的 `zed_extension_api` 做法）；随包插件在 `assets/plugins/`；插件源码在独立仓库 `lollipopkit/serverbox-plugins`。

验收：

- `crates/sbm_plugin/tests/pdk_compat.rs`：Rust、Go、JS 三种 PDK 编译的同一个插件在 wasmi 上运行；CI 覆盖五个平台的 host。
- `crates/sbm_plugin/tests/permission_scope.rs`：import 全部 host function 的模块，在每种 manifest 下实例化，未授权的调用必须 trap。
- `test/plugin_isolation_test.dart`：扫描 `lib/`，插件 id 只允许出现在 `lib/plugin/`、`lib/l10n/`、`assets/plugins/`。
- `crates/serverbox_plugin_api` 自带测试 harness：host function 的应答由测试脚本给出，插件在没有 app 的情况下跑完一次交互（Crux 的「测试充当 shell」）。移植时 Dart 侧的 fixture 迁到这里。

---

## 三、runtime

| 方案 | iOS | 二进制 | 载入一个模块 | 缺的 proposal | 说明 |
|---|---|---|---|---|---|
| **`wasmi` 2.0** | 解释器，纯 Rust，`no_std` | 约 1 MB | 毫秒级（流式翻译） | `gc`、`exception-handling`、`threads`、`function-references`；无 component model | 2026-09-01 发布，较 1.0 快 2.2 倍；两次安全审计；`wasmi_wasi` 提供 wasip1；fuel 计量。Zellij 2026 年从 wasmtime 迁到 wasmi：载入从秒级到毫秒级，去掉了编译缓存，二进制变小 |
| wasmtime + Pulley | 解释器；维护者 2026-01 确认可用 | Cranelift 必须编进来，10–20 MB | 一次 Cranelift 优化编译，秒级；产物绑定 wasmtime 版本 | 无 | Pulley 是 Tier 3；iOS 属「支持但测试较少」；需要 `signals_based_traps(false)` |
| WAMR | 官方平台列表无 iOS | C，cmake + bindgen | 快 | 无 component model | 12 个 target 各需 C 工具链；本仓库为 RSA 已拒绝过同类代价 |
| Extism 官方 runtime | 基于 wasmtime，无 iOS | — | — | — | ABI 与 runtime 无关，见第四节 |
| `wasm_run` 包 | 可能 | 第二套工具链 | — | — | 已停更，钉在 wasmtime 14 / wasmi 0.31 |
| QuickJS / Lua 解释器 | 可以 | 小 | — | — | 只覆盖一种语言 |

选 `wasmi`。加进 `sbm_ffi` 只是一个 Cargo 依赖：`hook/build.dart` 已经为五个平台构建这个 crate，不需要 podspec，不需要新的构建脚本。

代价是 `gc` 与 `exception-handling` 缺席，Kotlin/Wasm 因此排除；wasmi 3.0 的路线图包含这两项。

**能写插件的语言**（Extism 官方 PDK）：Rust、Go（TinyGo）、C、C++、Zig、AssemblyScript、Haskell、.NET（C# / F#）、JavaScript（QuickJS-ng 经 wizer 冻结，模块约 1 MB 起，JS 解释器运行在 wasm 解释器里，计算密集部分预期慢 50–100 倍）、Python（PyO3 + wizer，需要 WASI）。

---

## 四、ABI

### 4.1 Extism ABI，host 自己实现

Extism 的 ABI 由两部分组成：一个 kernel 模块（`extism-runtime.wasm`，Rust 编译到 `wasm32-unknown-unknown`，负责内存分配与 input / output 缓冲，与每个插件实例链接）和 host 提供的 `extism:host/env` 函数（`config_get`、`var_get`、`var_set`、`http_request`、`http_status_code`、`http_headers`、`log_*`、`get_log_level`）。数据以 `(offset, length)` 指向线性内存，PDK 在上面封装 JSON。

官方 Rust runtime 基于 wasmtime，但这个 ABI 已被独立实现过：`go-sdk` 在 wazero 上、`chicory-sdk` 在 Chicory 上、`js-sdk` 在浏览器上。`crates/sbm_plugin` 做同一件事：在 wasmi 上链接 kernel、实现 `extism:host/env`，再加本 app 的 `extism:host/user`。选它的理由是 PDK：每种语言一个，由 Extism 维护。ABI 钉在 v1（2023-12 起稳定）。

### 4.2 Exports（插件 → 宿主）

输入输出都是 JSON。

| export | 时机 | 返回 |
|---|---|---|
| `init(ctx)` | 实例创建后一次 | — |
| `open(surface, ctx)` | 页面 / 卡片 / tab / 设置面首次显示 | `{ui: Node}` |
| `on_event(msg, value?)` | 用户操作。`msg` 是节点 `on` 里插件自己放的 JSON，`value` 是输入控件的当前值 | `{ui: Node}` |
| `tick()` | 宿主按共享刷新间隔调用，仅当 surface 可见 | `{ui: Node}` |
| `on_server_event(e)` | connected / disconnected / deleted | — |
| `validate_config(cfg)` | 编辑器保存前 | `{errors: [...]}` |
| `tool_<name>(args)` | AI agent 调用 manifest 声明的 tool | JSON |
| `dispose()` | 实例销毁前 | — |

### 4.3 Host functions（宿主 → 插件可调用），`extism:host/user`

| 函数 | 需要的权限 | 对应今天的宿主实现 |
|---|---|---|
| `server.exec(script, opts)` | `server.exec` | `ServerNotifier.ensureExec` → `ServerExec.run`。`opts.server` 必须是宿主发出的句柄：server surface 的绑定服务器，或 `ui.pickServer()` 的返回值 |
| `http.request(req)` | `net.http`；`req.via == "ssh"` 另需 `server.stream` | 替代 Extism 内建的 `http_request`。`via: ssh` 时宿主经 `ensureShellClient` 的 `SSHForwardChannel` 建连；`ignoreCert`、cookie jar 由宿主持有。PVE 的端口转发与 Dio session 合并为这一个函数 |
| `ui.patch(path, node)` | 无 | 替换上一棵树里 JSON Pointer 指向的子树。长任务流式更新用，避免每行日志重发整棵树 |
| `ui.prompt(spec)` | `ui.dialog` | `context.showRoundDialog`，阻塞到用户回答。PVE 的 2FA 用 |
| `ui.pickServer()` | 无 | `server_picker.dart`。全局 surface（tab）选目标服务器用；返回的句柄可用于 `server.exec` |
| `ui.toast(text)` | 无 | `Toast.show` |
| `store.get / set / list(prefix)` | 无（自己的命名空间） | Extism `var_get / var_set` 的持久化版本，见第七节 |
| `config_get` | 无 | 插件设置 + 绑定服务器上的插件配置 |
| `log_*`、`diag.crumb(name)` | 无 | `Loggers`；`DiagCategory('plugin:<id>')`。只记录调用发生，不记录内容 |
| `nav.openServer(id)`、`nav.goTab(id)` | 无 | `homeTabRequestProvider` |

这两张表是 1.3 问题的答案，也是权限清单本身。每一行加入即永久；版本号在 manifest 的 `abi`，宿主只加不减。

### 4.4 线程模型

一个实例对应一个（插件，服务器）二元组；tab 这种全局 surface 对应（插件，null）。实例固定在 `sbm_ffi` 线程池的一条线程上（Zellij 的 pinned-thread 模型，分配与释放在同一线程）。

host function 从插件看是同步的：Rust 线程经 flutter_rust_bridge 的 `DartFnFuture` 调 Dart，阻塞到 Dart 的 async 工作完成。wasm 执行受 fuel 限制；host 调用受 Dart 侧超时限制；取消等于丢弃实例。内存上限 64 MB，`trap_on_grow_failure`。

UI isolate 不解析任何插件数据。今天的 PVE 在 `Computer` 上解析响应，是同一目的的临时做法。

---

## 五、UI

模型来自 ruxlet：插件的 `view` 返回一棵 widget 树，宿主用一个通用 renderer 构建 Flutter widget；状态与消息都在插件侧，副作用经 host function。本设计里 `open` / `on_event` / `tick` 三个 export 的返回值就是 `view` 的输出。

### 5.1 节点

```json
{
  "t": "column",
  "k": "guests",
  "p": {"spacing": 8},
  "c": [
    {"t": "kv", "p": {"k": "CPU", "v": "12%"}},
    {"t": "btn", "p": {"label": "l10n.start"}, "on": {"tap": {"start": 101}}},
    {"t": "input", "k": "search", "p": {"value": "web"}, "on": {"change": {"search": null}}}
  ]
}
```

- `t`：词汇表里的类型名。布局：`column`、`row`、`expanded`、`padding`、`sized`、`scroll`、`list`、`spacer`、`divider`；本 app 的控件：`card`（`CardX`）、`kv`（`KvRow`）、`expand`（`ExpandTile`）、`percent`（`PercentCircle`）、`line_chart`、`bar_chart`、`btn`、`input`、`table`、`progress`、`tag`、`text`、`icon`。词汇表是 UI 侧的 API，与 4.3 同等永久，只加不减。
- `k`：稳定 key，映射为 `ValueKey`。有 key 的输入控件在重建之间保留焦点与光标，这是 ruxlet 记录的经验，也是 Flutter element tree 的 diff 规则。
- `p`：属性。字符串以 `l10n.` 开头时宿主按当前 locale 从 `l10n/<locale>.json` 取值，回退 `en`。
- `on`：事件到消息的映射。值是插件自己定义的 JSON，宿主原样交给 `on_event`；输入控件另附 `value`。
- 未知的 `t` 或不合法的 `p` 渲染为一张错误卡片并记 log，不抛出。

每次调用返回整棵树，宿主重建该 surface 的 widget 子树，diff 由 Flutter 完成。一页二十个 guest 约两百个节点、二十 KB，每个刷新间隔一次，在 FFI 上可以忽略。流式输出（benchmark 的日志）用 `ui.patch` 替换子树。

### 5.2 Surface

`page`（功能栏按钮打开的页面）、`card`（详情页卡片）、`tab`（首页 tab）、`settings`（设置页的一段）。宿主为每个 surface 持有上一棵树；`open` 给出第一棵，之后由 `on_event`、`tick`、`ui.patch` 更新。

**服务器编辑器里的配置段不走这套树。** manifest 的 `config.fields` 声明字段（`key`、`type: text | password | bool | int | select`、`label`、`secret`、`role: address`），宿主用自己的表单控件渲染；跨字段校验走 `validate_config`。理由：表单是宿主已经有的东西，`Input` 与 `TipText` 的写法统一比可定制重要。

### 5.3 SDK

`crates/serverbox_plugin_api` 提供 `UiNode<Msg>` 的类型化 builder（`column([...])`、`btn(label).on_tap(Msg::Start(101))`）与 `Msg` 的序列化，Rust 作者不接触 JSON。其他语言按 SDK 发布的 JSON schema 直接构造。

### 5.4 测试

词汇表里每个类型一组 golden：一份 JSON 节点加一张截图。类型的属性一旦发布不能变，golden 是能捕获这一点的测试。插件侧的测试用 5.3 的 harness：给定 host function 的应答，断言返回的树。

### 5.5 考虑过的替代

| 方案 | 未采用的原因 |
|---|---|
| `rfw`（Remote Flutter Widgets） | 两种产物（`.rfwtxt` 树与数据），插件作者要学一门 DSL；数据绑定与 `switch` 的语义是第二套要写文档的东西。它的优点（Flutter 团队维护、格式向后兼容）在 5.1 的节点 schema 上同样可以做到 |
| Dioxus 的 `WriteMutations` 协议 | 一条 mutation 流需要宿主维护一棵 real DOM 并按 `ElementId` 应用；Flutter 重建 widget 树时 element tree 已经在做同一件事。ruxlet 也只为节省传输才 diff |
| egui 之类在 wasm 内自绘、宿主贴图 | 失去本 app 的控件外观、无障碍与文字选择；每帧跨 FFI |
| WebView | 桌面 Linux 的 WebView 依赖不稳定；外观与 app 不一致；与 iSH 的 2.5.2 经验同类 |

---

## 六、权限

### 6.1 清单

| 权限 | 含义 |
|---|---|
| `server.exec` | 在句柄指向的服务器上执行命令 |
| `server.stream` | 经句柄指向的服务器的 SSH 连接建立 TCP 连接（`http.request` 的 `via: ssh`） |
| `net.http: [pattern]` | 直连 HTTP。pattern 可以是 glob，也可以是 `$config.<key>`，指向 `role: address` 的配置字段 |
| `ui.dialog` | 弹对话框并等待输入 |
| `clipboard` | 读写剪贴板 |
| `storage.sync` | 自己的 kv 参与备份同步 |

始终授予：`store`、`config_get`、`ui.patch`、`ui.pickServer`、`ui.toast`、`log`、`nav`。

### 6.2 执行

**链接期。** 未授权的 host function 链接到一个 trap `PermissionDenied` 的 stub；运行路径上没有 `if granted`。这是 watch token 的做法：作用域由路由表定义。`permission_scope.rs` 挂真 linker，对每种 manifest 断言每个未授权函数 trap；另一条测试断言 linker 的函数表与 4.3 逐项相等，新增 host function 不更新文档与测试就不通过。

**服务器作用域**由句柄给出。插件只能对宿主发给它的句柄执行 `server.exec` 与 `via: ssh`。插件拿不到 `spi.ssh.pwd` 或任何凭据。

**用户同意**。安装时列出权限；更新新增权限时重新同意；首次开启在线仓库时的对话框按 F-Droid 收录政策第 5 条措辞。这同时满足 App Store 4.7.3「每个软件单独取得用户同意」。

---

## 七、存储

宿主拥有三张表；插件没有自己的表，也没有 migration。

```sql
CREATE TABLE plugin_install (
  id TEXT NOT NULL PRIMARY KEY,
  version TEXT NOT NULL,
  repo TEXT,                  -- NULL 表示随包
  enabled INTEGER NOT NULL,
  granted TEXT NOT NULL,      -- JSON，用户同意过的权限
  installed_at INTEGER NOT NULL
) WITHOUT ROWID;

CREATE TABLE server_plugin_cfg (
  server_id TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE,
  plugin_id TEXT NOT NULL,
  cfg TEXT NOT NULL,          -- JSON，按 manifest 的 config.fields
  cfg_ver INTEGER NOT NULL,
  PRIMARY KEY (server_id, plugin_id)
) WITHOUT ROWID;

CREATE TABLE plugin_kv (
  plugin_id TEXT NOT NULL,
  server_id TEXT REFERENCES server (id) ON DELETE CASCADE,  -- NULL 表示全局
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (plugin_id, server_id, key)
) WITHOUT ROWID;
```

- `server_plugin_cfg` 用 JSON 列，理由与 `tables.dart` 给 `setting` 的相同：没有按字段的查询，宿主对内容不可知。`cfg_ver` 由插件在 `init` 里自行升级。秘密字段（PVE 密码）与今天 `pve_pwd` 列的保护级别一致：整库加密。分享时按 `secret` 去掉，今天 `server_share.dart:126` 对 `bmc.credId` 手写的就是这个。它是 `server` 的子表，写入 stamp 父行，与 `container_host` 相同。
- `plugin_kv` 是 Extism `var_get / var_set` 的持久化。benchmark 的历史（每台 50 条，每条几十 KB）放这里，上限由插件维护。设备本地；声明了 `storage.sync` 的插件，其 kv 作为一个以插件 id 为键的 sync root。
- 备份：`BackupV2` 增加 `plugins: {id: {cfg: [...], kv: [...]}}`，通用。
- 卸载：删文件、删三张表里的行、撤销权限。是否保留 `server_plugin_cfg` 与 `plugin_kv` 问用户。
- 用户排列过的按钮、卡片、tab 按 id 存储。安装插件时把它 `defaultOn` 的贡献追加到用户的行里，卸载时移除；没有插件认领的 id 读取时丢弃。这替代了 `introducedAfterBuild`：随包插件在首次运行带它的版本时安装，效果相同。
- 迁移（m021）：`serverBtns` 从 enum index 改为 id，`ServerFuncBtn` 冻结进 `legacy_adapters.dart` 供 Hive 导入映射；`pve_*`、`bmc_*` 列在对应插件交付时迁入 `server_plugin_cfg`，旧列保留一个版本（标 TODO），之后按 m017 的 create-copy-drop-rename 删除。`hive_release_migration_test.dart` 三组 fixture 原样通过。

---

## 八、分发与安装

### 8.1 仓库

新建 `lollipopkit/serverbox-plugins`，与 `shellbox-rootfs` 同样刻意不作 submodule。GitHub Releases 发布 `index.json` 与 `index.json.sig`。验证复用 `RootfsManifestTrust` 的三条：对下载的原始字节验签再解析、serial 回滚保护、`valid_until`。Ed25519，公钥编进 app。

index 每项：`id`、`version`、`abi`、`sha256`、`size`、`url`、`permissions`、本地化名称与描述、`license`、`source_url`。

官方仓库只收 FOSS 插件，`NonFreeAddons` 由此不适用。第三方仓库：用户输入 URL 与公钥指纹，首次显示指纹让用户核对。

### 8.2 安装、随包、更新

安装：下载 `.sbp`，校验 `sha256`，解压到 `Paths.doc/plugins/<id>/<version>/`，wasmi 在安装时验证模块，写 `plugin_install`。任一步失败回滚目录。

随包：`assets/plugins/*.sbp` 首次启动安装，`repo = NULL`。离线、验签失败、在线仓库关闭时都有这一份；仓库里的更新覆盖它。

更新：与 `RootfsManifestSource.refresh` 同一节奏；权限有增量时先同意后安装。

本地开发：桌面版可以从一个目录加载未打包、未签名的插件（Zed 的 Install Dev Extension），`plugin_install.repo = 'dev'`，页面上标出。这是插件作者的调试通路，也是移植期间跑 Dart 与插件两份实现做对比的通路。

版本兼容：manifest 的 `abi` 与 app 版本的对应表放在 SDK 的 README（Zed 的做法）。app 拒绝 `abi` 高于自己的插件，index 里同一插件保留多个 `abi` 的版本。

### 8.3 平台政策

**App Store**。4.7 原文：「Apps may offer certain software that is not embedded in the binary, specifically HTML5 and JavaScript mini apps and mini games, streaming games, chatbots, and plug-ins」，附带条件 4.7.1–4.7.5。对本设计有约束力的三条：4.7.2 不得向该软件扩展或暴露原生平台 API（4.3 的 host function 是 app 级功能，非平台 API，属灰色）；4.7.3 每个软件单独取得用户同意（6.2 的安装对话框）；4.7.4 提供包含 universal link 的软件 index（`website/` 为每个插件生成一页）。2.5.2 的风险仍然存在：2026 年 3 月以来 Apple 对运行时下载代码的执法趋严，WASM 解释执行没有判例。已定默认开启；退路是 build flag `SBM_PLUGIN_REPO`，关闭后 App Store 构建只有随包插件，功能不变，一次普通发版即可切换。

**F-Droid**。收录政策第 5 条允许下载附加组件，条件是显式 opt-in 并说明绕过了 F-Droid 的检查。在线仓库默认关闭，开关旁放这段说明。

---

## 九、状态命令插件

`crates/sbm_parser` 的命令清单（一条命令加一个解析器，字节进、类型化计数出）在同一 runtime 上是第二组 export（`status_cmd`、`parse`），不需要 UI 与权限。不在第一批；manifest 的 `contributes.status` 段为它留位。monitor 执行同一个模块是它的延伸，不在本设计范围。

---

## 十、顺序

每步一个 PR，每步验证一个不可替代的部分：

1. `crates/sbm_plugin`：wasmi + Extism ABI host + 权限 linker + `pdk_compat.rs` / `permission_scope.rs`；`sbm_ffi` 暴露 `load / call / drop`；Dart 侧 `PluginHost` 回调；`crates/serverbox_plugin_api` 与它的测试 harness。不碰 `lib/` 的功能代码。
2. 宿主：registry、manifest → contributions（功能栏、卡片、tab、设置改为遍历）、m021、词汇表渲染器与 golden、`PluginPage` / `PluginCard`、安装 / 卸载页面、本地开发目录、三张表、备份字段。
3. PVE 移植为 Rust 插件，随包发布。按「test as spec」：先把 `pve_test.dart` 的 fixture 移到插件的测试里，结果一致后删除 Dart 实现。验证 `http.request via ssh`、`ui.prompt`、实例状态跨调用、`tick`、`card` + `page`。
4. benchmark 移植。验证 `tab`、`ui.pickServer`、`plugin_kv`、备份、长任务（`setsid` 分离运行不受影响：命令仍然短，`YabsScript` 的生成逻辑进插件）。
5. process、services 移植。验证列表 / 表格 widget 与按系统类型的可用性。
6. 在线仓库、第三方仓库、`website/` 的 index 页；之后 bmc 与其余功能。

---

## 十一、代价

| 项 | 说明 |
|---|---|
| 调试 | 一个功能跨 Dart、FFI、wasm 三层；插件侧靠 5.3 的 harness 与 log |
| 词汇表的表达力 | 只能用 5.1 列出的类型；自定义绘制、复杂手势、动画不可用。每加一个类型都是永久 API |
| 整棵树重发 | 每次 `tick` 传整棵树；大列表（process 页几百行）要靠 `list` 类型只传可见窗口，或 `ui.patch` |
| 解释执行 | wasmi 较原生慢一个数量级；JS / Python 插件再乘一层。对本 app 的负载（解析命令输出、拼 JSON）可接受，对计算密集任务不可接受 |
| 缺 `gc` / `exception-handling` | Kotlin/Wasm 排除，等 wasmi 3.0 |
| 政策 | 2.5.2 无 WASM 判例；4.7.2 属灰色。`SBM_PLUGIN_REPO` 是退路 |
| ABI 永久 | 4.2、4.3 两张表与 5.1 的词汇表一旦发布，每次改动要考虑所有已发布插件 |
| Extism ABI 版本 | 钉在 v1。Extism 若出 v2，PDK 升级后 host 需要跟进 |
| 多卡片刷新 | 详情页多张插件卡片同时 `tick`，每张一次 wasm 调用加一次重建；`tick` 只在可见时调用是第一道缓解 |
| 二进制 | wasmi 约 1 MB，每个 ABI 一份；渲染器是纯 Dart |
| 移植量 | PVE 三个文件 1700 行、process 1167 行、benchmark 约 2000 行要用另一种语言重写。「test as spec」把风险压到 fixture 上 |
| 失去 exhaustive switch | 少写一个贡献是运行时缺失。由 `plugin_isolation_test.dart` 与 golden 覆盖 |

---

## 十二、参考项目

| 项目 | 是什么 | 借鉴了什么 |
|---|---|---|
| [ruxlet](https://github.com/mikolajbadyl/ruxlet) | Rust 写状态与 `view`，Flutter 作通用 renderer；Elm 式 `update` / `Cmd` / `Sub`；稳定 key 保留焦点 | 第五节的整个模型：插件返回 widget 树，宿主渲染，事件带消息回插件。它只支持桌面、0.2.x、cdylib 直接加载，借用的是模型，代码不用 |
| [Crux](https://github.com/redbadger/crux) | Rust core 无副作用，`update` 返回 effect 请求，shell 执行后 `resolve`；core 可编译到 WASM；「测试充当 shell」 | 5.3 的测试 harness。它的 effect / resolve 模型没有采用，原因是 Extism 的 PDK 假设 host function 同步，换模型就失去十种语言 |
| [Zed extensions](https://zed.dev/blog/zed-decoded-extensions) | `zed_extension_api` crate 隐藏 WIT；`extension.toml`；registry 仓库由 CI 构建并发布 index；本地目录作 dev extension；api 版本与 app 版本对应表 | 二节的 SDK crate、8.2 的本地开发与版本兼容、8.1 的仓库形态。它用 wasmtime + component model，不适用于 iOS |
| [Zellij](https://github.com/zellij-org/zellij/pull/4449) | wasmi 上的插件系统；pinned-thread；`StoreLimits` | 第三节的 runtime 选择、4.4 的线程模型与内存上限 |
| [Dioxus](https://docs.rs/dioxus-core/latest/dioxus_core/trait.WriteMutations.html) | VDOM 与 renderer 之间用 `Mutation` 流 | 5.5 里评估后未采用 |
| [rfw](https://pub.dev/packages/rfw) | Flutter 团队的远程 widget 描述格式 | 5.5 里评估后未采用；它的「local widget library 是永久 API、用 golden 锁」保留在 5.4 |
| [Rinf](https://github.com/cunarist/rinf)、[Oxide](https://github.com/oxide-stack/oxide) | Rust 持有状态、Flutter 消费快照的 FRB 上层 | 与本设计同向，但都是同一二进制内的 Rust，不涉及沙箱与分发 |
| [frui](https://github.com/fruiframework/frui)、[Xilem / Masonry](https://github.com/linebender/xilem)、Freya | 在 Rust 里重做 Flutter 式 widget 树并自绘 | 不适用：目标是替代 Flutter，本设计的目标是让插件用 Flutter 的控件 |

---

## 参考

- [Wasmi 2.0 发布](https://wasmi-labs.github.io/blog/posts/wasmi-v2.0/) · [crates.io](https://crates.io/crates/wasmi) · [Zellij 从 wasmtime 迁到 wasmi（PR #4449）](https://github.com/zellij-org/zellij/pull/4449)
- [wasmtime Pulley 在 iOS（#12251）](https://github.com/bytecodealliance/wasmtime/issues/12251) · [wasmtime 支持层级](https://docs.wasmtime.dev/stability-tiers.html)
- [Extism PDK](https://extism.org/docs/concepts/pdk/) · [Extism kernel](https://github.com/extism/extism/tree/main/kernel) · [go-sdk（wazero 上的 ABI 实现）](https://github.com/extism/go-sdk)
- [ruxlet](https://docs.rs/ruxlet/latest/ruxlet/) · [Crux 的 managed effects](https://redbadger.github.io/crux/part-2/effects.html) · [Zed 扩展的构建与分发](https://zed.dev/blog/zed-decoded-extensions) · [rfw](https://pub.dev/packages/rfw)
- [App Store Review Guidelines 4.7](https://developer.apple.com/app-store/review/guidelines/#4.7) · [F-Droid 收录政策](https://f-droid.org/docs/Inclusion_Policy/) · [F-Droid Anti-Features](https://f-droid.org/docs/Anti-Features/)
- [Dart / WebAssembly 编译](https://dart.dev/web/wasm) · [`wasm_run`](https://pub.dev/packages/wasm_run)
- [Fixing Section 2.5.2](https://saagarjha.com/blog/2020/11/08/fixing-section-2-5-2/) · [Guideline 2.5.2 被拒案例](https://ptkd.com/journal/guideline-2-5-2-downloading-scripts-without-review)
