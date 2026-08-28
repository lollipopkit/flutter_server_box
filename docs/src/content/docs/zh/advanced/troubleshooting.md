---
title: 常见问题
description: 常见问题及处理方法
---

## 连接问题

### SSH 无法连接

**常见现象：** 连接超时、连接被拒绝或身份验证失败。

**排查步骤：**

1. 确认服务器运行 SSH server。支持 Linux、macOS、Android/Termux，以及运行 OpenSSH Server 的 Windows 主机。
2. 在其他终端手动测试：`ssh user@server -p port`。
3. 检查防火墙和网络路由，确认 SSH 端口可达。
4. 核对用户名、密码或 SSH key。
5. 如果配置了 jump server 或 ProxyCommand，先确认它们能单独连接目标主机。

### 连接频繁断开

**常见现象：** 终端闲置一段时间后断开，或 App 退到后台后连接消失。

**处理方法：**

1. 在服务器 `/etc/ssh/sshd_config` 中配置 SSH keep-alive：

   ```text
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. Android 上开启 **后台运行**，允许通知，并关闭 Server Box 的电池优化。MIUI/HyperOS 还需要将省电策略设为“无限制”。
3. iOS 无法保证连接在后台持续运行；回到 App 后等待它重新连接。

## 输入问题

### 无法输入某些字符

1. 使用终端上方的虚拟键盘发送 Esc、Tab、Ctrl/Alt 组合键和常用符号。
2. 使用 **IME** 按钮切换系统键盘的显示状态。
3. 如果第三方输入法行为异常，暂时切换到系统默认输入法。

## App 问题

### App 启动时崩溃或显示黑屏

通过 JSON 编辑器修改无效设置可能导致启动失败。

1. 优先从修改前的备份恢复。
2. Android：打开 **系统设置 → 应用 → Server Box → 存储**，清除应用数据。
3. iOS：删除并重新安装 App，然后从备份恢复。

清除数据或重新安装会删除本机未备份的数据，请将其作为最后手段。

### 备份或恢复失败

**备份失败：**

- 检查设备剩余存储空间。
- 确认 App 具有访问目标位置的权限。
- 更换存储位置后重试。

**恢复失败：**

- 确认备份文件完整且未被修改。
- 检查备份文件是否来自兼容版本。
- 如果备份包含凭据，确认当前 App 能够访问用于解密数据库的系统安全存储。

## 小组件和 Watch App 问题

### 小组件不更新

- 确认服务器上的 Monitor agent 正在运行，且 App 中的 Monitor HTTP 配置仍然有效。
- iOS 小组件的刷新时间由系统决定，可能需要等待一段时间；也可以删除后重新添加。
- Android 小组件可点击手动刷新，并检查配置页面中选择的服务器和指标。
- Watch App 需要与 iPhone 配对，并且服务器必须配置 Monitor agent。修改服务器后，打开 iPhone App 等待同步。

### 小组件显示错误或没有服务器

- 在 App 中至少配置一台带 Monitor agent 的服务器。
- 检查 agent 的 HTTPS、登录凭据和网络可达性。
- 小组件不再使用手动填写的 `/status` URL；如果旧版本留下了这类地址，请按 App 中的一次性提示重新配置服务器。

## 性能问题

### App 响应慢

- 增大服务器状态刷新间隔。
- 检查网络延迟和带宽。
- 暂时禁用不需要的服务器或状态卡片。
- 减少同时运行的终端和文件传输任务。

### 耗电量高

- 增大状态刷新间隔。
- 关闭不需要的后台运行或后台刷新功能。
- 关闭不使用的 SSH 会话。

## 获取帮助

如果问题仍未解决：

1. 搜索 [GitHub Issues](https://github.com/lollipopkit/flutter_server_box/issues)。
2. 提交新的 Issue，并附上 App 版本、平台、相关日志和复现步骤。
3. 如果问题涉及 Monitor agent，同时提供 agent 版本和相关配置（请删除密码、token 等敏感信息）。
