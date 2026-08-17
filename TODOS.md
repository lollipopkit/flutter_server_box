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

## Agent 风险徽标:成因编进枚举,已做

`AskAiCommand.classifyRisk` 是白名单:`readOnly` 是唯一一个对命令下了正面判断的结论,
其余全是「没认出来」。原来「没认出来」和「匹配到修改型模式」共用 `caution`,而它的
中文标签是「会更改系统」——对 `sleep 60` 这种命令这是一句假话,和模型自己写的「不会
修改系统」当场矛盾。

现在枚举是 `readOnly / unknown / unvettedHost / caution / destructive`,三种成因各有
各的徽标文案,`raisedByUnvettedHost` 这个 bool 去掉了。`canAutoRun` 不变——只有
`readOnly` 能自动跑。`risk` 是纯 getter、从不序列化,所以加值不涉及任何历史数据迁移。

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

## macOS 两套产物:自动导入的那条假设还没实测

引导和迁移已经做完(`DmgNotice`、`SandboxImport`、`Paths` 的非沙盒分支)。不沙盒版
首次启动会把 `~/Library/Containers/com.lollipopkit.toolbox/Data/Documents` 整个复制
到 `~/Library/Application Support/ServerBox`,覆盖两类人:App Store 版用户,以及
`52a0ec1b` 之前那批**沙盒版 DMG** 用户(他们的数据也在同一个容器里)。

剩下三条:

- **keychain 是否两边通用,没有实测过。** hive 的盒子用 AES 加密,密钥在
  `SecureStoreProps.hivePwd`,走 data protection keychain,access group 来自
  application-identifier。两个 build 同 team、同 bundle id,理应拿到同一项,但只是
  推断。代码不依赖这个推断:`SandboxImport.hasBoxKey` 读不到密钥就返回 `noKey`、
  不复制,并提示改用备份文件;`Stores.init` 失败还有 `undo` 兜底。要确认的是真机
  上实际走的是哪条分支(签名 DMG + 有容器数据的机器,看日志里的
  `Sandbox import: <result>`)。
- **容器读取权限。** macOS 14 起,一个 app 读另一个 app 的容器要用户点头;同 bundle
  id 大概率不弹窗,但没验证。被拒时是 `denied`,提示里给了「完全磁盘访问权限」的入口。
- **App Store 版什么时候停更,没定。** 文案现在只说「以后可能停止更新」。定下来之后
  `macDmgBody` 要改成具体的说法。

另外:`Hive.initFlutter()` 的默认目录仍是 documents,只是 `HiveStore.init` 每次都显式
传 `path`,所以没有盒子落在那里。哪天有人直接 `Hive.openBox` 不传 path,就会在不沙盒
版的 `~/Documents` 里冒出一个盒子。

## Android rootfs:剩下的是升级路径和 apk-tools 3

`AndroidRootfs` 已经能用了(下载并校验 Alpine 3.22.5、proot 进 rootfs、terminal tab
里有入口、`integration_test/rootfs_shell_test.dart` 覆盖到 `apk add`),CI 也构建
proot 并在构建后检查两个 `.so` 确实进了 APK。剩下两条:

- **Alpine 分支钉在 3.22。** 3.23+ 的 apk-tools 3 在 proot 下所有仓库都报
  `Permission denied`(同一环境里 busybox `wget` 能取同样的 URL,本地文件仓库也正常),
  原因未查明。3.22 是最后一个 apk-tools 2.14 的分支。等原因查明或上游修掉再往上跟。
- ~~升级路径~~ 已做:`.installed` 里的版本和 pin 不一致时,打开 Alpine 终端会提示一次
  (说明重装会丢容器里 `apk add` 装过的东西),不点就照常用旧的;入口显示的是**已装的**
  版本号,有更新时副标题写出新版本。留了一条 TODO:marker 为空的老安装当作「更旧」处理,
  等没有这种安装了可以删。

已经定了的两条,不用再议:

- **只做 arm64。** 构建脚本和 rootfs tarball 都是 aarch64,x86_64 / 32 位设备上
  `isAvailable` 是 false,入口不显示。
- **`useLegacyPackaging` 全局开。** 没有按库控制的开关。实测 arm64 release APK:开
  25.5 MB,关 47.8 MB —— 开了反而更小(解压出来的库在 APK 里是压缩存储的,映射的不是),
  代价是安装后库存两份。

## Flutter 的 state restoration 在这个 app 里是失效的

实测(API 36 模拟器,debug build):终端 tab 的 `restoreState` 跑起来时
`bucket == null`,也就是它 `registerForRestoration` 的东西从来没被写出去过。
`MaterialApp` 上有 `restorationScopeId: 'serverbox'`,但页面挂在 `home:` 下,而
`home:` 生成的 route 没有 restoration id——没有 id 的 route 不会给子树发 bucket。

终端 tab 已经绕开了:标签集改存 `Stores.history.sshTabs`(Hive),进程被杀后能恢复,
已验。剩下三处还在用这套机制,等于什么都没做:

