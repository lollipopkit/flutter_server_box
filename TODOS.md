# TODOs / 后续方向

不在排期内的想法和已知缺口,先记在这里,免得丢了。

## App:直接通过 HTTP 读取服务器数据,而不是只走 SSH + shell

目前 Flutter app 读取服务器状态的唯一方式是:SSH 上去、上传并运行生成的脚本、
解析 `SrvBoxSep` 分隔的文本输出。哪怕这台服务器本来就跑着 `monitor`(它本来就
通过带鉴权的 HTTP API 暴露同样的数据——甚至更多,包括历史数据),app 也只走
这一条路径。

想法:让 app 可以选择直接通过 HTTP API(`/api/v1/status`、`/api/v1/metrics`、
`/api/v1/metrics/history`)访问服务器上的 `monitor` 实例,而不是走 SSH+shell——
前提是用户那台服务器上确实跑着 `monitor`。好处:
- 状态轮询不用再走 SSH 往返 / shell 解析——延迟更低,不用折腾脚本上传和版本管理
- 能用上 `monitor` 的历史接口(图表)和更丰富的指标(gpus/disk_details/ifaces),
  现在 SSH+shell 这条路径完全没解析这些
- 少一条要维护正确性的代码路径——SSH+shell 解析已经积累了一长串平台差异问题
  (参见 crates/sbm_parser 的 dart_compat 测试用例)

待定问题(先记下来,不是结论):
- 鉴权/配对体验:app 需要每台服务器的 `monitor` URL + 凭证(和面板那边
  `monitor/frontend/src/lib/servers.svelte.ts` 的服务器注册表是同一套思路)
- SSH 大概率还是得留着,因为有些操作 monitor 根本不提供(进程列表/结束进程、
  关机/重启/休眠、终端、SFTP)——这是在 SSH 之上做加法,不是替代
- CORS:monitor 的 `cors_allowed_origins` 是为浏览器场景(Pages 面板)设计的;
  app 不是浏览器,这个限制对它可能根本不适用——需要确认 `ntex_cors`/`Cors`
  中间件对非浏览器 HTTP 客户端的行为(Origin 头是浏览器加的,Dart 的
  `http`/`dio` 客户端不主动设置的话不会带,那大概率就和 curl 一样直接绕过
  CORS 校验、不受影响)
- app 里需要一个 `monitor` 客户端模块(存 token、配 base URL),以及怎么和现有
  的按服务器分 provider 的模型整合到一起,这个也要想清楚

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

## macOS 每核 CPU:monitor 已支持,App 还不行

`monitor` 现在通过 `sysinfo`/Mach 的 `host_processor_info`(参见
`monitor/src/monitoring/macos_cpu.rs`)在原生运行时能拿到 macOS 真实的每核 CPU
数据。但 **app** 通过 SSH 连上 macOS 服务器时还是拿不到——macOS 上没有任何 shell
命令能暴露每核数据(htop 自己的 macOS 后端也是进程内直接调用同一个 Mach API,
不是靠 shell)。这和上面那条是同一条架构主线:如果 app 能通过 HTTP 和 `monitor`
实例通信,就能顺带白嫖到真实的每核读数,而 SSH+shell 这条路在这件事上是条死路。

## sbm_ffi:Swift Package Manager 支持

Flutter 3.44 起 SPM 是默认路径,`flutter build ios/macos` 会对 `sbm_ffi` 报
"The following plugins do not support Swift Package Manager"。项目里其他 13 个
plugin 都已走 SPM(见生成的 `FlutterGeneratedPluginSwiftPackage/Package.swift`),
只剩 `sbm_ffi` 靠 CocoaPods —— `ios/Podfile.lock` 和 `macos/Podfile.lock` 里都只有
它一个 pod。混合模式在 3.44 下可用,警告不阻塞构建,但 Flutter 声明未来会变成 error。

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

