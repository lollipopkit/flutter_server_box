# TODOs / 后续方向

不在排期内的想法和已知缺口,先记在这里,免得丢了。

## ServerBox 作为 MCP server:把内置 Agent 的工具借给本机的 CLI agent

想法:app 启动时在本机起一个 MCP server,把 `globalAgentToolDefinitions` 那六个工具
(`run_shell_command`、`read_file`、`write_file`、`ssh_connect`、`ssh_disconnect`、
`serverbox`)暴露出去,再把它配置进本机终端里的 Claude Code / Codex / agents,并附一套
skills。这样在终端里干活的 agent 不用自己配 SSH,就能用 app 已经配好的服务器。

**可行**,而且大部分是现成的:六个工具都从 `GlobalAgentToolService.execute` 一个入口走,
所以 MCP 那层只是换一种调用方式,不需要第二份实现。要新建的只有传输层 —— app 里目前
**没有任何 HTTP server**。

### 三部分,按风险从低到高

1. **server 本身。** `dart:io` 的 `HttpServer` 绑 `127.0.0.1`,streamable HTTP 传输,
   默认关闭。协议面很小:`initialize` / `tools/list` / `tools/call`。macOS 三个
   entitlement 文件都已经有 `com.apple.security.network.server`,所以连沙盒版都能监听。
   端口固定 + 占用时递增,选中的端口和 token 写在一处让客户端能读到。
   鉴权用 bearer token,每次安装生成一个,存 `SecureStore`。

2. **审批闸门 —— 这条是这个功能的成败所在。** 内置 Agent 有一整套风险分级和
   `canAutoRun`,非只读命令要用户点头。MCP 客户端如果绕过它,就等于本机任何进程都能在
   你所有服务器上执行任意命令。所以:MCP 来的调用**一律**走同一个审批 UI,而且比内置
   Agent 更严 —— 连 `readOnly` 也不自动跑,除非用户按工具单独放开;界面上要能看出
   当前是外部客户端在驱动。

3. **写客户端配置 + skills。** Claude Code 的 `mcpServers`、Codex 的
   `[mcp_servers.serverbox]`、`~/.agents/skills` 下的 skill 文件。合并而不是覆盖,
   原子写 + 备份(照 `monitor/src/core/config_file.rs` 的做法),而且必须是用户点按钮
   触发,不能开机自己改人家的配置文件。

### 已查清(2026-08,spec 版本 `2026-07-28`)

- **两个客户端都支持 Streamable HTTP,所以不需要 stdio 桥,也不需要多打一个二进制。**
  - Codex:`mcp_servers.<id>.url` + `bearer_token_env_var` + `http_headers`。token 走
    **环境变量**,不落进配置文件 —— 比原先设想的干净。它还有
    `default_tools_approval_mode` 和 `tools.<tool>.approval_mode`,是客户端侧的第二道
    闸门(不能替代我们自己那道)。
  - Claude Code:`claude mcp add --transport http <name> <url> --header "Authorization:
    Bearer …"`,或者写进 `.mcp.json` / `~/.claude.json`,`"type": "http"`
    (`"streamable-http"` 是别名)。有个坑:条目有 `url` 但没有 `type` 会被当成 stdio
    server 而报错跳过。scope 三档:`local`(默认)/ `project` / `user`。
- **stdio 没有被废弃**,当前 spec 的两个标准传输就是 stdio 和 Streamable HTTP。被废弃的
  是 2024-11-05 那版的 HTTP+SSE(2025-03-26 起)。选 HTTP 的理由是进程模型 —— stdio 要
  客户端把 server fork 出来,而 app 是已经在跑的 GUI 进程。
- **`~/.agents/skills` 是跨 agent 的公共约定**,Codex / Cursor / Copilot / OpenCode 都读;
  Claude Code 读的是 `~/.claude/skills`,要单独放一份。格式是一个技能一个目录,里面
  `SKILL.md`,YAML frontmatter 至少 `name` + `description`,可选 `scripts/`、
  `references/`、`assets/`。加载是渐进的:启动只读 name/description,用到才读全文 ——
  所以 description 要写得能被选中。

### 还没定的一件事

**Dart 侧手写还是找现成的。** pubspec 里没有 mcp 依赖。`2026-07-28` 这版的协议面比过去
小:没有 `initialize` 握手(版本号按请求走 `_meta.io.modelcontextprotocol/protocolVersion`)、
server 不再发起 JSON-RPC 请求、Roots / Sampling / Logging 都已废弃。要实现的只有
`server/discover`、`tools/list`、`tools/call`。手写是可行的,但网上多数示例还是旧握手那
一套,照抄会写错。