- `lib/view/page/home.dart` —— 底部 tab 的选中项
- `lib/view/page/storage/tab.dart` —— 文件页(另一个 agent 的 lane,和 file-plan 一起看)
- `lib/view/page/ssh/page/page.dart` —— 终端页自己的 tmux session/window。功能上不影响:
  tmux 状态现在由 tab 那层的 JSON 带着走,但页面里这三个 `Restorable*` 字段看着像在工作,
  其实没有。

两条路:要么让 home route 拿到 restoration id(改动小但要确认 Flutter 那条链路),要么
像终端 tab 一样各自落到 store。**没定**。注意 saved instance state 本来也扛不住用户
在最近任务里划掉 app,而"划掉之后回来还在"恰恰是终端最需要的,所以 store 那条路更稳。

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

## iOS Linux 环境:代码层面已完成,剩真机和审核

装机路径、每会话独立 pty、`/dev` 设备节点、终端入口、Agent 本地目标都做完了,在模拟器
验过。原来记的两条已修,原因和当初的判断不同:

一个现象,两个串联的 bug,少修一个症状完全不变 —— 这也是第一次判断看起来「被证实」的原因。

**一、open 本身就失败。** `generic_open("/dev/pts/N")` 返回 ENOENT,跟 devptsfs 无关。
`mount_find`(`fs/mount.c`)有个 thread-local 缓存,判据是「路径以缓存挂载点为前缀」,
这和「哪个挂载点拥有这条路径」不是同一个问题:`/dev` 是 `/dev/pts/0` 的前缀,但后者属于
`/dev/pts`。`path_normalize` 逐段走路径,所以查 `/dev/pts/0` 之前必然先查 `/dev`,于是
必然拿到错的文件系统。在 app 里同一时刻查两次实测:

    cold  /dev/pts/0 → mount='/dev/pts' trimmed='/0'
    warm  /dev/pts/0 → mount='/dev'     trimmed='/pts/0'

upstream 不触发:那边 `/dev` 在根挂载里,挂载点是 `""`,缓存明确不存它。把 `/dev` 做成
独立 fakefs 才暴露出来。修在 fork 的 `647408c` —— 直接删掉快路径而不是修正它:那条路径
为了加 refcount 一样要拿 `mounts_lock`,省下的只是遍历几个挂载点。

**二、后面那个判断也是错的。** `create_stdio`(`kernel/init.c:137`)打开路径后要求
`S_ISCHR(fd->stat.mode)`,但 `fd->stat` 是 adhoc 文件系统自己的一份 stat
(`fs/fd.h:114`),`generic_openat` 填的是 `fd->type`;devpts 的 fd 走 `fd_create`,
该结构体全零,所以这个判断恒为假。`sbm_ish.c` 现在自己打开 slave 并检查真正被设置的
字段,`create_stdio` 保留为回退分支且落到时会 syslog —— 静默降级正是当初把这件事藏住的
原因。

**引擎补丁是新增的维护面。** `build-ish-ios.sh` 在 checkout 到 pin 的 commit 之后应用
`scripts/ish-patches/` 下所有补丁,可重复应用,补丁打不上就直接失败而不是跳过,所以升
pin 不会静默丢掉修复。

顺带解决的:`generic_openat` 对字符设备走 `dev_open` → `tty_open`,会给 session leader
认领控制终端,所以 `/dev/tty`、job control、Ctrl-C 都对了;会话最后一个 fd 关闭时 tty 也
会被释放,adhoc fd 从来不会。命令会话(`command != NULL`)另外关掉 `OPOST` 和 `ECHO`。

模拟器实测(iPhone 17 Pro Max, iOS 26.5):`integration_test/ios_rootfs_test.dart` 八条
全过,`tty` 和 `readlink /dev/fd/1` 都报 `/dev/pts/N`,`echo > /dev/stdout` 能到。

**命令行 4 KB 上限,已绕开。** `sbm_ish_open` 把 `/bin/sh`、`-c` 和命令拼进一个 4096 字节的
块(`ios/Runner/ish/sbm_ish.c:525`),超出返回 `-E2BIG`,到调用方是「the guest refused a
session (-7)」——这句话不提长度。guest 自己的 `ARGV_MAX` 是 32 页,从来不是限制方。撞得到
这堵墙的是 Agent 的 shell 工具:脚本由模型生成,长度不受约束。`IshExec.run` 现在超过 4000
字节就把脚本写进 guest 的 `/tmp` 再 `sh` 它,读脚本的仍是 session 自己那个 shell,重定向、
`export` 和退出码都不变。模拟器实测:4000 字节能开,5000 字节返回 -7。

**Agent 的 iOS 本地目标**是 `IshExec`,形状照 Android(容器是唯一的本机,文件工具在
容器内解析,共用 `resolveWithinRoot` 这条边界)。一个设计点:pty 对 `ServerExec` 是错的
形状——两条流会合并、输入会回显、程序会以为自己在终端里。所以命令自己的 stdout/stderr
重定向到 guest `/tmp` 下两个文件,从 host 读(`realfs` 下两边看的是同一棵目录树),
console 上剩下的(重定向本身失败时 shell 的报错)算作 stderr。

