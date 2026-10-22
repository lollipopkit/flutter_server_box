---
title: Desk 应用
description: 在 Monitor 面板的桌面中安装第三方应用
---

[Monitor agent](/docs/zh/advanced/monitor-agent/) 的网页面板是一个桌面，应用在窗口中
运行。除了面板自带的应用，还可以从 `.fsba` 包安装第三方应用。它们与
[Monitor 应用](/docs/zh/advanced/monitor-apps/)不同：后者是在服务器上部署 Docker Compose
服务。

已安装的应用运行在面板的沙箱 frame 中，没有网络访问，也不能调用 agent 的 API。它只能
通过权限允许的功能使用桌面：自己的窗口、通知和自己的存储。`wasm` 类型的应用还带有一个
由 agent 运行的后端，在权限允许时可以读取服务器状态、运行程序，或以 root 身份运行脚本。以 root
身份运行任何内容之前，桌面会弹出自己的对话框，写明是哪个应用以及它要做什么，并要求输入 sudo
密码；密码随这次请求发给 agent，应用拿不到。

## 安装应用

**App Store** 会列出 agent 提供的桌面应用：ServerBox 签名的标为 **ServerBox**，其他的标为
**未知发布者**。选择 **安装** 会显示应用申请的权限，输入密码后完成安装和批准。

来自其他来源的包：

1. 在面板中打开 **Settings → Apps**。
2. 在 **Installed** 下选择 **Install…**，选择 `.fsba` 包。agent 会检查这个包，检查不
   通过时拒绝安装，例如 manifest 含有未知字段，或包内有指向包外的条目。
3. 应用会显示为 **Waiting**。选择 **Approve**，阅读它申请的权限，然后输入你的密码。

批准后，应用会出现在 **All Apps** 中。其他已打开的桌面在下次启动时
才会看到它。

每个新的包都需要重新批准，包括已批准应用的新版本，即使申请的权限没有变化。列表中会显示
版本号和包 SHA-256 的前几位，可以与发布者公布的值核对。

## 权限

| 权限 | 允许 |
|---|---|
| `notifications` | 在桌面上显示通知 |
| `background` | 窗口隐藏时继续运行 |
| `status` | 仅 `wasm`：读取服务器状态 |
| `process` | 仅 `wasm`：以 agent 的系统账户运行程序 |
| `root` | 仅 `wasm`：以 root 身份运行脚本，每次都需要你在桌面的对话框中输入 sudo 密码确认（可以记住 15 分钟） |

后端能做什么，由应用批准时获得的权限和 agent 的传输规则决定：`process` 和 `root`
与 agent 的其他功能一样，需要 HTTPS 或同机调用方。它们能访问的范围就是 agent 运行所用的
系统账户能访问的范围，见[访问](/docs/zh/advanced/monitor-agent/#访问)。

已批准的应用能读取其权限允许的所有内容。
沙箱会阻止它发出网络请求，但无法阻止它通过跳转 frame 把读到的内容发送出去。只安装
来自可信发布者的应用。

## 使用和移除应用

每个应用在 **Settings → Apps → All apps** 下都有自己的页面：是否在 dock 中、窗口隐藏时
是否继续运行（需要 `background` 权限），以及批准时授予的权限。

**Installed** 下的 **Remove** 会移除该应用，并删除其中保存的数据。

## 开发应用

见[开发 Desk 应用](/docs/zh/development/desk-apps/)。
