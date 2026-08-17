# TODOs / 后续方向

不在排期内的想法和已知缺口,先记在这里,免得丢了。

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

## Agent 与多面板:交付了但没验过的部分

代码都已合入,以下手工验证项一直没跑,记在这里免得当成验过的:

**Agent**
- `serverbox` 的 `open_server` 一次都没被调用过,除单元测试外没有任何运行时证据
- 移动端完全没跑过:悬浮窗胶囊、贴边、底部面板、键盘遮挡(动画部分有
  `agent_shell_view_test.dart`,真机形态没有)
- 拒绝 host key 时工具是否干净失败 —— 只验过接受。原先记的「没有注入点」不成立:
  `genClient` 本来就收 `onHostKeyPrompt`,是 `_sshConnect` 没有往下传。要自动化就把它
  透出来;在那之前是真服务器 + 换过 host key 才走得到
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

## Hive → SQLite:分阶段做,以及加密怎么落

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

第一阶段只动引擎,`Store` 接口不变,上层零改动:

```
kv(store TEXT, key TEXT, value BLOB, updated_at INTEGER, PRIMARY KEY(store, key))
```

`HiveStore` 换成 `SqliteStore`,`get`/`set`/`keys`/`clear`/`lastUpdateTs` 一一对应;
`box.watch()` 换成自己发的 per-key 通知,`HivePropListenable` 那套 `_BoxListenerManager`
逻辑可以整个搬过去。providers、backup、UI 一行不用改。

第二阶段只关系化真正需要 SQL 的:

- **`connection_stats`**:现在为了做时间窗口查询,额外开了一个不加密的 `conn_stats_index`
  盒子,外加手写的 `_rebuildIndexCore` / `_compactIfNeeded` / 每服务器 100 条上限。这一整套
  在 SQL 里是一条 `DELETE WHERE timestamp < ?` 加一个索引。
- **`agent_conversation`**:同理。
- `setting` / `server` / `snippet` / `key` / `history` 留在 K-V。它们都在 10KB 以下,
  关系化只换来迁移工作量——上一版的 diff 就是证据。

### 加密:两条路

两条都是 SQLCipher(整库加密,包括 key 和索引)。

- **`sqlcipher_flutter_libs` + `package:sqlite3`**:五个平台都支持;Linux 要 `libssl-dev`、
  Windows 要 `choco install openssl`(CI 要改);iOS/macOS 装 SQLCipher pod,README 明确写
  「依赖任何链接普通 sqlite3 的包都会出事」——目前 `pubspec.lock` 里干净,这条不成立,但
  以后加依赖时要盯着。同步调用是原生的。
- **Rust `rusqlite` + FRB**:`libsqlite3-sys` 的 `bundled-sqlcipher-vendored-openssl` 把
  SQLCipher 和 OpenSSL 一起编进去,无系统依赖、无 pod,走现有的 cargokit 出五个平台的产物;
  同步调用靠 `#[frb(sync)]`。代价:每次 K-V 操作过一次 FFI;而且 CLAUDE.md 写的 FFI 边界
  原则是「不持有可变状态」,一个数据库连接正好是可变状态,要么破例要么专门论证。
  注意 Windows 上必须用 vendored-openssl 那个 feature,`bundled-sqlcipher` 单独用只在 Unix
  上成立。

**倾向第一条**,而且不要 drift。不用 drift 的理由就是上面第二个决定:它是异步优先的,
而异步化 `Store` 正是上一版把改动摊开的原因。

### 两个具体的点

**密钥要用 raw key,不是 passphrase。** 上一版是 `PRAGMA key = '$escapedKey'`,SQLCipher 会
把它当口令做 PBKDF2 派生(默认 256000 轮)。而 `SecureStoreProps.hivePwd` 里存的本来就是
`Hive.generateSecureKey()` 产生的 32 字节随机密钥,直接用 `PRAGMA key = "x'<64位hex>'"`
跳过派生,既快也没有降低强度。

**迁移的形状。** 每个盒子一次,`Stores.init` 之前跑,用现有 cipher 打开 `*_enc.hive`
逐 key 写进 `kv` 表;成功后**保留** `.hive` 文件若干版本再删,理由和 `SandboxImport` 一样
——复制过的原件留着,出问题可回退,并且加 TODO 标记删除时机。`BackupV2` 是 JSON,
和存储引擎无关,不受影响。

### 顺带要清的残留

上一版分支从没发布,所以下面这些对真实用户不存在,只在开发机上:

- `~/Library/Application Support/ServerBox/app.db` + `app.db-wal`(4KB / 1.7MB,Mar 7),
  `sqlite3` 已经读不动了。
- `lib/core/utils/sandbox_import.dart:306` 对 `app.db` 的特判,和 `:375` 跳过 `.db-shm` 的
  那段——现在是死代码。这轮决定之后,要么删掉,要么改成指向新库。
