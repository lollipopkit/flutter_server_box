---
title: 架构
description: 架构模式与设计决策
---

Server Box 遵循整洁架构 (Clean Architecture) 原则，在数据层、领域层和表现层之间实现了清晰的分离。

## 分层架构

```
┌─────────────────────────────────────┐
│          表现层 (Presentation)      │
│         (lib/view/page/)            │
│  - 页面、组件、控制器                │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│         业务逻辑层 (Business Logic) │
│      (lib/data/provider/)           │
│  - Riverpod Provider                │
│  - 状态管理                         │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│           数据层 (Data)             │
│      (lib/data/model/, store/)      │
│  - 模型、存储、服务                  │
└─────────────────────────────────────┘
```

## 关键模式

### 状态管理：Riverpod

- **代码生成**：使用 `riverpod_generator` 实现类型安全的 provider
- **State Notifiers**：用于包含业务逻辑的可变状态
- **Async Notifiers**：用于处理加载中和错误状态
- **Stream Providers**：用于处理实时数据

### 不可变模型：Freezed

- 所有数据模型均使用 Freezed 实现不可变性
- 使用联合类型 (Union types) 表示不同状态
- 内置 JSON 序列化支持
- 提供 CopyWith 扩展以便于更新

### 本地存储：Hive

- **hive_ce**：Hive 的社区版
- 无需手动添加 `@HiveField` 或 `@HiveType` 注解
- 类型适配器 (Type adapters) 自动生成
- 持久化键值对存储

## 依赖注入 (DI)

服务和存储类通过以下方式注入：

1. **Provider**：向 UI 层暴露依赖
2. **GetIt**：服务定位器（在适用情况下使用）
3. **构造函数注入**：显式声明依赖关系

## 数据流

```
用户操作 → Widget → Provider → 服务/存储 → 模型更新 → UI 重构
```

1. 用户与组件交互
2. 组件调用 provider 方法
3. Provider 通过服务/存储更新状态
4. 状态更改触发 UI 重新构建
5. 组件反映最新状态

## 自定义依赖

项目使用了多个自定义分支以扩展功能：

- **dartssh2**：增强的 SSH 功能
- **xterm**：支持移动端的终端模拟器
- **fl_lib**：共享的 UI 组件和工具类

## 多线程处理

- **Isolates**：将繁重的计算任务移出主线程
- **computer 包**：多线程工具类
- **Async/Await**：非阻塞式 I/O 操作
