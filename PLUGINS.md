# 插件系统

ServerBox 插件用 JavaScript 或 TypeScript 编写，可以增加服务器指标、详情卡片和操作页面。插件负责处理数据和描述界面，ServerBox 负责绘制 Widget，以及执行命令、访问网络和保存数据。

当前分支已接通 QuickJS runtime、TypeScript SDK、Flutter host、安装与更新、在线仓库，以及 monitor agent 的状态采集。`packages/plugins/` 中的监听端口、磁盘占用和定时任务插件用于验证这些接口。本文说明当前设计、实现进度和待办，不代表这些功能都已发布到各平台商店。

2026-09-06，插件方案从 WebAssembly 改为 JavaScript，旧 Rust SDK 和 BMC 插件已删除。选型依据和当时的测量见第三节。PVE、benchmark、process、services 和 BMC 等内置功能继续用 Dart 实现；BMC 的决定见 4.9。

## 一、要解决什么问题

### 1.1 用户和作者能做什么

用户可以安装、更新、停用和卸载插件，也可以添加第三方仓库。作者可以增加状态指标，并在服务器功能栏、详情页、首页和设置页提供界面；服务器编辑器中的插件配置由 manifest 声明。

每个插件最终是一个 ES module。App 直接加载 JavaScript，不需要按平台分别编译。使用 TypeScript 或第三方依赖时，作者在发布前将它们打包成单个 JavaScript 文件。

本文使用以下术语：

- **host**：运行插件并提供接口的 ServerBox，包括 Rust runtime、Flutter App 或 monitor agent。
- **manifest**：`manifest.json`，声明名称、版本、权限、配置字段和界面入口。
- **ABI**：插件与 host 交换数据、调用函数的约定；修改时需要考虑已有插件。
- **surface**：插件在 App 中的一块显示区域，例如详情卡片或独立页面。
- **SDK**：插件作者使用的类型定义、Widget 构造函数和辅助工具。

### 1.2 平台限制

iOS 方案不依赖 JIT。QuickJS 解释执行 JavaScript，不需要生成可执行内存页，也不需要额外的 JIT entitlement。

解释执行不等于允许在线下载代码。App Store 和 F-Droid 的分发安排见第八节，其中 App Store 2.5.2 的审核不确定性不会因为采用 JavaScript 而消失。

