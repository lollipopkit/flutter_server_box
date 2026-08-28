---
title: 本机终端
description: 在运行 Server Box 的设备上打开 shell
---

如果当前构建包含相应能力，终端标签页会在服务器列表之前显示本机 shell 和 Server Box 提供的 Linux userland。

它们排在前面是因为本机始终可访问，也不需要凭据。

## 本机 shell

本机 shell 运行在 Server Box 所在的设备上。在支持选择 shell 的平台上，App 使用 `$SHELL` 指定的 shell，因此通常与终端 App 打开的 shell 相同。

| 平台 | 可用性 |
|---|---|
| Linux、Windows | 可用 |
| macOS（DMG 版本） | 可用 |
| macOS（App Store 版本） | 不可用 |
| Android | 可用，但 shell 能力与桌面端不同 |
| iOS | 不可用 |

**macOS App Store 版本不支持本机 shell。** 该版本运行在沙盒中，沙盒进程无法打开伪终端，因此 App 不显示这个入口。DMG 版本没有该沙盒限制，可以提供本机 shell。App 会检查当前运行的构建版本，界面会据此显示或隐藏入口。

**iOS 不支持本机 shell。** App Store App 无法启动进程，沙盒中也没有可用于启动的 `/bin/sh`。

## Linux 环境

如果平台不提供 shell，或者本机 shell 的能力有限，Server Box 可以安装独立的 Linux userland。目前默认提供 Alpine 3.22.5，也可以从 App 提供的 release 列表中选择其他发行版和版本，包括 Debian 和 Ubuntu。

它会在终端标签页中显示为 **<发行版> <版本>**，紧邻本机 shell，因为二者都运行在同一设备上。发行版和版本在安装时选择；更新只在同一 profile 内进行，不提供重新选择。

Android 和 iOS 使用不同的实现：

- **Android**：解包真实的 Linux rootfs，并使用 `proot` 进入。当前仅支持 arm64；rootfs 从网络下载 tarball，下载内容会通过固定摘要校验。
- **iOS**：无法直接启动进程，因此 App 内置 Linux 解释器；这里的“环境”是该解释器使用的文件系统。

**是否提供这些功能取决于构建配置。** 某个构建可能只提供本机 shell、只提供 Alpine 环境、两者都提供，或两者都不提供。如果终端标签页中没有对应入口，说明当前构建未包含该能力。

### 适用场景

- 在手机上使用 `curl`、`dig`、`ssh` 或 `jq` 等工具
- 执行不希望直接在生产服务器上进行的临时操作
- 为 Agent 提供与设备文件系统隔离的执行目标，详见[Agent](/docs/zh/advanced/agent/)

环境使用对应发行版的标准 userland，因此可以使用它自带的包管理器安装软件包：Alpine 用 `apk add`，Debian 和 Ubuntu 用 `apt install`。

### 文件隔离

Alpine userland 有独立的文件系统，无法读取手机存储、App 数据、私钥或用户文件。因此，移动端的**在本机执行命令**与桌面端含义不同：移动端使用独立的 userland，桌面端使用计算机本身的 shell。

## 与服务器终端的区别

终端模拟器、虚拟键盘和标签页等上层功能相同，区别只在于字节流的来源。

本机 shell 不需要验证 host key，也不会像服务器连接那样自动重连；它不会出现在服务器列表或状态图表中。它是终端会话，不是被监控的服务器。
