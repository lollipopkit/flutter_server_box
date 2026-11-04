---
title: 测试指南
description: 运行和编写 Server Box 测试
---

## 运行测试

```bash
# Flutter 和 Dart 测试
flutter test

# 指定测试文件
flutter test test/unit/server/disk_test.dart

# 生成覆盖率报告
flutter test --coverage
```

## 测试结构

Dart 测试位于 `test/`，按 `unit/`、`widget/`、`platform/` 和 `migration/` 分类。共享 helper 和 release fixture 分别位于 `helpers/` 和 `fixtures/`。测试应验证行为和输入输出，不依赖外部网络或真实服务器。

`unit/` 按功能域划分为 `ssh/`、`terminal/`、`file/`、`server/`、`store/`、`ai/`、`geo/`、`rootfs/`、`monitor/`、`benchmark/`、`remote_desktop/`、`virt/`、`workspace/`、`view/` 和 `app/`；主题测试（`theme_*_test.dart`）直接放在 `unit/` 下。同一功能的 store、provider 和 model 测试放在一起。`store/` 存放共用的存储设施（数据库、schema、备份恢复和设置）；`app/` 存放版本、本地化、崩溃上报、诊断和构建检查。

## Rust 测试

```bash
# Rust workspace 的全部测试
cargo test --workspace

# FFI parity test：先构建 FFI crate
cargo build -p sbm_ffi
flutter test test/unit/app/frb_parser_test.dart
```

`crates/sbm_parser/tests/dart_compat.rs` 使用与 Dart 相同的 fixture，锁定两侧 parser 的行为。

### 需要显式开启的测试

以下测试需要真实主机；未设置环境变量时会静默跳过：

