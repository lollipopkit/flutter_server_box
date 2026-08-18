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

## 集成测试

`integration_test/` 存放 `flutter test` 无法回答的问题。单元测试跑在 `flutter_tester` 下，它不加载任何 plugin，所以经 plugin 或 FFI 到达的代码在那里从未真正运行过。这些测试运行在真机上的真实 App 里：

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

`make analyze` 也覆盖这个目录（`flutter analyze lib test integration_test`）。dart
testWidgets('添加服务器流程', (tester) async {
  await tester.pumpWidget(MyApp());

  // 点击添加按钮
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // 填写表单
  await tester.enterText(find.byKey(Key('name')), 'Test Server');
  // ...
});
```

## 最佳实践

1. **Arrange-Act-Assert**：清晰地组织测试结构（准备-执行-断言）
2. **描述性名称**：测试名称应描述其行为
3. **每个测试仅一个断言**：保持测试的专注度
4. **Mock 外部依赖**：不要依赖真实服务器
5. **测试边缘情况**：处理空列表、空值等
