---
title: 本机终端
description: 在运行 Server Box 的设备上打开 shell
---

当前构建支持时，终端标签页会在远程服务器之前显示本机执行入口：运行在**本机**的 shell，以及 Server Box 提供的 Linux userland。

这两个入口无需连接服务器或提供凭据。

## 本机 shell

本机 shell 运行在 Server Box 所在的计算机或设备上。在支持选择 shell 的平台上，App 会启动 `$SHELL` 指定的 shell，通常与终端 App 打开的 shell 相同。

| 平台 | 可用性 |
|---|---|
| Linux、Windows | 可用 |
| macOS（DMG 版本） | 可用 |
| macOS（App Store 版本） | 不可用 |
| Android | 可用，但 shell 能力与桌面端不同 |
| iOS | 不可用 |

**macOS App Store 版本没有本机 shell。** 该版本受沙盒限制，无法打开伪终端，因此不会显示本机 shell 入口。DMG 版本可以提供本机 shell。Server Box 会检查当前构建，只在功能可用时显示入口。

**iOS 不支持本机 shell。** App Store App 无法启动进程，沙盒中也没有 `/bin/sh` 可供启动。

## Linux 环境

如果平台没有 shell，或本机 shell 功能有限，Server Box 可以安装独立的 Linux userland。目前默认版本为 Alpine 3.22.5；release 列表也可能提供 Debian、Ubuntu 等其他发行版和版本。

终端标签页会以 **<发行版> <版本>** 标记该环境，并将其列在本机 shell 旁边。安装时选择发行版和版本；更新会保留当前 profile，不能借更新切换版本。

Android 和 iOS 使用不同的实现：

- **Android：**解包 Linux rootfs 并通过 `proot` 进入。当前构建支持 arm64；App 会下载 rootfs tarball，并用固定摘要校验文件。
- **iOS：**App 无法直接启动进程，因此内置 Linux 解释器。这里的 userland 是该解释器使用的文件系统。

**是否提供这些功能取决于构建配置。** 某个构建可能只提供本机 shell、只提供 Alpine 环境、两者都提供，或两者都不提供。如果终端标签页中没有对应入口，说明当前构建未包含该能力。

### 适用场景

- 在手机上使用 `curl`、`dig`、`ssh` 或 `jq` 等工具
- 执行不希望直接在生产服务器上进行的临时操作
- 为 Agent 提供与设备文件系统隔离的执行目标，详见[Agent](/docs/zh/advanced/agent/)

每个 userland 都采用对应发行版的标准目录结构和包管理器。例如，Alpine 使用 `apk add` 安装软件包，Debian 和 Ubuntu 使用 `apt install`。

### 文件隔离

Alpine userland 使用独立文件系统，无法读取手机存储、App 数据、私钥或用户文件。因此，移动端的**在本机执行命令**运行于隔离的 userland；桌面端则运行于计算机自身的 shell。

## 与服务器终端的区别

本机终端与服务器会话共用终端模拟器、虚拟键盘和标签页，区别仅在于终端输入和输出的来源。

本机 shell 不需要验证服务器 host key，也不会像服务器会话那样自动重连。它不会加入服务器列表，也没有状态图表。
