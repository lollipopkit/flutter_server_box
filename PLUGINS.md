# 插件系统

ServerBox 计划允许用户安装第三方插件，用来增加服务器状态指标、详情卡片和操作页面。插件是一个 JavaScript 模块，界面由 ServerBox 绘制；执行命令、访问网络、保存数据等操作，都要通过 ServerBox 提供的接口。

**目前还不能在 App 里安装或使用插件。** 2026-09-06 之前按 WebAssembly 方案实现过 Rust 运行时、SDK 和 BMC 示例的插件侧代码。同日改用 JavaScript 方案，那部分实现需要重做，理由和实测见第三节，影响范围见第十节。本文记录改用 JavaScript 之后的设计，不是已发布功能的说明。

目前的安排是：先做只负责提供采集命令、解析状态数据的插件，再做带界面的插件。PVE、benchmark、process、services 等内置功能继续用 Dart 实现；BMC 保留为验证插件界面的样本。

## 一、要解决什么问题

### 1.1 用户和作者能做什么

用户可以在线安装、更新和卸载插件。插件作者可以增加状态指标，也可以在服务器功能栏、详情页、首页、服务器编辑器和设置页增加内容。

作者用 JavaScript 写插件，或者用 TypeScript 编译成 JavaScript。插件是一个 ES module，App 直接加载源码，不需要为每个目标平台编译。用到打包时（把 TypeScript 和依赖合成单文件），由作者在发布前完成。

本文中的几个词：

- **宿主**：运行插件的 ServerBox，包括 Rust 运行时和 Flutter App。
- **manifest**：插件的 `manifest.json`，说明名称、版本、权限、配置项和界面入口。
- **ABI**：插件与宿主交换数据、调用函数的约定。已经发布的插件依赖它，修改时必须考虑兼容性。
- **surface**：插件在 App 中的一块显示区域，例如详情卡片或独立页面。
- **SDK**：供插件作者使用的类型定义和辅助函数，负责包装底层接口。

### 1.2 平台限制

普通 iOS 第三方 App 不能依赖 JIT，插件只能解释执行。QuickJS 是解释器，满足这个限制；它不需要生成可执行页面，也不需要额外的 entitlement。

在线下载插件还要考虑 App Store 和 F-Droid 的政策，具体发布安排见第八节。解释执行不能保证避开 App Store 2.5.2，这一点无论运行时是 WASM 还是 JavaScript 都一样。

