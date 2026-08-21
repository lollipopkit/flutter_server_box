---
title: 测试指南
description: 测试策略与运行测试
---

## 运行测试

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/disk_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage
```

## 测试结构

测试位于 `test/` 目录中。当前测试套件基本是扁平结构，按解析器、模型和工具行为分组，例如 `disk_test.dart`、`container_test.dart` 和 `ssh_config_test.dart`。

## Rust 测试

状态解析位于共享 Rust workspace 中：

```bash
# 全部 Rust 测试（解析库、原生采样、FFI 壳、monitor）
cargo test --workspace

# FFI 双跑一致性测试：断言 Dart 侧经 flutter_rust_bridge
# 获得完全一致的结果（需先构建 FFI crate）
cargo build -p sbm_ffi
flutter test test/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` 以原 Dart fixture 套件锁定解析行为。

### 需要显式开启的测试

有两个套件需要一台真实主机，未配置时会静默跳过：

```bash
# SSH 端到端：把生成的脚本上传到远端执行，并把解析结果与直接执行命令的输出比对。
# 需先在 workspace 根目录的 .env 里设置
# SBM_E2E_SSH_HOST=<ssh 目标或 ~/.ssh/config 别名>
cargo test -p sbm_parser --test ssh_e2e

# 用真实 sshd 测试 monitor 终端，而不是 monitor/tests/fake_sshd/ 里的进程内假
# sshd。需要 SBM_E2E_TERMINAL_*。
cargo test -p server_box_monitor --test terminal_ws
```

## monitor 面板测试

monitor 的 Svelte 前端有自己的测试套件（vitest + @testing-library/svelte）：

```bash
cd monitor/frontend
npm run test
npm run test:coverage

# 类型检查，也是 `npm run build` 的一部分
npm run check
```

## 单元测试

测试业务逻辑和数据模型：

```dart
test('应当计算 CPU 百分比', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## Widget 测试

测试 UI 组件：

```dart
testWidgets('ServerCard 应当显示服务器名称', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: ServerCard(server: testServer),
      ),
    ),
  );

  expect(find.text('Test Server'), findsOneWidget);
});
```

## Provider 测试

测试 Riverpod provider：

```dart
test('serverStatusProvider 应当返回状态', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
});
```

## 外部依赖

`flutter test` 必须保持确定性：解析器、模型和命令构建测试不得依赖网络或真实服务器。当功能引入服务边界时，添加有针对性的 fake 或 fixture。

上文「需要显式开启的测试」里的 Rust 套件是例外。未设置对应环境变量时会跳过，所以默认的 `cargo test --workspace` 仍然什么都不需要。

## 存储迁移

存储迁移会在一次启动中遍历用户的真实记录，写入完成标记后不会再次读取旧数据。
因此迁移错误通常是静默丢数据，而不是崩溃。每个迁移都必须保留永久回归测试，输入
应来自被迁移版本实际写出的字节，而不是当前版本的 adapter 重新生成的数据。

| 文件 | 作用 |
|---|---|
| `test/hive_release_migration_test.dart` | 读取每个 fixture，断言所有 store 完整导入 |
| `test/fixtures/hive_v{1466,1480,1491}/` | 这些版本各自写出的 box，以及生成器和 README |
| `test/hive_import_test.dart` | 验证导入本身的重试、幂等和按 box 进度 |
| `test/m005_monitor_insecure_http_test.dart` | 验证 m005 增加明文 HTTP 选择且可重复执行 |

当前 fixture 测试会依次覆盖 `HiveImport`、`KvToTablesMigration` 和
`MonitorInsecureHttpMigration`。使用当前 adapter
预先写入数据只能证明当前代码和自己一致，不能证明它仍能读取旧 release 的格式。
fixture 一旦用于回归测试就不能为了让测试通过而重新生成。

### 生成 release-authentic fixture

1. `git worktree add /tmp/<tag> <tag>`，初始化该 release 的 `pubspec.yaml` 所需子模块，运行 `flutter pub get`。
2. 将 `test/fixtures/hive_v1466/gen_fixture.dart.txt` 复制到临时测试中，按该 release 的模型、adapter 和依赖版本调整，并用旧 release 自己的代码写出 `.hive` bytes。数据应覆盖每一个可选字段、每一种枚举值和每一种存储类型，并包含非 ASCII 字符、引号和换行。
3. 将结果复制到 `test/fixtures/hive_v<tag>/`，保留生成器说明和 README，然后删除 worktree。
4. 用当前代码通过 public store API 编写读取测试，同时检查数据库编码没有残留旧 shape 的字段。

生成器以 `.txt` 签入，因为它针对旧 release 的 API，在当前 tree 中无法通过 `flutter analyze`。

## 集成测试

`integration_test/` 存放 `flutter test` 无法回答的问题。单元测试运行在 `flutter_tester` 下，不会加载任何 plugin，因此经 plugin 或 FFI 到达的代码不会在那里实际运行。这些测试运行在已连接的真实设备或模拟器上的 App 中，因此 plugin 和 FFI 代码会在真实的 App 环境中执行：

| 文件 | 回答的问题 |
|---|---|
| `local_shell_test.dart` | 本机 shell 是否真的能启动 |
| `rootfs_shell_test.dart` | Linux userland，经 App 实际使用的 API |
| `android_exec_test.dart` | Android 允许从 App 自己的目录执行什么 |
| `android_rootfs_test.dart` | Android guest 机制是否可行 |
| `ios_rootfs_test.dart` | iOS 上的 Linux userland |
| `ios_bench_test.dart` | Linux guest 在真实硬件上的开销 |
| `ios_load_test.dart` | guest 工作时对 App 的开销 |
| `sandbox_import_test.dart` | 接管沙盒版本的数据 |

```bash
# 需要已连接的设备或模拟器；仅执行 flutter test 不会运行它们
flutter test integration_test/local_shell_test.dart
```

`make analyze` 也会分析这个目录（`flutter analyze lib test integration_test`）。

### iOS 17+ 无线设备

当 Xcode 通过网络连接 iOS 17+ 设备而不是使用数据线时，`flutter test` 会因关闭端口
发布而无法启动 App。使用 integration-test driver 并发布端口：

```bash
flutter drive --publish-port \
  --driver=integration_test/driver.dart \
  --target=integration_test/ios_rootfs_test.dart
```

首次运行时设备会请求本地网络权限，需要允许该权限。

## 最佳实践

1. **Arrange-Act-Assert**：清晰地组织测试结构（准备-执行-断言）
2. **描述性名称**：测试名称应描述其行为
3. **按行为使用足够的断言**：保持测试专注，同时完整验证该行为
4. **Mock 外部依赖**：不要依赖真实服务器
5. **测试边缘情况**：处理空列表、空值等
