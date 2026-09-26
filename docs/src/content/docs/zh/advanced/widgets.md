---
title: 主屏幕小组件
description: 在主屏幕添加服务器状态小组件
---

使用主屏幕小组件前，需要在服务器上安装 [Monitor agent](/docs/zh/advanced/monitor-agent/)，再将该服务器添加到 App。App 会自动向小组件提供已配置的 Monitor 服务器列表。

## 工作方式

小组件直接向 Monitor agent 请求数据，因此 App 无需保持打开。对于每台已配置 Monitor agent 的服务器，App 会向小组件提供名称、地址和短期 read-only token。token 保存在平台的安全凭据存储中。

小组件有两种固定布局：**Small** 显示当前读数，**Medium** 显示多个指标的图表。设置时选择服务器和主指标；URL 从服务器配置中读取，无需手动填写。

## iOS 小组件

iOS 小组件需要 iOS 17 或更新版本。

### 添加步骤

1. 长按主屏幕，然后点击 **+**。
2. 搜索 “Server Box”。
3. 选择 **Small** 或 **Medium**。
4. 小组件出现后，长按它并点击 **编辑小组件**。
5. 选择要显示的服务器。

每个 iOS 小组件显示一台服务器。Small 显示当前读数；Medium 显示多个指标的图表。

### 注意事项

- 在 App 中添加已配置 Monitor agent 的服务器。
- App 会应用该服务器的 `allowInsecure` 设置。除非确实需要让非 loopback 连接使用明文 HTTP，否则请使用 HTTPS。
- iOS 决定小组件的刷新时间，不保证固定间隔。
- 可以添加多个小组件，分别显示不同服务器。

## Android 小组件

### 添加步骤

1. 长按主屏幕，点击 **小组件**。
2. 找到 “Server Box”，选择 Small 或 Medium 类型并添加。
3. 在配置页面选择服务器和主指标。
4. 点击保存。
5. 点击主屏幕上的小组件可以手动刷新。

每个 Android 小组件实例都会单独保存服务器和指标选择，因此多个小组件可以显示不同内容。服务器列表由 App 提供；如果列表为空，请先添加一台配置了 Monitor agent 的服务器。

## Watch App

Watch App 需要 watchOS 10 或更新版本，并直接从 Monitor agent 读取数据。因此，它只显示 App 中已配置 Monitor agent 的服务器。这些服务器默认会同步；如需排除某台服务器，请打开 **iOS 设置 → 应用 → iOS → Watch 应用**。

### 配置步骤

1. 在 iPhone 上打开 Server Box。
2. 打开 **设置 → 应用 → iOS → Watch 应用**。
3. 排除不想在手表上显示的服务器，其余 Monitor 服务器会同步。
4. 等待同步完成。

Watch App 中服务器页面按名称排序，与 App 中服务器列表的顺序无关。

添加**锁屏小组件**时，请使用系统小组件库并在那里选择服务器；Server Box 内没有单独的锁屏小组件设置项。

## 故障排除

### 小组件或 Watch App 不更新

- 确认 Monitor agent 正在运行，且配置地址可访问。
- 检查 App 中保存的 Monitor 用户名、密码、证书和 `allowInsecure` 设置。
- iOS 系统决定刷新时间。请等待下次刷新，或删除后重新添加小组件。
- 点击 Android 小组件可手动刷新；打开其配置页确认服务器和指标选择。
- Watch 必须与 iPhone 配对。更改服务器设置后，在 iPhone 上打开 Server Box 并等待同步。

### 小组件显示错误或没有服务器

- 在 App 中至少添加一台配置了 Monitor agent 的服务器。
- 检查 agent 的 HTTPS 地址、登录凭据和网络连接。
- 小组件不再使用手动填写的 `/status` URL。如果旧版本留下了这类地址，请按 App 中的一次性提示重新配置服务器。

## 安全性

- 优先使用 HTTPS。
- 非 loopback 地址使用明文 HTTP 时，必须在 App 中为该服务器开启**允许不安全 HTTP**。小组件 endpoint（`/api/v1/metrics`、`/api/v1/metrics/history`、`/api/v1/watch-token`）没有对应的 agent 开关；agent 的 `allow_insecure` 仅适用于 `[remote_access.terminal]` 和 `[remote_access.fs]`。
- 不要将 Monitor 凭据或小组件 token 写入公开文档或提交到版本控制。
