---
title: 移动端功能
description: iOS 和 Android 的平台特定功能
---

Server Box 在 iOS 和 Android 上提供生物识别、主屏幕小组件、后台运行和虚拟键盘等功能。

## 生物识别

使用设备的生物识别功能解锁 App：

- **iOS**：Face ID 或 Touch ID
- **Android**：设备支持的生物识别方式，例如指纹

在 **设置 → 应用 → 通用 → 生物识别身份验证** 中启用。设备尚未录入生物识别信息时，App 会提示你先完成录入。

## 主屏幕小组件

小组件需要服务器运行 [Monitor agent](/docs/zh/advanced/monitor-agent/)。安装 agent 后，在 App 中配置服务器，系统小组件会从 App 发布的服务器列表中读取数据；小组件本身不需要手动填写 URL。iOS 小组件需要 iOS 17 或更高版本；这不会影响 iOS App 本身的最低版本。

### iOS

1. 长按主屏幕，点击 **+**。
2. 搜索 “Server Box”。
3. 选择 **Small** 或 **Medium** 小组件。
4. 添加后长按小组件，点击 **编辑小组件**，选择服务器。

Small 小组件显示当前读数；Medium 小组件显示多个指标的图表。每个小组件只选择一台服务器。

### Android

1. 长按主屏幕，点击 **小组件**。
2. 找到 “Server Box”，选择 Small 或 Medium 类型并添加。
3. 在配置页面选择服务器和主指标。
4. 点击保存；之后可以点击小组件手动刷新。

## Android 后台运行

要在 App 退到后台后继续保持 SSH 连接：

1. 在 **设置 → 应用 → 通用 → Android 设置 → 后台运行** 中开启。
2. 在系统设置中允许 Server Box 发送通知。
3. 按设备厂商的要求关闭电池优化；MIUI/HyperOS 等系统还需要将省电策略设为“无限制”。

后台连接会使用常驻通知。没有通知权限时，Android 无法运行所需的 foreground service，连接在后台可能会中断。

## iOS 后台行为

iOS 会限制 App 在后台运行。连接可能被系统暂停；回到 App 后会重新连接。后台刷新能否及时执行由系统决定。

## 推送通知

服务器告警由服务器上的 [Monitor agent](/docs/zh/advanced/monitor-agent/) 发送。告警规则和推送渠道需要在 Monitor 侧配置。

## 移动端 UI 功能

- **下拉刷新**：重新获取服务器状态
- **横屏模式**：为终端提供更宽的显示区域
- **虚拟键盘**：提供 Esc、Tab、Ctrl/Alt 等终端常用按键

## 文件集成

- **文档选择器**：选择本地文件用于 SFTP 上传，以及备份的导入和导出
- **分享**：将文件导出到其他 App