Dart 不用来编写插件：App 内没有可以加载第三方 Dart 代码的运行时，dart2wasm 的产物也需要 JavaScript 宿主环境。相关问题见 [dart-lang/sdk#53884](https://github.com/dart-lang/sdk/issues/53884)。

### 1.3 内置功能为什么难加

现在增加一个功能，通常要同时修改按钮枚举、图标和名称的 switch、详情卡片、首页 tab、编辑表单、数据库、设置、备份和生命周期处理。以此前统计的 PVE 为例，它自己的三个文件约 1700 行，接入代码还分散在另外 15 个文件中。

其中还有数据兼容问题：功能栏按钮存的是 enum index，详情卡片存的是 name，首页 tab 又有 Hive 字段编号。增加或移动入口时，不能只改界面。

这些重复修改说明 App 缺少统一的功能注册表。按钮是否可用、点击前是否需要 SSH 连接等条件，也应该在注册时集中声明。

已完成（第十节第 4 步）：`Feature`/`FeatureSlot`/`Features`。三个入口面共用一个 id 空间、一份默认值规则、一份"这次升级新增了什么"的规则。内置入口仍然是 Dart enum —— 它们带着画自己的控件和点击后执行的代码，那两样不是数据 —— 变成数据的是关于它们的一切，也正是插件 manifest 的 `contributes` 要自己提供的部分。

### 1.4 内置功能与第三方插件分开处理

内置功能使用 Dart feature registry：每个功能在一处声明入口和依赖，App 读取注册表来显示按钮、卡片等内容。按钮存储也要从 enum index 迁到稳定 id，原计划放在 m021。

第三方功能才使用本文的插件系统。它们需要独立安装、权限限制和版本管理。内置功能随 App 一起发布，全部改成插件会增加约 6600 行重写工作，还会让调试跨越 Dart、FFI、JavaScript 三层，并受到插件控件的限制。

BMC 是唯一保留的 UI 插件样本：它主要显示一张详情卡片，不需要复杂长列表和图表，适合先验证接口、存储和交互。不过一个样本不能证明所有界面需求都已覆盖，因此 UI 插件要晚于状态插件发布。

## 二、整体怎么工作

**每个宿主函数收一个对象、答一个对象。** 宿主的实现就是这样 —— 一次 host call 每个方向只带一个 JSON 值 —— 所以 SDK 里写成多参数的签名描述的是一个不存在的接口：照它写的插件能通过自己的测试，到设备上才失败。`Sb` 和 `MockHost` 已按此更正。

一个插件是扩展名为 `.sbp` 的 zip 包，包含 `manifest.json`、`plugin.js`、`l10n/*.json` 和 `icon.png`。`plugin.js` 是一个 ES module，导出第四节列出的函数。

带界面的插件按下面的流程工作：

1. ServerBox 读取 manifest，检查版本和权限，决定在哪里显示入口。
2. 用户打开页面时，宿主新建一个 JavaScript 上下文，按已授权的权限装入宿主接口，加载 `plugin.js`。
3. 插件返回一份 JSON，描述要显示的文字、按钮和布局。
4. Flutter 把这份描述画成 App 自己的控件。
5. 用户点击按钮或修改输入后，宿主把事件交给插件；插件处理后返回新的界面。

插件不能直接操作 Flutter 控件。需要请求网络、执行命令或弹出对话框时，它调用宿主提供的函数，宿主检查权限后执行。

代码位置与进度如下。2026-09-06 决定改用 JavaScript：运行时已换成 QuickJS，SDK 已换成 TypeScript 包，按 WebAssembly 方案写的 Rust SDK 和 BMC 插件已删除。

| 位置 | 负责什么 | 当前进度 |
|---|---|---|
| `crates/sbm_plugin` | QuickJS 运行时、宿主接口注入、权限检查、manifest 解析、实例线程、异步桥、状态结果校验 | 已实现，113 个测试通过 |
| `packages/plugin-api` | TypeScript SDK：类型定义、控件构造函数、帧裁剪、模拟宿主的测试工具 | 已实现，45 个测试通过 |
| `plugins/bmc` | BMC 的 Redfish 请求、状态处理和界面描述 | 未开始；参照 `packages/redfish/` 与 `git log` 里已删除的 Rust 移植 |
| `crates/sbm_ffi` 的插件接口 | 让 Dart 加载、调用和释放插件 | 已实现，`test/plugin_ffi_test.dart` 17 个测试通过 |
| `lib/plugin/` | 注册、渲染、宿主回调和安装管理 | 未开始 |
| `assets/plugins/` | 随 App 分发的插件包 | 未开始 |
| `lollipopkit/serverbox-plugins` | 插件源码与发布仓库 | 未开始 |

只维护一套插件接口，不另做一套 Dart 插件接口。SDK 计划发布到 npm，同时提供 `.d.ts`，让不用 TypeScript 的作者也能看到接口定义。

## 三、为什么选 QuickJS

插件由 [quickjs-ng](https://github.com/quickjs-ng/quickjs) 执行，Rust 侧通过 `rquickjs` 绑定。本节记录 2026-09-06 从 WebAssembly 改到 JavaScript 的依据和实测数据。

先前方案是 `wasmi` 2.0 加 Extism ABI v1，理由主要有两条：一是能复用 Extism 的多语言 PDK，二是 WASM 的沙箱和 fuel 计量。第一条在重新讨论后不再成立——插件作者用什么语言不再是要保护的需求，本文只需要一种写法。去掉这条之后，两个运行时的其余差别在下面几节量了一遍。

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

结论是：性能差距在本项目的负载下看不出来，而没有构建步骤、原生异步和现成的时钟每天都会用到。

### 3.2 五个平台的构建实测

`rquickjs` 0.12.2 附带 quickjs-ng 0.15.1 的 C 源码（约 8.3 万行），由 `cc` crate 编译。2026-09-06 在 macOS 上逐个目标试过：

| target | 结果 | 需要的条件 |
|---|---|---|
| `aarch64-apple-darwin` | 通过 | 附带的预生成 bindings |
| `aarch64-apple-ios` | 通过 | 开启 `bindgen`，并传 `-isysroot $(xcrun --sdk iphoneos --show-sdk-path)` |
| `aarch64-linux-android` | 通过 | 开启 `bindgen`，用 NDK clang 和对应 `--sysroot` |
| `x86_64-pc-windows-gnu` | 通过 | 预生成 bindings，加一个 C 编译器（用 `zig cc` 验证） |
| `aarch64-unknown-linux-musl` | 通过 | 同上 |

`rquickjs-sys` 自带 16 个 target 的预生成 bindings，覆盖 Windows 的 msvc 和 gnu、Linux 的 gnu 和 musl、macOS 两个架构，但**不含 iOS 和 Android**。这两个平台要开 `bindgen`，因此构建环境需要 libclang 和正确的 sysroot。这是 `hook/build.dart` 里要补的配置，不是阻塞项，但比纯 Rust 依赖多一层需要维护的东西。

C 源码本身没有为这些平台打补丁：用 `zig cc` 交叉到 windows-gnu 和 linux-musl 一次通过。

### 3.3 性能实测

用同一个任务对比：解析 `df -P` 风格的输出，过滤掉 tmpfs，算出占用比例并组装 JSON。两侧结果断言相等，否则比较的不是同一件事。环境是 aarch64-apple-darwin、release、2000 次迭代。

| 输入 | wasmi | QuickJS |
|---|---|---|
| 663 B（8 个文件系统） | 70.8 µs | 110.4 µs |
| 15.8 KB（200 个文件系统） | 1.47 ms | 2.65 ms |
| 冷启动（建运行时、载入模块、建实例） | 0.5–0.9 ms | 0.2–0.6 ms |

链接后的体积增量，条件与 3.4 表相同：

| 运行时 | 相对空基线增加 |
|---|---|
| QuickJS（rquickjs） | 约 0.75 MB |
| wasmi（std + validate） | 约 0.70 MB |

这些数字都取自开发机，不是 iOS 或 Android 设备上的结果。移动端尤其是低端机的表现还没有量过；接入后需要在真机上复测。

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

WASI 也不能解决网络问题：`wasm32-wasip1` 没有 `sock_connect`，不能建立出站连接；`wasm32-wasip2` 网络更完整，但产物是 component，wasmi 不支持。何况本设计要求网络请求经过宿主，以便检查目标地址、SSH 范围和证书，即使运行时能直接建 socket 也不会开放给插件。这一条在 JavaScript 方案下同样成立：插件上下文里没有 `fetch`。

### 3.5 JavaScript 支持范围

quickjs-ng 0.15.1。2026-09-06 在引擎里抽查了 19 项：

| 可用 | 不可用 |
|---|---|
| class 与私有字段、`async`/`await`、generator、`Proxy`、`BigInt`、可选链、`??`、`Array.at`、`Object.groupBy`、具名捕获组、`WeakRef`、TypedArray、`Promise.allSettled`、`String.replaceAll`、`JSON.parse` reviver | `structuredClone`、`Intl` |

`fetch` 和 `require` 都不存在，符合沙箱边界：网络只能走宿主注入的接口。

`Intl` 缺失需要注意：日期和数字的本地化格式要么由宿主处理，要么单独把 Intl 编进引擎，后者体积不小。这一项接入前要定。

抽查 19 项不等于符合度数字。完整的 test262 没有跑过，引擎自带的 `run-test262.c` 需要另外下载整套测试集。

### 3.6 考虑过的其他运行方式

| 方案 | 没有采用的原因 |
|---|---|
| 插件跑在 App 自带的 Linux 环境里（iOS 用 ish-arm64，Android 用 proot，桌面用本机） | iOS 的 Linux 引擎由 `SBM_ISH` 控制且默认关闭，原因正是 App Store 2.5.2；插件系统建在上面会和它共用同一个开关。桌面走本机则没有隔离，插件能读到用户的 SSH 私钥和 App 数据库。三个平台的环境也不一致 |
| wasmtime + Pulley | 见 3.4 |
| WAMR | 需要为多个目标维护 C 工具链，且官方平台列表没有 iOS |
| `wasm_run` | 运行时版本较旧且已停更 |

需要在本机跑外部工具（例如 `kubectl`、`ansible`）是另一类需求，性质接近现有的自定义命令，不在本文范围。

## 四、插件和 App 怎么互相调用

### 4.1 底层约定

`crates/sbm_plugin` 为每个实例新建一个 QuickJS 上下文，把宿主接口装到全局对象 `sb` 上，然后把 `plugin.js` 作为 ES module 载入。数据以 JavaScript 值传递，不经过序列化缓冲区。

宿主接口是**按已授权的权限装入**的：没有授权的函数装成一个直接抛 `PermissionDenied` 的替身，说明缺哪一项权限。判断在建上下文时做一次，调用路径上没有分支。插件拿不到未装入的能力，也没有办法自行构造。

`plugin.js` 只能是单个文件，不能从网络或其他文件动态 `import`。需要拆分模块或使用依赖时，作者在发布前打包成一个文件。

上下文里没有浏览器和 Node 的全局对象：没有 `fetch`、`require`、`process`、`XMLHttpRequest` 和文件系统。`Date`、`JSON`、`Math`、`RegExp`、`TextEncoder` 这些语言自带的部分可用，具体范围见 3.5。

接口发布后要保持兼容，manifest 的 `abi` 标明所需版本。

### 4.2 App 调用插件的函数

插件用 ES module 的具名导出提供下列函数。每个都可以是 `async`，宿主等待返回的 Promise 完成。

| 导出 | 什么时候调用 | 插件返回什么 |
|---|---|---|
| `init(ctx)` | 实例创建后调用一次 | 初始化状态 |
| `open(surface)` | 页面、卡片、tab 或设置区域首次显示 | `{ui}`，省略 `ui` 表示该区域没有内容 |
| `onEvent(msg, value)` | 用户操作控件 | `{ui}` |
| `tick()` | 显示区域可见时，按 App 的共享刷新间隔调用 | `{ui}`，省略表示界面没有变化 |
| `onServerEvent(e)` | 服务器连接、断开或删除 | 处理生命周期变化 |
| `validateConfig(cfg)` | 编辑器保存前 | `{errors: [...]}` |
| `configOptions(key)` | 配置下拉框需要动态选项 | `{options: [{value, label}]}` |
| `tool(name, args)` | AI agent 调用 manifest 中声明的工具 | JSON |
| `dispose()` | 实例销毁前 | 释放会话等资源 |

`configOptions` 和 `tool` 用一个参数区分对象，不再按名字生成多个导出。WebAssembly 方案下每个导出是一个独立符号，只能用 `options_<key>` 这样的命名；ES module 没有这个限制。

`configOptions` 处理无法写死在 manifest 里的选项，例如 BMC 插件保存的共享账号列表。对未配置的服务器，优先用 manifest 的 `requires_config` 隐藏入口，避免为了判断是否显示而创建实例。

插件抛出的异常由宿主捕获，记录日志并在该区域显示错误，不影响页面其余部分。

### 4.3 插件可以调用的 App 函数

全局对象 `sb` 按用途分组。凡是要经过 Dart 的都返回 Promise；只读本地状态的是同步函数。下表是设计，Dart 侧尚未接上实际功能。

| 接口 | 用途 | 所需权限 |
|---|---|---|
| `sb.server.exec(req)` | 在宿主允许的服务器上执行命令 | `server.exec` |
| `sb.http.fetch(req)` | 发 HTTP 请求，可直连或经服务器的 SSH 连接访问 | `net.http`；经 SSH 时另需 `server.stream` |
| `sb.ui.patch(path, node)` | 替换界面的一部分，适合持续追加日志 | 无额外权限 |
| `sb.ui.prompt(spec)` | 弹出对话框并等待用户回答 | `ui.dialog` |
| `sb.ui.pickServer()` | 让用户选择服务器，返回可操作的句柄 | 无额外权限 |
| `sb.ui.toast(text, kind)` | 显示提示 | 无额外权限 |
| `sb.store.get / set / list` | 读写插件自己的持久化数据 | 无额外权限 |
| `sb.diag.crumb(name, level)` | 记录诊断事件，只记录发生了什么，不记录敏感内容 | 无额外权限 |
| `sb.nav.openServer(h)` / `sb.nav.goTab(id)` | 打开服务器或切换 tab | 无额外权限 |
| `sb.clipboard.read / write` | 读写剪贴板 | `clipboard` |
| `sb.config.get(key)` | 读取插件设置和绑定服务器上的插件配置；同步 | 无额外权限 |
| `sb.log.trace / debug / info / warn / error` | 写日志；同步 | 无额外权限 |

时间不需要宿主接口，`Date.now()` 可用。这是与 WebAssembly 方案的一处差别，先前需要为此单独加 `time_now`。

`sb.server.exec` 对接现有 `ServerNotifier.ensureExec` 和 `ServerExec.run`。插件只能使用宿主给出的服务器句柄，来源是当前绑定的服务器或用户选择结果，不能自行指定任意服务器。

HTTP 统一走 `sb.http.fetch`，上下文里没有 `fetch` 这个全局函数。这样才能统一处理地址权限、SSH 转发、cookie 和证书。经 SSH 时，宿主通过 `ensureShellClient` 和 `SSHForwardChannel` 建立连接。

证书复核分两步，避免用户还没确认就发送密码：

1. `probeCert: true` 只握手、读取证书并关闭连接，不发送 HTTP 请求内容。宿主拒绝同时带 body 或 header 的探测请求。
2. 用户核对后，正式请求携带 `pinSha256`，宿主按指纹验证证书。按当前设计，没有指纹时拒绝证书，不能自动信任首次见到的证书。

返回的 `cert` 包含指纹、subject、issuer、有效期和 `expired`，供用户核对。

宿主需要一组测试证明未授权接口确实抛错、参数级检查确实生效，以及接口表与实际装入的对象一致。WebAssembly 方案下这组测试是 `permission_scope.rs`；换到 QuickJS 后要重写，断言内容不变。

### 4.4 线程、超时和资源限制

每个“插件 + 服务器”对应一个实例；首页 tab 等全局区域对应不绑定服务器的实例。

**一个实例一条线程。** QuickJS 的运行时不能跨线程使用，`Instance` 持有的值也不是 `Send`，所以实例在自己的线程上创建、调用和析构，上层通过通道与它通信，可以从任何线程调用。同一个实例的调用被通道串行化：轮询期间到达的点击排在它之后，而不是与它并行 —— 插件自己的状态就是这么假设的。

线程数在实践中很小：实例只在对应区域可见时存在，一个详情页显示的是一台服务器的卡片。一条挂起的线程只占几 KB 已提交栈，比共享线程池需要的机制便宜 —— 宿主调用未完成时那次调用正停在 `Context::with` 里面，没法挂起，要复用线程就得把 `Instance::call` 改写成可恢复的状态机。数量真的成为问题时再考虑那条路。

**异步。** 宿主函数返回一个未完成的 Promise：Rust 侧向 App 发起请求后立即把控制权还给引擎，插件的 JavaScript 调用栈随之退栈，App 答复后再驱动任务队列继续执行。所以等待期间实例只占内存，而且一个插件可以同时挂着多个调用（`Promise.all`）。

这条路径已经端到端验证过：`ChannelBridge` 把每次调用变成一个带 `call_id` 的请求交出去，另一条线程按自己的节奏调用 `answer` 回答，插件从 `await` 处继续。测试覆盖单次等待、`Promise.all` 里两个同时未完成的调用、连续多次 `await` 且插件状态跨恢复保持、App 报错被插件 `catch`、日志不需要回答、以及两个实例共用一座桥而答复互不串线。

`ChannelBridge` 是同步的，不需要执行器。这一点是有意的：宿主调用发起于插件自己的线程，那条线程不属于任何异步运行时，`tokio::spawn` 在那里会 panic。所以桥把请求交出去、稍后取答复，正好是 `PendingCall` 已经描述的形状。

未完成的请求会在自身析构时把自己从桥的表里移除（`Arc::new_cyclic` 持一个 `Weak`），答复了的、取消了的、超时了的都走这一条路径，App 不需要记得清理任何东西。

FFI 那一层已经接好：`sbm_ffi` 用 `StreamSink` 把请求推给 Dart，Dart 处理完调用同步的 `answer` 报上 `callId`。`test/plugin_ffi_test.dart` 在真的 Dart isolate 上走通了加载、调用、宿主回调、权限拒绝。

**`load` 和 `call` 不能标 `frb(sync)`。** 两者都要等插件，而插件在等 Dart 回答；跑在 Dart isolate 上就会停住那个必须去回答的 isolate，两边都不会继续。`answer` 和几个小接口是同步的，因为它们只碰一张表。

一处 `RustStreamSink` 的行为要记下来：**不要 `await subscription.cancel()`**。它的流来自一个坐在 `ReceivePort` 上的 `async*` 生成器，端口空闲时取消订阅返回的 future 不会完成。App 也没有理由去等它 —— sink 随运行时存在，结束它的方式是丢掉运行时。

等待答复时线程按退避轮询：前 50 毫秒每毫秒看一次，之后每 25 毫秒。固定一毫秒会让一次慢的 BMC 请求唤醒这条线程三万次，在手机上这是白花的电；代价是给一次本来就要几秒的调用再加最多 25 毫秒。

**资源限制**用四项，均已实现并有测试：`JS_SetMemoryLimit` 限制运行时内存，`JS_SetMaxStackSize` 让递归得到异常而不是崩溃，中断回调按墙钟时间中止长时间运行的 JavaScript，另有一个等待宿主答复的超时。中断回调只覆盖 JavaScript 执行本身；等待宿主的时间不计入，插件被唤醒时重新计时。

丢弃实例时，运行时会对每个未完成的调用调用 `PendingCall::cancel`，让 App 有机会取消请求 —— 否则一次被放弃的 BMC 请求会留下一个没人释放的会话。卸载接口会等待线程结束再返回，因为析构发生在那条线程上。

具体的内存上限和时间上限（当前默认 64 MB / 5 秒 / 120 秒）尚未按真机负载定过。计量精度比 WASM 的 fuel 粗：fuel 可以按指令数计，中断回调只能按时间近似。

一处实现约束记在这里：持有 JavaScript 值的字段必须在运行时之前析构。quickjs 在 `JS_FreeRuntime` 里断言 `list_empty(&rt->gc_obj_list)`，顺序反了会直接 abort 进程，而不是报错。`Instance` 的字段顺序因此是有意义的。

## 五、插件界面怎么画

插件保存自己的状态，并返回一棵 JSON 控件树；Flutter 根据它生成界面。这借鉴了 ruxlet 的交互方式，但不使用它的动态库加载方案。

### 5.1 节点格式

下面的例子显示 CPU 使用率、一个启动按钮和一个输入框：

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
| `t` | 控件类型，例如 `column`、`text`、`btn` |
| `k` | 稳定标识，映射为 Flutter 的 `ValueKey` |
| `p` | 控件属性，例如文字、间距和颜色含义 |
| `c` | 子节点 |
| `on` | 用户事件对应的消息，由宿主原样传给 `onEvent`；输入控件另传当前 `value` |
| `v` | 该子树的修订号，由 SDK 自动填写，作者不写。见 5.2 |
| `s` | `1` 表示"这棵子树你已经有了"，同样由 SDK 填写。见下 |

`s` 是补上的：`spacer` 和 `divider` 本来就没有 `p` 也没有 `c`，所以 `{t, v}` 同时意味着"一个 spacer"和"复用你手上那个"。没有这个标记，宿主收到一个新 spacer 会当成"复用一个从没见过的修订号"并报错。SDK 的 `Walked.changed` 是同一个混淆在上一层的版本。

`k` 比看上去重要。Flutter 用 `runtimeType` 加 `key` 判断新旧节点是不是同一个（`Widget.canUpdate`）；不带 key 的一组子节点重排之后，框架会把每个节点和现在占据该位置的那个配对，于是对应的 element 和它保存的状态被丢弃。输入焦点只是其中一种表现，列表行的滚动位置和展开状态也一样。

设计中的布局类型有 `column`、`row`、`expanded`、`padding`、`sized`、`scroll`、`list`、`spacer`、`divider`。内容和交互类型有 `card`、`kv`、`expand`、`percent`、`line_chart`、`bar_chart`、`btn`、`input`、`table`、`progress`、`tag`、`text`、`icon`。其中部分对应 App 现有的 `CardX`、`KvRow`、`ExpandTile` 和 `PercentCircle`。

颜色用 `tone` 表达：`normal`、`muted`、`success`、`warning`、`danger`。实际颜色由 App 主题决定。

以 `l10n.` 开头的字符串从 `l10n/<locale>.json` 查找，找不到时回退到 `en`。带参数时，在 key 后用 U+001F 分隔参数，替换翻译中的 `{0}`、`{1}`；SDK 会移除参数中自带的分隔符。完整句子交给翻译文件，避免插件拼接出无法自然翻译的文案。

插件每次构建整棵树，SDK 负责裁掉没有变化的部分（5.2）。持续输出日志时可以用 `sb.ui.patch`，按 JSON Pointer 替换子树。未知控件或非法属性应显示错误卡片并记录日志，避免影响整个页面。

**节点格式还有一个未决问题：如何表示命名区域。** 例如折叠面板既需要标题节点，也需要内容节点，现在只能把标题塞进 `p.title`。候选方案是让 `c` 按名称保存子树，或者增加 `slot` 节点。发布 UI 接口前需要确定，否则后续修改会影响已有插件。

### 5.2 怎么让 Flutter 少做事

界面每隔一段时间刷新一次，而每次刷新真正变的通常只有几个数字。这一节记录为此做的三件事，依据是 Flutter 自己的更新机制。

已实现：`lib/data/model/plugin/node.dart`（节点格式）、`lib/view/widget/plugin/surface.dart`（一个 surface 跨帧保存的东西）、`lib/view/widget/plugin/render.dart`（画树），测试在 `test/plugin_render_test.dart`。

**Flutter 的判断点。** `Element.updateChild`（`packages/flutter/lib/src/widgets/framework.dart`）在新旧 widget 相等时直接返回，不调用 `update()`，于是整棵子树跳过：不重建、不布局、不绘制。`Widget` 没有重写 `==`，所以这个比较是引用相等。每次从 JSON 重新构造的 widget 全是新对象，永远走不到这条路径 —— 框架只能遍历整棵树，逐个属性比较之后才发现什么都没动。

#### 修订号：让宿主复用同一个 Widget 实例

每个节点带一个 `v`。宿主已经持有该修订号时，节点只发 `{t, k, v}`，宿主交还上次构建的**同一个 Widget 实例**，于是命中上面那条路径。

`v` 由 SDK 的 `frame()` 计算，插件作者不写。它保留上次发出的树，逐节点做深比较，没变的裁成三个字段，变了的和它到根的路径重新编号 —— 父节点的修订号也必须变，否则宿主会复用一个子节点已经过时的 Widget。

已实现并有测试：一次什么都没变的刷新，整棵树塌缩成根节点一个 stub，约 35 字节；只有一个叶子变化时，发出的是到它的那条路径，兄弟节点仍是 stub。

判断"变了没有"用的是深比较而不是哈希：树本来就要走一遍，而哈希碰撞的表现是一张卡片不再更新。实现里有一处专门处理：`NaN` 在 `===` 下不等于自身，而一个传感器连续两次读不出数不算变化。

#### 值绑定：结构不变时连树都不发

属性可以写成 `{"$": "cpu"}`，表示跟随一个具名值。宿主把这样的叶子建成 `ValueListenableBuilder`，每个 slot 一个 notifier。刷新时插件答 `{"values": {...}}` 而不是 `{"ui": ...}`，宿主只更新对应 notifier —— **不重建任何 widget，不遍历 element，只有绑定的叶子的 RenderObject 被标脏**。

一张形状固定、数字在动的卡片，一次刷新因此是几百字节和 O(变化的值)，而不是整棵树。这也是 Flutter 开发者手写这种界面时的做法：给会变的值一个 notifier，而不是对整页 `setState`。

#### 列表：用 `ListView.builder`，不要materialize

`list` 可以声明 `count`（总行数）和 `from`（已提供的第一行的下标），只携带一段窗口。宿主用 `ListView.builder` 渲染，滚动越界时通过 `listWindow` 导出向插件要更多。几百行的进程页因此只构建屏幕上的十几个 widget。

**这个回调发生在滚动过程中**，所以必须是异步加占位行；同步进插件会让一个慢插件卡住滚动。不声明 `count` 时，给出的行就是全部，这在几十行以内是对的，几百行时不对。

行必须带 key，理由见 5.1。

#### 宿主侧还可以做、不改协议的

- `card` 和每个列表行外面包 `RepaintBoundary`，隔离重绘。
- 叶子节点做规范化缓存：属性相同的 `text` / `kv` 返回同一个 Widget 实例，同样命中那条快路径，即使没有 `v`。
- 不要在 UI isolate 上 `jsonDecode` 整棵树。更好的做法是根本不产生 JSON —— FRB 可以直接返回类型化的 Dart 对象。递归结构 FRB 支不支持尚未验证，第十节第 2 步要确认。

#### 为什么现在做

今天一张 BMC 卡片约两百个节点、一分钟刷新一次，直接重发整棵树也看不出来。但 5.1 的节点格式是永久接口：`v`、值绑定和窗口式 `list` 都改变节点的形状，等有插件发布之后再加，已发布的插件都用不上。这是接口形状的决定，不是当前性能的决定。

三者都是可选的：不使用它们的插件行为和以前一样，而 `v` 由 SDK 自动填写，作者本来就不需要知道它存在。

### 5.3 界面显示在哪里

支持四种 surface：`page` 是功能栏按钮打开的页面，`card` 是服务器详情卡片，`tab` 是首页标签页，`settings` 是设置页中的一段。宿主为每个区域保存当前控件树。

服务器编辑器使用另一种更简单的方式：插件在 `config.fields` 声明字段，App 用统一的表单控件显示。字段支持 `text`、`password`、`bool`、`int`、`select`，并可声明 `label`、`secret`、`role: address`、`options` 或 `options_from`。跨字段检查交给 `validateConfig`。

`contributes.card.requires_config` 和 `contributes.page.requires_config` 表示“这台服务器配置了该插件才显示”。`options_from` 表示下拉选项由 `configOptions(key)` 提供。

配置字段由宿主管理，插件不直接写它们。插件自己生成的数据，例如用户确认过的 BMC 证书指纹，放在自己的存储里。

### 5.4 作者怎么写和测试

SDK（`packages/plugin-api`）提供控件构造函数和类型定义，作者不必手写 JSON。用 TypeScript 写时，`sb` 的接口、控件属性和事件消息都有类型；用 JavaScript 写时，同一份声明供编辑器提示。`satisfies Plugin` 可以让导出签名被检查，而插件本身仍然是一个模块。

插件逻辑可以在 bun 里直接用测试框架跑：`MockHost`（`@serverbox/plugin-api/test`）装到 `globalThis.sb` 上，按脚本回答 HTTP、对话框、存储和命令执行，并记录插件问了什么。不需要启动 App，也不需要 QuickJS。

模拟宿主复制了真实宿主的两条拒绝规则，否则插件会在测试里通过、在设备上失败：没有 `pinSha256` 也没有 `probeCert` 的请求不发出；带 body 或 header 的证书探测被拒绝。`denied` 选项让 manifest 没申请的权限按真实方式抛出。

按 WebAssembly 方案实现的 `plugins/bmc/tests/` 已经用这种方式覆盖过发现设备、登录、轮询、电源操作与确认、证书复核和账号增删。改写为 TypeScript 时，这些用例和 `packages/redfish/test/` 的 fixture 一起作为依据。

### 5.5 宿主侧如何验收

Flutter 渲染器需要为每种控件准备 JSON 输入和 golden 截图，检查显示效果、主题和后续兼容性。这部分尚未实现。

还需要一组端到端测试：在真实的 QuickJS 上下文里加载一个插件，跑完一次完整交互，确认导出调用、权限拒绝和资源限制都按设计生效。另外增加 `test/plugin_isolation_test.dart`，检查插件专属逻辑是否散落到通用 App 代码中。插件自己的单元测试不能替代这些。

### 5.6 界面的限制

BMC 样本已经促使设计增加了 `tone`、`requires_config`、`options_from`、`probeCert` 和响应中的 `cert`。更复杂的插件还会提出新需求。

目前的控件描述不能完整表达 App 已有的下拉刷新、侧滑、长按菜单、过滤搜索和图表 tooltip 等交互。每增加一种能力，都要长期维护兼容性。这是让内置功能继续使用 Dart、暂缓开放 UI 插件的主要原因。

### 5.7 考虑过的其他界面方案

| 方案 | 没有采用的原因 |
|---|---|
| Remote Flutter Widgets（`rfw`） | 作者需要另外学习控件描述 DSL 和数据绑定规则 |
| Dioxus mutation 协议 | 宿主还要维护节点 id 和逐条变更；目前先让 Flutter 处理整棵树更新 |
| 插件内自绘，如 egui 一类 | 难以沿用 App 控件外观、无障碍和文字选择，还要持续跨 FFI 传帧 |
| WebView | Linux 桌面依赖和统一外观增加维护成本，也不能消除商店政策问题 |

## 六、权限怎么管

### 6.1 插件需要声明什么

| 权限 | 允许做什么 |
|---|---|
| `server.exec` | 在宿主授权的服务器上执行命令 |
| `server.stream` | 通过该服务器的 SSH 连接建立 TCP 连接，供 `sb.http.fetch` 的 `via: "ssh"` 使用 |
| `net.http: [pattern]` | 访问匹配的 HTTP 目标；pattern 可用 glob，也可用 `$config.<key>` 引用 `role: address` 配置 |
| `ui.dialog` | 弹出对话框并等待输入 |
| `clipboard` | 读写剪贴板 |
| `storage.sync` | 让插件自己的键值数据参与备份同步 |

读写自己的存储、读取配置、更新自己的界面、让用户选服务器、显示提示、日志和导航，不需要额外申请权限。这不表示插件能访问其他插件的数据。

### 6.2 宿主如何执行限制

建上下文、装入 `sb` 时，未授权的函数装成直接抛 `PermissionDenied` 的替身，错误信息说明缺哪一项权限。判断只在这一刻做，调用路径上没有分支。涉及具体地址和服务器的请求，还要检查调用参数是否在授权范围内。

**插件不能靠 `catch` 绕过拒绝。** JavaScript 没有不可捕获的抛出，所以这一条由宿主执行：发生拒绝时记在实例上，那次调用结束后宿主无论插件返回了什么都判为失败。少了这条，一个没拿到 `ui.dialog` 的插件可以吞掉错误，继续执行那个对话框本来要确认的电源操作 —— 机器就在没确认的情况下关机了。一次被拒的调用不会让实例作废，下一次调用正常。

服务器句柄由宿主发放。插件不能获得 App 保存的 SSH 密码等凭据，也不能用自行构造的句柄访问其他服务器。

**插件不能修改服务器记录。** 这不是一条要靠实现记住的规则：`sb` 上没有任何函数写服务器。`sb.store.set` 写的是插件自己的键值空间；某台服务器上的插件配置由编辑器按 manifest 声明的表单写入，插件只能通过 `sb.config.get` 读。碰到服务器的两个函数一个是执行命令、一个是打开它的页面，都不改它。

这一条由 `permission_scope.rs` 的一个测试固定住，因为它会以「后来为了某个局部理由加了一个写接口」的方式丢失 —— 那样要先删掉那个测试，是一件需要争论的事，而不是一件会被忽略的事。

安装页面计划列出每个插件请求的权限，用户同意后才启用。更新增加权限时，需要重新取得同意。F-Droid 构建首次开启在线仓库时，还要说明下载的插件未经过 F-Droid 检查。

## 七、配置和数据存在哪里

数据库由 App 管理。插件不创建自己的表或数据库 migration，而是使用下面三张计划新增的通用表：

- `plugin_install`：安装版本、来源、启用状态和已同意的权限。
- `server_plugin_cfg`：每台服务器上的插件配置。
- `plugin_kv`：插件自己的键值数据，可按服务器保存，也可全局保存。

已实现（m022，schema v22 → v23）。Drift 的定义在 `lib/data/store/db.dart`，手写的 DDL 在 `lib/data/store/migrations/m022_plugin_tables.dart`，两者由 `test/plugin_store_test.dart` 的 migration 组比对 —— `tables_schema_test.dart` 只见得到全新创建的 schema，永远跑不到那一步。

与原草案的**一处偏离**：`plugin_kv` 拆成了两张表。草案里 `server_id` 可空且属于主键，这在 SQLite 里做不到 —— `WITHOUT ROWID` 表拒绝主键列为 NULL；而普通 rowid 表又不会拒绝第二条同 key 的全局行，因为 SQLite 认为两个 NULL 互不相同。也就是说，唯一能表达"全局"的形状，同时也是唯一没有唯一性约束的形状。拆开之后两半都有诚实的主键，按服务器的那一半还能跟着服务器级联删除。

原草案：

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

配置用 JSON 保存，因为宿主不需要按内部字段查询。`cfg_ver` 已定：存的是**写入这一行时 manifest 声明的 `abi`**。宿主是这张表唯一的写入者，也是这一列唯一的写入者 —— 插件无法转换自己的配置，因为它根本写不了这张表。这个数字留给将来**宿主侧**的转换：那是这种步骤唯一需要分支的依据，而且只有写入的那一刻知道。目前没有任何转换：manifest 里已不存在的字段在读取时被忽略，新增字段取 `default`，这两件事编辑器读 `config.fields` 时本来就会做。秘密字段沿用现有整库加密保护，分享时按 `secret` 标记移除。服务器配置更新时，要像 `container_host` 一样更新父行 stamp。

`plugin_kv` 提供持久化存储。实例内的临时状态用普通 JavaScript 变量即可，但实例销毁后不保留。键值数据默认留在本机，声明并获准 `storage.sync` 后，按插件 id 作为独立同步项处理。备份计划在 `BackupV2` 中增加通用的 `plugins: {id: {cfg: [...], kv: [...]}}` 字段。

卸载时删除插件文件、安装记录并撤销权限，是否保留配置和数据由用户选择。删除服务器时，它关联的插件配置和数据一并清理。

按钮、卡片和 tab 的排列按稳定 id 保存。安装时追加标记为 `defaultOn` 的入口，卸载时移除，读取时忽略无人认领的 id。这也替代原来的 `introducedAfterBuild` 处理。

迁移分两部分：

- ~~Dart registry 的迁移~~：已完成。`serverBtns` 由 enum index 迁到 id（m021），旧顺序冻结在 `legacy_adapters.dart` 的 `kLegacyServerFuncBtnIds` —— 用它而不是 `ServerFuncBtn.values` 转换，是因为"声明顺序从此可以随便改"正是这一步要换来的东西。`Backup.merge`/`BackupV2.merge` 也会跑它：恢复不经过 schema migrator，而那时版本号早已越过这一步。
- BMC 的迁移：交付插件时，将 `bmc_addr`、`bmc_cred_id`、`bmc_cert_sha256` 迁入配置表和键值表。旧列保留一个版本后，按 m017 的 create-copy-drop-rename 方式删除；现有 Hive 迁移 fixture 需继续通过。PVE 留在 Dart，`pve_*` 列不迁移。

## 八、怎么下载、安装和更新

### 8.1 插件仓库

计划新建 `lollipopkit/serverbox-plugins`，独立维护，不作为 submodule。GitHub Releases 发布 `index.json` 和 Ed25519 签名 `index.json.sig`，官方公钥编进 App。

验证沿用 `RootfsManifestTrust` 的规则：先对下载的原始字节验签，再解析；检查 serial 防止退回旧索引；检查 `valid_until` 防止使用过期索引。

索引记录插件的 `id`、`version`、`abi`、`sha256`、`size`、`url`、`permissions`、本地化名称与描述、`license` 和 `source_url`。官方仓库只收自由开源插件。添加第三方仓库时，用户需要提供 URL 和公钥指纹，并核对指纹。

### 8.2 安装流程和本地开发

安装时下载 `.sbp`，校验 SHA-256，解压到 `Paths.doc/plugins/<id>/<version>/`，把 `plugin.js` 载入一个一次性上下文以确认语法和导出可用，再写安装记录。中间失败则回滚本次安装目录。

随包插件放在 `assets/plugins/*.sbp`，首次启动时安装，来源记为 `repo = NULL`。这样离线或关闭在线仓库时仍有可用版本；联网后可以安装仓库中的更新。更新检查沿用 `RootfsManifestSource.refresh` 的节奏，新增权限必须先经用户同意。

桌面版计划支持直接加载本地开发目录，不要求打包或签名，来源记为 `repo = 'dev'`，并在页面中明确标记。BMC 接入期间也用它对比 Dart 和插件两份实现。

SDK README 将列出 ABI 与 App 版本的对应关系。App 拒绝加载 ABI 高于自身支持版本的插件，仓库为不同 ABI 保留兼容版本。

### 8.3 App Store 和 F-Droid

App Store 构建的既定方案是默认开启在线仓库，但这不代表已经确认能通过审核。设计依据是 Review Guidelines 4.7 对非内嵌 plug-ins 的规定，还需要处理逐插件同意、带 universal link 的插件索引，以及不得暴露原生平台 API 等要求。ServerBox 的宿主函数是否符合相关边界，仍有审核不确定性；解释执行本身不能保证避开 2.5.2，改用 JavaScript 也不改变这一点。

计划用 `website/` 为每个插件生成介绍页。保留构建开关 `SBM_PLUGIN_REPO`：必要时可关闭在线仓库，只保留随包插件；届时无法在线安装和更新。

F-Droid 构建的在线仓库默认关闭。用户主动开启前，需要说明下载的插件绕过了 F-Droid 的检查。官方仓库只收自由开源插件，以避免推广非自由附加组件对应的 `NonFreeAddons` 问题。发布前仍需核对当时政策。

## 九、第一批做状态命令插件

这类插件用于增加 ZFS pool、UPS/NUT、smartctl 字段或厂商传感器等状态指标。现在增加这些指标通常要修改 `sbm_parser` 并提交 PR，插件可以让作者独立扩展。

它使用同一个运行时，但只提供两个导出，在 manifest 的 `contributes.status` 中声明：

| 导出 | 输入 | 输出 |
|---|---|---|
| `statusCmd(platform)` | 目标系统 | `{cmd}`，要执行的采集命令 |
| `parse(text)` | 命令输出 | `StatusResult` |

`StatusResult` 是一个固定的小形状，不是控件树：一个标题、若干条 `{label, value, percent?, tone?}`、一条可选说明。App 用画自己指标的同一套控件来画它。这正是它能在第五节的词汇表定稿之前发布的原因，也是一个坏的状态插件最坏后果只是一个数字不对的原因。

结果由 `crates/sbm_plugin/src/status.rs` 校验，而不是交给 Dart 解释一段 JSON —— 理由和 manifest 一样：只有一个解析器，而插件的输出是不可信的。能修剪的就修剪（超长标签截断、越界的 `percent` 丢弃而不是钳制、空行去掉、最多 64 条），只有整体形状不对才拒绝。一条坏数据的代价是少一行，不是一张画不出来的卡片。

### 9.1 命令怎么执行

**不进状态脚本。** 状态脚本每隔几秒跑一次，是热路径；把插件的命令编进去意味着每次轮询的耗时和失败模式都不再有上界。脚本本身也是上传到服务器复用的，编进去还意味着装一个插件就要重传。

所以插件的命令由 App 单独执行（`ServerNotifier.ensureExec`），节奏可以比状态轮询慢，和 `EXTENDED` 那批是同一个道理。服务器上不留文件。

用户的自定义命令已经按同样的方式改过：它们现在是脚本里的一个独立函数 `SbCustom`，由 App 按 `Stores.setting.customCmdInterval` 单独触发，缓存上一次的输出在中间的轮询里重放（`_customRaw`）。插件的命令照搬这套节奏与缓存的做法，但不共用它的目录 —— 那个目录是用户的数据，插件的命令来自插件。

多个插件合并成一次往返：`sbm_parser::script::inline_cmds_script` 生成一条命令，逐个跑完所有插件的采集命令。每条的超时、输出上限、临时输出文件都和自定义命令共用同一段 shell（`sb_cmd`/`SbCmd`），因为那四条 fallback 路径是最容易重写错的部分。命令 base64 内联，写进临时文件、跑完即删。

输出用自己的分隔符 `SrvBoxPluginSep`，不与用户自定义命令的 `SrvBoxCusCmdSep` 共用：两边都是宿主没写的文本，共用一个命名空间会让一边取对名字就能顶掉另一边的读数。

### 9.2 边界

「插件不直接执行命令」不等于「没有执行风险」：`statusCmd` 返回的命令仍要由宿主执行，且它来自插件而不是用户。

**信任边界落在 `server.exec` 上。** 声明了 `contributes.status` 的 manifest 必须同时申请 `server.exec`，否则解析阶段就拒绝 —— 那条权限的含义正是"在你的服务器上执行命令"，于是这类插件通过已有的安装对话框和权限列表出现在用户面前，而不是靠某个人记得再加一处披露。安装页展示的命令来自 `statusCmd` 本身（`PluginRuntime.statusCmd`），和运行时用的是同一次调用的同一个值，所以"给用户看的"和"实际执行的"不会因为问了两次而不一致。

仍未解决的是运行时命令变化：`statusCmd` 在配置改变后会返回不同的命令，这是正常的（比如换了一个 pool 名），但也意味着安装时看到的那条不是永久承诺。可选做法是按 SSH host key 的同一套 trust-on-first-use：记住每台服务器上次跑的命令，变了就先让用户看过再跑。这条留到第 5 步和插件卡片一起定。

App Store 对这种扩展的判断也不能仅凭它没有 UI 就下结论。

## 十、接下来按什么顺序做

每一步单独提交 PR，并验证该步的实际效果。第 1 步的 WebAssembly 版本已经实现过一次，改用 JavaScript 后需要重做；第 6 步 BMC 的解析逻辑和测试用例可以从那份实现里搬。

| 顺序 | 工作 | 当前状态与验收重点 |
|---|---|---|
| 1 | QuickJS 运行时、`sb` 接口注入、权限检查、manifest 解析，以及 TypeScript SDK | **已完成**。运行时 81 个测试（权限拒绝、接口表一致性、异步、资源限制、实例线程），SDK 45 个测试（控件、l10n、帧裁剪、模拟宿主） |
| 2 | `sbm_ffi` 暴露加载、调用和释放，Dart 实现宿主回调 | **已完成**。`PluginBridge` 实现 14 个接口的协议侧（`sb.http.fetch` 除外，见下），`PluginRuntimeService` 持有运行时并把请求流接到它上面。`test/plugin_bridge_test.dart` 21 个、`test/plugin_runtime_service_test.dart` 6 个（真 QuickJS 上下文）、`test/plugin_ffi_test.dart` 21 个 |
| 3 | 接入状态命令插件，随包提供一个样本 | 进行中。`StatusResult` 的形状与校验、`contributes.status`（含必须申请 `server.exec`）、`inline_cmds_script`（一次往返跑完所有插件命令、服务器上不留文件）、`PluginRuntime.statusCmd`/`statusParse`、SDK 的状态插件类型和样例都已完成，Rust 侧 121 个测试 + `test/plugin_ffi_test.dart` 打通「插件要什么命令 → 真跑一遍 → 结果回到同一个插件」。剩下的要等第 5 步的插件存储：App 得先知道装了哪些插件，才谈得上在状态页画出来 |
| 4 | Dart feature registry 和按钮 id 迁移 | **已完成**。`lib/data/model/app/feature.dart`：`Feature`/`FeatureSlot`/`Features`，三个入口面（功能栏按钮、详情卡片、首页 tab）合并成一个 id 空间和一份"这次升级新增了什么"的规则。`serverBtns` 由 enum index 迁到 id（m021，`kLegacyServerFuncBtnIds` 冻结旧顺序），恢复备份时也会转换 |
| 5 | Flutter 渲染器、插件卡片、存储、备份、安装管理和开发目录 | 进行中。**存储已完成**（四张表 m022 + 三个 store，23 个测试）；**渲染器已完成**（22 种控件、5.2 的三项、l10n、错误节点，24 个测试）。剩下插件卡片和其余 surface、`BackupV2` 的 `plugins` 字段、安装管理、开发目录，以及 5.5 的 golden 截图 |
| 6 | 在 App 中接通 BMC 插件 | 未开始；对照 `packages/redfish/test/` 的 fixture 和现有行为，验证一致后再删除 Dart 实现及 `packages/redfish` |
| 7 | 在线仓库、第三方仓库和网站插件页 | 未开始；先只收状态插件，BMC 验证完 UI 接口后再开放 UI 插件 |

命名子区域的表示方式（见 5.1）、`Intl` 是否编入引擎（见 3.5）、内存和时间上限的具体数值（见 4.4），都要在 UI 插件正式开放前定下来。

## 十一、主要代价和未决问题

最需要控制的是 UI 接口的范围。控件太少，插件做不出需要的界面；不断增加控件和属性，又会形成一套需要长期兼容的界面框架。BMC 只能验证简单卡片，长列表、复杂表格和流式输出仍缺少样本。

其他需要继续验证的事项：

- **宿主回调的实现**：FFI 已通，但 14 个接口在 Dart 侧还只有测试里的假实现。接到 `ServerNotifier.ensureExec`、SSH 转发、证书校验、对话框和存储上是第 5 步的主要工作量。
- **性能与资源**：解释执行比原生慢；开发机上的解析耗时见 3.3，移动端真机没有量过。内存和时间上限的数值待定，计量精度也比 WASM 的 fuel 粗。5.2 的裁剪、值绑定和窗口式列表已在 SDK 侧实现，宿主侧的复用缓存、`ValueListenableBuilder` 和 `ListView.builder` 尚未实现，实际收益要接入后测量。
- **构建依赖**：QuickJS 是 C 源码，iOS 和 Android 没有预生成 bindings，构建环境需要 libclang 和正确的 sysroot。这部分要写进 `hook/build.dart` 并在五个平台的 CI 上验证。
- **语言支持范围**：抽查的 19 项见 3.5，完整 test262 没有跑过。`Intl` 缺失影响日期和数字的本地化，处理方式待定。
- **供应链**：插件可以打包 npm 依赖，一个插件里可能含有大量第三方代码。审核方式和 `.sbp` 的体积上限需要定。
- **调试和兼容**：错误可能跨 Dart、FFI 和 JavaScript；发布后的导出名、`sb` 接口和节点属性都要维护兼容。SDK 测试和日志只能覆盖其中一部分。
- **数据接入**：数据库表仍是草案，配置升级由谁写入、备份同步和卸载保留行为需要在宿主实现中落实。
- ~~**自定义命令目前在状态脚本里**~~：已改。现在是独立的 `SbCustom` 函数，周期可配置并按状态轮询间隔向上取整；保存改成 compare-and-swap，读取不再回退到 `.bak`。功能保留，没有去掉。插件的状态命令仍不建立在它之上（见 9.1）。
- **两套注册方式**：内置功能用 Dart registry，第三方用 manifest，需要避免相同入口逐渐出现不同的行为。
- **测试覆盖**：注册表不像 exhaustive switch 那样由编译器检查所有分支，需要集成测试检查漏注册、迁移和入口显示。
- **平台政策**：在线分发仍有商店审核不确定性。

## 十二、参考项目

| 项目 | 本设计参考的部分 |
|---|---|
| [ruxlet](https://github.com/mikolajbadyl/ruxlet) | Rust 返回界面描述、Flutter 渲染、事件回传，以及用稳定 key 保留控件状态；不复用其桌面动态库加载方式 |
| [Crux](https://github.com/redbadger/crux) | 在测试中模拟宿主响应，让插件逻辑脱离 App 运行；未采用 effect / resolve 调用模型 |
| [Zed extensions](https://zed.dev/blog/zed-decoded-extensions) | SDK 包装接口、独立仓库、开发目录加载和版本兼容表；未采用其 wasmtime + component model 运行方案 |
| [quickjs-ng](https://github.com/quickjs-ng/quickjs)、[rquickjs](https://github.com/DelSkayn/rquickjs) | 当前使用的引擎和 Rust 绑定 |
| [Zellij](https://github.com/zellij-org/zellij/pull/4449) | 评估 WebAssembly 方案时参考过它的运行时选型、固定线程实例和内存限制；本项目最终未用 WASM |
| [Dioxus](https://docs.rs/dioxus-core/latest/dioxus_core/trait.WriteMutations.html) | 评估过逐条界面变更协议，目前未采用 |
| [rfw](https://pub.dev/packages/rfw) | 评估过远程控件格式，保留用 golden 检查控件兼容性的思路 |
| [Rinf](https://github.com/cunarist/rinf)、[Oxide](https://github.com/oxide-stack/oxide) | Rust 保存状态、Flutter 消费快照的分工；它们不解决插件沙箱和在线分发 |
| [frui](https://github.com/fruiframework/frui)、[Xilem / Masonry](https://github.com/linebender/xilem)、Freya | 评估过 Rust 自绘界面；本项目继续使用 Flutter 控件，因此未采用 |

## 参考

- [quickjs-ng](https://github.com/quickjs-ng/quickjs) · [rquickjs](https://docs.rs/rquickjs/) · [test262](https://github.com/tc39/test262)
- 评估 WebAssembly 方案时用到的资料：[Wasmi 2.0 发布](https://wasmi-labs.github.io/blog/posts/wasmi-v2.0/) · [Zellij 从 wasmtime 迁到 wasmi（PR #4449）](https://github.com/zellij-org/zellij/pull/4449) · [wasmtime Pulley 在 iOS（#12251）](https://github.com/bytecodealliance/wasmtime/issues/12251) · [wasmtime 支持层级](https://docs.wasmtime.dev/stability-tiers.html) · [Extism PDK](https://extism.org/docs/concepts/pdk/)
- [ruxlet](https://docs.rs/ruxlet/latest/ruxlet/) · [Crux 的 managed effects](https://redbadger.github.io/crux/part-2/effects.html) · [Zed 扩展的构建与分发](https://zed.dev/blog/zed-decoded-extensions) · [rfw](https://pub.dev/packages/rfw)
- [App Store Review Guidelines 4.7](https://developer.apple.com/app-store/review/guidelines/#4.7) · [F-Droid 收录政策](https://f-droid.org/docs/Inclusion_Policy/) · [F-Droid Anti-Features](https://f-droid.org/docs/Anti-Features/)
- [Dart / WebAssembly 编译](https://dart.dev/web/wasm) · [`wasm_run`](https://pub.dev/packages/wasm_run)
- [Fixing Section 2.5.2](https://saagarjha.com/blog/2020/11/08/fixing-section-2-5-2/) · [Guideline 2.5.2 被拒案例](https://ptkd.com/journal/guideline-2-5-2-downloading-scripts-without-review)