App 内没有加载第三方 Dart 代码的 runtime，dart2wasm 的产物也需要 JavaScript host 环境，因此插件不使用 Dart 编写。相关问题见 [dart-lang/sdk#53884](https://github.com/dart-lang/sdk/issues/53884)。

### 1.3 内置功能为什么难加

此前新增功能往往需要同时修改按钮 enum、图标和名称的 switch、详情卡片、首页 tab、编辑表单、数据库、设置、备份和生命周期处理。以当时统计的 PVE 为例，功能自身的三个文件约 1700 行，接入代码还分散在另外 15 个文件中。

入口的存储方式也不统一：功能栏按钮使用 enum index，详情卡片使用 name，首页 tab 还有 Hive 字段编号。调整入口时容易影响旧数据。

当前已用 `Feature`、`FeatureSlot` 和 `Features` 统一入口 ID、默认显示规则和新增入口的处理方式。是否可用、是否需要 SSH 等条件也由 registry 集中声明。内置 Widget 和点击逻辑仍由 Dart enum 提供，插件则通过 manifest 的 `contributes` 提供入口信息。

### 1.4 内置功能与第三方插件分开处理

内置功能随 App 发布，使用 Dart feature registry。按钮存储已在 m021 从 enum index 迁到稳定 ID，备份恢复也会处理旧格式。

第三方插件需要独立安装、授权和版本管理。把所有内置功能改成插件，按原估算会增加约 6600 行重写工作，还会让调试跨越 Dart、FFI 和 JavaScript 三层，并受插件 Widget 范围限制。

接口验证使用 `packages/plugins/` 中的三个插件。它们最初只有 `page`，目前已补上监听端口的 `card`、磁盘占用的 `settings` 和定时任务的多服务器 `tab`。四种 surface 都已有实际用例，golden 截图仍待补齐。

## 二、整体怎么工作

host call 每个方向传一个 JSON 值。需要多个字段时，将它们放在同一个 request 对象中，不能写成多个位置参数；SDK 的 `Sb` 和 `MockHost` 必须与实际调用方式一致。

插件包是扩展名为 `.sbp` 的 zip，包含 `manifest.json`、`plugin.js`，以及插件提供的 `l10n/*.json`、`icon.png` 和 `assets/`。`plugin.js` 导出第四节约定的函数。

带界面的插件按以下流程运行：

1. ServerBox 读取 manifest，检查 ABI 和权限，注册界面入口。
2. 用户打开 surface 时，host 创建 QuickJS instance，装入已授权的接口并加载脚本。
3. host 调用插件，插件返回描述界面的 JSON tree。
4. Flutter 将 tree 渲染成 App 的 Widget。
5. 用户操作后，host 将 event 交给插件，插件返回新 tree 或发送 patch。

插件不能直接操作 Flutter Widget。命令、网络、对话框和存储都通过 host 接口访问。

| 位置 | 职责 | 当前状态 |
|---|---|---|
| `crates/sbm_plugin` | QuickJS runtime、权限和 manifest 检查、instance 线程、异步 bridge、状态结果校验 | 已实现 |
| `packages/plugin-api` | TypeScript 类型、Widget 构造、状态管理、frame 裁剪和 MockHost | 已实现 |
| `packages/plugins/*` | 监听端口、磁盘占用、定时任务 | 已实现，带 MockHost 和真实 QuickJS 测试 |
| `crates/sbm_ffi` 的插件接口 | 让 Dart 加载、调用和释放插件 | 已实现 |
| `lib/data/model/plugin/`、`lib/data/provider/plugin/`、`lib/view/widget/plugin/`、`lib/view/page/plugin/` | 配置、host callback、渲染、安装和仓库页面 | 已实现 |
| `assets/plugins/` | 随 App 分发的插件包 | 未采用，目前没有随 App 分发的插件 |
| `lollipopkit/serverbox-plugins` | 官方仓库和插件包 release；源码仍在本仓库 | 发布流程已接通 |

原开发记录中的阶段性测试数量为：runtime 113 个、SDK 45 个、FFI 17 个。它们来自不同阶段，不是当前测试总数，也不是本次文档修改重新验证的结果。

只维护一套插件接口，不另做 Dart 插件 SDK。TypeScript SDK 计划发布到 npm，并提供 `.d.ts`，供 JavaScript 作者获得编辑器提示。

## 三、为什么选 QuickJS

插件由 [quickjs-ng](https://github.com/quickjs-ng/quickjs) 执行，Rust 侧通过 `rquickjs` 绑定。本节记录 2026-09-06 从 WebAssembly 改到 JavaScript 的依据和实测数据。

先前方案使用 `wasmi` 2.0 和 Extism ABI v1，主要看重多语言 PDK、隔离和 fuel 计量。后来决定只提供 JavaScript / TypeScript 写法，多语言 PDK 不再是必要条件，因此重新比较了构建、异步、性能和资源限制。

### 3.1 决定的理由

| 项 | QuickJS | wasmi | 说明 |
|---|---|---|---|
| 插件构建 | 不需要；直接加载 `.js` | 需要 WASM 工具链 | 作者改一行就能试，AI 生成后也不必先配置工具链 |
| 异步 | 引擎自带 Promise 和任务队列 | 调用栈不能跨等待挂起 | 见 4.4，这是先前方案最难处理的一处 |
| 时钟 | `Date.now()` 可用 | `wasm32-unknown-unknown` 没有 | 先前方案要为此加 `time_now` 接口 |
| 数据交换 | JSON 是原生对象 | 需要跨线性内存序列化 | |
| 解析性能 | 慢约 1.6–1.8 倍 | 更快 | 见 3.3，绝对值都很小 |
| 计量精度 | 内存上限加中断回调 | fuel 可按指令计 | wasmi 在这一项更细 |
| 构建依赖 | C 源码，需要各平台 C 编译器 | 纯 Rust | 见 3.2 |

当时测量中，两者的绝对耗时都较小，因此选择了开发步骤更少、原生支持 Promise 和时钟的 QuickJS。移动端表现仍需真机验证。

### 3.2 五个平台的构建实测

`rquickjs` 0.12.2 附带 quickjs-ng 0.15.1 的 C 源码（约 8.3 万行），由 `cc` crate 编译。2026-09-06 在 macOS 上逐个目标试过：

| target | 结果 | 需要的条件 |
|---|---|---|
| `aarch64-apple-darwin` | 通过 | 附带的预生成 bindings |
| `aarch64-apple-ios` | 通过 | 开启 `bindgen`，并传 `-isysroot $(xcrun --sdk iphoneos --show-sdk-path)` |
| `aarch64-linux-android` | 通过 | 开启 `bindgen`，用 NDK clang 和对应 `--sysroot` |
| `x86_64-pc-windows-gnu` | 通过 | 预生成 bindings，加一个 C 编译器（用 `zig cc` 验证） |
| `aarch64-unknown-linux-musl` | 通过 | 同上 |

`rquickjs-sys` 自带 16 个 target 的预生成 bindings，覆盖 Windows 的 msvc 和 gnu、Linux 的 gnu 和 musl、macOS 两个架构，但**不含 iOS 和 Android**。这两个平台要开 `bindgen`，因此构建环境需要 libclang 和正确的 sysroot。当前已通过 `hook/build.dart` 和 `hook/bindgen_environment.dart` 接入这些配置，维护时仍需匹配各平台工具链。

C 源码本身没有为这些平台打补丁：用 `zig cc` 交叉到 windows-gnu 和 linux-musl 一次通过。

### 3.3 性能实测

用同一个任务对比：解析 `df -P` 风格的输出，过滤掉 tmpfs，算出占用比例并组装 JSON。两侧结果断言相等，否则比较的不是同一件事。环境是 aarch64-apple-darwin、release、2000 次迭代。

| 输入 | wasmi | QuickJS |
|---|---|---|
| 663 B（8 个文件系统） | 70.8 µs | 110.4 µs |
| 15.8 KB（200 个文件系统） | 1.47 ms | 2.65 ms |
| 冷启动（创建 runtime、加载模块和 instance） | 0.5–0.9 ms | 0.2–0.6 ms |

链接后的体积增量，条件与 3.4 表相同：

| runtime | 相对空基线增加 |
|---|---|
| QuickJS（rquickjs） | 约 0.75 MB |
| wasmi（std + validate） | 约 0.70 MB |

这些数字来自开发机。iOS、Android，尤其是低端设备上的表现仍需真机测量。

### 3.4 WebAssembly 方案留下的测量

改用 JavaScript 之后这些数据不再影响选型，但记录下来，避免以后重复讨论。条件是 aarch64-apple-darwin、cdylib、release、`opt-level = "z"`、LTO、strip、`panic = "abort"`：

| 配置 | 链接后的大小 | 相对空基线增加 |
|---|---|---|
| 空基线 | 0.02 MB | — |
| wasmi：std + validate | 0.72 MB | 约 0.7 MB |
| wasmtime：runtime + pulley + cranelift + gc + threads | 2.71 MB | 约 2.7 MB |
| wasmtime 再加 component model 和 WASI p2 | 3.76 MB | 约 3.7 MB |

更早的文档把静态库的大小当成 App 增量，写成 10–20 MB，这个数字不准确；静态库包含最终链接时会被丢弃的内容。

当时不选 wasmtime 的另外两条理由：Pulley 虽然能解释执行，但它执行的字节码由 Cranelift 生成，只启用 `runtime + pulley` 时 `Module::new` 不存在，只能加载预编译产物，而预编译产物绑定 wasmtime 版本和 target triple；另外 Pulley 属于 Tier 3，iOS 的测试覆盖情况有限。

当时评估的 WASI 路径也不满足网络需求：`wasm32-wasip1` 没有 `sock_connect`，不能建立出站连接；`wasm32-wasip2` 网络更完整，但产物是 component，wasmi 不支持。本设计要求网络请求经过 host，以便检查目标地址、SSH 范围和证书，因此不会向插件开放直接建立 socket 的能力。这一条在 JavaScript 方案下同样成立：插件上下文里没有 `fetch`。

### 3.5 JavaScript 支持范围

quickjs-ng 0.15.1。2026-09-06 在引擎里抽查了 19 项：

| 可用 | 不可用 |
|---|---|
| class 与私有字段、`async`/`await`、generator、`Proxy`、`BigInt`、可选链、`??`、`Array.at`、`Object.groupBy`、具名捕获组、`WeakRef`、TypedArray、`Promise.allSettled`、`String.replaceAll`、`JSON.parse` reviver | `structuredClone`、`Intl` |

`fetch` 和 `require` 都不存在，符合沙箱边界：网络只能走 host 注入的接口。

`Intl` 尚不可用。日期和数字格式可以交给 host，也可以将 Intl 编入引擎，但后者会增加体积；处理方式仍待确定。

这 19 项抽查不能代表完整语言符合度。完整的 test262 没有跑过，引擎自带的 `run-test262.c` 需要另外下载整套测试集。

### 3.6 考虑过的其他运行方式

| 方案 | 没有采用的原因 |
|---|---|
| 插件跑在 App 自带的 Linux 环境里（iOS 用 ish-arm64，Android 用 proot，桌面用本机） | iOS 的 Linux 引擎由 `SBM_ISH` 控制且默认关闭，原因正是 App Store 2.5.2；插件系统建在上面会和它共用同一个开关。桌面走本机则没有隔离，插件能读到用户的 SSH 私钥和 App 数据库。三个平台的环境也不一致 |
| wasmtime + Pulley | 见 3.4 |
| WAMR | 需要为多个目标维护 C 工具链，且官方平台列表没有 iOS |
| `wasm_run` | runtime 版本较旧且已停更 |

需要在本机跑外部工具（例如 `kubectl`、`ansible`）是另一类需求，性质接近现有的自定义命令，不在本文范围。

## 四、插件和 App 怎么互相调用

### 4.1 底层约定

`crates/sbm_plugin` 为每个 instance 创建 QuickJS context，将 host 接口装到全局对象 `sb` 上，再加载 `plugin.js`。JavaScript 一侧使用原生值；跨 Dart bridge 的请求和答复使用 JSON。

未授权的函数会被替换为直接抛出 `PermissionDenied` 的 stub。接口权限在创建 context 时确定；具体 server handle、目标地址等参数仍需在调用时检查。

`plugin.js` 必须是单个文件，不能从网络或其他文件动态 `import`。拆分模块或引入依赖时，作者在发布前完成打包。

context 没有浏览器或 Node 的 `fetch`、`require`、`process`、`XMLHttpRequest` 和文件系统。`Date`、`JSON`、`Math`、`RegExp` 和 `TextEncoder` 等可用，语言支持范围见 3.5。

manifest 的 `abi` 声明插件需要的接口版本。发布后的导出、request 格式和 Widget 属性都需要维护兼容性。

### 4.2 App 调用插件的函数

插件通过 ES module 的具名导出提供函数，可以返回 Promise。下表包含已接通的调用和保留的接口设计；声明了类型不代表 App 已经调用它。

| 导出 | 用途 | 返回值 |
|---|---|---|
| `init(ctx)` | instance 创建后初始化 | 无 |
| `open(surface)` | 首次显示 page、card、tab 或 settings | `{ui}`；省略表示没有内容 |
| `onEvent({msg, value})` | 处理用户操作 | `{ui}`，可省略未变化的界面 |
| `tick()` | 刷新可见 surface，或处理 host call 的答复 | `{ui}`，可省略未变化的界面 |
| `onHook(ev)` | 打开 surface 时按范围加载数据 | 无，通过 patch 更新界面 |
| `onServerEvent(e)` | 处理服务器连接、断开或删除的接口设计 | 无 |
| `validateConfig(cfg)` | 配置保存前的校验接口设计 | `{errors: [...]}` |
| `configOptions(key)` | 动态配置选项的接口设计 | `{options: [{value, label}]}` |
| `tool(name, args)` | AI agent 调用工具的接口设计 | JSON |
| `dispose()` | instance 销毁前释放资源 | 无 |

`configOptions` 和 `tool` 用参数区分选项或工具，不再使用 WebAssembly 方案中的 `options_<key>` 一类导出名。动态选项适合 manifest 无法枚举的数据，例如插件自己保存的账号列表。

`listWindow`、`configOptions` 和 `tool` 的 host 调用尚未接通，其最终 request 格式仍需确定。TODO：接通时统一单参数 contract，删除 SDK 中的临时签名说明。

未配置的服务器可以通过 `requires_config` 隐藏入口，避免仅为判断是否显示就创建 instance。插件异常由 host 捕获，在对应 surface 显示错误并记录日志。

### 4.3 插件可以调用的 App 函数

`sb` 按用途分组。经过 Dart 的调用返回 Promise，配置读取和日志等接口为同步调用。App 侧由 `AppPluginHostOps` 接入现有功能。

| 接口 | 用途 | 所需权限 |
|---|---|---|
| `sb.server.exec(req)` | 在获准的服务器上执行命令 | `server.exec` |
| `sb.server.cancel(req)` | 取消本 surface 内具有相同 `cancelKey` 的 exec | `server.exec` |
| `sb.server.list()` | 列出全部服务器，仅返回 handle 和显示名 | `server.list` |
| `sb.http.fetch(req)` | HTTP 请求；直连已实现，`via: "ssh"` 尚未实现 | `net.http`；经 SSH 时另需 `server.stream` |
| `sb.ui.patch({path, node})` | 替换界面子树 | 无额外权限 |
| `sb.ui.prompt(spec)` | 显示对话框并等待回答 | `ui.dialog` |
| `sb.ui.pickServer()` | 让用户选择服务器，返回 handle | 无额外权限 |
| `sb.ui.toast(req)` | 显示提示 | 无额外权限 |
| `sb.store.get / set / list` | 读写插件自己的持久化数据 | 无额外权限 |
| `sb.diag.crumb(req)` | 记录事件名称和级别，不应包含敏感值 | 无额外权限 |
| `sb.nav.openServer(req)` / `sb.nav.goTab(req)` | 打开服务器或切换 tab | 无额外权限 |
| `sb.nav.openTerminal(req)` | 打开 terminal 并预填命令；仅 `run: true` 时发送 | `server.exec` |
| `sb.clipboard.read / write` | 读写剪贴板 | `clipboard` |
| `sb.config.get(key)` | 同步读取插件配置 | 无额外权限 |
| `sb.log.trace / debug / info / warn / error` | 同步写日志 | 无额外权限 |

时间直接使用 `Date.now()`，不再需要 WebAssembly 方案的 `time_now` 接口。

#### 4.3.1 取消命令执行

`sb.server.exec` 支持 `timeoutMs`，App 默认限制为 5 分钟。插件也可以传入 `cancelKey`，供停止按钮调用 `sb.server.cancel({key})`。key 只作用于当前 surface，可以同时取消多台服务器上的同一组任务。

超时和取消都会 reject，不返回普通的 `{code, stdout, stderr}`。例如被中断的 `du` 只有部分输出，不能当作完整读数。

取消后的远端状态由传输层通过 `ExecCancelKind` 报告：SSH 可以通过 channel 发送信号；monitor agent 的 HTTP 请求没有对应的取消通道，App 停止等待后，命令仍可能继续到 agent 自己的 timeout。插件应读取错误中的 `remote`，不能只凭本地请求结束就显示“已停止”。

```ts
try {
  await sb.server.exec({ server, script, cancelKey: "scan", timeoutMs: 120_000 });
} catch (e) {
  const { kind, remote } = classify(e);   // kind: "cancelled" | "timeout"
  if (remote === "running") {             // "stopped" | "running"
    // 得说出来。那台机器还在走文件系统。
  }
}
```

ABI 4 允许 `BridgeError::Failed` 携带 JSON 对象，并将字段附加到 JavaScript `Error`。`name`、`message` 和 `kind` 不能被覆盖。这样 `remote` 等信息不必编码进错误字符串。

host 自己拒绝调用时也提供结构化字段：`kind` 是 `denied`、`unavailable` 或 `bad_request`，`operation` 表示被拒绝的 host function，缺少授权时另有 `permission`。SDK 仍暂时兼容旧 host 的英文 message；TODO：停止支持 ABI 4 之前的 host 后删除 message fallback。

一个 instance 同时只处理一个 call。如果 call 一直等待长命令，停止按钮的 event 也只能排队。因此长任务应使用 `resource(load, { background: true })`：先显示 loading 并返回，结果到达后再更新，见 5.3.5。

为支持这个过程，runtime 和 App 分别负责两件事：

- `Instance::call` 在执行导出前交付已收到的 host 答复。未完成的 host call 属于 instance，可以跨越多次导出调用。
- `PluginSurfaceView` 在 host 答复后触发一次 tick；若已有 call 正在执行，则等它结束。没有周期刷新配置的 card 也能收到结果。

使用 background resource 的插件必须导出 `tick`，`surface()` 已提供它。缺少这个导出时，界面可能停留在 loading。

#### 4.3.2 打开界面时的 hook

host 在打开 surface 时调用 `onHook(ev)`，传入 `{kind, contribution, servers}`。card 的 `servers` 是绑定的服务器，面向多台服务器的 tab 则可以收到多台服务器。插件据此决定加载哪些数据。

`onHook` 适合进入页面时加载一次的数据，`tick` 适合持续变化的读数。原生包更新的 `PkgHook` 也采用类似方式：更新 tab 刷新全部服务器，详情页只刷新当前服务器。

服务器列表必须由 host 按 `server.list` 授权过滤。没有这项权限时，只能提供 surface 已绑定的服务器，不能通过 hook 暴露其余服务器。当前 `kind` 只有 `"enter"`；surface 关闭时直接卸载 instance，尚未定义 `leave` 或 `refresh` hook。

#### 4.3.3 服务器访问和 HTTP

`sb.server.exec` 接入 `ServerNotifier.ensureExec` 和 `ServerExec.run`。插件只能使用 host 发放的 handle，来源是绑定服务器、`pickServer`、获准的 `server.list` 或 hook。

`server.list` 单独授权，因为列出全部服务器与操作用户已选中的服务器是两种能力。返回值只有 handle 和显示名，不包含 App 保存的地址、用户名或凭据。执行命令必须经过 host。

`sb.nav.openTerminal` 同样需要 `server.exec`。默认只预填命令，用户可以检查后按回车；只需要命令输出时应使用 `sb.server.exec`。

HTTP 统一通过 `sb.http.fetch`，便于检查目标地址、cookie 和证书。经 SSH 的设计会使用 `ensureShellClient` 和 `SSHForwardChannel`，但当前 `via: "ssh"` 返回 `unsupported`，不会擅自改为直连。

HTTPS 使用证书 pin，实现在 `lib/data/provider/plugin/http.dart`。客户端以 `SecurityContext(withTrustedRoots: false)` 创建，不依赖系统 CA 根证书，只有匹配的 `pinSha256` 才会被接受。没有 pin 的正式 HTTPS 请求会被拒绝。HTTP 不涉及证书 pin，但仍受目标地址权限限制；请求不跟随重定向。

证书确认分两步，避免确认前发送密码：

1. `probeCert: true` 只完成 TLS 握手，读取证书后关闭连接，不发送 HTTP 请求。带 body 或 header 的探测会被拒绝。
2. 用户核对证书后，正式请求携带 `pinSha256`，host 按指纹校验。

返回的 `cert` 包含指纹、subject、issuer、有效期和 `expired`。host 不会自动信任首次见到的证书。

`permission_scope.rs` 等测试检查未授权接口、参数范围，以及接口声明与实际注入是否一致。

### 4.4 线程、超时和资源限制

每个 surface 使用独立 instance，可以绑定一台服务器，也可以作为全局区域。状态插件在采集时创建 instance，采集后释放。

contribution key 只说明“这是哪个入口”，不能作为 runtime instance ID。同一个入口可能同时显示两份，每次加载都会分配唯一 ID，用它隔离 patch callback、server handle 和待取消命令。源码、manifest、权限、配置或绑定入口变化时替换 instance；locale 和 asset 目录变化只清理 Widget cache 并重新渲染，不丢失插件状态和当前读数。

每个 instance 使用自己的线程，QuickJS context 在该线程上创建、调用和销毁。上层通过 channel 通信，同一 instance 的 call 串行执行，插件不需要处理两个导出同时修改状态的情况。

周期 tick 使用 backpressure：上一轮未结束时只记一次“还要刷新”，不把每个 timer event 都排进 runtime。hook、event 和 tick 在 Dart 侧可能同时等待，因此 surface 使用 in-flight 计数判断是否空闲；不能用一个 bool 表示多个 caller。

当前先采用一 instance 一线程。instance 主要随可见 surface 存在；原设计估算挂起线程的已提交 stack 为几 KB。若以后线程数量成为问题，再评估共享线程池：当前等待期间仍停留在 `Context::with` 中，复用线程需要将 `Instance::call` 改为可恢复的 state machine。

host 函数返回 Promise。Rust 发出请求后将控制权交还 QuickJS，App 答复后再推进 job queue，插件从 `await` 后继续。因此一个插件可以用 `Promise.all` 同时等待多个 host call。

`ChannelBridge` 用 `call_id` 配对请求和答复，不依赖 async runtime。插件线程不属于 Tokio runtime，不能直接在那里调用 `tokio::spawn`。`PendingCall` 负责待处理请求，销毁时通过 `Arc::new_cyclic` 保存的 `Weak` 将自己从 bridge 表中移除，完成、取消和超时都走这条清理路径。

已有测试覆盖单次等待、两个并行 host call、多次连续 `await`、恢复后的状态、错误 catch、无需答复的日志，以及多个 instance 共用 bridge 时的答复隔离。

FFI 使用 `StreamSink` 将请求发给 Dart，Dart 处理后通过同步 `answer(callId)` 返回。`load` 和 `call` 不能标为 `frb(sync)`：它们等待插件，而插件可能等待 Dart；阻塞 Dart isolate 会造成互相等待。`answer` 只更新表，可以同步执行。

取消 `RustStreamSink` 订阅时不要等待 `subscription.cancel()`：其 `async*` stream 使用 `ReceivePort`，端口空闲时该 Future 可能不完成。stream 随 runtime 释放而结束。

等待 host 答复使用退避轮询：前 50 毫秒每 1 毫秒检查一次，之后每 25 毫秒检查一次，以减少慢请求期间的无效唤醒。

资源限制已实现并有测试：

| 限制 | 实现 | 当前默认值 |
|---|---|---|
| runtime 内存 | `JS_SetMemoryLimit` | 64 MB |
| stack | `JS_SetMaxStackSize` | 512 KB |
| JavaScript 执行时间 | interrupt callback | 5 秒 |
| 等待 host 答复 | host call timeout | 120 秒 |

JavaScript 执行时间不包含等待 host 的时间，每次恢复执行时重新计时。这与 4.3.1 中命令执行的 `timeoutMs` 是不同限制。默认值尚需用移动端真机负载验证；按时间中断也不如 WASM fuel 的指令计量精确。

卸载 instance 时，runtime 对未完成请求调用 `PendingCall::cancel`，并等待 instance 线程结束。host 可以据此取消实际请求、释放会话。

Rust 字段的析构顺序必须保证 JavaScript 值先于 runtime 释放，否则 `JS_FreeRuntime` 的 `list_empty(&rt->gc_obj_list)` 断言会导致进程 abort。

### 4.9 BMC 留在 Dart

2026-09-08 决定保留 BMC 的 Dart 实现和 `packages/redfish`，不再改成插件。

BMC 已经发布并有测试，重写后功能并没有增加，却多了一套实现和调试路径。三个新插件更适合验证接口，因为它们能直接暴露从零开发时缺少的能力。

BMC 还有带外键、参与备份和同步的 `bmc_credential` 表，插件的键值存储无法直接替代。为 BMC 设计的 `probeCert` 和证书 pin 仍保留在 HTTP 接口中。

BMC 不再承担复杂 UI 的验证。当前改由三个实际插件覆盖四种 surface，长列表、复杂表格和流式输出仍需进一步验证。

## 五、插件界面怎么画

插件保存状态并返回 JSON Widget tree，Flutter 负责渲染。这借鉴了 ruxlet 的交互方式，但不使用它的动态库加载方案。

### 5.1 节点格式

下面的例子显示 CPU 使用率、启动按钮和输入框：

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

| 字段 | 含义 |
|---|---|
| `t` | Widget 类型，例如 `column`、`text`、`btn` |
| `k` | 稳定 key，映射为 Flutter `ValueKey` |
| `p` | 属性，例如文字、间距和语义颜色 |
| `c` | 子节点 |
| `on` | event 对应的消息；host 通过一个 `{msg, value}` 对象传给 `onEvent` |
| `v` | 子树 revision，由 SDK 自动生成 |
| `s` | `1` 表示复用 host 已持有的子树，由 SDK 自动生成 |

`s` 用于区分完整节点和复用 stub。`spacer`、`divider` 本来就可能没有 `p` 和 `c`，不能仅凭缺少这些字段判断是否复用。SDK 的 `Walked.changed` 同样需要区分这两种情况。

可重排的节点应提供稳定 `k`。Flutter 用 `runtimeType` 和 key 判断新旧 Widget 是否对应；没有 key 时按位置匹配，重排可能让输入焦点、展开状态等跟错行。

| 类别 | 支持的类型 |
|---|---|
| 布局 | `column`、`row`、`expanded`、`flexible`、`align`、`wrap`、`stack`、`positioned`、`padding`、`sized`、`scroll`、`list`、`spacer`、`divider` |
| 内容 | `card`、`tile`、`summary`、`kv`、`expand`、`percent`、`progress`、`tag`、`text`、`icon`、`table`、`banner`、`badge`、`tooltip`、`skeleton`、`line_chart`、`bar_chart`、`pie_chart` |
| 输入和操作 | `btn`、`input`、`toggle`、`checkbox`、`segmented`、`dropdown`、`slider`、`chip`、`menu`、`tabs` |
| 交互包装 | `refresh`（下拉刷新）、`dismiss`（滑动操作） |

`row` / `column` 支持 `main` / `cross` 对齐，`padding` 可以单独指定一边。部分类型对应 App 已有的 `CardX`、`KvRow`、`ExpandTile` 和 `PercentCircle`。

插件描述状态，主题决定外观。例如 `tile.selected` 由 `ListTile.selected` 绘制，不需要插件通过更换图标模拟选中。颜色使用 `tone`：`normal`、`muted`、`success`、`warning`、`danger`。字号使用 `xs` / `sm` / `md` / `lg` / `xl`，字重使用 `medium` / `bold`，对齐使用 `start` / `center` / `end`。命令、路径和 hash 可以用 `mono` 表示等宽字体。

以 `l10n.` 开头的字符串从 `l10n/<locale>.json` 读取，缺译时回退到 `en`。参数用 U+001F 分隔，替换 `{0}`、`{1}`；SDK 会移除参数中自带的分隔符。完整句子应放在翻译文件中。

manifest 的名称、描述和 `contributes.*.label` 也可以使用 l10n key。`InstalledPlugin.strings` 在显示时按 App 当前语言解析，安装记录保留 key，因此切换语言不需要重装。

所有向用户显示插件文字的入口都要解析 l10n，包括 `sb.ui.prompt`、`sb.ui.toast` 和设置页标题。bridge 知道请求来自哪个插件，负责解析标签；输入框的 `value` 是原始数据，不能当作翻译 key 改写。

仓库索引不区分语言，`plugin-tools` 的 `manifestOf` 使用包中的 `en` 翻译生成名称和描述。打包时，`manifestL10nKeys` 会检查这些 key 是否存在。官网插件页则按访问者语言选择翻译。

插件可以每次构建完整 tree，由 SDK 裁掉未变化部分；持续输出可通过 `sb.ui.patch` 和 JSON Pointer 替换子树。未知类型或非法属性应显示局部错误并记录日志。渲染器也检查父节点：例如在 flex 外使用 `expanded` 或 `spacer` 时做降级处理，避免 Flutter layout 异常影响整个 surface。

部分交互状态由 host 管理：

- `tabs` 在 host 内切换当前页，避免一次往返带来停顿。
- `dismiss` 发出滑动 event 后不立即删行，是否移除由插件返回的 tree 决定。
- `refresh` 等待下一棵 tree 后结束 loading，并设等待上限。

命名区域仍待确定。例如折叠面板同时需要标题和内容节点，候选方案是让 `c` 按名称保存子树，或新增 `slot` 节点。正式发布 UI contract 前需要决定。

### 5.2 怎么减少界面更新的工作量

实现位于 `lib/data/model/plugin/node.dart`、`lib/view/widget/plugin/surface.dart` 和 `lib/view/widget/plugin/render.dart`，测试位于 `test/plugin_render_test.dart`。

每次刷新通常只有少数读数变化。SDK 和 host 通过以下方式减少传输、Widget 构建和无关更新。

#### revision：复用已有 Widget

Flutter 的 `Element.updateChild` 遇到相同 Widget 实例时，可以跳过该次父级更新。`Widget` 默认按引用比较；每次从 JSON 创建新对象无法利用这条路径。子树自身仍可能因状态变化而重建或重绘。

SDK 的 `frame()` 保存上一棵 tree，逐节点深比较。未变化的子树发送带 `s: 1` 的 `{t, k, v, s}` stub，host 按 `v` 返回已缓存的 Widget。子节点变化时，它到根节点路径上的 revision 都要更新，避免复用旧父节点。

原测试记录中，完全未变化的 tree 可以缩成约 35 字节的根 stub；只有一个叶子变化时，只发送该路径，兄弟节点仍为 stub。比较不用 hash，避免碰撞导致界面停止更新；连续两个 `NaN` 也按未变化处理。

#### 值绑定：只发送变化的读数

属性写成 `{"$": "cpu"}` 时，表示绑定名为 `cpu` 的值。host 为每个 slot 保存 notifier，并使用 `ValueListenableBuilder` 更新对应区域。

插件返回 `{"values": {...}}` 即可更新读数，不必返回整棵 `ui`。这会重建绑定区域，而不是整页；对于结构固定的卡片，传输量和处理量主要随变化的值增加，原设计估算一次刷新为几百字节。

#### 列表：按需构建可见行

`list` 的 `count` 表示总行数，`from` 表示已提供窗口的起始位置。host 使用 `ListView.builder`，但实际构建量还受外层布局和 `shrinkWrap` 影响，不能仅凭使用 builder 就保证只构建可见行。不声明 `count` 时，传入的行就是全部内容。可重排的行必须带 key。

滚动超出已有窗口后，通过 `listWindow` 获取更多行的回调尚未接通。它需要异步调用和占位行，不能让滚动等待插件执行。

#### host 侧缓存和重绘隔离

`card` 和列表行使用 `RepaintBoundary` 隔离重绘。相同属性的 `text`、`kv` 等叶子也可以复用 Widget，但这种缓存不能用于含子节点的 `summary`、`tile`：只比较父属性会漏掉按钮和 trailing 的变化。带子树的复用交给 revision。

当前跨 Dart bridge 仍需解析 JSON。后续可评估 FRB 直接返回类型化对象，减少 UI isolate 的 `jsonDecode` 工作；递归类型是否适合这条路径尚未验证。

#### 为什么提前定义这些字段

原设计估算 BMC 卡片约 200 个节点、每分钟刷新一次，当时直接重发整棵 tree 也能接受。但 revision、值绑定和列表窗口会影响节点格式，应在发布 contract 前确定。三者都可选，revision 由 SDK 自动处理，插件作者不必手写。

### 5.3 界面显示在哪里

| surface | 位置 |
|---|---|
| `page` | 服务器功能栏按钮打开的页面 |
| `card` | 服务器详情页卡片 |
| `tab` | 首页 tab |
| `settings` | 插件设置区域 |

`page.needs` 按 `ServerCapabilities` 过滤入口，功能栏按稳定 ID 分发。插件声明 `contributes.settings` 时，App 的 `app.plugins` 设置项会展开对应入口；没有这类 contribution 时不增加分支。

服务器编辑器使用 manifest 的 `config.fields` 描述表单。字段设计支持 `text`、`password`、`bool`、`int`、`select`，以及 `label`、`secret`、`role: address`、`options`、`options_from`。跨字段校验使用 `validateConfig`，动态选项使用 `configOptions(key)`；调用接入状态见 4.2。

`contributes.card.requires_config` 和 `contributes.page.requires_config` 表示配置该插件后才显示入口。

配置由 host 写入，插件通过 `sb.config.get` 读取。插件自己产生的数据，例如用户确认过的证书指纹，放在自己的键值存储中。

### 5.3.5 SDK 中的状态管理

`state()` 保存状态，`resource()` 加载异步数据，`surface()` 生成 host 需要的导出。构建函数读取哪个状态，就会订阅哪个状态；值变化后，SDK 重新构建界面。

```ts
const filter = state("");
const jobs = resource(async () => read(filter.value));

export const { open, onEvent, tick, dispose } = surface(() =>
  jobs.when({ loading: () => skeleton(), error: ..., data: ... }),
);
```

第一版曾采用类似 Riverpod 的 `ref.watch(p)`。后来改为追踪读取，避免将 `ref` 逐层传给 `rowFor`、`emptyFor`、`settingsView`、`field` 等构建函数。

每个 surface 有独立 JavaScript instance，因此模块级 `state()` 也只属于该 surface。状态管理完全在 SDK 中实现，跨 host 边界仍然只有 tree 和消息。

依赖追踪是同步的：只记录第一次 `await` 前读取的值。`resource` 所需的状态应先读取，再开始异步操作。

SDK 统一处理三类容易遗漏的工作：

- 状态改变后自动更新 tree，不必在每个 event handler 里手写 `return {ui: view()}`。
- event handler 可以是 closure。SDK 保存函数，将 token 交给 host，再用返回的 token 找到 handler；底层仍传递消息。
- loading、data 和 error 是同一个异步值的不同状态，不需要分别维护多个 bool。

runtime 在 call 期间推进 JavaScript job queue。普通 resource 因此在本次 call 返回前完成；中间状态通过 patch 发送，最终状态作为返回值。`onHook` 中需要 `await app.settle()`，让首次加载能完成。

长任务使用 `resource(load, { background: true })`，不阻塞当前 call。界面先显示 loading，用户仍能点击停止按钮；host 答复后由下一次 tick 处理结果，见 4.3.1。短暂的 store 读取一般不需要 background，否则表单会多一次 loading 切换。

surface 不再显示时，无需继续发送界面 patch；`no_surface` 应按这一情况处理。下次 `open` 会发送完整 tree。

### 5.4 作者怎么写和测试

`packages/plugin-api` 提供 TypeScript 类型和 Widget 构造函数，JavaScript 作者也可以使用同一份 `.d.ts` 获得提示。导出签名可用 `satisfies Plugin` 检查。

`MockHost` 来自 `@serverbox/plugin-api/test`，安装到 `globalThis.sb` 后，可以模拟 HTTP、对话框、存储和命令执行，并记录请求。插件测试可直接在 Bun 中运行，不需要 App 或 QuickJS。

MockHost 应复现真实 host 的拒绝规则，包括缺少 `pinSha256` / `probeCert` 的 HTTPS 请求、携带 body 或 header 的证书探测，以及 `denied` 指定的权限限制。

旧 WebAssembly BMC 插件的 `plugins/bmc/tests/` 曾覆盖设备发现、登录、轮询、电源确认、证书复核和账号管理。那份实现已删除，仅保留为测试设计的历史参考。当前测试对象是 `packages/plugins/` 中的三个插件。

### 5.5 host 侧如何验收

已有真实 QuickJS 和 Dart 测试验证插件加载、交互、host callback 和权限限制。MockHost 测试验证插件逻辑，真实 runtime 测试验证 SDK 与 App 的 contract，两者不能互相替代。

待补齐每种 Widget 的 JSON 输入和 golden 截图，覆盖显示效果、主题及后续兼容性。计划中的 `test/plugin_isolation_test.dart` 也尚未实现，用于检查插件专属逻辑是否散落到通用 App 代码。

### 5.6 界面的限制

BMC 的早期设计带来了 `tone`、`requires_config`、`options_from`、`probeCert` 和响应中的 `cert`。三个实际插件又推动了 `shellQuote`、`sb.server.list`、`sb.nav.openTerminal` 和 `onHook`。

当前已有下拉刷新、滑动操作和图表等 Widget，但仍不能完整表达 App 的复杂交互。长列表、复杂表格、过滤搜索、长按菜单和图表 tooltip 等场景需要逐项验证。每增加一种类型或属性，都需要长期维护兼容性。

### 5.7 考虑过的其他界面方案

| 方案 | 没有采用的原因 |
|---|---|
| Remote Flutter Widgets（`rfw`） | 作者需要另学 Widget 描述 DSL 和数据绑定规则 |
| Dioxus mutation 协议 | host 还需维护节点 ID 和逐条 mutation；当前先使用 tree 更新 |
| 插件内自绘，例如 egui | 难以沿用 App 外观、无障碍和文字选择，还需持续跨 FFI 传帧 |
| WebView | 增加 Linux 桌面依赖和外观统一成本，也不能消除商店审核问题 |

## 六、权限怎么管

### 6.1 插件需要声明什么

| 权限 | 允许做什么 |
|---|---|
| `server.exec` | 在 host 授权的服务器上执行命令，也用于 terminal 和取消执行 |
| `server.stream` | 通过服务器的 SSH 建立 TCP 连接，为 `via: "ssh"` 预留 |
| `server.list` | 列出全部服务器，只返回 handle 和显示名 |
| `net.http: [pattern]` | 访问匹配的 HTTP 目标；支持 glob 和 `$config.<key>`，后者引用 `role: address` 配置 |
| `ui.dialog` | 显示对话框并等待输入 |
| `clipboard` | 读写剪贴板 |
| `storage.sync` | 让插件的键值数据参与备份同步 |

读取配置、使用自己的存储、更新自己的界面、让用户选择服务器、显示提示、日志和普通导航不需要额外权限。`openTerminal` 例外，需要 `server.exec`。这些接口不会授予其他插件的数据访问权。

安装对话框由 `PluginsPage` 展示请求的权限，用户接受全部权限或取消安装，不提供逐项授权组合。申请 `server.exec` 时额外说明插件会在服务器上执行命令。

用户同意的集合与 manifest 取交集后写入 `plugin_install.granted`，加载时再次取交集。新版本新增的权限必须重新取得同意，不能仅靠修改 manifest 获得。

### 6.2 host 如何执行限制

未授权接口在 context 创建时被替换为抛出 `PermissionDenied` 的 stub；具体 server handle 和网络目标还会在调用时检查。

插件可以 catch JavaScript 异常，但 host 会记录权限拒绝，并在本次 call 结束时将它判为失败。下一次 call 仍可正常执行。这保证拒绝不会被伪装成一次成功调用，但不能撤销该 call 中已经发生的其他操作，也不能代替敏感操作自身的确认流程。

插件不能读取 App 保存的 SSH 密码等凭据，不能使用自行构造的 handle 访问其他服务器。`sb` 也没有修改 App 服务器记录的接口：`sb.store.set` 只写插件自己的键值空间，服务器上的插件配置由 host 表单写入。

`permission_scope.rs` 用测试约束这些边界。新增 host 接口时，需要同时检查它是否改变了原有授权范围。

第三方仓库的来源与校验状态在安装流程中展示。F-Droid 的分发说明见 8.3。

## 七、配置和数据存在哪里

数据库由 App 管理，插件不能自行建表或执行数据库 migration。m022（schema v22 → v23）已建立四张表：

- `plugin_install`：安装版本、来源、开关和已授予权限。
- `server_plugin_cfg`：每台服务器上的插件配置。
- `plugin_kv`：插件的全局键值数据。
- `server_plugin_kv`：插件按服务器保存的键值数据。

Drift 定义在 `lib/data/store/db.dart`，migration DDL 在 `lib/data/store/migrations/m022_plugin_tables.dart`。`test/plugin_store_test.dart` 比对 migration 结果；只检查新建数据库的 `tables_schema_test.dart` 不能替代它。

原草案将全局和服务器数据放在同一张 `plugin_kv` 中，以 NULL `server_id` 表示全局。这个设计不能满足唯一性要求：`WITHOUT ROWID` 不允许主键列为 NULL，普通 rowid 表又允许多个包含 NULL 的重复组合。因此实际实现拆成两张表，服务器数据也能通过外键级联删除。

下面保留原 SQL 草案用于说明差异，不能作为当前 migration 使用。TODO：历史设计说明归档后删除这份草案；当前 schema 以代码为准。

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

-- 实际实现拆成了 plugin_kv (plugin_id, key) 和
-- server_plugin_kv (server_id, plugin_id, key)，理由见上
CREATE TABLE plugin_kv (
  plugin_id TEXT NOT NULL,
  server_id TEXT REFERENCES server (id) ON DELETE CASCADE,  -- NULL 表示全局
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (plugin_id, server_id, key)
) WITHOUT ROWID;
```

配置保存为 JSON，host 不按内部字段查询。`cfg_ver` 记录写入时 manifest 的 `abi`，供未来 host 侧转换使用；插件不能写这张表。当前读取时忽略已删除字段，新增字段使用 `default`，没有单独的配置转换步骤。更新服务器配置时也要更新父行 stamp，与 `container_host` 一致。

当前插件配置沿用现有数据库加密保护。`secret` 标记用于识别敏感字段；服务器分享目前不包含插件配置，将来若支持分享，必须先移除这些字段。

instance 内的临时状态使用 JavaScript 变量，销毁后不保留。持久化键值数据默认只留在本机，获准 `storage.sync` 后按插件 ID 作为独立同步项处理。

备份使用 `BackupV2.plugins: {id: {cfg: [...], kv: [...]}}`，模型为 `PluginBackup`：

- 恢复时合并数据，不删除备份未提到的插件数据。同一条数据冲突时使用备份中的值。
- server ID 与 snippet、port forward 使用同一套重映射；指向不存在服务器的条目跳过。
- 安装记录和插件文件不进入备份。恢复的数据可以保留到用户重新安装插件后使用。

`ServerShare` 与备份是不同模型，不携带这些插件数据。

卸载时删除插件文件、安装记录并撤销权限，用户可以选择是否保留配置和数据。删除服务器时，相关配置和键值数据通过外键清理。`PluginPackage` 检查包内容，`PluginInstaller` 负责先写文件、再写记录、最后调整入口排列，避免记录指向未写入的文件。

按钮、card 和 tab 的排列使用稳定 ID。首次安装时追加 `defaultOn` / `default_on` 标记的入口，卸载时移除，读取时忽略未注册 ID。更新不恢复用户已经隐藏的入口。

Dart registry 的 m021 migration 已完成。旧 enum 顺序冻结在 `legacy_adapters.dart` 的 `kLegacyServerFuncBtnIds`，不能使用当前 `ServerFuncBtn.values` 解释旧数据。`Backup.merge` / `BackupV2.merge` 也会转换，因为恢复备份不经过 schema migration。TODO：停止支持旧备份格式后删除这层兼容转换，保留历史 migration 所需定义。

BMC 不做插件 migration，`bmc_addr`、`bmc_cred_id`、`bmc_cert_sha256` 继续保留在 `server` 表中，见 4.9。

## 八、怎么下载、安装和更新

### 8.1 插件仓库

仓库采用类似 Homebrew tap 的结构：一个 git 仓库，每个插件一个 TOML 文件，文件中声明各版本的包地址。客户端下载最新 tree，不需要 git client。用户可以添加多个仓库，加入顺序决定同 ID 插件的优先级。

存储使用 `plugin_repo` 表（m024）和 `PluginRepoStore`，页面在 `lib/view/page/plugin/store.dart`。

```
repo.toml                              schema、name
plugins/app/serverbox/diskusage.toml   每个插件一个文件，里面写包的 url
```

仓库 tree 只保存文本。官方仓库的 `.sbp` 放在该仓库自己的 release 中，每个插件版本一个 release，tag 为 `<id>-<version>`，例如 `app.serverbox.diskusage-1.0.1`。已发布的 release 不替换；内容变化应发布新版本。

插件 ID 使用 reverse-DNS 格式，前两段作为发布者目录，其余部分作为插件路径。`app.serverbox.diskusage` 对应 `plugins/app/serverbox/diskusage.toml`。文件内 ID 与路径不一致时，客户端拒绝读取。

`PluginRepoSource.archiveUrlOf` 将仓库地址转换为 `<repo>/archive/HEAD.tar.gz`。GitHub、Gitea 和 Forgejo 使用这条路径，默认分支由服务端解析。安装时再下载 TOML 中 `url` 指向的包。原发布验证记录中，GitHub 的 `HEAD` 缓存可能延迟约 10 秒；刚 push 后验证失败时，需要考虑这一延迟。

插件 release 放在插件仓库，不放在 App 仓库，避免 App 更新检查误将插件 tag 解析为 build 号。`fl_lib` 对无法识别为 App 版本的 release 返回 null，相关行为由 `update_test.dart` 覆盖。

仓库 tarball 的读取上限为：压缩后 16 MB、解压后 64 MB、单个条目 8 MB。插件 `.sbp` 另有自己的限制，见 8.2。

#### 来源和校验

当前不使用插件签名。早期考虑的 Ed25519、`index.json.sig`、内置公钥、serial 和 `valid_until` 均未采用。当前信任来源是 HTTPS 和仓库运营者，安装前使用仓库声明的 SHA-256 校验包内容。

索引和包来自不同位置，摘要用于确认下载的包与索引声明一致。格式也允许使用仓库内的 `path`，但官方发布流程使用 release URL。

这个机制能发现只替换了包、没有修改索引的情况，不能防止控制索引的人同时修改 URL 和摘要。是否引入签名，以及发布者身份、密钥轮换和防回退要求，留在 `TODOS.md` 第 2 节继续评估；可参考 `RootfsManifestTrust`。

| 规则 | 实现位置 |
|---|---|
| 没有 checksum 时默认拒绝；用户可在下载前明确同意跳过 | `PluginTrustIssue.noDigest` |
| checksum 不匹配时必须拒绝，不能跳过 | `PluginTrustRefused.skippable` |
| `repo.toml` 的 schema 高于 App 支持版本时拒绝整个仓库 | `PluginIndex.fromFiles` |
| 单个插件 TOML 无法读取时只跳过该插件；`repo.toml` 无法读取时拒绝整个仓库 | `PluginIndex.fromFiles` |
| 选择 `abi <= ABI_VERSION` 的最新插件版本 | `PluginListing.bestFor` |
| ABI 太新的版本仍显示，但禁用安装并说明需要更新 App | `StoreEntry.appTooOld` / `tooNew` |
| 多个仓库提供相同 ID 时，先添加的仓库优先，并显示冲突来源 | `PluginStore.merge` / `StoreEntry.shadowed` |
| 索引和包要求 HTTPS，loopback 例外 | `PluginRepoSource` |
| 仓库缓存 24 小时，可手动刷新 | `PluginRepoRecord.staleAt` |

官方仓库为 [`lollipopkit/serverbox-plugins`](https://github.com/lollipopkit/serverbox-plugins)，原记录的建立日期为 2026-09-09，只收自由开源插件。本节描述当前本地发布流程，不代表重新检查了线上所有 release。

`PluginRepoStore.officialUrls` 保存官方地址，`_initApp` 在 schema migration 后调用 `seedOfficial`，每个 URL 只添加一次。用户删除过的地址不会因为仓库列表为空而被重新加入，未来新增的官方 URL 仍可单独添加。

当前不做评分、评论、下载量或自动更新。前三项需要有状态的后端；插件更新由用户主动触发。

#### 打包与发布

`packages/plugin-tools/bin/pack.ts` 生成 `.sbp`，`bin/repo.ts` 生成仓库 TOML。生成器遵守以下规则：

- 从实际包内容计算摘要。
- 合并已有版本，不用本次 `dist/` 覆盖历史版本，保证旧 App 仍能找到兼容版本。
- 只重写本次涉及的插件文件。
- 同版本内容变化默认拒绝；`--allow-republish` 可在生成器层显式放行，但官方发布脚本仍不会替换已有 release。

工具端使用 `Bun.TOML.parse` 和专用输出代码，App 使用已有依赖 `package:toml`。两边均使用完整 TOML parser。`test/fixtures/plugin_repo/` 保存工具的真实输出，`test/plugin_repo_generated_test.dart` 用 App parser 读取，检查跨语言格式是否一致。

`scripts/publish-plugins.sh` 的顺序是：打包 → 上传新版本 release → 生成 TOML → 本地核对 → commit → push → `bin/verify.ts` 重新读取线上仓库。

必须先上传包，再发布引用它的 TOML。中途停止时，未被索引引用的 release 不影响用户；先发布索引则可能让用户下载到 404。`verify.ts` 的 URL 模式会按客户端路径读取线上 tarball，再校验每个包的摘要、大小和 manifest，检查本地文件与实际发布内容是否一致。

### 8.2 安装流程和本地开发

安装顺序为：下载 → 校验 SHA-256 → `PluginPackage.read` 检查内容 → 取得权限同意 → 写入 `Paths.doc/plugins/<id>/` → 保存安装记录 → 注册默认入口。

包读取会检查路径穿越、解压炸弹和大小。当前 `.sbp` 解压后总量上限为 8 MB，单个条目上限为 4 MB。

目录不带版本号，每个 ID 只保留一份当前安装。新包先写入 `<id>.new`，再整体替换，避免 manifest 和脚本来自不同版本。安装阶段不额外创建一次性 QuickJS context 检查脚本语法，语法错误在首次加载时显示。

#### 更新和回退

更新时依次 rename：`<id>` → `<id>.prev`，`<id>.new` → `<id>`。`plugin_install.previous`（m025）保存旧目录对应的安装记录。

保留完整记录是为了恢复用户当时同意的 `granted`，不能从旧 manifest 重新推导授权。只保留上一版，回退后不再提供第二次回退；下次更新重新保留被替换的版本。

两次 rename 之间可能中断。`refresh()` 开头会调用 `repair()`：如果只剩 `<id>.prev` 而当前目录缺失，就恢复旧目录；同时清理残留 `<id>.new`。卸载也会删除这两个目录。

ABI 4 的 `data_version`（默认 0）声明插件数据格式。回退到不同 `data_version` 时，旧代码可能无法正确读取已有数据，App 会在确认前说明风险并使用红色确认按钮。回退仍可继续，但不等于恢复了数据快照。

更新沿用安装的下载、校验和安装器，只在两处区别处理：

- 只有新增权限时才调用 `askPluginUpgradeConsent`。无需再次询问时，继续使用上次的授权集合，而不是直接授予新 manifest 的全部权限。
- 不重新启用被用户关闭的插件，也不恢复用户已隐藏的入口；`default_on` 只在首次安装生效。

#### 本地开发

`bun run dev` 让 bundler 在保存后重建 `dist/`。桌面 App 的 `PluginDevWatcher` 每秒检查开发目录中的 `plugin.js`、`manifest.json` 和 `l10n/*.json`，变化后调用 `refresh()`。

源码变化会重建 QuickJS instance，因此这是 hot restart，原 instance 的临时状态不会保留。使用轮询是为了避开各平台 `Directory.watch` 对原子替换的差异。

`console` 已转发到 `sb.log`。插件异常显示在对应 surface 中，消息和插件 stack 使用可选择的等宽文字，不截断为三行。

当前没有 `assets/plugins/*.sbp` 形式的随 App 插件。`packages/plugins/` 中的插件可通过仓库安装，也可在桌面端加载开发目录。`SettingStore.pluginDevDirs` 只保存路径，不复制目录；卸载开发插件只移除登记，不删除作者的文件。

#### 安装来源

`plugin_install.repo` 有三类值，由 `PluginInstall.origin` 解释：仓库 URL、`dev`（开发目录）、`file`（手动选择的 `.sbp`）。

商店只为来自同一仓库的安装显示普通更新。相同 ID 来自其他来源时，显示“替换”并通过 `pluginReplaceTip` 确认，“全部更新”不会处理它。

`refresh()` 只为 `repo = 'dev'` 的记录读取开发目录。安装 `.sbp` 时移除该 ID 的开发目录登记，避免记录写着仓库版本，实际却继续运行开发代码。TODO：不再需要识别旧 null 来源记录时，删除对应兼容 fallback。

#### ABI 检查

`plugin_read_manifest` 拒绝高于 host `ABI_VERSION` 的插件。SDK README 按 ABI 版本说明新增能力，不维护易过期的 App 版本对照表。

`plugin_ffi_test.dart` 比较 SDK 与 host 的 ABI 常量，并检查实际构建产物中的已知新 Widget 是否要求对应 ABI。曾出现 SDK 仍声明 ABI 1、host 已到 ABI 2 的情况：少报版本会让插件在旧 App 上部分失效。

当前 host 为 ABI 4；磁盘占用因取消执行等能力使用 ABI 4，监听端口和定时任务为 ABI 3。后两者使用 `skeleton`、`tile.selected` 等 ABI 3 能力，构建产物检查也覆盖 `banner`、`chip` 等节点名。

### 8.3 App Store 和 F-Droid

App Store 的既定方案是默认开启在线仓库，但尚不能据此确认审核结果。原设计参考 Review Guidelines 4.7，需继续核实逐插件同意、带 universal link 的插件索引、原生平台 API 边界，以及 2.5.2 对下载代码的要求。发布前应按当时政策确认。

官网介绍页在 `website/` 的 `/plugins/`（`src/Plugins.svelte` 和 `plugins/index.html`）。`vite.config.js` 的 `pluginCatalog` 在构建时读取 `packages/plugins/*/manifest.json`，生成版本、ABI、权限和入口信息。页面支持七种语言，插件名称和描述从插件自己的 l10n 文件解析，不再单独维护一份介绍数据。

2026-09-09 决定不增加 `SBM_PLUGIN_REPO` 构建开关。最初设想是关闭在线仓库后只保留随包插件，但当前没有随包插件；需要平台专用分发方式时再确定构建方案。

F-Droid 方案基于官方仓库只收自由开源插件，在线仓库不默认关闭。用户添加的第三方仓库不经过 F-Droid 检查，安装流程会说明来源和校验状态。是否涉及 `NonFreeAddons` 等标记，发布前仍需核对政策。

### 8.4 插件报告

“插件没反应”可能发生在不同阶段，报告需要帮助作者区分：

| 情况 | 阶段 | 需要判断什么 |
|---|---|---|
| 数据采集失败 | `exec` / `http` | 超时、取消或服务器未答复 |
| 插件执行失败 | `load` / `init` / `open` / `event` / `tick` / `hook` / `status` | 哪个导出失败、错误类别是什么 |
| UI 更新失败 | `patch` | 插件已产生 tree，但未成功更新 surface |

`PluginHealthStore` 按插件 ID 保存最近一次成功、最近一次失败和连续失败次数，记录阶段、时间和耗时。数据仅留在本机，使用 `updateLastUpdateTsOnSet: false`，不触发设置同步。分别保留成功和失败，才能看出“页面打开成功，但采集失败”等情况。

设置页的插件列表可以生成纯文本报告，包括 App build、host ABI、插件版本、插件 ABI、`data_version`、来源、开关、已授予权限、保留的上一版和运行记录。报告先展示，再由用户复制。

报告不包含命令输出、配置值、HTTP body 或异常 message。失败仅记录 App 定义的 `pluginFailureTag`，例如 `denied`、`timeout`、`unavailable`、`module`、`threw`。异常 message 可能带路径或主机名，因此只在本机 surface 和日志中显示，由用户另行决定是否分享。`plugin_report_test.dart` 检查报告字段的隐私范围。

`sb.diag.crumb` 是另一条路径：它记录插件主动提供的事件，进入 breadcrumb 和 `DiagnosticsUpload`。插件报告记录 host 观察到的结果，只有用户复制后才离开设备。

## 九、第一批做状态命令插件

状态插件用于增加 ZFS pool、UPS/NUT、smartctl 字段或厂商传感器等指标。作者可以独立发布，不必每次修改 `sbm_parser`。

它使用同一套 runtime，在 manifest 的 `contributes.status` 声明，并提供两个导出：

| 导出 | 输入 | 输出 |
|---|---|---|
| `statusCmd(ctx)` | 包含目标 platform 的 context | `{cmd}`，需要执行的采集命令 |
| `parse(ctx)` | 包含命令输出的 context | `StatusResult` |

`StatusResult` 包含标题、若干 `{label, value, percent?, tone?}` 和可选说明，App 使用固定 Widget 渲染。它不依赖完整 UI tree，但采集命令仍有执行风险，见 9.2。

`crates/sbm_plugin/src/status.rs` 统一校验结果：截断过长标签、丢弃越界 `percent`、移除空行、最多保留 64 条。只有整体格式无法解析时才拒绝结果，局部坏数据尽量只影响对应行。

### 9.1 命令怎么执行

插件命令不并入每隔几秒执行的主状态脚本，避免拖慢常规指标，也避免安装插件后重传状态脚本。App 通过 `ServerNotifier.ensureExec` 单独执行，频率可以低于状态轮询，与 `EXTENDED` 指标的处理类似。

App 侧采集由 `PluginStatusCard` 管理，在卡片可见时按 `customCmdInterval` 运行。每次采集创建 instance，结束后释放；需要跨次保存的数据放入插件存储。服务器上不保留插件脚本文件。

自定义命令也已从主状态函数中分离，由独立 `SbCustom` 按 `Stores.setting.customCmdInterval` 执行，期间复用 `_customRaw`。插件沿用类似的采集节奏和缓存方式，但不使用用户的自定义命令目录。

`sbm_parser::script::inline_cmds_script` 支持将多个插件命令合并成一次往返。它复用 `sb_cmd` / `SbCmd` 的 timeout、输出上限和临时文件逻辑，包括四条 fallback 路径。命令以 base64 内联，执行时写入临时文件，完成后删除。

App 当前仍按一张 card 一次 exec 采集；原设计判断详情页通常只有一两个状态插件，暂不引入合并调度。

输出使用 `SrvBoxPluginSep`，与用户自定义命令的 `SrvBoxCusCmdSep` 分开，防止两类外部输出互相覆盖读数。

### 9.2 边界

采集命令来自插件，即使由 host 代为执行，也必须经过授权。声明 `contributes.status` 的 manifest 必须申请 `server.exec`，否则解析时拒绝。

安装流程可以通过 `PluginRuntime.statusCmd` 获取插件要执行的命令。命令展示与执行应使用同一份采集结果，避免重复调用产生不同内容；安装时展示过某条命令，也不代表未来命令永远不变。

配置变化可能改变 `statusCmd` 的结果，例如改为检查另一个 pool。是否按每台服务器记录上次命令、变化后再次确认，仍待决定；可参考 SSH host key 的 trust-on-first-use 流程。

状态插件没有自定义 UI，也不能据此判断其 App Store 审核结果。

## 九点五、agent 也跑插件

App 侧采集依赖 App 运行，无法单独为直接读取 agent `/metrics` 的 history、手表和桌面小组件提供数据。因此 monitor agent 也支持运行状态插件。

agent 已有命令采集和 `sbm_parser` 解析流程。插件沿用“生成命令 → 执行 → 解析为 `StatusResult`”的方式，只是命令与解析逻辑由插件提供。

曾考虑让 agent 只执行命令、App 再解析，但这样 agent 无法保存结构化 history；只在 manifest 中写死命令又无法表达 `$config` 和条件逻辑。因此 agent 也嵌入 JavaScript runtime。

### 9.5.1 agent 提供的 host 接口

`HostProfile`、`HostFn::available_in` 和 `Manifest.runs_in` 已实现。agent 不支持的函数使用抛异常的 stub，机制与未授权接口相同，拒绝理由为 `Refusal::Unavailable`。

| 接口 | agent 是否提供 | 说明 |
|---|---|---|
| `sb.http.fetch` | 是 | 可从 agent 所在网络访问目标 |
| `sb.store` / `sb.config` / `sb.diag` / `sb.log` | 是 | 存储、配置、诊断和日志 |
| `sb.ui.*` / `sb.nav.*` / `sb.clipboard` | 否 | agent 没有用户界面 |
| `sb.server.list` | 否 | agent 不持有 App 的服务器列表 |
| `sb.server.exec` / `sb.server.cancel` | 否 | agent 不发放 server handle |

agent 没有 `sb.server.exec`，不代表状态插件不能执行命令。插件通过 `statusCmd` 返回命令，再由 agent 的采集流程执行。

manifest 的 `runs_in` 默认为 `["app"]`，可声明 `["app", "agent"]`。声明支持 agent 时必须使用这组接口子集，带 UI contribution 的 manifest 会在解析阶段被拒绝。

### 9.5.2 授权和分发

agent 插件默认关闭。运维在 `config.toml` 的 `[plugins]` 中按 ID 启用，并将包放入配置的目录。实际权限取配置授权与 manifest 请求的交集。

App 不提供向 agent 推送插件代码的功能。`full_access` 对命令执行的授权不等于同意安装常驻、定时运行的插件；agent 的插件由运维单独管理。

App 和 agent 不共用授权。前者由设备用户同意，后者由服务器运维配置，并在 agent 运行账号下无人值守执行。

### 9.5.3 数据格式和采集优先级

- `/metrics` 增加 `plugin_status: {<id>: StatusResult}`，按 extended 周期采集，中间周期沿用上次结果，与 `pkg` 类似。
- 不通过 capabilities 列出插件，App 根据实际返回的 `plugin_status` 判断是否已有读数。
- `/metrics/history` 保存各周期的 `StatusResult`，供历史数据消费者使用。

agent 已返回某插件的读数时，App 的 `PluginStatusCard` 直接显示，不再自行采集，避免页面与 history、手表和小组件使用不同结果。

`plugin_status` 使用单独的宽松 parser，某个插件的畸形记录只影响它自身，不让 `MonitorMetrics.fromJson` 拒绝整份 `/metrics`。App 将结果放入 `ServerStatus.agentPlugins`。`sbm_plugin::status::wire` 与 `test/plugin_agent_status_test.dart` 使用同一份 wire 示例检查格式。

### 9.5.4 构建和执行

`x86_64-unknown-linux-musl` 和 `aarch64-unknown-linux-musl` 均有 `rquickjs-sys` 预生成 bindings，agent 不需要额外启用 bindgen。原记录估算二进制增加约 1 MB，并增加 QuickJS 的 C 依赖。

agent 的 `sb.store` 使用 `plugin_kv`，按 plugin ID 和 scope 隔离；HTTP 使用与 App 相同的 pin 规则，由 rustls `ServerCertVerifier` 实现。

bridge 自带 async runtime。agent 的 `#[ntex::main]` 使用 current-thread runtime，不能在当前线程等待插件时，又将插件需要的答复调度回同一线程。

插件由运维安装，但其代码和外部输入仍需按不可信数据处理。引入 JavaScript engine 也增加了需要维护的依赖和隔离边界。

### 9.5.5 实施顺序

先用监听端口、磁盘占用和定时任务验证 App 的接口，再接入 agent，避免两端复制同一个 contract 错误。当前两端均已接入，后续接口变动仍需同时验证各自支持的范围。

## 十、实现进度和下一步

以下保留原实施步骤，区分已经接通的功能与剩余验收。每项实现应单独提交 PR，并验证实际行为。表后的测试数量是原开发记录，不是本次文档修改重新运行的结果。

| 原步骤 | 工作 | 当前状态和剩余事项 |
|---|---|---|
| 1 | QuickJS runtime 和 TypeScript SDK | 已替代 WebAssembly 版本；权限、manifest、异步 bridge、资源限制和 SDK 已实现 |
| 2 | FFI 和 Dart host callback | 已接通 `PluginBridge`、`PluginRuntimeService`、`AppPluginHostOps`；HTTP 直连与证书 pin 已实现，`via: "ssh"` 待实现 |
| 3 | 状态命令插件 | `StatusResult`、`contributes.status`、`inline_cmds_script`、`PluginRuntime.statusCmd` / `statusParse` 和 App card 已接通；未采用随 App 分发样本 |
| 4 | Dart feature registry 和稳定 ID | 已实现 `lib/data/model/app/feature.dart`；m021 和备份恢复处理旧按钮 ID |
| 5 | Flutter 渲染、存储、安装和备份 | 四种 surface、m022、插件开关、安装卸载、开发目录和备份已接通；m023 将 `homeTabs` 改为 ID，首页、macOS 菜单栏和排序页共同使用；golden 截图待补齐 |
| 6 | BMC 插件 | 2026-09-08 取消，保留 Dart 实现与 `packages/redfish` |
| 7 | 在线仓库和网站 | 多仓库、ABI 版本选择、SHA-256、安装更新和 `/plugins/` 已实现；发布工具见 8.1 |
| 5.5 | 实际插件覆盖四种 surface | 已有监听端口 card、磁盘占用 settings、定时任务多服务器 tab，以及三个 page；golden 截图待补齐 |
| 8 | agent 状态插件 | host 子集、运维配置、extended 采集、`plugin_status` 和 App 显示已接通 |

后续增加的取消执行、上一版回退、开发目录监听和插件报告分别见 4.3.1、8.2、8.4。

原阶段性验证记录：步骤 1 为 runtime 81 个、SDK 45 个测试；步骤 2 为 bridge 26 个、HTTP 12 个、runtime service 6 个、FFI 21 个；步骤 3 为 Rust 121 个；步骤 5 先记录 81 个，接入状态 card 后为 84 个。当时渲染器记录为 22 种 Widget，bridge 为 14 个接口。这些数字反映当时进度，不能作为当前总数。

### 三个插件发现的问题

三个插件都使用 `contributes.page` 和 `onHook`，同时有 MockHost 与真实 QuickJS 测试。它们已帮助发现并修复以下问题：

- `onEvent` 曾被写成两个参数，而 host 只传 `{msg, value}`，导致 MockHost 测试通过、App 按钮却没有响应。
- 多服务器 hook 曾发出 runtime 未登记的 handle，实际执行时被拒绝。
- `open` 启动的 Promise 在 call 返回后没有继续推进，settings 表单一直停在 loading。
- 长命令阻塞 call，停止按钮的 event 无法送达；ABI 4 的 background resource 和 host 答复后的 tick 处理了这条路径。
- `timeoutMs` 曾未传到 App 的实际执行控制；取消执行接入时补上，并在错误中提供远端状态。
- runtime 曾只在等待循环中交付 host 答复，不等待的导出无法收到结果；现在在执行导出前先交付已有答复。

`shellQuote` 已统一放入 SDK。拼入命令的路径、单元名等即使来自服务器，也必须正确 quote，不能让每个插件重复实现 shell 转义。

以下约束仍需让作者了解：

- surface 不显示时 `sb.ui.patch` 会拒绝。插件应区分“无需更新界面”和“采集失败”，避免一次 patch 失败中断后续工作。
- 权限拒绝可以被 JavaScript catch，但 host 仍会将本次 call 判为失败，见 6.2。
- 尚无 `sb.nav.openPortForward`。是否新增应根据多个实际场景决定，避免 host API 随单个插件不断增加。

正式开放 UI contract 前，还需确定命名区域、`Intl` 处理方式和真机资源预算，并补齐 golden 验收。

## 十一、主要代价和未决问题

UI contract 的范围需要持续控制。类型太少会限制插件，类型和属性过多则会形成一套长期维护的 UI framework。复杂表格、长列表和流式输出仍需要更多实际插件验证。

目前的待办如下：

- **HTTP 经 SSH 访问**：`via: "ssh"` 尚未实现，需要将 `SSHForwardChannel` 适配为 `HttpClient.connectionFactory` 使用的 `ConnectionTask<Socket>`。
- **性能与资源**：frame 裁剪、Widget 缓存、值绑定和 `ListView.builder` 已有实现；收益和资源默认值仍需在移动端真机测量。`listWindow` 回调尚未接通。
- **构建验证**：iOS、Android 的 bindgen 配置已接入。`hook/bindgen_environment.dart` 为 iOS 使用 `xcrun --show-sdk-path`，为 Android 从 `CodeConfig.cCompiler` 推导 `<prebuilt>/sysroot`，避免硬编码 SDK 或混用 `ANDROID_NDK_HOME`。原记录已验证 iOS device、Android arm64、macOS 本地构建，五个平台的 CI 交叉编译验证仍待完成。
- **语言支持**：第三节只记录了 19 项抽查，完整 test262 未运行。`Intl` 缺失时，日期和数字的本地化方案仍待确定。
- **供应链**：包大小检查已经实现，npm 依赖的审查方式和发布者信任机制仍需完善。
- **调试与兼容**：已有 SDK 测试、真实 runtime 测试、日志和插件报告；仍需维护跨 Dart、FFI、JavaScript 的 contract，补齐 golden，并确定尚未接入的导出格式。
- **配置与数据版本**：数据库、备份和卸载已实现；未来配置转换、插件数据升级及回退兼容仍需明确。`cfg_ver` 与 `data_version` 的用途不同，不能混用。
- **入口一致性**：Dart registry 和插件 manifest 需要遵循相同的默认显示、排序和入口失效规则，并用集成测试检查遗漏注册和旧数据转换。
- **平台分发**：在线插件仍有商店审核不确定性，发布前核对政策及对应说明。

原文中的自定义命令问题已解决：命令由独立 `SbCustom` 执行，周期按轮询间隔向上取整，保存使用 compare-and-swap，读取不再回退到 `.bak`。插件状态采集与它分开，见 9.1。

## 十二、参考项目

| 项目 | 本设计参考的部分 |
|---|---|
| [ruxlet](https://github.com/mikolajbadyl/ruxlet) | Rust 返回界面描述、Flutter 渲染、事件回传，以及用稳定 key 保留 Widget 状态；不复用其桌面动态库加载方式 |
| [Crux](https://github.com/redbadger/crux) | 在测试中模拟 host 响应，让插件逻辑脱离 App 运行；未采用 effect / resolve 调用模型 |
| [Zed extensions](https://zed.dev/blog/zed-decoded-extensions) | SDK 包装接口、独立仓库、开发目录加载和版本兼容表；未采用其 wasmtime + component model 运行方案 |
| [quickjs-ng](https://github.com/quickjs-ng/quickjs)、[rquickjs](https://github.com/DelSkayn/rquickjs) | 当前使用的引擎和 Rust 绑定 |
| [Zellij](https://github.com/zellij-org/zellij/pull/4449) | 评估 WebAssembly 方案时参考过它的 runtime 选型、固定线程实例和内存限制；本项目最终未用 WASM |
| [Dioxus](https://docs.rs/dioxus-core/latest/dioxus_core/trait.WriteMutations.html) | 评估过逐条界面变更协议，目前未采用 |
| [rfw](https://pub.dev/packages/rfw) | 评估过远程 Widget 格式，保留用 golden 检查 Widget 兼容性的思路 |
| [Rinf](https://github.com/cunarist/rinf)、[Oxide](https://github.com/oxide-stack/oxide) | Rust 保存状态、Flutter 消费快照的分工；它们不解决插件沙箱和在线分发 |
| [frui](https://github.com/fruiframework/frui)、[Xilem / Masonry](https://github.com/linebender/xilem)、Freya | 评估过 Rust 自绘界面；本项目继续使用 Flutter Widget，因此未采用 |

## 参考

- [quickjs-ng](https://github.com/quickjs-ng/quickjs) · [rquickjs](https://docs.rs/rquickjs/) · [test262](https://github.com/tc39/test262)
- 评估 WebAssembly 方案时用到的资料：[Wasmi 2.0 发布](https://wasmi-labs.github.io/blog/posts/wasmi-v2.0/) · [Zellij 从 wasmtime 迁到 wasmi（PR #4449）](https://github.com/zellij-org/zellij/pull/4449) · [wasmtime Pulley 在 iOS（#12251）](https://github.com/bytecodealliance/wasmtime/issues/12251) · [wasmtime 支持层级](https://docs.wasmtime.dev/stability-tiers.html) · [Extism PDK](https://extism.org/docs/concepts/pdk/)
- [ruxlet](https://docs.rs/ruxlet/latest/ruxlet/) · [Crux 的 managed effects](https://redbadger.github.io/crux/part-2/effects.html) · [Zed 扩展的构建与分发](https://zed.dev/blog/zed-decoded-extensions) · [rfw](https://pub.dev/packages/rfw)
- [App Store Review Guidelines 4.7](https://developer.apple.com/app-store/review/guidelines/#4.7) · [F-Droid 收录政策](https://f-droid.org/docs/Inclusion_Policy/) · [F-Droid Anti-Features](https://f-droid.org/docs/Anti-Features/)
- [Dart / WebAssembly 编译](https://dart.dev/web/wasm) · [`wasm_run`](https://pub.dev/packages/wasm_run)
- [Fixing Section 2.5.2](https://saagarjha.com/blog/2020/11/08/fixing-section-2-5-2/) · [Guideline 2.5.2 被拒案例](https://ptkd.com/journal/guideline-2-5-2-downloading-scripts-without-review)
