---
title: 主屏幕小组件
description: 在主屏幕添加服务器状态小组件
---

主屏幕小组件需要服务器运行 [Monitor agent](/docs/zh/advanced/monitor-agent/)。安装并配置 agent 后，在 App 中配置服务器，小组件会自动获取可用服务器列表。

## 工作方式

小组件直接读取 Monitor agent 的认证 API，不依赖 App 在前台运行。App 会将带 Monitor agent 的服务器名称、地址和短期 read-only token 发布给系统小组件；token 保存在平台提供的安全存储中。

小组件显示 Small 或 Medium 两种固定布局：Small 显示当前读数，Medium 显示多个指标的图表。添加小组件时选择服务器和主指标，不能手动填写 URL。

## iOS 小组件

iOS 小组件需要 iOS 17 或更高版本。

### 添加步骤

1. 长按主屏幕，点击 **+**。
2. 搜索 “Server Box”。
3. 选择 **Small** 或 **Medium**。
4. 添加后长按小组件，点击 **编辑小组件**。
5. 选择要显示的服务器。

### 注意事项

- 服务器需要在 App 中配置 Monitor agent。
- App 会检查每台服务器的 `allowInsecure` 设置；除 loopback 外，通常应使用 HTTPS。
- iOS 会决定小组件的刷新时间，不能保证固定间隔。
- 同一台设备可以添加多个小组件，并分别选择服务器。

## Android 小组件

### 添加步骤

1. 长按主屏幕，点击 **小组件**。
2. 找到 “Server Box”，选择 Small 或 Medium 类型并添加。
3. 在配置页面选择服务器和主指标。
4. 点击保存。
5. 点击主屏幕上的小组件可以手动刷新。

Android 小组件的配置保存在每个小组件实例中，因此多个小组件可以分别显示不同服务器或指标。服务器列表由 App 发布；如果列表为空，请先在 App 中配置带 Monitor agent 的服务器。

## Watch App

Watch App 需要 watchOS 10 或更高版本。它直接从 Monitor agent 获取数据，因此只能显示在 App 中配置了 Monitor agent 的服务器。默认会同步这些服务器；你可以在 **iOS 设置 → 应用 → iOS → Watch 应用** 中排除不希望在手表上显示的服务器。

### 配置步骤

1. 在 iPhone 上打开 Server Box。
2. 前往 **设置 → 应用 → iOS → Watch 应用**。
3. 选择要显示的服务器；列表顺序决定手表上的翻页顺序。
4. 等待 Watch App 同步。

**锁屏小组件**使用同一页的独立设置，只能选择一台服务器。

## 故障排除

### 小组件或 Watch App 不更新

- 确认 Monitor agent 正在运行，且设备能够访问其 URL。
- 确认 App 中的 Monitor 用户名、密码、证书和 `allowInsecure` 设置仍然有效。
- iOS 刷新由系统调度，请等待一段时间，或删除后重新添加小组件。
- Android 小组件可点击手动刷新；重新打开配置页面检查服务器和指标。
- Watch App 需要与 iPhone 配对；修改服务器配置后打开 iPhone App，等待同步完成。

### 小组件显示错误或没有服务器

- 在 App 中至少配置一台带 Monitor agent 的服务器。
- 检查 agent 的 HTTPS、登录凭据和网络可达性。
- 小组件不再使用手动填写的 `/status` URL。如果旧版本留下了这类地址，请按 App 中的一次性提示重新配置服务器。

## 安全性

- 尽可能使用 HTTPS。
- 对非 loopback 的 HTTP 连接，必须在 App 和 Monitor agent 两端明确开启不安全 HTTP。
- 不要把 Monitor 登录密码或小组件 token 写入公开文档或版本控制。