不需要真机就能跑的两个测试:`test/file_tail_test.dart`(边写边读,多字节字符跨轮次
截断是会被用户撞到的那个 case)、`test/ish_exec_test.dart`(实际交给 guest 的那段 shell)。

剩下的是 `local-ssh-plan.md` 的 M2(Instruments 看内存和发热)和 M5(送审)。CI 有
`Build ios` job,但它不跑 `scripts/build-ish-ios.sh`,所以上传的 IPA 一直是 `SBM_ISH=0`。

**M1、M3 已在真机上跑过**(iPad Pro 11" 三代,iOS 18.7.8 —— 是真机,但 M1 芯片,不是手机)。
M1:`ios_rootfs_test.dart` 9/9,模拟器上成立的在设备上都成立,4 KB argv 墙的位置一模一样。
M3:39 行数据,但**第一次跑是失败的** —— `fork+exec 50` 报 -360 ms。原因是
`proc_show_uptime` 用 `%lu` 打印百分秒,`.07` 变成 `.7`,按两位小数解析就是 `.70`,前跳
0.63 秒,下一次正常读数看着就在倒退。设备实测 300 次读取里 63 次格式不对。已有的
`the guest clock is a clock` 看不到这个:它在 `sleep 1` 两侧采样、允许 0.5–3.0 秒,0.63 的
跳变正好落在里面 —— 这是这个文件里第三个时钟 bug,每次都对上一个 bug 写的测试免疫。新增
`/proc/uptime keeps its two decimal places` 盯 300 次读取的格式和单调性。

修复在 fork 的 `eec9af7e`。**`scripts/build-ish-ios.sh` 的 pin 还指着 `0d592524`,等 fork
推上去再动。** 在此之前,别人重建引擎会拿回旧的,新测试会失败。

**M4(止血开关剥干净)已验,结论和检查方法分开说。** Release 设备构建两次,只改开关:
引擎内部符号 5 → 0,`ish-arm64|fakefs|realfs` 字符串 81 → 0,sqlite 字符串 66 → 0,
`otool -L` 里的 `libsqlite3.dylib` 消失,二进制小 620 KB;`sbm_ish_available` 编成
`mov w0,#0; ret`。剥得干净。

但**原来写的检查方法是错的** —— 文档和 `Ish.xcconfig` 都说"搜 `sbm_ish_boot`",而八个
`sbm_ish_*` 两边都导出(Dart 按名字查符号,所以带 `used`;关掉时它们是两条指令的桩)。
照旧说明做的人会搜到符号、以为没剥掉。能区分的是引擎内部符号、引擎字符串、`otool -L`
里的 sqlite。三处说明已改。顺带更正:FFI 面是八个函数,不是六个。

## 自定义命令:改成服务器上的文件,三层一起动

已定的三条:

1. **保序,用户可拖动排序**。文件名前缀 `NNNNN_`,间隔 100 —— 往两条之间插一条只需重命名
   一个文件,不用重排整个目录(文件在 SSH 那头,这一点很实际)。
2. **服务器是唯一来源**。命令不再进 app 的备份,顺带消掉「恢复别人给的备份 → 在你每台
   服务器上执行任意代码」那条路。代价:配置绑在服务器上,重装服务器就没了。
3. **monitor 也要跑**,web 端也要能配置。否则 monitor-only 的服务器永远没有这个功能。

已落地的只有**约定层**(`sbm_parser::script`):`CUSTOM_CMD_DIR`、`CUSTOM_CMD_ORDER_STEP`、
`custom_cmd_file_name`、`custom_cmd_name_from_file`,连同测试。它不改变任何现有行为,
但 app 和 monitor 从此有同一套文件名规则可依。

剩下的按**不会回归**的顺序做——脚本改成读目录、而 app 还没写目录,自定义命令就会当场失效:

1. **app 先写目录**(装脚本时顺带写 `custom_cmds/`,批量一次传完,写临时目录再 rename;
   删掉的命令要显式删远端文件)。此时脚本仍然内联,功能不变。
2. **脚本改成读目录**:Status 里遍历 `$(dirname $0)/custom_cmds`,`echo` 用文件名里的编码名
   当 marker,`sh "$f"` 执行(不用执行位,绕开 noexec),有 `timeout` 就套 5 秒。
   同时 `ScriptOptions.custom_cmds` 删掉、FFI 那个参数删掉、`allScript` 不再传。
   `tests/script_compat.rs` 的基线要重写——脚本字节从此不随用户配置变化,这本身是收益。
   Windows 侧用 `Get-ChildItem | Sort-Object Name` + `&`。
3. **app 的拖动排序 UI**,以及从 `Spi.customCmds`(Hive/备份)迁移到服务器目录:要一次迁移
   和一个「服务器连不上时怎么编辑」的答案。
4. **monitor**:扩展周期里读同一个目录、执行、结果并进 status 响应;web 端做编辑界面。
   注意 monitor 现在**根本不跑** Status(采集已换成 `sbm_native`,共享脚本只用于扩展函数),
   所以这不是「把配置传进去」,是新增一段采集。
