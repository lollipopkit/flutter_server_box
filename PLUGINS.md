# 插件系统 — 调研

状态：**调研，未开工**。结论是「先不要从 runtime 开始」，理由在下面。

题目：把 PVE 之类的功能做成可热加载的插件，例如 WASM。

---

## 一、PVE 实际需要什么

不是「解析一段 JSON」。读 `lib/data/provider/pve.dart`：

| 它做的事 | 需要宿主给什么 |
|---|---|
| 开一条 SSH 端口转发（`SSHForwardChannel` + 本地 `ServerSocket.bind`）—— PVE 的 API 通常不对公网开放 | 一条字节流，以及 `genClient` 那一整套（直连 / jump / ProxyCommand） |
| 登录，并处理 **2FA challenge**（`_pendingTfaChallenge`） | 一个能弹对话框、拿到用户输入再回来的通道 |
| 持一个 Dio session，可选 `badCertificateCallback` 忽略证书 | HTTP 客户端 + 一个安全策略的例外 |
| 按共享的刷新间隔轮询 | 定时器和生命周期（前后台、连接状态） |
| 画图表、每个 node / guest 一张卡片，卡片上有操作 | Flutter widget |

PVE 自己三个文件约 **1700 行**，此外还嵌在：

```
lib/data/store/db.dart            server 表上的列
lib/data/store/server.dart
lib/data/store/migrations/m004    schema 历史里两处
lib/data/store/migrations/m017
lib/data/model/server/custom.dart
lib/data/model/server/server_private_info.dart
lib/data/provider/server/all.dart
lib/data/provider/server/monitor_http.dart
lib/view/page/server/edit/*       编辑器里的字段
lib/view/page/server/detail/view.dart
lib/data/model/app/server_detail_card.dart   详情页的一张卡
lib/data/model/app/error.dart     它自己的错误类型
```

**这 15 个文件才是插件 API 的真实规模。** 一个 WASM 模块能接手的部分 —— 把响应变成类型化的模型 —— 大概 200 行。

---

## 二、硬约束

### UI 问题

**WASM 模块画不出 Flutter widget。** 三条出路，都有代价：

| 出路 | 代价 |
|---|---|
| 插件只出数据，宿主画 | 宿主仍然得知道什么是 node、什么是 guest —— 模型留在 app 里，插件只剩解析 |
| 插件返回一份 UI 描述，宿主渲染（server-driven UI） | 等于**再发明一门 widget 语言**，要设计、写文档、做版本、做安全。它会变成这个 app 真正的对外 API |
| 插件根本不做 UI，只是一个数据源，UI 是通用的 | 能做，但那就不是「PVE 插件」了 |

---

## 三、可选方案

| 方案 | iOS 能跑 | 进得了 F-Droid | 能画 UI | 备注 |
|---|---|---|---|---|
| `wasmi` 编进 `sbm_ffi`，插件随包 | 是（解释器） | 是 | 否 | 和现有 Rust workspace 天然契合 |
| 同上但插件可下载 | 灰色（2.5.2） | anti-feature | 否 | 需要一个插件仓库 + 签名 |
| `wasmtime` | **否**（JIT） | 是 | 否 | 直接出局 |
| [`wasm_run`](https://pub.dev/packages/wasm_run) 包 | 可能 | 引入第二套工具链 | 否 | 已停更，仍钉在 wasmtime 14 / wasmi 0.31 |
| [Extism](https://github.com/extism/extism) | **否** | — | 否 | Rust SDK 基于 wasmtime；官方给移动端的答案是 Android 上用 Chicory |
| QuickJS / JS 解释器 | 是 | 随包则是 | 否 | 唯一有 App Store 明文例外的语言 |
| Lua | 是 | 是 | 否 | 最小的实现代价 |
| 在以上任意一种之上做声明式 UI | 是 | 是 | 勉强 | **代价最高的一项** |
| 用 Dart 写插件编译成 WASM | **否** | — | — | dart2wasm 的产物只面向 JS 宿主，跑不进 wasmtime/wasmi（[dart-lang#53884](https://github.com/dart-lang/sdk/issues/53884)） |

最后一行值得单独强调：**插件不能用 Dart 写。**

---

## 四、这个仓库已经有的 seam

好消息是骨架都在，而且都是为了别的原因先长出来的：

- `ServerExec` —— 「跑这条命令，告诉我它说了什么」。已经同时覆盖 SSH 和 monitor 的 `/exec`。
- `FileBackend` / `SshCredential.fileTransport` —— 一个后端换掉另一个，调用方不知道。
- `ServerCapabilities` / `UnionCapabilities` —— 「这台机器能做什么」已经是被询问的，而不是被 if 出来的。
- `crates/sbm_parser` —— 命令清单和解析已经是纯函数、已经是唯一真相、已经被 `tests/dart_compat.rs` 锁住。
- `crates/sbm_ffi` —— 已经是 flutter_rust_bridge crate，由 `hook/build.dart` 构建。**加 `wasmi` 进去不需要新插件、不需要 podspec（CocoaPods 已经移除）、五个平台一份构建脚本。**

所以第一个插件面**不该是 PVE**，而应该是 `sbm_parser` 的命令清单：一个插件贡献**一条命令和一个解析器** —— 字节进、类型化计数出。这正是 WASM 擅长的形状，不需要 UI、不需要网络、不需要凭据，而且宿主已经有地方放结果（`ServerStatus`、详情页的卡片）。

---

## 五、风险

- **插件 API 是永久的。** 一旦存在，它命名的每一个 seam 都变成公开契约。这个仓库已经因为「一个 store 的主键用了用户输入的名字」付过一次代价。
- **WASM 沙箱隔离的是内存，不是能力。** 一个拿到 `ServerExec` 的插件，就拿到了用户服务器上的 root。所以**授权清单才是真正的设计**，而不是 runtime 的选择。
  - 已有两处可以直接当先例：monitor agent 的 `full_access` grant（在 `config.toml` 里，默认全关），以及 watch token 的「作用域由路由表定义、由 `monitor/tests/watch_token_scope.rs` 挂真 router 锁住」。
- **第二门 UI 语言的维护成本。** 声明式 UI 那条路一旦走上，它就是 app 的对外 API，改一次要考虑所有已发布的插件。

---

## 参考

- [Dart / WebAssembly 编译](https://dart.dev/web/wasm) · [Flutter Wasm 支持](https://docs.flutter.dev/platform-integration/web/wasm)
- [`wasm_run`](https://github.com/juancastillo0/wasm_run) · [pub](https://pub.dev/packages/wasm_run)
- [Extism](https://github.com/extism/extism) · [crates.io](https://crates.io/crates/extism)
- [Fixing Section 2.5.2](https://saagarjha.com/blog/2020/11/08/fixing-section-2-5-2/) · [Guideline 2.5.2 被拒案例](https://ptkd.com/journal/guideline-2-5-2-downloading-scripts-without-review)
