---
title: 远程桌面（RDP 和 VNC）
description: 通过 SSH 或 Monitor 连接图形桌面
---

Server Box 在 Android、iOS、Linux、macOS 和 Windows 上提供 RDP 与 VNC 客户端。客户端
通过已有的服务器连接访问桌面：使用 SSH，或使用 Monitor。 这样无需将桌面端口暴露到
运行 Server Box 的网络。

## 配置连接

1. 在 Server Box 中为服务器配置 SSH，或配置 Monitor。 两种方式都可用时，
   应用会先尝试服务器设置中的**优先连接方式**，失败后再回退到另一种方式。
2. 打开**远程桌面**主标签并选择服务器，也可以从该服务器的详情页进入。
3. 为桌面添加连接配置。同一服务器内的配置名称不能重复。
4. 选择 **Connect** 可打开会话或切换到已有会话。使用 **Edit** 修改配置；编辑页中的
   **Test** 会按当前表单内容连接，并替换该配置已有的会话。

目标地址从服务器所在的网络解析，而不是从运行 Server Box 的手机或电脑解析。默认目标
如下：

| 协议 | 默认目标 |
| --- | --- |
| RDP | `127.0.0.1:3389` |
| VNC | `127.0.0.1:5900` |

如果桌面服务运行在服务器本机，可以使用默认目标；也可以填写该服务器能够访问的内网地址。
SSH 连接沿用终端和端口转发使用的认证方式及跳板机设置。使用 Monitor 时，Monitor
所在机器会以自身运行账户连接目标。App
只会在连接目标为本机回环地址时，通过明文 HTTP 连接 Monitor。

除非启用**保存密码**，密码不会持久保存。连接时输入的密码只保留在当前会话的内存中，供
该会话重连使用。保存的密码会写入 Server Box 加密数据库，也会包含在加密备份和同步数据
中；通过服务器二维码分享时不会包含远程桌面密码。

## 验证 RDP 证书

Server Box 会先使用系统信任库验证 RDP 服务器证书。证书受信任且名称与目标地址匹配时，
应用会直接继续连接。

如果证书是自签名证书、签发者未知或名称不匹配，Server Box 会在发送凭据前中止连接，并
显示证书身份和 SHA-256 fingerprint：

1. 通过独立的可信渠道核对 fingerprint。
2. 选择**信任并重新连接**，将该证书加入此配置的信任记录。
3. 后续连接只接受相同的 fingerprint。
4. 如果证书发生变化，连接会被阻止。核实新 fingerprint 后再选择**替换信任**。

修改配置中的协议、目标主机或端口会清除已保存的证书信任。日志和诊断信息不会包含密码、
剪贴板文本或证书内容。

## 会话与操作

**远程桌面**标签可以同时保留多个 RDP/VNC 会话。宽窗口会在当前桌面旁显示会话列表，
列表栏可以调整宽度或折叠；窄窗口可点按顶部的会话名称切换会话。

查看器支持适应窗口、1:1 和固定缩放、全屏、重连、关闭、只读模式、发送剪贴板、软键盘
和 Ctrl+Alt+Delete。桌面平台还支持实体键盘、鼠标左/中/右键和滚动。键盘焦点离开查看器
时，应用会释放仍处于按下状态的 RDP 按键。

手机和平板默认使用触控板模式：单指移动指针并点按操作，双指右键或滚动，双指捏合缩放。
直接指针模式则将触摸位置映射到远程桌面的对应位置。

RDP 支持文本剪贴板双向同步。经典 VNC 剪贴板使用 Latin-1；遇到无法表示的文本时，
Server Box 会拒绝发送，避免字符损坏。RDP 可以根据查看器调整远程分辨率；VNC 使用服务端
提供的画面尺寸。

## 断线恢复

传输失败后，Server Box 会分别等待 1、2、5 秒后重试。每次重试都会重新确认连接，并创建
只监听本机回环地址的临时隧道。认证失败、证书被拒绝或配置无效时不会自动重试。

服务器给出连接失败或会话结束的原因时，Server Box 会显示该原因，不会自动重连：密码错误、
账户被锁定或过期、空闲或会话时长限制、注销、另一个连接接管了会话、服务器关机等。重试会
得到相同的结果，从另一个连接接管会话还会把那个连接断开。原因解决后，选择**重新连接**。

## xrdp 排错

服务器只提供 Standard RDP Security 时，连接会失败。这种模式使用 RC4，且不验证服务器
身份，因此 Server Box 要求 TLS 或 CredSSP/NLA。接受这种旧模式的客户端（例如 Windows
客户端）仍能连接。在服务器上：

1. 在 `/etc/xrdp/xrdp.ini` 中设置 `security_layer=negotiate` 或 `tls`，不要用 `rdp`。
2. 确保 xrdp 能读取 `certificate` 和 `key_file` 指向的文件。Debian 和 Ubuntu 的默认私钥
   位于 `/etc/ssl/private`，只有 `ssl-cert` 组可读：`sudo adduser xrdp ssl-cert`。
3. 重启 xrdp：`sudo systemctl restart xrdp`。如果 `/var/log/xrdp.log` 中有
   `Cannot read private key file` 之类的行，说明第 2 步仍未完成。

桌面平台和 Android 会在操作系统允许时使用应用现有的后台行为。iOS 可能暂停后台网络
活动；返回应用后，Server Box 会检查会话，并在需要时重新连接。

## 协议支持范围

- **RDP：**支持 TCP、TLS、CredSSP/NLA、图形、键盘与指针输入、动态分辨率和文本 CLIPRDR。
  用户名/密码和可选域主要使用 NTLM；不保证支持 Kerberos。不支持 Standard RDP Security（RC4）。
- **VNC：**支持 RFB 3.3、3.7、3.8，以及 None 和经典 VNC Authentication。经典 VNC 密码
  只能是 ASCII；可以输入更长的密码，与 TigerVNC 一样只使用前 8 个字符。支持 Raw、CopyRect、ZRLE、Tight、Tight JPEG、光标和桌面尺寸更新。
- VNC 暂不支持 VeNCrypt、SASL、Apple Remote Desktop 认证和 RealVNC 私有认证。
- 暂不支持音频、麦克风、多显示器、RemoteApp、RDP Gateway、UDP，以及文件、磁盘、打印机、
  USB 或智能卡重定向。
