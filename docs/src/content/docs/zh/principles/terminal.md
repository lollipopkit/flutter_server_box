---
title: 终端实现
description: SSH 终端的内部工作原理
---

SSH 终端是功能最复杂的模块之一，基于自定义的 xterm.dart 分支构建。

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
  // 1. 获取 SSH 客户端
  final client = await genClient(spi);

  // 2. 创建 PTY
  final pty = await client.openPty(
    term: 'xterm-256color',
    cols: 80,
    rows: 24,
  );

  // 3. 初始化终端模拟器
  final terminal = Terminal(
    backend: PtyBackend(pty),
  );

  // 4. 设置调整尺寸处理程序
  terminal.onResize.listen((size) {
    pty.resize(size.cols, size.rows);
  });

  return TerminalSession(
    terminal: terminal,
    pty: pty,
    client: client,
  );
}
```

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
- 优化重绘

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

### 平台特定实现

**iOS：**
- 基于 UIView 的自定义键盘
- 可通过键盘按钮切换
- 根据焦点自动显示/隐藏

**Android：**
- 自定义输入法
- 与系统键盘集成
- 快速操作按钮

### 键盘按键

| 按钮 | 操作 |
|--------|--------|
| **切换 (Toggle)** | 显示/隐藏系统键盘 |
| **Ctrl** | 发送 Ctrl 修饰符 |
| **Alt** | 发送 Alt 修饰符 |
| **SFTP** | 打开当前目录 |
| **剪贴板 (Clipboard)** | 上下文感知的复制/粘贴 |
| **脚本 (Snippets)** | 执行命令脚本 |

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

### 捏合缩放 (Pinch-to-Zoom)

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

## 性能优化

- **脏矩形 (Dirty rectangle)**：仅重绘更改的区域
- **行缓存 (Line caching)**：缓存渲染的行
- **延迟滚动 (Lazy scrolling)**：长缓冲区的虚拟滚动
- **批量更新**：合并多次写入
- **压缩**：压缩滚动缓冲区内容
- **防抖 (Debouncing)**：对快速输入进行防抖处理

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
