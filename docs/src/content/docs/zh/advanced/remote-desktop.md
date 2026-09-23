---
title: 远程桌面（RDP 和 VNC）
description: 通过 Server Box 的 SSH 连接或 Monitor 代理访问图形桌面
---

Server Box 在 Android、iOS、Linux、macOS 和 Windows 上内置 RDP 与 VNC 客户端。所有远程桌面连接都会经过服务器已有的连接：SSH，或开启了 `remote_access.full_access` 的 Monitor 代理。因此不需要把 RDP 或 VNC 端口暴露给运行 Server Box 的网络。

## 配置远程桌面

1. 先为服务器配置接入方式：SSH，或开启了 `remote_access.full_access` 的 Monitor 代理。两者都配置时，远程桌面遵循服务器的**优先使用**设置，失败时回退到另一种。
2. 打开**远程桌面**主标签并选择服务器，或从服务器详情页进入**远程桌面**。
3. 添加一个或多个配置；同一服务器内的配置名称不能重复。
4. 在**远程桌面**主标签中选择服务器，再点击配置的 **Connect** 或 **Edit** 按钮。编辑页的 **Test** 会用当前表单内容打开会话，并替换该配置已有的会话；**Connect** 则切换到已有会话，不会重复创建。

目标主机从服务器所在的网络解析，而不是从运行 Server Box 的手机或电脑解析——走 SSH 时从 SSH 服务器解析，走 Monitor 代理时从代理所在机器解析。因此，当桌面服务就在那台机器上时，可以直接使用默认值：

| 协议 | 默认目标 |
|---|---|
| RDP | `127.0.0.1:3389` |
| VNC | `127.0.0.1:5900` |

也可以填写只有那台机器才能访问的内网主机名或地址。SSH 密码、密钥、键盘交互认证、跳板机和 `ProxyCommand` 与终端及端口转发功能共用同一条连接路径。走 Monitor 代理时，连接由代理以自身运行的账户发起——这与它的 Shell 是同一项授权，因此只在 `full_access` 打开时提供，且非本机回环的明文连接会被拒绝。

密码默认不保存。启动会话时输入的密码只保留在当前会话内存中，并用于该会话的重连。启用**保存密码**后，密码会进入 Server Box 的加密数据库，并包含在加密备份和同步数据中。通过二维码分享服务器时不会包含远程桌面密码。

## RDP 证书验证

Server Box 会先通过系统信任库验证 RDP 服务器证书。如果证书受信任且名称与配置的目标一致，会直接继续连接。

遇到自签名证书、未知签发者或名称不匹配时，Server Box 会在发送凭据前停止，并显示证书身份和 SHA-256 fingerprint：

1. 通过另一个可信渠道核对 fingerprint。
2. 选择**信任并重新连接**，将 fingerprint 固定到当前配置。
3. 后续连接只接受相同的 fingerprint。
4. 证书变化时会阻止连接并同时显示新旧 fingerprint。只有重新核实服务器后，才能选择**替换信任**。

修改协议、目标主机或目标端口会自动清除已保存的 fingerprint。日志和诊断不会记录密码、剪贴板文字或证书正文。

## 会话与操作

远程桌面标签可以同时保留多个 RDP/VNC 会话。宽窗口在左侧显示会话列表，右侧显示当前桌面，列表栏可以像 App 中其他栏一样拖动和折叠；窄窗口可点击顶部的会话名称打开切换列表。

查看器支持适应窗口、1:1、固定缩放、全屏、重连、关闭、只读模式、发送剪贴板、软键盘和 Ctrl+Alt+Delete。桌面平台支持物理键盘、鼠标左/中/右键和滚轮；键盘失焦时会释放所有已按下的 RDP 按键。

移动端默认使用触控板模式：单指移动指针、单击、双指右键、双指滚动和捏合缩放。直接指针模式会把触摸位置直接映射到远程桌面。

RDP 支持文本剪贴板双向同步。经典 RFB 剪贴板只能表示 Latin-1；VNC 文本包含无法表示的字符时，Server Box 会拒绝发送并提示用户，避免产生乱码。

RDP 在视口稳定 300 ms 后调整远程分辨率；VNC 使用服务器提供的画面尺寸。隐藏的会话会停止跨 Rust/Flutter 边界发送画面，重新显示时再发送最新的完整帧。

## 断线重连

传输层瞬时故障会在 1、2、5 秒后重试。每次重试都会重新确认连接并创建新的、只监听本机回环地址的临时隧道——一条 SSH 直连 TCP 通道，或代理的 TCP 中继。认证失败、证书被拒绝和配置错误不会自动重试。

桌面平台和 Android 会在操作系统允许时使用 App 现有的后台行为。iOS 可能暂停后台网络任务；回到前台后，Server Box 会检查会话并在需要时重新连接。

## 首版协议范围

首版有意限制在以下范围：

- RDP 使用 TCP、TLS、CredSSP/NLA、图形、键鼠输入、动态分辨率和文本 CLIPRDR。用户名/密码和可选域主要使用 NTLM，不保证 Kerberos。
- VNC 支持 RFB 3.3、3.7、3.8 的 None 和经典 VNC Authentication。经典密码最多为 8 个 ASCII 字节。支持 Raw、CopyRect、ZRLE、Tight、Tight JPEG、光标和桌面尺寸更新。
- VNC 暂不支持 VeNCrypt、SASL、Apple Remote Desktop 认证和 RealVNC 私有认证。
- 暂不包含音频、麦克风、多显示器、RemoteApp、RDP Gateway、UDP，以及文件、磁盘、打印机、USB 或智能卡重定向。
- 渲染使用跨平台 Flutter BGRA 图像路径。后续可在不改变会话 API 的前提下替换为原生纹理渲染器。

## 实现与构建

协议引擎位于现有的 `sbm_ffi` Rust 库中：

- [IronRDP 0.17](https://github.com/Devolutions/IronRDP)，MIT OR Apache-2.0
- [vnc-rs 0.5.3](https://github.com/HsuJv/vnc-rs)，MIT OR Apache-2.0

IronRDP 只启用了所需功能。`third_party/ironrdp` submodule 指向 [lollipopkit/IronRDP fork](https://github.com/lollipopkit/IronRDP) 的 `serverbox` branch。该 branch 保持 IronRDP 0.17 的 API 和 crate 版本不变，并包含 ServerBox 所需的 transport、certificate trust 和 dependency compatibility 修改。更新时应先修改 fork，再在本仓库中更新 pinned commit。

修改 FFI API 后，需要运行 Flutter Rust Bridge 生成和常规 Flutter 代码生成。`cargo test --workspace` 会测试协议代码。默认忽略的 `frame_backpressure_stays_bounded_at_1080p` 是 60 秒压力测试，发布前应显式执行。

Windows 主机可构建并验证 Windows 和 Android 产物。iOS/macOS 最终链接需要 Apple 构建主机，Linux 最终链接需要 Linux 主机。正式发布前仍需在各平台实机验证键鼠/触控、旋转、全屏、后台恢复以及真实 RDP/VNC 服务器。
