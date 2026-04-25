---
title: 代码生成
description: 使用 build_runner 进行代码生成
---

Server Box 大量使用代码生成技术来处理模型、状态管理和序列化。

## 何时运行代码生成

在修改以下内容后需要运行：

- 带有 `@freezed` 注解的模型
- 带有 `@JsonSerializable` 的类
- Hive 模型
- 带有 `@riverpod` 的 Provider
- 本地化文件 (ARB 文件)

## 运行代码生成

### 普通构建

用于常规代码生成：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 清理后重建

仅在生成缓存异常或生成结果不一致时使用。先清理，再重新生成：

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## 生成的文件类型

### Freezed (`*.freezed.dart`)

具有联合类型 (Union types) 的不可变数据模型：

```dart
@freezed
class ServerState with _$ServerState {
  const factory ServerState.connected() = Connected;
  const factory ServerState.disconnected() = Disconnected;
  const factory ServerState.error(String message) = Error;
}
```

### JSON 序列化 (`*.g.dart`)

由 `json_serializable` 生成：

```dart
@JsonSerializable()
class Server {
  final String id;
  final String name;
  final String host;

  Server({required this.id, required this.name, required this.host});

  factory Server.fromJson(Map<String, dynamic> json) =>
      _$ServerFromJson(json);
  Map<String, dynamic> toJson() => _$ServerToJson(this);
}
```

### Riverpod Provider (`*.g.dart`)

由 `@riverpod` 注解生成：

```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  int build() => 0;
}
```

### Hive 适配器 (`*.g.dart`)

为 Hive 模型 (hive_ce) 自动生成：

```dart
@HiveType(typeId: 0)
class ServerModel {
  @HiveField(0)
  final String id;
}
```

## 生成本地化代码

```bash
flutter gen-l10n
```

根据 `lib/l10n/*.arb` 文件生成 `lib/generated/l10n/` 目录下的代码。

## 提示

- 使用 `--delete-conflicting-outputs` 避免冲突
- 如果生成文件已被本仓库跟踪，请继续提交这些生成文件
- **切勿**手动编辑生成的文件
