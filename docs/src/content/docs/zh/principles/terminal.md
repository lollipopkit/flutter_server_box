---
title: 终端实现
description: Server Box 终端的工作方式
---

终端是 Server Box 中功能较多的模块之一，底层使用自定义的 xterm.dart fork。

## 终端数据来源

无论数据来自哪里，字节流之上的 UI、终端模拟器、虚拟键盘和标签页都使用同一套实现。`ShellBackend` 有以下实现：

| Backend | 数据来源 |
|---|---|
| `SshShellBackend` | SSH channel；下文主要介绍此路径 |
| `LocalShellBackend` | 本机 shell；Android 上也可运行 Alpine 环境 |
| `IshShellBackend` | iOS 上的 Linux interpreter |
| `MonitorShellBackend` | Monitor agent 的 `/api/v1/terminal/ws` |

调用方只需打开 session 并读写字节流，不需要关心具体 backend。前两种本机实现详见[本机终端](/docs/zh/advanced/local-terminal/)，Monitor backend 详见[Monitor Agent](/docs/zh/advanced/monitor-agent/)。

下文介绍 SSH 路径；其他 backend 提供相同的上层接口。

## 架构概览

```text
┌─────────────────────────────────────────────┐
│ 终端 UI 层                                   │
│ 标签页、虚拟键盘、文本选择                    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ xterm.dart 模拟器                            │
│ PTY、VT100/ANSI 模拟、渲染                   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ SSH client 层                                │
│ session、channel、数据流                     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 远程服务器                                   │
│ shell 进程、PTY、命令执行                    │
└─────────────────────────────────────────────┘
```

## 终端 Session 生命周期

### 创建 session

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

SSH backend 使用 `SSHPtyConfig` 创建 SSH PTY，并负责 shell 的生命周期。`TerminalSession` 也用于本机和 Monitor agent backend。

### 终端模拟

xterm.dart fork 提供：

**VT100/ANSI 模拟：**

- 光标移动
- 256 色
- 粗体、下划线等文字属性
- 滚动区域
- alternate screen buffer

**渲染：**

- 按行渲染
- 双向文字
- Unicode 和 Emoji
- 合并更新，减少不必要的重绘

### 数据流

```text
用户输入
    ↓
虚拟键盘或实体键盘
    ↓
终端模拟器（按键 → escape sequence）
    ↓
SSH channel（发送）
    ↓
远程 PTY
    ↓
远程 shell
    ↓
命令输出
    ↓
SSH channel（接收）
    ↓
终端模拟器（解析 ANSI sequence）
    ↓
渲染到屏幕
```

## 多标签页

每个标签页拥有独立的 terminal session。切换页面时，session 和终端状态会保留：

- SSH 连接继续保持，直到连接断开或 session 被关闭
- 终端状态保留
- scrollback buffer 保留
- 输入历史保留

标签页名称由服务器名称和序号组成；同一服务器打开多个标签页时，名称会追加序号。

## 虚拟键盘

虚拟键盘是跨平台的 Flutter Widget，显示在终端上方。可用按键定义于 `lib/data/model/ssh/virtual_key.dart`。移动端可以同时显示虚拟键盘和系统键盘。

| 按键 | 操作 |
|---|---|
| **Esc / Tab / Home / End / PgUp / PgDn / 方向键** | 发送对应按键 |
| **Ctrl / Alt / Shift** | 为下一次输入附加修饰键 |
| **IME** | 显示或隐藏系统键盘 |
| **Clipboard** | 根据当前上下文复制或粘贴 |
| **SFTP** | 在 SFTP 浏览器中打开当前目录 |
| **Snippet** | 选择并执行命令片段 |
| **符号** | 输入 `/ \ _ + = - ( ) [ ] { } < >` 等符号 |

按键集合和顺序可以在设置中自定义。

## 文本选择

1. 长按终端文字进入选择模式。
2. 拖动选择范围。
3. 松开后复制到剪贴板。

## 字体和尺寸

终端根据字体大小和可用空间计算行列数：

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

移动端支持捏合缩放终端文字；字体大小改变后会重新计算 PTY 尺寸。

## 配色方案

- **浅色（Light）**：浅色背景、深色文字
- **深色（Dark）**：深色背景、浅色文字
- **AMOLED**：纯黑背景

## 性能

xterm.dart fork 使用自定义 painter，仅在终端内容变化时重绘。远程输出会先合并，再交给终端模拟器处理，减少大量小片段更新造成的开销。

## 特色功能

- **Snippet 执行**：将保存的命令插入终端并执行。
- **SFTP 快速访问**：从终端当前工作目录打开 SFTP 浏览器。
- **跨 backend**：本机 shell、Alpine 环境和 Monitor terminal 使用与 SSH 相同的上层终端 UI。
