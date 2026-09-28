---
title: 常见问题
description: 常见问题及处理方法
---

## 连接问题

### SSH 无法连接

常见现象包括连接超时、被拒绝，或身份验证失败。

请按顺序检查：

1. 确认服务器已安装并运行 SSH server。支持的系统包括 Linux、macOS、Android/Termux，以及运行 OpenSSH Server 的 Windows。
2. 在其他终端运行 `ssh user@server -p port` 测试连接。
3. 检查网络路由和防火墙规则，确认 SSH 端口可达。
4. 核对用户名以及配置的密码或 SSH key。
5. 如果使用 jump server 或 ProxyCommand，单独测试这条连接路径能否到达目标主机。

### 连接频繁断开

终端可能在闲置一段时间后断开，也可能在 App 进入后台后断开。

可以尝试以下方法：

1. 在服务器的 `/etc/ssh/sshd_config` 中配置 SSH keep-alive：

   ```text
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. Android 上开启 **后台运行**、允许通知，并为 Server Box 关闭电池优化。MIUI/HyperOS 可能还需要将电池策略设为“无限制”。
3. iOS 可能会暂停后台连接。返回 Server Box 并等待重新连接。

## 输入问题

### 无法输入某些字符

1. 使用终端上方的虚拟键盘输入 Esc、Tab、Ctrl/Alt 组合键和常用符号。
2. 点击 **IME** 切换系统键盘的显示状态。
3. 如果第三方输入法输入异常，暂时切换到系统键盘再试。

## App 问题

### App 启动时崩溃或显示黑屏

通过 JSON 编辑器写入无效设置可能导致 App 无法启动。

1. 使用修改设置前创建的备份恢复。
2. Android：打开 **系统设置 → 应用 → Server Box → 存储**，清除应用数据。
3. iOS：删除并重新安装 App，然后从备份恢复。

清除应用数据或重新安装会删除所有未备份的数据。只有其他恢复方式都不可用时再尝试。

### 备份或恢复失败

**备份失败：**

- 检查设备剩余存储空间。
- 确认 App 具有访问目标位置的权限。
- 更换存储位置后重试。

**恢复失败：**

- 确认备份文件完整，且未被改动。
- 确认备份由兼容版本的 App 创建。
- 如果备份包含凭据，确认 App 能访问解密凭据所需的系统安全存储。

## 小组件和 Watch App 问题

### 小组件不更新

- 确认 Monitor agent 正在运行且配置的 URL 可访问，并检查 App 中的 Monitor HTTP 设置。
- iOS 系统决定小组件的刷新时间。请等待下次刷新，或移除后重新添加小组件。
- Android 上可点击小组件手动刷新，再打开其配置页面检查所选服务器和指标。
- Watch App 必须与 iPhone 配对。修改服务器后，在 iPhone 上打开 Server Box 并等待同步。

### 小组件显示错误或没有服务器

- 在 App 中至少添加一台配置了 Monitor agent 的服务器。
- 检查 agent 的 HTTPS 地址是否可访问，以及登录凭据是否正确。
- 小组件使用 App 中的服务器列表，不再读取手动填写的 `/status` URL。如果旧版本留有此类地址，请按 App 中的一次性提示重新配置服务器。

## 性能问题

### App 响应慢

- 增大状态刷新间隔。
- 检查网络延迟和可用带宽。
- 暂时停用不需要的服务器或状态卡片。
- 减少同时进行的终端会话和文件传输。

### 耗电量高

- 增大状态刷新间隔。
- 不需要时关闭后台运行或后台刷新。
- 关闭未使用的 SSH 会话。

## 获取帮助

如果以上方法仍未解决问题：

1. 搜索 [GitHub Issues](https://github.com/lollipopkit/flutter_server_box/issues)。
2. 提交 Issue，并注明 App 版本、平台、相关日志和复现步骤。
3. 如果问题涉及 Monitor agent，也请提供其版本和相关配置；先删除密码、token 等敏感信息。
