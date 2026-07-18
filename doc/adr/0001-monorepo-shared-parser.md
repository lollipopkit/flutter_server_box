# ADR 0001: Monorepo 化与共享状态解析库

- 状态:已接受
- 日期:2026-07-18
- 决策人:lollipopkit

## 背景

ServerBox 生态目前有两套独立的服务器状态解析实现:

1. **flutter_server_box(App,Dart)**:事实标准,约 2100 行,
   `lib/data/model/server/` 按类型拆分(cpu/disk/net_speed/memory/temp/
   disk_smart/nvidia/amd/battery/sensors/conn/windows_parser),覆盖
   Linux / BSD(macOS)/ Windows 三套采集格式,`test/` 下有 40+ fixture 测试。
   采集命令由 `lib/data/model/app/scripts/` 的 `ShellCmdType` 枚举 +
   per-platform `ScriptBuilder` 生成,输出按 `SrvBoxSep.<cmd>` 分段。
2. **server_box_monitor(Rust,RIIR 后)**:`src/monitoring/monitoring.rs`
   内置采集命令与解析,仅覆盖 Linux/macOS 的 cpu/mem/disk/net/temp,
   Windows 为空壳,分段符为 `SrvBox`。

双实现已经产生真实漂移:macOS `PhysMem` 括号内逗号导致 total 恒 0、
磁盘聚合未按 `/dev` 前缀过滤/去重导致重复统计、阈值格式与 Go/App 不一致等,
均在 RIIR 过程中逐一修复。每一处漂移都意味着 App 展示与 monitor 告警
对同一台服务器给出不同数值。

App 仓库内 `packages/server_box_monitor` 为旧 Go 版监控的整包残留,
未被 pubspec 引用,待清理(TODO)。

## 决策

### 1. 单一解析库(single source of truth)

抽取纯解析 crate **`sbm_parser`**(无 IO、无 tokio/sqlx,serde 输出):

- 输入:`SystemType`(linux/bsd/windows)+ `Map<cmd, raw_output>`
- 输出:结构化 `ServerStatus`
- **解析为纯函数**:只产出原始计数器(rx/tx 字节、CPU ticks 等),
  差分/滑窗计算由 crate 提供纯函数(如 `compute_speed(prev, cur)`),
  可变状态(时序窗口)留在调用方。FFI 边界不持有可变状态。
- monitor 直接以 crate 依赖使用;App 经 flutter_rust_bridge v2 +
  cargokit 生成 Dart binding 使用。

### 2. 脚本源同一

采集命令清单(cmd 名 → 各平台命令)随 `sbm_parser` 维护,作为解析的
配套契约:命令、分段符(统一为 `SrvBoxSep.<cmd>`)、解析器三者同版本演进。

- monitor 端:本机执行命令清单后交给解析器
- App 端:由同一清单生成 SSH 脚本(替代 `ShellCmdType` 中硬编码的命令),
  经 FFI 或构建期 codegen 导出给 Dart
- 现有 `res/monitor.sh`(Go 版遗产)与 Rust 端硬编码命令表废弃

### 3. Monorepo:并入 flutter_server_box

最终形态下,monitor(服务端 client + web 前端)与 parser 并入 App 仓库:

```
flutter_server_box/            # monorepo
├── lib/ ...                   # Flutter App(经 FRB 使用 sbm_parser)
├── crates/
│   ├── sbm_parser/            # 共享解析库 + 命令清单(单一事实来源)
│   └── sbm_ffi/               # flutter_rust_bridge 绑定薄壳
├── monitor/                   # 服务器端监控(现 server_box_monitor)
│   ├── src/                   # Rust 服务(采集/规则/推送/API)
│   └── frontend/              # React web 前端
└── ...
```

- Rust 侧以 cargo workspace 组织(`crates/*` + `monitor`)
- server_box_monitor 仓库归档,git 历史通过 subtree merge 保留
- 顺带删除 `packages/server_box_monitor`(旧 Go 残留)

### 4. 解析覆盖补全

以 App 的 Dart 实现为语义基准迁移,并优化/补全三平台覆盖:

- **Linux**:cpu、mem/swap、disk(含 Btrfs)、net、temp、uptime、conn、
  diskio、battery、sensors → 全量进 `sbm_parser`
- **macOS/BSD**:补全 netstat/top/vm_stat/df 解析(修正现有 Rust 端缺口,
  如温度、swap)
- **Windows**:从空壳补齐,迁移 `windows_parser.dart` 的 PowerShell JSON
  解析(CIM/WMI 差分含在纯函数差分模型内)
- App 专属且迭代快的解析(NVIDIA XML、AMD JSON、SMART)**后置**,
  留在 Dart,待稳定后再评估迁移——避免 Rust 化拖慢 App 功能迭代

### 5. 测试即规格

迁移一个模块前,先把 App 对应的 Dart fixture 测试移植为 Rust 测试;
Dart 侧以同一 fixture 断言 FFI 返回值一致后,才删除 Dart 实现。
(方法同 monitor 仓库 `tests/go_compat.rs` 对 Go 版的行为锁定。)

## 迁移路径

1. **Phase 1(monitor 仓库内,零 App 风险)**:workspace 拆分,
   抽取 `sbm_parser`(含命令清单),monitor 接入,移植 Dart fixture 测试,
   补全三平台解析
2. **Phase 2**:`sbm_ffi` + FRB 接入 App,Dart 侧逐模块切换到 FFI 并
   用 fixture 双跑验证,删除已迁移的 Dart 解析
3. **Phase 3**:subtree merge 并入 App 仓库形成 monorepo,归档旧仓库,
   清理 `packages/server_box_monitor`;App 脚本生成切换到共享命令清单

> **进度附注(2026-07)**:Phase 1–3 已完成。原定后置的热区解析
> (GPU NVIDIA/AMD、SMART、battery、sensors、diskio、conn、uptime、
> sys/host/cpuBrand)也已全部迁入 `sbm_parser` 并通过 Dart fixture
> 与 FFI 双跑锁定。命令清单以 `core` 标记区分开销:monitor 周期采集
> 仅执行 core 命令,GPU/SMART 等高开销命令由 App 按需执行。
> 剩余工作:App 生产代码逐模块切换到 FFI 并删除 Dart 解析实现、
> 脚本生成切换到 `command_specs`、CI 五平台交叉编译验证。

## 后果

**收益**

- 双端行为强一致:同一服务器,App 展示与 monitor 告警数值一致
- 解析 bug 修一次、两端生效;fixture 测试单份维护
- Windows/macOS 覆盖从 monitor 端的缺失/空壳补齐到 App 同等水平

**成本**

- App 构建链引入 Rust 工具链与五平台交叉编译(iOS/Android/macOS/
  Windows/Linux),CI(fl_build)需适配;iOS 需静态库多架构
- App 体积增加约 1–2 MB
- 纯 Dart 贡献者改解析需要碰 Rust + 重新生成 binding(通过后置热区
  解析缓解)

**已考虑的替代方案**

- **维持双实现 + 行为测试对齐**:测试只能锁已知行为,漂移仍会发生
  (本次 RIIR 已实证),否决
- **Dart 作为唯一实现**:monitor 服务端无法复用 Dart(不引入 Dart VM
  运行时的前提下),否决
- **独立 parser 仓库(三仓库)**:版本协调成本高于 monorepo,且脚本
  清单与 App 发布强耦合,否决
