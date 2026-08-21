---
title: 架构概览
description: 应用程序的高层架构设计
---

Server Box 采用分层架构，明确分离各层职责。

## 架构分层

```
┌─────────────────────────────────────────────────┐
│          表现层 (UI)                            │
│          lib/view/page/, lib/view/widget/       │
│  - 页面、组件、控制器                            │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         业务逻辑层                              │
│         lib/data/provider/                      │
│  - Riverpod Provider, State Notifier            │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│           数据访问层                            │
│         lib/data/store/, lib/data/model/        │
│  - SQLite 存储、数据模型                         │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         外部集成层                              │
│  - SSH (dartssh2), 终端 (xterm), SFTP           │
│  - monitor agent HTTP API                       │
│  - 平台特定代码 (iOS, Android 等)               │
└─────────────────────────────────────────────────┘
```

## 应用基础

### 入口点

`lib/main.dart` 初始化应用：

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 根组件

`MyApp` 提供以下功能：
- **主题管理**：浅色/深色主题切换
- **路由配置**：导航结构
- **Provider Scope**：依赖注入根节点

### 首页

`HomePage` 负责导航：
- **标签页界面**：服务器、SSH、文件、脚本
- **状态管理**：各标签页独立状态
- **导航**：功能入口

## 核心系统

### 状态管理：Riverpod

**为何选择 Riverpod？**
- 编译时安全
- 易于测试
- 不依赖 `BuildContext`
- 跨平台兼容性好

**使用的 Provider 类型：**
- `StateProvider`：简单的可变状态
- `AsyncNotifierProvider`：处理加载/错误/数据状态
- `StreamProvider`：实时数据流
- Future providers：一次性异步操作

### 数据持久化：SQLite

应用数据存储在一个加密的 SQLite 数据库 `store.db` 中。设置和历史记录使用键值存储，具有关联关系的记录使用实体表。

**存储类：**
- `SettingStore`：应用偏好设置
- `ServerStore`：服务器配置
- `SnippetStore`：命令脚本
- `PrivateKeyStore`：SSH 密钥

### 不可变模型：Freezed

**优势：**
- 编译时不可变性
- 联合类型处理状态
- 内置 JSON 序列化
- `copyWith` 方法

## 跨平台策略

### 插件系统

Flutter 插件提供平台集成：

| 平台 | 集成方式 |
|----------|-------------------|
| iOS | Swift Package Manager, Swift/Obj-C |
| Android | Gradle, Kotlin/Java |
| macOS | Swift Package Manager, Swift |
| Linux | CMake, C++ |
| Windows | CMake, C++ |

### 平台特定功能

**仅限 iOS：**
- 实时活动 (Live Activities)
- Apple Watch 配套应用

**移动端：**
- 主屏幕小组件(iOS/Android)
- 推送通知(经由 ServerBox Monitor)

**仅限 Android：**
- 后台运行(前台服务)

**仅限桌面端：**
- 原生菜单栏(macOS)
- 窗口尺寸持久化

## 自定义依赖

### dartssh2 分支

增强版 SSH 客户端，具有：
 - 更完善的移动端支持
- 增强的错误处理
- 性能优化

### xterm.dart 分支

终端模拟器，具有：
- 移动端优化的渲染
- 手势支持
- 虚拟键盘集成

### fl_lib

共享工具包，包含：
- 通用组件
- 扩展方法
- 辅助函数

## 构建系统

### fl_build 包

自定义构建系统，用于：
- 多平台构建
- 代码签名
- 资源打包
- 版本管理

### 构建流程

```
make.dart (版本计算) → fl_build (执行构建) → 平台产物
```

1. **预构建**：从 Git 计算版本号
2. **构建**：为目标平台编译
3. **后构建**：打包和签名

## 数据流示例

### 连接方式

访问服务器有两种方式：SSH，或通过服务器上的 monitor agent HTTP API。两者互斥：
monitor 服务器不携带任何 SSH 凭据。

可用功能由 `ServerCapabilities` 决定，因此需要 shell 的功能不必关心具体由谁提供：

| | SSH | monitor agent |
|---|---|---|
| 状态、图表 | 支持 | 支持 |
| 历史数据 | 不支持，只有 App 打开期间采样的数据 | 支持，agent 会持续采样 |
| 命令（进程、systemd、容器、电源） | 支持 | 需要 agent 的 `full_access` |
| 终端 | 支持 | 需要 `full_access` |
| 文件浏览 | 支持，经 SFTP | 需要 agent 的文件 API，且限制在其配置的 roots 内 |
| SFTP 传输、端口转发 | 支持 | 不支持 |

monitor 服务器没有 SFTP 和端口转发，因为 agent 没有端点可以将连接中继到 App
指定的地址。

### 服务器状态更新

经 SSH:

```
1. 定时器触发 →
2. Provider 调用 service →
3. Service 执行 SSH 命令脚本 →
4. 原始输出交由共享 Rust 解析库（sbm_parser，经 FFI）解析 →
5. 状态更新 →
6. UI 使用新数据重新构建
```

经 monitor agent:

```
1. 定时器触发 →
2. Provider 请求 agent 的 /api/v1/metrics →
3. agent 已经使用同一个 Rust crate 完成解析 →
4. 状态更新 →
5. UI 使用新数据重新构建
```

两端都用 `sbm_parser` 解析，因此两条路径产出相同的 `ServerStatus`。

### 用户操作流

```
1. 用户点击按钮 →
2. Widget 调用 provider 方法 →
3. Provider 更新状态 →
4. 状态更改触发重构 →
5. UI 反映新状态
```

## 安全架构

### 数据保护

- **密码 / SSH 密钥**：存储在加密的 SQLite 数据库中；加密密钥本身保存在平台安全存储（Keychain/Keystore）
- **主机指纹**：安全存储
- **会话数据**：不进行持久化

### 连接安全

- **主机密钥验证**：检测中间人攻击
- **加密**：标准 SSH 加密
- **不存储明文**：敏感数据不会以明文存储
