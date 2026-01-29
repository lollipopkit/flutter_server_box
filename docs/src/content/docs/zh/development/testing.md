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

测试文件位于 `test/` 目录中，其结构与 `lib` 目录保持一致：

```
test/
├── data/
│   ├── model/
│   └── provider/
├── view/
│   └── widget/
└── test_helpers.dart
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

## Mock 模拟

对外部依赖使用 Mock 模拟：

```dart
class MockSshService extends Mock implements SshService {}

test('应当能连接到服务器', () async {
  final mockSsh = MockSshService();
  when(mockSsh.connect(any)).thenAnswer((_) async => true);

  // 使用 mock 进行测试
});
```

## 集成测试

测试完整的用户流程（位于 `integration_test/`）：

```dart
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