```bash
# SSH end-to-end：上传生成的脚本，在远端执行并与直接命令输出比较
# 在 workspace 根目录的 .env 中设置：
# SBM_E2E_SSH_HOST=<SSH 目标或 ~/.ssh/config 别名>
cargo test -p sbm_parser --test ssh_e2e

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

## 单元测试（Unit Test）

单元测试用于验证纯业务逻辑、数据模型与解析器：

```dart
test('calculates CPU percentage', () {
  final cpu = CpuModel(usage: 75.0);
  expect(cpu.usagePercentage, '75%');
});
```

## 组件测试（Widget Test）

组件测试用于验证 UI 组件的布局、文本渲染与交互行为：

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

涉及本地存储写入的组件测试必须在 `setUp` 中调用 `openTestDb()`，并在 `tearDown` 中调用 `closeTestDb()`（先排空挂起的写入操作再关闭 SQLite 连接）。测试应通过常规构造函数访问隔离数据库，迁移测试则使用生产环境的 `setting` 存储名。切勿在生产代码中添加仅用于测试的构造函数、状态重置方法或可变网络工厂；有状态服务应遵循正常的实例生命周期，HTTP 与文件系统的测试替身统一放在 `test/helpers/` 下。

对于包含文本输入框或其他持续请求帧刷新（frame）的组件，请勿调用 `pumpAndSettle()`，应改用固定步长的 `pump(duration)` 并设置合理的超时时间。

## 状态测试（Provider Test）

Provider 测试用于验证状态变更与异步返回结果：

```dart
test('returns server status', () async {
  final container = ProviderContainer();
  final status = await container.read(serverStatusProvider(testServer).future);
  expect(status, isA<StatusModel>());
  container.dispose();
});
```

## 外部依赖隔离

默认测试必须保持确定性。解析器、数据模型、命令组装及常规组件测试均不得访问真实网络或外部服务器。涉及外部服务边界时，请使用专用的 Fake、Fixture 或 Mock。

前文提到的 SSH 端到端测试属于例外，仅在显式配置环境变量后才会运行，因此直接执行 `cargo test --workspace` 不依赖任何外部服务。

## 存储迁移测试

用户设备上的存储结构迁移通常只执行一次。一旦写入迁移完成标记，应用便不会再次读取旧版数据，因此迁移逻辑中的缺陷往往会导致数据静默丢失而非直接报错崩溃。

每一版迁移都必须保留永久的回归测试，并使用历史发布版本真实写入的二进制数据（Fixture）：

| 文件 | 作用 |
|---|---|
| `test/migration/hive_release_migration_test.dart` | 对每个历史版本的 Fixture 执行 Hive 导入与已注册的数据库迁移 |
| `test/fixtures/hive_v{1466,1480,1491}/` | 对应历史发布版本真实写出的 Hive Box 文件、生成脚本及说明 |
| `test/migration/hive_import_test.dart` | 验证导入中断重试、幂等性及按 Box 记录的迁移进度 |
| `test/migration/m0NN_*_test.dart` | 针对每一步 SQLite Schema 迁移的独立验证测试 |

Fixture 一旦纳入回归测试，绝不能为了绕过测试失败而重新生成。使用当前版本的 Adapter 生成测试数据只能证明当前代码自洽，无法验证它仍能正确解析旧版本写出的数据格式。

### 生成真实历史版本的 Fixture

1. 使用 `git worktree add /tmp/<tag> <tag>` 检出目标历史版本，初始化子模块并运行 `flutter pub get`。
2. 将 `test/fixtures/hive_v1466/gen_fixture.dart.txt` 复制到临时测试目录中，根据该历史版本的模型、Adapter 和依赖版本调整代码，使用旧版本自身的代码生成 `.hive` 二进制文件。样本数据应涵盖可选字段、枚举值、各类 Store 以及非 ASCII 字符、引号和换行符。
3. 将生成的二进制文件复制到 `test/fixtures/hive_v<tag>/`，保留生成脚本说明与 README，随后清理临时 worktree。
4. 在当前分支使用公开的 Store API 编写读取断言，并验证迁移后的数据库记录中无残留旧字段。

生成脚本以 `.txt` 扩展名入库，以便与当前源码树的静态分析隔离。

## 集成测试（Integration Test）

`integration_test/` 用于验证 `flutter test` 无法覆盖的平台集成行为。由于单元测试运行在不加载原生插件的 `flutter_tester` 环境中，无法执行涉及平台通道或 FFI 动态库的逻辑，集成测试则直接运行在真实设备或模拟器上：

| 文件 | 验证内容 |
|---|---|
| `local_shell_test.dart` | 本机 Shell 是否能正常启动 |
| `rootfs_shell_test.dart` | 内置 Alpine 环境能否通过应用接口正常执行命令 |
| `android_exec_test.dart` | Android 应用私有目录下的二进制执行权限 |
| `android_rootfs_test.dart` | Android 端 `proot` 引导机制 |
| `ios_rootfs_test.dart` | iOS 端内置 Linux 运行环境 |
| `ios_bench_test.dart` | 真实硬件上的内置环境性能开销 |
| `ios_load_test.dart` | 内置环境高负载运行时对宿主应用的影响 |
| `sandbox_import_test.dart` | App Store 沙盒构建版本的数据迁移接管 |

```bash
# 需连接真机或启动模拟器
flutter test integration_test/local_shell_test.dart
```

运行 `make analyze` 时同样会检查 `integration_test/` 目录。

### iOS 17+ 无线调试设备

当 Xcode 通过局域网无线连接 iOS 17+ 真机时，需显式发布驱动端口：

```bash
flutter drive --publish-port \
  --driver=integration_test/driver.dart \
  --target=integration_test/ios_rootfs_test.dart
```

首次运行时系统会弹窗请求本地网络权限，请点击允许。

## 测试编写准则

1. 采用 Arrange–Act–Assert（准备、执行、断言）结构组织测试代码。
2. 测试名称应描述业务行为，而非内部实现细节。
3. 针对核心行为编写充分断言，同时保持单个测试职责单一。
4. 使用 Fake 或 Fixture 隔离外部环境依赖。
5. 覆盖空列表、缺失字段、非法输入与权限拒绝等边界场景。

## 固定二进制样本（Fixtures）

Rootfs 签名等二进制测试样本必须保持原始字节不变：`.gitattributes` 已将 JSON 换行符固定为 LF，并将签名文件标记为二进制。切勿为了通过测试而重新签名或重新生成样本文件（样本代表历史发布版本真实产出的字节，改写样本将失去回归验证意义）。

测试应优先覆盖真实生产代码路径：样本数据应直接交由真实安装器解析，HTTP 测试应使用本地回环 Socket 而非过度 Mock。
