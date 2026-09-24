---
title: 桌面端功能
description: macOS、Linux 和 Windows 的平台特定功能
---

桌面版 Server Box 提供更大的工作区域、完整键盘支持，以及各平台特有的窗口功能。

## macOS

### 菜单栏

macOS 菜单栏包含以下菜单和快捷键：

- **Server Box**：关于、设置（⌘,）和退出（⌘Q）
- **导航**：切换首页标签页（⌘1 … ⌘9）
- **信息**：查看项目相关链接

### 窗口管理

App 会记住窗口大小和位置，并在下次启动时恢复。

## Linux

- 支持 X11 和 Wayland
- 集成系统文件选择器
- 以 AppImage 形式分发

## Windows

- 支持原生窗口控制
- 以便携式 zip 包分发

## 桌面端通用功能

### 主题

- 浅色
- 深色
- 跟随系统

AMOLED 已改为内置主题，Dark 使用纯黑背景，Light 使用标准浅色配色。
原 AMOLED 自动迁移为 Dark + AMOLED，原自动 AMOLED 迁移为 System + AMOLED。
主题包声明支持 Light 和/或 Dark；只支持一种模式时，ThemeMode 会锁定并显示说明。

### 与移动端相比

- 更大的显示区域，适合同时查看多个指标
- 全尺寸键盘，终端输入更方便
- 文件传输和批量操作更高效
- 更适合同时处理多个任务