### 已知的边界,先写下来免得当成 bug

- **macOS App Store 版写不了那些配置文件** —— 沙盒进程碰不到 `~/.claude.json` 和
  `~/.agents/skills`。它仍然可以监听端口,所以第 1、2 部分照常,第 3 部分只能给一段
  让用户自己粘的片段。DMG 版不受限。
- **iOS / Android 没有可配置的对象。** guest 里的 socket 就是宿主进程的 socket,所以
  端口理论上够得到,但那两个平台上没有 Claude Code 要配。先划在范围外。
- **token 落在明文配置文件里,本机任何进程都读得到。** 和 SSH agent socket 是同一类
  威胁模型,但这些工具够得到你**每一台**服务器,所以要明说,不能默认开。
- app 得开着。这不是一个后台服务。

## monitor:relay 模式(不强制暴露公网端口)

目前要从局域网外访问 `monitor` 面板,必须把 agent 的端口暴露到公网(端口转发/
反向代理/内网穿透)——对非技术用户是个门槛,对技术用户也是实打实的攻击面。

想法:做一个可选的"relay"模式——agent 把状态数据推送到官方(维护者)部署的
relay 服务,而不是(或者除了)在本地直接对外提供面板访问;面板改为访问 relay
而不是直连 agent,这样 agent 完全不需要开放任何入站端口。relay 侧的历史数据
上限 1 小时(只是转发/缓存,不做长期存储——完整历史仍然只能通过直连 agent
获取)。

待定问题(先记下来,不是结论):
- **鉴权/身份**:relay 需要一套独立于 agent 本地 JWT 登录的推送凭证(config.toml
  里加一个用户自己申请的 relay token,例如 `[relay] token = "..."`);面板这边
  "relay 上的哪个 agent"要怎么映射成一个服务器条目也需要单独设计 UX(大概率是
  在 `monitor/frontend/src/lib/servers.svelte.ts` 现有的直连 URL 条目旁边,加一种
  `relay://<id>` 风格的条目)
- **推 vs 拉的节奏问题**:relay 模式把数据流向倒过来了(agent 主动推,而不是
  面板轮询);现有的空闲暂停机制(`AppState.last_viewer_seen`,见
  monitor/CLAUDE.md)是靠面板直接轮询 `/metrics`/`/status` 来判断"有没有人在看"
  的——relay 模式下 agent 侧完全拿不到这个信号,除非 relay 再把"有人在看"的提示
  回传给 agent(这就多了一条控制通道,不只是数据通道了)
- **数据最小化**:是不是所有字段都要推(包括电池/传感器/SMART/主机名这些),
  还是应该让用户在 relay 模式下自己选择哪些字段不想经过 relay——哪怕 relay 是
  同一个维护者运营的官方服务
- **relay 自身的滥用/成本控制**:每个 agent 的限流、每个账号能同时推送的 agent
  数量上限、是做限量的免费版还是搞个付费版换更长的保留期——这是这个仓库里第一个
  需要维护者自己运营、自己掏钱的托管服务,和现有"纯自托管"的模式不一样
- **直连优先的混合兜底**:如果一个 agent 既能直连(同一局域网)又能走 relay,
  面板要不要自动优先直连,直连失败了才退回 relay 数据,避免非必要时依赖 relay
  (也省延迟)
- relay 是一个新的、独立部署的服务(不是 `monitor` 本身的一部分)——需要单独
  决定放哪个 crate/仓库、怎么部署、TLS/域名怎么搞,这和现在"每个 agent 一个
  单体二进制"的假设不一样,是本仓库目前唯一的例外

## sbm_ffi:脱离 CocoaPods,改走 Dart build hooks(已做,但只验过两个平台)

**状态(2026-08-19):已合入。** cargokit 五个接入点和整个 `cargokit/` 目录已删,
`crates/sbm_ffi` 不再是 Flutter plugin,改由根目录 `hook/build.dart` 编译。
FRB 升到 `2.13.0-beta.6`(Rust 与 pubspec 两处)。

已验证:macOS 与 iOS 构建通过,产物里有 `sbm_ffi.framework`,两个
`Podfile.lock` 里都只剩 `flutter_pty`。`flutter test test/frb_parser_test.dart`
与 `cargo test --workspace` 通过。

