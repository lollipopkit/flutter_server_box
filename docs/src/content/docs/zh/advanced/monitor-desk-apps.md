---
title: Desk 应用
description: 在 Monitor 面板的桌面中安装第三方应用
---

[Monitor agent](/docs/zh/advanced/monitor-agent/) 的网页面板是一个桌面，应用在窗口中
运行。除了面板自带的应用，管理员还可以从 `.fsba` 包安装第三方应用。它们与
[Monitor 应用](/docs/zh/advanced/monitor-apps/)不同：后者是在服务器上部署 Docker Compose
服务。

已安装的应用运行在面板的沙箱 frame 中，没有网络访问，也不能调用 agent 的 API。它只能
通过权限允许的功能使用桌面：自己的窗口、通知和自己的存储。`wasm` 类型的应用还带有一个
由 agent 运行的后端，在权限允许时可以读取服务器状态、读取文件或运行命令。

## 安装应用

安装、批准和移除应用都需要管理员账号。

1. 在面板中打开 **Settings → Apps**。
2. 在 **Installed** 下选择 **Install…**，选择 `.fsba` 包。agent 会检查这个包，检查不
   通过时拒绝安装，例如 manifest 含有未知字段，或包内有指向包外的条目。
3. 应用会显示为 **Waiting**。选择 **Approve**，阅读它申请的权限，然后输入你的密码。

批准后，应用会出现在服务器上所有账号的 **All Apps** 中。其他已打开的桌面在下次启动时
才会看到它。

每个新的包都需要重新批准，包括已批准应用的新版本，即使申请的权限没有变化。列表中会显示
版本号和包 SHA-256 的前几位，可以与发布者公布的值核对。

## 权限

| 权限 | 允许 |
|---|---|
| `notifications` | 在桌面上显示通知 |
| `background` | 窗口隐藏时继续运行 |
| `status` | 仅 `wasm`：读取服务器状态 |
| `files.read` | 仅 `wasm`：读取 `[remote_access.fs] roots` 内的文件，账号需要有 `files` 授权 |
| `exec` | 仅 `wasm`：运行命令，账号需要有 `shell` 授权 |

应用获得的权限不会超过使用它的账号：后端每次调用时，agent 都会检查账号的授权。见
[账号和权限](/docs/zh/advanced/monitor-agent/#账号和权限)。

已批准的应用以打开它的账号身份运行，能读取该账号的授权和应用自身权限共同允许的内容。
沙箱会阻止它发出网络请求，但无法阻止它通过跳转 frame 把读到的内容发送出去。只安装
来自可信发布者的应用。

## 使用和移除应用

每个应用在 **Settings → Apps → All apps** 下都有自己的页面：是否在 dock 中、窗口隐藏时
是否继续运行（需要 `background` 权限），以及批准时授予的权限。

**Installed** 下的 **Remove** 会为服务器上的所有账号移除该应用，并删除各账号在其中保存
的数据。

## 开发应用

见[开发 Desk 应用](/docs/zh/development/desk-apps/)。
