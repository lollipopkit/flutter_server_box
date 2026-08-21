---
title: 终端实现
description: SSH 终端的内部工作原理
---

终端是功能最复杂的模块之一，基于自定义的 xterm.dart 分支构建。

## 字节从哪里来

字节流之上只有一套实现，包括同一个模拟器、同一套虚拟键盘和同样的标签页。之下，
`ShellBackend` 有四个实现：

| 后端 | 字节来源 |
|---|---|
| `SshShellBackend` | SSH channel；本页其余部分讲的就是它 |
| `LocalShellBackend` | 本机的 shell；Android 上是 Alpine 容器内的 shell |
| `IshShellBackend` | iOS 上的 Linux 解释器 |
| `MonitorShellBackend` | monitor agent 的 `/terminal/ws` |

调用方打开一个会话并向它写入，上层 UI 不会去问是四个中的哪一个应答的。前两个见
[本机终端](/docs/zh/advanced/local-terminal/)，最后一个见
[Monitor Agent](/docs/zh/advanced/monitor-agent/)。

本页其余部分介绍 SSH 路径。其他后端提供相同的接口。

## 架构概览

```
┌─────────────────────────────────────────────┐
│              终端 UI 层                     │
│  - 标签页管理                               │
│  - 虚拟键盘                                 │
│  - 文本选择                                 │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         xterm.dart 模拟器                   │
│  - PTY (伪终端)                             │
│  - VT100/ANSI 模拟                          │
│  - 渲染引擎                                 │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SSH 客户端层                       │
│  - SSH 会话                                 │
│  - 通道管理                                 │
│  - 数据流                                   │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            远程服务器                       │
│  - Shell 进程                               │
│  - 命令执行                                 │
└─────────────────────────────────────────────┘
```

## 终端会话生命周期

### 1. 创建会话

```dart
Future<TerminalSession> createSession(Spi spi) async {
  final session = TerminalSession(source: ServerSource(spi));
  await session.connect();
  final shell = await session.openShell();
  if (shell == null) throw StateError('No shell backend');
  session.bindForeground(shell);
  return session;
}
```

会话的 backend 使用 `SSHPtyConfig` 创建 SSH PTY，并负责 shell 生命周期。同一个
`TerminalSession` 形状也用于本机和 monitor agent backend。

### 2. 终端模拟

xterm.dart 分支提供：

**VT100/ANSI 模拟：**
- 光标移动
- 颜色（支持 256 色）
- 文本属性（粗体、下划线等）
- 滚动区域
- 交替屏幕缓冲区

**渲染：**
- 基于行的渲染
- 双向文本支持
- Unicode/Emoji 支持
- 减少不必要的重绘

### 3. 数据流向

```
用户输入
    ↓
虚拟键盘 / 实体键盘
    ↓
终端模拟器 (按键 → 转义序列)
    ↓
SSH 通道 (发送)
    ↓
远程 PTY
    ↓
远程 Shell
    ↓
命令输出
    ↓
SSH 通道 (接收)
    ↓
终端模拟器 (解析 ANSI 编码)
    ↓
渲染到屏幕
```

## 多标签页系统

### 标签页管理

```dart
class TerminalTabs {
  final Map<String, TabData> _tabs = {};
  String? _activeTabId;

  void createTab(Server server) {
    final id = _generateTabId(server);
    _tabs[id] = TabData(
      id: id,
      name: _generateTabName(server),
      session: createSession(server),
    );
    _activeTabId = id;
  }

  String _generateTabName(Server server) {
    final count = _tabs.values
        .where((t) => t.name.startsWith(server.name))
        .length;
    return count == 0 ? server.name : '${server.name}($count)';
  }
}
```

### 会话持久化

标签页在导航切换时会保持状态：
- SSH 连接保持活跃
- 终端状态保留
- 滚动缓冲区保留
- 输入历史保留

## 虚拟键盘

虚拟键盘是所有平台通用的 Flutter widget,渲染在终端上方
(可用按键定义在 `lib/data/model/ssh/virtual_key.dart`),
在移动端，虚拟键盘与系统键盘同时显示。

### 键盘按键

| 按钮 | 操作 |
|--------|--------|
| **Esc / Tab / Home / End / PgUp / PgDn / 方向键** | 发送对应按键 |
| **Ctrl / Alt / Shift** | 为下一个按键附加修饰符 |
| **IME** | 显示/隐藏系统键盘 |
| **剪贴板 (Clipboard)** | 上下文感知的复制/粘贴 |
| **SFTP** | 在 SFTP 浏览器中打开当前目录 |
| **脚本 (Snippet)** | 选择并执行命令脚本 |
| **符号** | `/ \ _ + = - ( ) [ ] { } < >` 等 |

按键集合与顺序可在设置中自定义。

## 文本选择

1. **长按**：进入选择模式
2. **拖动**：扩大选择范围
3. **释放**：复制到剪贴板

## 字体与尺寸

### 尺寸计算

```dart
class TerminalDimensions {
  static Size calculate(double fontSize, Size screenSize) {
    final charWidth = fontSize * 0.6;  // 等宽字体宽高比
    final charHeight = fontSize * 1.2;

    final cols = (screenSize.width / charWidth).floor();
    final rows = (screenSize.height / charHeight).floor();

    return Size(cols.toDouble(), rows.toDouble());
  }
}
```

### 捏合缩放（Pinch-to-Zoom）

```dart
GestureDetector(
  onScaleStart: () => _baseFontSize = currentFontSize,
  onScaleUpdate: (details) {
    final newFontSize = _baseFontSize * details.scale;
    resize(newFontSize);
  },
)
```

## 配色方案

- **浅色 (Light)**：浅色背景，深色文字
- **深色 (Dark)**：深色背景，浅色文字
- **AMOLED**：纯黑背景

## 性能

xterm.dart fork 使用自定义 painter 渲染,仅在终端内容更新时重绘;
输出会先缓冲并合并，再传给终端模拟器。

## 特色功能

### 脚本执行

```dart
void executeSnippet(Snippet snippet) {
  final formatted = formatSnippet(snippet);
  terminal.paste(formatted);
  terminal.paste('\r');  // 执行
}
```

### SFTP 快速访问

```dart
void openSftp() async {
  final cwd = await terminal.getCurrentWorkingDirectory();
  Navigator.push(
    context,
    SftpPage(initialPath: cwd),
  );
}
```