`flutter_pty` 也一起做了:`packages/flutter_pty` 是
[TerminalStudio/flutter_pty](https://github.com/TerminalStudio/flutter_pty) 的
fork,把同样的五个平台构建集成换成一个 `hook/build.dart`(用 `native_toolchain_c`)。
上游最后一个版本是 0.4.2(2025-01),没有 `Package.swift`,唯一那个 SwiftPM PR
(#21)只做了 macOS 且无人回应。

**结果:两个 `Podfile.lock` 里第三方 pod 归零**,只剩 Flutter 自身。
`flutter build` 现在会提示 "All plugins found are Swift Packages, but your
project still has CocoaPods integration"。

**未验证:Android / Linux / Windows。** 这三个平台原先分别走 cargokit 的
gradle plugin 和 CMake,现在改走同一个 hook,但本机没跑过。要在 CI 或对应机器上
各跑一次 `dart run fl_build -p <platform>`。

**下一步(现在才有可能做):彻底 deintegrate CocoaPods。** Flutter 列出的步骤是
`pod deintegrate` 加上从 `{ios,macos}/Flutter/*.xcconfig` 里移除 `Pods-Runner`
的 include。没做的原因:Podfile 因为 Watch app 和 widget extension 而是
non-standard,这两个 target 得单独验过。

两条注意事项:
- **不要用 `flutter_rust_bridge_codegen integrate`。** 它是给新项目的脚手架:
  在本仓库上跑会重新格式化 188 个文件、脚手架出一个新的 `rust/` crate、`hook/`、
  `test_driver/`,并且把 7 个 submodule 也一起格式化。`generate` 是安全的
  (它的 `dart fix` 只作用于生成目录,实测不外溢)。
- **FRB 2.13.0 至今只有 beta。** native-assets 后端要求 `>= 2.13.0-beta.2`,
  stable 仍停在 2.12.0。这是本项目目前唯一钉在 prerelease 上的依赖。

以下是当初的分析,留作记录。

## sbm_ffi:脱离 CocoaPods 的原分析

Flutter 3.44 起 SPM 是默认路径。SPM 本身已经生效——13 个 plugin 走的是生成的
`{ios,macos}/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`
——剩下的走 CocoaPods 回退。**回退里有两个 pod,不是一个**:`sbm_ffi` 和
`flutter_pty`(`~/.pub-cache/hosted/pub.dev/flutter_pty-0.4.2` 只有 podspec,
没有 `Package.swift`)。两个 `Podfile.lock` 的 `DEPENDENCIES` 都列着这两个。

时限不是 Flutter 定的:CocoaPods trunk 于 **2026-12-02 永久只读**,Flutter 声明
回退会在那之后移除,具体日期未定。

卡点:`crates/sbm_ffi/{ios,macos}/sbm_ffi.podspec` 靠 CocoaPods 的 `script_phase`
调 `cargokit/build_pod.sh` 编 Rust,再用 `-force_load` 链接 `libsbm_ffi.a`。
`Package.swift` 没有等价机制:
- SwiftPM build tool plugin 的 `prebuildCommand` 跑在 sandbox 里(profile 是
  `deny file-write*` 项目目录,只允许写 pluginWorkDirectory),cargo 写 `target/`
  和 `~/.cargo` 都会被拒;Xcode 没有传 `--disable-sandbox` 的入口
  (swift-package-manager#7121),`ENABLE_USER_SCRIPT_SANDBOXING=NO` 管的是
  Run Script phase,对 plugin sandbox 无效
- cargokit 上游已于 2026-03-26 归档,irondash/cargokit#106 提了这件事,无人跟进
- flutter_rust_bridge 的 SPM PR(fzyzcjy/flutter_rust_bridge#3315)未合并

**结论改为走 Dart build hooks**,不再等 SPM。原先记的"native assets 仍是实验
特性(`--enable-native-assets`)"已不成立:build hooks 自 **Flutter 3.38 /
Dart 3.10** 起 stable,无需任何 flag,本项目在 Flutter 3.47 / Dart 3.13。走 hooks
意味着 sbm_ffi 既不需要 podspec 也不需要 `Package.swift`,五个平台统一,
CocoaPods 那条时限对它不再适用。

做法:`flutter_rust_bridge_codegen integrate --integration-backend native-assets`
生成 `crates/sbm_ffi/hook/build.dart`(经 `flutter_rust_bridge_hooks` 调
`native_toolchain_rust`),删掉 cargokit 的 5 个接入点(`{ios,macos}` podspec、
`{linux,windows}/CMakeLists.txt`、`android/build.gradle`)和 `cargokit/` 目录,
`pubspec.yaml` 的五平台 `ffiPlugin: true` 声明随之去掉。另需新增
`rust-toolchain.toml`(该后端要求钉具体 toolchain + targets,仓库现在没有);
`crate-type = ["cdylib", "staticlib"]` 已经是对的。

**未解的两件事:**
- **后端只有 beta。** 要求 `flutter_rust_bridge_codegen >= 2.13.0-beta.2`,而
  2.13.0 至今无 stable(最新 `2.13.0-beta.6`),stable 仍是项目现钉的 2.12.0
  (`crates/sbm_ffi/Cargo.toml` 与 `pubspec.yaml` 两处)。要么接受 beta,要么等,
  而 12-02 在前面
- **`flutter_pty` 不在这条路上。** 它是普通 Flutter plugin 不是 FFI plugin,
  hooks 解决不了。sbm_ffi 迁完 Podfile 仍删不掉,除非上游支持 SPM 或本地 fork

被这条替代的旧路线(留作记录):预编译 xcframework + `.binaryTarget`。代价是在
Xcode 里直接 Run 不会重编 Rust,容易用到旧产物,还要维护打包脚本和 `-force_load`。
hooks 路线没有这些问题。

## monitor:cpu_core_metrics / velocity_metrics 是只写表

`monitor/src` 里没有任何 `SELECT ... FROM cpu_core_metrics` 或
`FROM velocity_metrics`——两张表只写不读。面板的每核数据来自 `/metrics` 的实时
`SystemMetrics.cpu_cores`,不是数据库。而 `cpu_core_metrics` 每周期每核一行,在
18 核机器上约占数据库总字节的 87%(每采样 3.9 KB,system_metrics +
velocity_metrics 合计只有 0.6 KB),外加三个索引,索引比表本身还大。

写入路径本身的正确性问题已修(见 `core_usage_percent`、store_metrics 的事务)。
剩下的是取舍问题,没有结论:
- 直接删表,把历史每核数据这个能力去掉;还是
- 补上读取接口(每核历史图表),让这份存储有用;还是
- 保留但降采样(例如只在扩展周期写一次,而不是每个核心周期)
`idx_cpu_core_metrics_server_core` 在任一方案下都没有对应的查询,先留着。

## 脚本 marker 协议:采用编码名,未采用 `SrvBoxData.` 逐行 framing

upstream `f647ce83` 对 marker 协议做了两层加固,本分支只取了第一层:

1. **marker 名 base64url 编码**(已采用)。marker 与命令输出共用一条流,原先
   任何以 `SrvBoxSep.` 开头的输出行都会被当成新 section。改为只认
   `SrvBoxSep.b64.<base64url>`,其余一律当数据。
2. **每行输出加 `SrvBoxData.` 前缀**(未采用)。实现方式是每条命令的输出管道
   接一次 `sed 's/^/SrvBoxData./'`,PowerShell 侧是逐行 `ForEach-Object`。

不采用第 2 层的理由:第 1 层已经把现实可达的歧义关掉了——要再撞上,输出行得
恰好以 `SrvBoxSep.b64.` 开头且后接合法 base64url。代价一侧则是每条命令多一次
fork,unix 脚本的核心命令约 20 条,在 busybox 路由器/NAS 这类目标硬件上每个
采样周期多 20 次 fork,而脚本 header 里的 `isBusybox` 说明这正是要支持的机型。

如果之后要收第 2 层,注意 upstream 的 framed 输出不做 `trim()`,与当前
`parse_script_output` 的行为不同。

## arm64 Linux 取不到 CPU 型号

`commands::LINUX` 的 `cpuBrand` 是 `cat /proc/cpuinfo | grep "model name"`,
`linux::parse_cpu_brand` 也按字面量 `model name` 匹配。aarch64 的
`/proc/cpuinfo` 没有这一行(orb 上 Debian bookworm / Alpine 3.23 实测,只有
`CPU implementer`、`CPU part`、`CPU variant` 等编号字段),该 section 恒为空,
About 卡片上没有 CPU 型号。覆盖面是所有 ARM 服务器(树莓派、ARM VPS、
Apple Silicon 上的 Linux 虚拟机)。

不是随手能补的,几个候选源都有缺口:
- `lscpu` 的 `Model name:`——Debian 有,Alpine 默认没装(util-linux 不在 base)
- `/proc/device-tree/model`——SBC 有,虚拟机没有(上述两台都没有)
- `CPU implementer`/`CPU part` 编号——要带一张 ARM 厂商/型号对照表

还有一个形状上的约束:`parse_cpu_brand` 返回 `(型号, 核数)`,核数靠数
`model name` 出现次数。`lscpu` 只输出一行,直接接上去核数会变成 1。要改就得
连解析侧的契约一起改。

## Agent 与多面板:交付了但没验过的部分

代码都已合入,以下手工验证项一直没跑,记在这里免得当成验过的:

**Agent**
- `serverbox` 的 `open_server` 一次都没被调用过,除单元测试外没有任何运行时证据
- 移动端完全没跑过:悬浮窗胶囊、贴边、底部面板、键盘遮挡(动画部分有
  `agent_shell_view_test.dart`,真机形态没有)
- 拒绝 host key 之后,Agent 那个工具是否干净失败。判定本身已经有测试
  (`test/host_key_verify_test.dart`,含「拒绝指纹不符时保留原 key」),剩下的是工具层:
  `_sshConnect` 抛出之后,会话没有被加进 `adHocSshSessionsProvider`、错误话术不会让模型
  原样重试。这半要真服务器 + 换过 host key,因为 `genClient` 要先有 socket 才谈得到验证
- 完整场景里的 monitor 安装那一半。`install.sh` 现在 systemd 和 OpenRC 都支持,两边的
  service 环节都在新建的 orbstack 机器上跑过(装/重复装/升级/卸载、跑在普通账户名下、
  杀掉进程能被拉回)。**但用的是 stub 二进制**,因为下面这条:

已验证的两条安全规则(凭据不出网、host key 由用户拍板)有出网请求体为证。

## monitor 从来没有发过 release

`install.sh` 的 `download()` 找的是 `monitor-v*` tag,而仓库里一个都没有 ——
`monitor-release.yml` 是 `workflow_dispatch`,一次都没跑过。所以 `install.sh install`
对任何人、任何平台都是「Failed to find a monitor-v* release」,包括 Agent 引导用户装
agent 的那条完整路径。

跑一次那个 workflow 就能解开。在那之前,离线包那条路(`SBM_INSTALL_PKG=<目录或 tarball>`)
是唯一能装成的方式,它本身也是内网服务器需要的。

## macOS 两套产物:App Store 版什么时候停更

自动导入已在真机上验过:keychain 两个 build 通用,容器读取不弹窗。剩下的是一个决定
——文案现在只说「以后可能停止更新」,定下日期之后 `macDmgBody` 要改成具体说法。

**`integration_test/` 里那几个 macOS 用例现在没人跑。** `macos.yml` 原本是
`flutter test integration_test -d macos`,一次都没绿过:hosted runner 上读不到 app 的
输出,每个文件都在加载阶段报 `The log reader stopped unexpectedly, or never started`,
启动本身撞的是 flutter/flutter#176850(`Failed to foreground app; open returned 1`),
该 issue 仍然 open 且在普通桌面上也复现。那个 workflow 已经改成只构建。要跑它们得有一台
机器:`flutter test integration_test/sandbox_import_test.dart -d macos`。

另外:`Hive.initFlutter()` 的默认目录仍是 documents,只是 `HiveStore.init` 每次都显式
传 `path`,所以没有盒子落在那里。哪天有人直接 `Hive.openBox` 不传 path,就会在不沙盒
版的 `~/Documents` 里冒出一个盒子。

## Android rootfs:Alpine 分支钉在 3.22

3.23+ 的 apk-tools 3 在 proot 下所有仓库都报 `Permission denied`(同一环境里 busybox
`wget` 能取同样的 URL,本地文件仓库也正常),原因未查明。3.22 是最后一个 apk-tools
2.14 的分支。等原因查明或上游修掉再往上跟,`integration_test/rootfs_shell_test.dart`
会在这件事变化时发现。

## iOS 的 Linux 环境:止血开关怎么用

`ios/Flutter/Ish.xcconfig` 里的 `SBM_ISH`,默认 `0`。

- `1` —— 链接 ish-arm64 引擎,`ios/Runner/ish/sbm_ish.c` 按真实实现编译
- `0` —— 同一个文件编成空壳,不链接任何库、不加头文件路径,`sbm_ish_available()`
  返回 false,Dart 侧据此不提供任何入口

止血流程就两步:改这一行、重新打包。不用改 Dart、不用动 pubspec、不用改 entitlement。
验证发出去的包是不是真的剥干净了:在二进制里搜 `sbm_ish_boot` 之外的引擎符号。

为什么要有这个:App Store 2.5.2 针对的是「下载并运行可执行代码」,iSH 上线四天就被
通知要下架。真出事的时候被卡住的不是这个功能,是整个 app 的下一次更新——那个时间点
不适合做重构。

默认是 `0`,因为引擎不在仓库里(`scripts/build-ish-ios.sh` 才会构建它),没跑过脚本的
检出根本链接不了;悄悄少链一个库的构建,比明确不做还糟。

## iOS Linux 环境:剩发热和送审

代码、模拟器、真机(iPad Pro 11" 三代,iOS 18.7.8)都走完了。引擎 fork 的维护方式见
`scripts/build-ish-ios.sh` 的注释,剥干净的验证方式见 `scripts/check-ish-linkage.sh`
—— 它由 `analysis.yml` 的 `iOS Linux engine` job 每次 push 跑一遍。

`build.yml` 的 `Build ios` job 不跑 `scripts/build-ish-ios.sh`,所以发布的 IPA 一直是
`SBM_ISH=0`。这是有意的:引擎要不要随包发是发布时的决定。

剩下两条,都要人:

- **发热。** 内存那半已经自动化了(`integration_test/ios_load_test.dart`,真机上跑完
  64 MB 落盘 + 三轮 sha256 + 400 个进程 + 20 万行排序,RSS 479 → 478 MB,峰值 500 MB,
  没有增长)。发热没有 API 可问 —— 一台在降频的设备,从 Dart 里看和一台本来就慢的设备
  完全一样。要 Instruments:`flutter build ios --profile`,Time Profiler + Thermal
  State,跑同一个负载,看 thermal state 有没有离开 nominal。
- **送审。** 开着功能提交,看结果。Guideline 2.5.2,不是技术问题,而且赌注不是这个功能
  被拒,是**整个 app 的下一次更新被卡住** —— 止血开关就是为这个存在的。这一条决定其余
  是否值得做完。

## Hive → SQLite:分阶段做,以及加密怎么落

**状态(2026-08-19):两个阶段都已合入。**

已做:
- `SqliteStore` 在 fl_lib(`store/sqlite.dart`),七个 K-V store 换过去,写入
  一律 JSON,75 处 `.box.` 已收敛。
- `connection_stats`(`conn_stat` 表)和 `agent_conversation`
  (`agent_conversation` + `agent_active` 两表)已关系化,各带索引。
  `conn_stats_index` 那个未加密的盒子随之消失,明文文件在导入时删除。
- `HiveImport` 负责一次性导入并记 schema v4。

未做 / 遗留:
- **`lib/hive/`、`hive_ce*` 依赖、`main.dart` 里的 `Hive.initFlutter()` 都还在。**
  17 个 TypeAdapter 现在只用于一件事:让 `HiveImport` 读得懂旧盒子。没有任何
  代码再往 Hive 写。这些要等到没有受支持的安装还停在 Hive 上才能删,`HiveImport`
  和 `SpiLegacyAdapter` 同批(代码里已标 TODO)。
- `~/Library/Application Support/ServerBox/app.db` 那批残留和
  `sandbox_import.dart` 里对它的特判仍未清理(见本节末尾)。

**一处没有覆盖到的路径:v2 记录的导入。** `HiveImport` 会把 `LegacySpiV2`
转成 `Spi`(原 `SpiNestSshMigration` 做的事),但没有测试跑过它 ——
`SpiLegacyAdapter.write` 按设计抛异常,所以测试造不出 v2 的盒子,除非再注册
一个只在测试里用的可写 adapter,而 Hive 按运行时类型解析写入,两个 adapter
认领同一个类型会让行为取决于注册顺序。覆盖面是「装了 v3 版本之前的包、之后
一直没启动过」的安装。`test/hive_import_test.dart` 覆盖的是 v3 那条路。

想换的理由有三条:Hive 把整个盒子读进内存、compact 靠重写整个文件;它只加密 value,
key 和盒子结构在文件里是明文;`hive_ce` 是社区接手的 fork。本机实测的盒子大小:
`connection_stats_enc.hive` 227KB、`agent_conversation_enc.hive` 128KB,其余(setting /
server / history / key / snippet)都在 10KB 以下——所以「Hive 撑不住」这个说法只对前两个
成立。

### 这条路已经走过一次

`fix/sqlite-migration-safety` 分支(2026-02-28 ~ 03-07,未合入任何主线,也不是当前 HEAD
的祖先)已经做完了一版:

- `drift 2.29` + `sqlcipher_flutter_libs 0.6.8`
- **完全关系化的 schema**——`Servers` / `ServerCustoms` / `ServerWolCfgs` / `ServerTags` /
  `ServerEnvs` / `PrivateKeys`,一张表一个概念
- `lib/data/db/app_db.g.dart` 8157 行生成代码;`5bc6976f ref(store): migrate core stores to
  async drift and pref` 改了 34 个文件,后面跟着 6 个 `fix: harden ...`
- 有 `lib/data/migration/hive_to_sqlite_migrator.dart`

**为什么没合,git 里没有说明,不要当成结论。** 但从 diff 的形状能看出代价在哪:它同时
改了三件事——存储引擎、数据模型、以及 `Store` 的同步 API 变成异步。三个一起动,所以
provider、backup、SFTP 页面、server 编辑页全被卷进去了。

### 三个决定应该拆开

- **引擎 Hive → SQLite**:这是真正想要的。
- **`Store` API 同步 → 异步**:不必须。`package:sqlite3` 是同步 API,drift 才是异步的。
  上一版的改动摊到 34 个文件,主要就是这一条带出来的。
- **K-V blob → 关系化 schema**:不必须,而且只有少数 store 值得。

第一阶段只动引擎,`Store` 接口不变:

```
kv(store TEXT, key TEXT, value TEXT /* JSON */, updated_at INTEGER, PRIMARY KEY(store, key))
```

`HiveStore` 换成 `SqliteStore`,`get`/`set`/`keys`/`clear`/`lastUpdateTs` 一一对应;
`box.watch()` 换成自己发的 per-key 通知,`HivePropListenable` 那套 `_BoxListenerManager`
逻辑可以整个搬过去。

两条原先没算到的成本:

- **`SqliteStore` 必须写在 fl_lib 里。** `Store` 是 `sealed class`
  (`packages/fl_lib/lib/src/core/store/iface.dart`),sealed 限制子类与基类同一
  library;`hive.dart` / `pref.dart` / `mock.dart` 都是 `part of 'iface.dart'`。
  所以这是跨仓库改动,不是 app 内部的事。
- **"上层零改动"只对 `Store` 的调用方成立,对直接摸 `box` 的地方不成立。**
  `rg -n '\bbox\.' lib/` = 75 处 / 18 文件。其中 `data/model/app/bak/backup.dart`
  独占 32 处,全是为了绕开 `lastUpdateTs` 而直接 `box.put/keys/delete/putAll`
  ——这些改用已有的 `updateLastUpdateTsOnSet: false` 参数即可,不需要 box。
  store 外部另有 5 处:`core/service/watch_sync.dart`(`box.watch()`)、
  `view/page/server/edit/actions.dart`(`box.keys`)、
  `view/page/setting/entries/app.dart`(备份加密,同 backup.dart)、
  `data/store/migrations/m002_nest_ssh.dart`。

序列化随之从 TypeAdapter 二进制换成 JSON,17 个 adapter 全部消失
(`lib/hive/` 整个目录 + `hive_ce*` 依赖)。覆盖情况已逐个核对:9 个类都有
`fromJson`(freezed 模型自带 `toJson`),7 个是 enum(按 name 存),setting 里的
virt keys 本来就存 `List<int>`,`agent_conversation` 本来就存 JSON Map。

第二阶段只关系化真正需要 SQL 的:

- **`connection_stats`**:现在为了做时间窗口查询,额外开了一个 `conn_stats_index`
  盒子,外加手写的 `_rebuildIndexCore` / `_updateIndex` / `_pruneExcessRecords` /
  `_compactIfNeeded` / 每服务器 100 条上限。这一整套在 SQL 里是一条
  `DELETE WHERE timestamp < ?` 加一个索引。
  **那个索引盒子是未加密的**——`connection_stats.dart` 开它时没传 `encryptionCipher`,
  本机实测 114 KB 明文存着 110 条 `<serverId>_<毫秒时间戳>`,比它索引的那个加密盒子
  还大。这是目前唯一一处现存的泄露,关系化之后随表消失(整库加密,索引也在库内)。
- **`agent_conversation`**:同理。`fetchForServer` 现在是全表扫加内存排序。
- `setting` / `server` / `snippet` / `key` / `history` / `docker` / `port_forward`
  留在 K-V。它们都在 10KB 以下,关系化只换来迁移工作量——上一版的 diff 就是证据。

### 加密:`package:sqlite3` 3.x + build hooks

**`sqlcipher_flutter_libs` 这条路没了。** 它已废弃(最后版本 `0.7.0+eol`,0.7.0 起
不再提供任何功能),README 要求改用 `package:sqlite3` 3.x。

替代方案比原方案好,原因是 CocoaPods:`package:sqlite3` 3.5.1 通过 **Dart build
hooks** 打包 SQLite,不是 Flutter plugin,既不产生 podspec 也不需要 `Package.swift`。
配置就是 pubspec 里一段:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

**选 `sqlite3mc` 而不是 `sqlcipher`。** 两者都是整库加密(包括 key 和索引),差别在
依赖:`sqlcipher` 在 Windows / Linux / Android 链接 OpenSSL,CI 要装系统依赖;
SQLite3MultipleCiphers 的 cipher 实现内置于源码("There is no direct dependency on
external projects"),而且它的 cipher 列表里就有一个 SQLCipher 兼容的 AES-256 方案,
日后要互操作可以切过去。新库没有历史包袱,默认方案即可。

Rust `rusqlite` + FRB 那条路不再考虑:它要先等 sbm_ffi 迁完 build hooks 才能脱离
CocoaPods(见上面那节),而且 CLAUDE.md 写的 FFI 边界原则是「不持有可变状态」,
一个数据库连接正好是可变状态。

不用 drift,理由是上面第二个决定:drift 是异步优先的,而异步化 `Store` 正是上一版
把改动摊到 34 个文件的原因。

### 三个具体的点

**密钥要用 raw key,不是 passphrase。** 上一版是 `PRAGMA key = '$escapedKey'`,会被
当口令做 PBKDF2 派生(默认 256000 轮)。而 `SecureStoreProps.hivePwd` 里存的本来就是
`Hive.generateSecureKey()` 产生的 32 字节随机密钥,直接用 `PRAGMA key = "x'<64位hex>'"`
跳过派生,既快也没有降低强度。

**迁移的形状。** 每个盒子一次,`Stores.init` 之前跑,用现有 cipher 打开 `*_enc.hive`
逐 key 转 JSON 写进 `kv` 表;成功后**保留** `.hive` 文件若干版本再删,理由和
`SandboxImport` 一样——复制过的原件留着,出问题可回退,并且加 TODO 标记删除时机。
`BackupV2` 是 JSON,和存储引擎无关,不受影响。

**迁移有顺序约束。** 新增 `SchemaVersion` v4 + `m003_hive_to_sqlite`。但 v2→v3 的
`SpiNestSshMigration` 依赖 `SpiLegacyAdapter` 和 Hive 的 typeId 解码(它直接读
`store.box`),所以 **m003 必须在 Hive 侧走完 v3 之后跑,m003 落地前不能删 Hive
依赖**。实际次序:保留 Hive 只读能力 → m002 → m003 → 之后的版本里删 Hive。

### 测试侧

19 个测试文件引用 Hive。各 store 的 `forBox(Box<dynamic> testBox)` 测试构造器换成
`sqlite3.openInMemory()`。这比 CLAUDE.md 里记的 Hive `bytes: Uint8List(0)` 干净,
而且不会踩 fake-async 下写锁不释放、`flutter test` 整体挂死那个坑。

### 顺带要清的残留

上一版分支从没发布,所以下面这些对真实用户不存在,只在开发机上:

- `~/Library/Application Support/ServerBox/app.db` + `app.db-wal`(4KB / 1.7MB,Mar 7),
  `sqlite3` 已经读不动了。
- `lib/core/utils/sandbox_import.dart:306` 对 `app.db` 的特判,和 `:375` 跳过 `.db-shm` 的
  那段——现在是死代码。这轮决定之后,要么删掉,要么改成指向新库。

## dartssh2:一次写入超过约 32 KiB 会挂住

同一条 SSH exec + stdin 的路径,把不同大小的内容写进远端命令(Windows 11 的
OpenSSH server,每档 3 次):

| 负载 | 结果 |
| --- | --- |
| 4 / 16 / 32 KiB | 3/3,每次约 190 ms |
| 64 KiB | 2/3 |
| 128 / 256 KiB | 0/3,45s 超时 |

同样 256 KiB 换系统 `ssh` 客户端是 5/5 通过,所以不是远端的问题。测量代码见
`test/windows_install_ssh_e2e_test.dart`,把里面那条 32 KiB 用例的尺寸调大即可复现。

可疑点在 `packages/dartssh2/lib/src/ssh_channel.dart` 的 `_uploadLoop`:正常路径按
`min(_remoteWindow, remoteMaximumPacketSize)` 取数据,但走 `_pendingUploadData` 那条
分支时只判断 `_remoteWindow > 0` 就把整块发出去,没有再对照当前窗口裁剪。窗口耗尽后
挂起、收到 WINDOW_ADJUST 恢复时,窗口可能只剩几字节而待发块有 32 KiB。**这是读代码
得出的推测,没有验证过**,也没有排查过是不是 Windows sshd 对超窗口的包有不同处理。

目前没有功能踩到它:状态脚本 4.5 KiB,SFTP 不受影响(`sftp/sftp_stream_io.dart:62`
用 `MaxChunkSize` 按 `defaultChunkSize` 分块)。会踩到的是"把一个大文件通过 exec 的 stdin 送过去"这种写法,现在没有。

dartssh2 是 submodule,要改得单独开分支,并且需要一个能稳定复现的最小用例——
现在的复现依赖一台真实 Windows 主机,不够。