两条候选路线(都还没做):
- **预编译 xcframework**:给 `crates/sbm_ffi/{ios,macos}/sbm_ffi/` 写 `Package.swift`,
  用 `.binaryTarget` 指向预先构建好的 `sbm_ffi.xcframework`,cargo 编译移到
  Makefile / fl_build 的 pre-build 步骤,绕开 sandbox。代价:在 Xcode 里直接 Run
  不会重编 Rust,容易用到旧产物;要额外维护打包脚本和 `-force_load` 处理
- **Dart native assets**:删掉 cargokit,改用 `hook/build.dart` +
  `native_toolchain_rust`,五个平台统一,不再需要 podspec 或 Package.swift。代价:
  Flutter native assets 仍是实验特性(`--enable-native-assets`),FRB 侧
  `ExternalLibrary` 的加载方式(`frb_generated.dart` 的 `stem`/`ioDirectory`)要改

现状决定:先维持混合模式,等 FRB #3315 合并或 native assets 转正再动。

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

## `BuildData.script` 不再跟踪脚本内容

`make.dart` 用 `lib/data/model/app/scripts/cmd_types.dart` 的 commit 数推导
`BuildData.script`,但脚本内容已经迁到 `crates/sbm_parser/src/{commands,script}.rs`,
改 Rust 不会让这个版本号变。

目前不构成故障:`single.dart` 每次建连都用 `cat >` 无条件重写脚本,远端不会留
旧版本。版本号只影响文件名(`srvboxm_v<n>.sh`),作用退化为与更老 App 版本遗留
文件不撞名。真要修就把 make.dart 的统计路径换成 Rust 那两个文件。

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

## Agent 风险徽标:`unknown` 和 `unvetted` 是不是同一个徽标

`AskAiCommand.classifyRisk` 是白名单:`readOnly` 是唯一一个对命令下了正面判断
的结论,其余全是「没认出来」。原来「没认出来」和「匹配到修改型模式」共用
`caution`,而它的中文标签是「会更改系统」——对 `sleep 60` 这种命令,这是一句
假话,而且和模型自己写的「不会修改系统」当场矛盾。`uptime && whoami` 同理:链式
命令根本不拆开分析。

已经拆开了(枚举加 `unknown`,fallthrough 和链式归入它,`caution` 留给真的匹配
到修改型模式的),`canAutoRun` 不变——只有 `readOnly` 能自动跑,安全性没放松。

**剩下的是标签语义,还没定**。同一时间另一条线在做「未审核主机」的拆分,给
`_unvettedFloor` 抬升后的结果也用了 `unknown`,并另配了 `askAiRiskUnvetted`
(「未审核的主机」)标签。于是同一个枚举值现在有两种成因:

- 命令没被认出来 → 应该说「未判定」
- 命令是只读的,但主机没被审核过 → 应该说「未审核的主机」

两者都不能自动执行,但徽标该说哪句话取决于成因,不是枚举值本身。现在靠
`raisedByUnvettedHost` 这个 bool 区分。要么把成因编进枚举,要么在徽标那层用
两个字段判断——没定,先记着。

l10n 里 `askAiRiskUnknown`(15 语言)已经加了。

## Agent 与多面板:交付了但没验过的部分

代码都已合入(`agent-plan.md`、`pane-plan.md` 已删除),以下手工验证项一直没跑,
记在这里免得当成验过的:

**Agent**
- `serverbox` 的 `open_server` 一次都没被调用过,除单元测试外没有任何运行时证据
- 移动端完全没跑过:悬浮窗胶囊、贴边、底部面板、键盘遮挡
- 重启后用失效 `session_id` 调用工具,应收到"连接不跨重启"而非裸异常 —— 未验
- 拒绝 host key 时工具是否干净失败 —— 只验过接受
- 完整场景里的 monitor 安装那一半:验证时用的是容器,没有 systemd

已验证的两条安全规则(凭据不出网、host key 由用户拍板)有出网请求体为证。

**多面板**
- 退出重开后终端能否恢复(tmux session/window、同一服务器的两个 shell 各自恢复)
- 文件页恢复到原来的目录、分栏分隔条位置
- 删除服务器后详情面板是否收回成整宽列表

其中文件页那几条已并入 `file-plan.md`,作为改造前的回归基线。

## macOS:把用户引导到 DMG 版,App Store 版进入兼容期

