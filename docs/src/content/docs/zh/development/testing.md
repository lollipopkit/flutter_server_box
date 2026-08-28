---
title: 测试指南
description: 运行和编写 Server Box 测试
---

## 运行测试

```bash
# Flutter 和 Dart 测试
flutter test

# 指定测试文件
flutter test test/disk_test.dart

# 生成覆盖率报告
flutter test --coverage
```

## 测试结构

Dart 测试位于 `test/`，按 parser、model、store 和 utility 行为组织。测试应验证行为和输入输出，不依赖外部网络或真实服务器。

## Rust 测试

```bash
# Rust workspace 的全部测试
cargo test --workspace

# FFI parity test：先构建 FFI crate
cargo build -p sbm_ffi
flutter test test/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` 使用与 Dart 相同的 fixture，锁定两侧 parser 的行为。

### 需要显式开启的测试

以下测试需要真实主机；未设置环境变量时会静默跳过：

```bash
# SSH end-to-end：上传生成的脚本，在远端执行并与直接命令输出比较
# 在 workspace 根目录的 .env 中设置：
# SBM_E2E_SSH_HOST=<SSH 目标或 ~/.ssh/config 别名>
cargo test -p sbm_parser --test ssh_e2e

# 使用真实 sshd 测试 Monitor terminal
# 需要 SBM_E2E_TERMINAL_* 环境变量
cargo test -p server_box_monitor --test terminal_ws
```

## Monitor 面板测试

Monitor 的 Svelte 前端有独立的 Vitest 和 Testing Library 测试：

```bash
cd monitor/frontend
npm run test
npm run test:coverage
npm run check
```

`npm run check` 进行类型检查，也是 `npm run build` 的一部分。

## Unit test

Unit test 用于验证纯业务逻辑、model 和 parser：

```dart
test('calculates CPU percentage', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## Widget test

Widget test 用于验证 Widget 的布局、文本和交互：

```dart
testWidgets('shows the server name', (tester) async {
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

会写入 store 的 Widget test 必须在 `setUp` 使用 `openTestDb()` 打开内存数据库，并在 `tearDown` 调用 `SqliteDb.close`；使用 store 的 `forTest()` constructor，避免测试共享 singleton cache 或写入真实文件。

不要对包含 text field 或其他持续调度 frame 的 Widget 使用 `pumpAndSettle()`。使用定次数的 `pump(duration)`，并为测试命令设置合理的 timeout。

## Provider test

Provider test 验证状态和异步结果：

```dart
test('returns server status', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
  container.dispose();
});
```

## 外部依赖

默认测试必须保持确定性。parser、model、命令构建和普通 Widget test 不应访问网络或真实服务器。引入外部服务边界时，添加专用 fake、fixture 或 mock。

上文的 SSH end-to-end 和真实 sshd 测试是例外；它们只在配置环境变量后运行，因此默认 `cargo test --workspace` 不需要外部服务。

## 存储迁移测试

存储迁移在用户设备上通常只有一次机会。迁移写入完成标记后不会重新读取旧数据，因此错误更可能表现为静默丢数据，而不是崩溃。

每个迁移都必须保留永久 regression test，并使用旧 release 实际写出的 bytes：

| 文件 | 作用 |
|---|---|
| `test/hive_release_migration_test.dart` | 对每个 release fixture 运行 Hive import 和已注册的 migration |
| `test/fixtures/hive_v{1466,1480,1491}/` | 这些 release 实际写出的 box、生成器和说明 |
| `test/hive_import_test.dart` | 验证 import 的重试、幂等和按 box 进度 |
| `test/m005_monitor_insecure_http_test.dart` | 验证 m005 的迁移行为 |

fixture 一旦进入 regression test，就不能重新生成来绕过失败。使用当前 adapter 生成数据只能证明当前版本与自己一致，不能证明它仍能读取旧 release 的格式。

### 生成 release-authentic fixture

1. 使用 `git worktree add /tmp/<tag> <tag>` 检出目标 release，初始化它需要的 submodule，并运行 `flutter pub get`。
2. 将 `test/fixtures/hive_v1466/gen_fixture.dart.txt` 复制到临时测试中，按目标 release 的 model、adapter 和依赖版本调整；使用旧 release 自己的代码写出 `.hive` bytes。数据应覆盖可选字段、枚举值、各类 store，以及非 ASCII 字符、引号和换行。
3. 将结果复制到 `test/fixtures/hive_v<tag>/`，保留生成器说明和 README，然后删除 worktree。
4. 使用当前代码通过 public store API 编写读取测试，并检查数据库编码没有残留旧字段。

生成器以 `.txt` 签入，因为它针对旧 release 的 API，在当前 tree 中不一定能通过 analyze。

## Integration test

`integration_test/` 用于验证 `flutter test` 无法覆盖的 plugin、FFI、平台 shell 和真实设备行为：

| 文件 | 验证内容 |
|---|---|
| `local_shell_test.dart` | 本机 shell 是否能启动 |
| `rootfs_shell_test.dart` | Alpine rootfs 是否能通过 App 的 API 运行 |
| `android_exec_test.dart` | Android App 目录中的进程执行能力 |
| `android_rootfs_test.dart` | Android guest 机制 |
| `ios_rootfs_test.dart` | iOS Linux userland |
| `ios_bench_test.dart` | 真实硬件上的 guest 开销 |
| `ios_load_test.dart` | guest 运行时对 App 的影响 |
| `sandbox_import_test.dart` | App Store sandbox build 的数据接管 |

```bash
# 需要已连接的设备或模拟器
flutter test integration_test/local_shell_test.dart
```

`make analyze` 也会分析 `integration_test/`。

### iOS 17+ 无线设备

当 Xcode 通过网络连接 iOS 17+ 设备时，需要发布 driver 端口：

```bash
flutter drive --publish-port \
  --driver=integration_test/driver.dart \
  --target=integration_test/ios_rootfs_test.dart
```

首次运行时，设备可能会请求本地网络权限，请允许该权限。

## 编写测试的建议

1. 使用 Arrange–Act–Assert 组织测试。
2. 测试名称描述实际行为，而不是实现细节。
3. 对关键行为添加足够断言，同时保持测试专注。
4. 使用 fake 或 fixture 隔离外部依赖。
5. 覆盖空列表、缺失值、无效输入和权限错误等边界情况。
