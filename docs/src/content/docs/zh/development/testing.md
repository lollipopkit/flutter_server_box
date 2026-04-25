---
title: 测试指南
description: 测试策略与运行测试
---

## 运行测试

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/battery_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage
```

## 测试结构

测试位于 `test/` 目录中。当前测试套件基本是扁平结构，按解析器、模型和工具行为分组，例如 `cpu_test.dart`、`container_test.dart` 和 `ssh_config_test.dart`。

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

避免让测试依赖真实 SSH 服务器。解析器、模型和命令构建测试应保持确定性；当功能引入服务边界时，再添加有针对性的 fake 或 fixture。

## 集成测试

当前仓库没有 `integration_test/` 测试套件。只有当功能需要端到端设备或完整应用流程覆盖时，再新增集成测试。dart
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