macOS 现在发两套产物(`52a0ec1b`):App Store 版必须沙盒,DMG 版不沙盒。差别不是
打包偏好,是**能力**——沙盒进程打不开伪终端的从属设备,所以本机终端在 App Store
版上不存在(`LocalShellBackend.isSupported` 会如实返回 false)。后续凡是需要
起进程的功能,大概率都会落在同一条线的另一边。

现在是兼容期:两套都发。方向是把用户往 DMG 引,**不强制**,但要让人知道
App Store 版以后可能不再更新。

要做的:

- App Store 版在**检查到新版本**时,除了给更新提示,再加一句推荐迁移到 DMG,并
  说明原因(有哪些功能这个版本给不了)。入口在 `AppUpdateIface.doUpdate`,调用
  点是 `view/page/home.dart:337` 和 `view/page/setting/entries/app.dart:118`;
  当前实现在 `packages/fl_lib/lib/src/core/update.dart`,**它现在不知道自己是不是
  App Store 版**,判据现成:`LocalShellBackend.isSandboxed`。
- 提示要可关闭、不反复骚扰。一次版本更新提一次,不是每次启动。
- 设置页里给一个常驻的说明入口,不能只在更新弹窗里出现一次。

**最大的障碍是数据不互通,这个必须先解决或先说清楚。** 同一个 bundle id,沙盒版
的数据在容器里(`~/Library/Containers/com.lollipopkit.toolbox/Data`),不沙盒版在
`~/Library/Application Support`。用户装了 DMG 版打开会看到一个空 app,服务器全
没了。可选做法:

- 迁移提示里明确要求先做一次备份(iCloud 或导出文件),换过去之后恢复;
- 或者 DMG 版首次启动时探测旧容器路径是否存在、有没有数据,主动提出导入。后者
  体验好得多,而且不沙盒版**读得到**那个容器目录,技术上可行——没验证过。

在这条解决之前,任何「推荐迁移」的文案都得把「会丢本地数据,先备份」放在最前面,
否则就是在坑人。

## 更新提示:显示中间所有版本的 changes,每个默认折叠

现在 GitHub 这条源只取最新一个 release 的正文:
`packages/fl_lib/lib/src/model/update.dart:151` 的 `_getGitHubAll()` 里
`_changelog = release.body`,`_getGitHubRelease()` 拿的是 latest。用户落后好几个
版本时,中间版本的 release notes 一条都看不到。

对照的是 JSON 那条源(`_getChangelog()`):它按 build 号筛出所有比当前新的条目,
拼成一个编号列表。GitHub 这条要做到同样的覆盖面,但**不能也拼成一坨**——release
正文往往很长,几个版本叠起来会把对话框撑爆。

要做的:

- 取所有 build 号大于当前的 release,不是只取 latest;
- 每个版本一个可折叠块,**默认折叠**,标题是版本号 + 日期,展开才是正文;
- 参考 agent 页面的工具卡片:`lib/view/page/agent/view.dart:584` 的 `_toolCard`,
  用的是 `ExpansionTile`(fl_lib 里有 `ExpandTile` 封装)。那里的注释写明了同一个
  取舍——「跑完的工具是一行日志,不是一条消息;它折叠成一行,好让它服务的那个答案
  留在屏幕上」,更新日志同理。
- 最新那一个是不是该默认展开,待定。倾向于是:用户最关心的就是刚更新到的这一版。

另外两条一起改:

- **标题用 GitHub 的 tag 名,不是 `'v1.0.$newest'`**。现在
  `packages/fl_lib/lib/src/core/update.dart:57` 把标题写死成 `v1.0.<build>`,
  显示的是 build 号,和 GitHub release 页上、和用户看到的版本号都对不上。tag 名
  在 release 对象里现成。
- **GitHub 这条路没有语言分支**。JSON 那条有 `changelogMap[_locale]`,GitHub 只
  有一个 `body`,写什么语言就显示什么语言。要不要按 locale 分,待定。

**改动落在 fl_lib**(`src/model/update.dart` + `src/core/update.dart`),不在本仓库。
