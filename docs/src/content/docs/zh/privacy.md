---
title: 隐私政策
description: Server Box 保存、发送哪些数据，以及如何控制这些行为
---

最后更新：2026-09-02。

Server Box 是连接你所配置服务器的客户端。它没有用户账号，也没有由开发者运营、用于中转 SSH、SFTP 或 Monitor 流量的服务。连接这些服务时，流量会从 App 直接发往你选择的 endpoint。

App 还会为诊断和你使用的功能发起独立的网络请求。下文会说明这些请求的目标和内容。Server Box 不包含广告，不使用广告标识符，也不会跨 App 追踪。

## 保存在本设备上的数据

| 数据 | 保存方式和行为 |
|---|---|
| 服务器名称、地址、端口、用户名和设置 | 加密的 SQLite 数据库 |
| SSH 密码、私钥、Monitor 和 BMC 凭据，以及配置的 AI API key | 加密的 SQLite 数据库；数据库加密密钥保存在系统钥匙串中 |
| 备份密码、WebDAV 密码和 GitHub token | 系统安全存储 |
| App 日志 | 仅保存在本机日志文件中；为便于排查问题，会保留当前运行和上一次运行的日志 |
| Agent 对话 | 本机数据库；其中可能包含 prompt、模型回复、命令输出、选中的终端文本和文件内容 |
| 活动终端输出 | 保存在活动会话中；会话结束后，终端不会继续保留这些内容 |

Agent 对话不会加入备份，也不会通过设备同步发送。在你从对话历史中删除前，它会保留在本设备上。Agent 对话仍可能被发送给你配置的 AI provider；详见 [AI 请求](#ai-请求)。

备份只在你主动请求时创建。根据选项和备份格式，备份可能包含服务器设置和凭据、私钥、代码片段、端口映射、容器设置、连接历史以及 App 设置。包含 App 设置时，其中也包括配置的 AI endpoint、model 和 API key。Agent 对话和设备本地状态不会包含在内。

未设置备份密码时，本地备份可能不加密。设置备份密码后，备份会在写入或上传前加密。自动远程备份要求设置非空的备份密码。备份发送到 iCloud、WebDAV 或 GitHub Gist 后，还会受到对应 provider 的存储、访问和保留规则约束。

## 自动诊断数据

自动诊断是 Server Box 发送到开发者诊断服务的唯一 telemetry。第一次自动上传前，引导页会先展示选择；之后可以随时在 **设置 → 应用 → 隐私** 中更改。

| 级别 | 自动发送的内容 |
|---|---|
| **不发送** | 不发送任何内容。本机日志仍保留在设备上，你仍可以准备手动报告。 |
| **基本信息** | 被捕获的崩溃和错误，以及构建信息、平台信息和在相关时附加的诊断面包屑。App 正常运行时不会持续发送数据。 |
| **完整信息** | 基本信息的全部内容，外加可用的性能追踪，以及 App 运行期间的粗粒度功能使用事件。 |

Android 默认值为**不发送**。iOS、macOS、Linux 和 Windows 默认值为**基本信息**。在支持自动诊断的构建中，第一次自动上传前都会显示引导页。

改为**不发送**会立即停止自动发送，不会等到下次启动。

### 自动报告可能包含什么

根据平台和错误类型，自动报告可能包含：

- 错误类型、错误信息和调用栈
- App 构建号、存储 schema 版本，以及该构建是否包含本机 Linux userland
- 操作系统和内核信息、硬件型号、CPU 核心数、内存大小，以及 App 的内存占用（具体取决于平台）
- 语言、locale 和时区
- Dart 与 Flutter 运行时版本
- 结构化诊断面包屑，例如使用的连接方式、终端或文件 backend 类型，以及某项操作的结果（如果有记录）
- 平台提供的 native crash、ANR 或 hang 原因和 trace（如果有）

面包屑使用固定的 action 名称，并对服务器相关值使用粗粒度信息或脱敏值。它们不会把终端输出、文件内容、密码或私钥作为诊断字段发送。App 自身的普通日志流在任何级别下都不会上传。

错误信息和调用栈来自底层 library，可能包含 App 没有主动创建的文本，因此不能保证每个异常都不包含服务器细节。不要把自动诊断理解为任意异常文本都已匿名化。

App 不会安装 native crash signal handler。平台提供 native crash、ANR 或 hang 记录时，Server Box 会在下次启动时读取它。如果启用了自动诊断，这条记录随后可以作为错误报告发送；否则会保留在本机，并可能出现在手动报告中。

### 完整信息额外发送什么

完整信息会发送性能追踪，例如连接服务器或列出目录所需的时间，但不会发送这些操作的内容。它还会把相同的结构化面包屑转换为粗粒度的功能使用事件，例如打开过终端，或文件操作使用了 SFTP 而不是 SCP。这些事件不包含 prompt、终端输出、文件内容、键盘输入或屏幕录制。

本项目使用的 OpenPanel analytics destination 写在源码中，错误上报 destination 也写在源码中。因此从未修改源码构建的版本——包括 F-Droid 重构建、fork 和你自己的 checkout——都会使用相同的 destination，除非构建者修改它们。完整信息默认关闭，必须手动开启；在你选择完整信息前，未修改的构建不会发送功能使用事件。

本项目实现了两个 analytics integration，它们对 identifier 的处理方式不同：

- 本项目使用的 OpenPanel integration 接受**按安装区分的标识符**。它会在设备上保存一个随机的 128-bit 值：开启完整信息时创建，离开完整信息时删除，保存在备份文件之外，且不由设备标识符、账号或硬件信息推导而来。它用于关联同一安装在多次启动中的事件，以及统计不同安装的数量，不用于识别个人或设备。
- App 也实现了 Aptabase integration，但发布版本没有配置它。它不使用持久的安装标识符；事件携带的 session ID 会在闲置一小时后轮换，因此不同启动之间的 session 无法关联。

根据 destination，事件可能携带操作系统及版本、设备类型和可用时的设备型号、App 版本和构建号，以及 locale。事件不包含广告标识符或账号标识符。

analytics service 还可能根据设备连接时使用的 IP 地址推导大致位置：国家和城市，以及代表该城市的坐标，不是你的精确位置。对于本项目使用的 OpenPanel 数据，该位置会与按安装区分的标识符一起保存；IP 地址本身不会作为事件字段保存。

## 脱敏和手动崩溃报告

结构化诊断面包屑在创建时就会处理为可发布的形式，然后才交给 reporting sink。它们使用固定的 action 名称，并用服务器相关值的替代值代替直接记录服务器名称、地址或用户名。

手动报告的处理方式不同。发生崩溃后，Server Box 可以显示上一次运行的日志和平台提供的 crash 或 hang trace，并在能够识别时替换已配置的服务器名称、SSH/Monitor 地址和用户名，然后将结果复制到剪贴板并打开 GitHub issue 页面。它不会自动发布：是否粘贴或提交由你决定，你可以先阅读完整内容。这条路径在所有诊断级别下都可用，包括**不发送**。

旧日志、临时连接的主机，以及 App 无法识别的值，仍可能出现在手动报告中。因此手动报告不保证匿名。粘贴到 GitHub 的内容是公开的，并受 [GitHub 隐私声明](https://docs.github.com/site-policy/privacy-policies/github-privacy-statement)约束。

## AI 请求

Agent 使用 **设置 → 应用 → AI** 中配置的 OpenAI-compatible endpoint。默认 endpoint 可以替换为其他 provider。只有在你发送 Agent 消息后，App 才会发起请求。

根据操作类型，请求可能包含你的 prompt、选中的终端文本、最近的对话历史、配置的服务器名称，以及 Agent 工作所需的上下文。执行命令或文件操作后，操作结果可能在后续请求中发送，以便模型继续工作。命令输出和文件内容即使不是 Server Box 主动添加的，也可能包含密码、token 或其他秘密；发送前请检查内容，并阅读 provider 的隐私政策。

API key 保存在本机加密的 App 数据库中，并作为 bearer credential 仅发送到你配置的 endpoint。选择在备份中包含 App 设置时，endpoint、model 和 API key 也会包含其中。Server Box 不会通过开发者的服务中转 AI 请求。

## 其他网络请求

以下请求只会在对应功能被使用时发起，不携带上文所述的自动诊断 payload。

| 请求 | 目标 | 时机和内容 |
|---|---|---|
| AI 请求 | 你配置的 endpoint | 发送 Agent 消息时；详见 [AI 请求](#ai-请求) |
| 备份或同步 | iCloud、你的 WebDAV server 或 GitHub Gist | 上传、下载或同步备份时；携带选定的备份文件，文件可能已加密 |
| 检查更新 | `api.github.com` | 开启自动检查更新后，在启动时发起 |
| Linux userland manifest | `github.com` | App 检查本机 Linux 环境是否有更新时发起；携带版本元数据和签名 |
| Linux userland 镜像 | 经验证的 manifest 指定的 distribution mirror 或 source URL | 安装或更新本机 Linux 环境时发起；下载的镜像会按 manifest 中的 digest 校验 |
| 服务器 logo 或发行版标识 | 你配置的 URL | 设置自定义 logo 或标识 URL 后发起；图片 provider 可能会收到该请求 |
| 赞助链接 | `cdn.lpkt.cn` | 打开赞助链接时发起 |
| 文档和 issue 链接 | `serverbox.lollipopkit.com` 或 `github.com` | 打开对应链接时发起 |

连接你自己的服务器、配置的 BMC 以及你部署的 Monitor agent，会直接发往这些 endpoint，不会经过开发者的基础设施。

## 诊断数据发往哪里

错误报告和性能追踪会发送到开发者运营的 Sentry-compatible server：`sentry.lollipopkit.com`。发布版本中的完整信息功能使用事件会发送到开发者运营的 OpenPanel analytics server：`diag.lollipopkit.com`。Aptabase integration 只有在构建版本提供 Aptabase endpoint 和 app key 时才会启用。

Sentry 和 OpenPanel 的 destination 写在源码中，因此从未修改源码构建的版本也会向这两个地址发送数据，除非构建者修改它们。完整信息仍默认关闭，必须由用户明确选择。

诊断数据不会用于广告，不会与其他公司共享，也不会用于跨 App 或跨网站追踪。诊断服务可能会在排查相应问题所需的期限内保留报告。如需请求删除报告，请在 [github.com/lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box/issues) 提交 issue，并提供大致时间、App 版本和问题的简短描述。不要在公开 issue 中包含密码、密钥或其他敏感内容。

## Watch App 和桌面小组件

Watch App、它的 complication，以及 iOS 和 Android 桌面小组件，会直接读取你部署的 Monitor agent。Server Box 会为每个 surface 签发一个只读 credential。该 credential 只能访问 Monitor metrics 接口（`/api/v1/status`、`/api/v1/metrics` 和 `/api/v1/metrics/history`），不能打开 shell、执行命令或浏览文件。

credential 保存在 Watch 自己的钥匙串中；在 iOS 上保存在共享钥匙串组中；在 Android 上使用 AndroidKeyStore 密钥加密保存。小组件的配置列表会包含服务器名称和 Monitor 地址，以便选择服务器；credential 则单独保存在平台安全存储中。配置了 Monitor 的服务器会自动包含在同步范围内。Watch 可以在**设置**中单独排除服务器；小组件会发布所有配置了 Monitor 的服务器，不使用单独的排除列表。只要 App 能联系 Monitor agent，排除或删除服务器就会吊销对应 Watch 或小组件 credential。

## 应用商店平台

App Store 和 Google Play 版本还可能受到平台自身上报机制的影响。Apple 和 Google 按照各自的政策收集相关信息，这些信息不是由 Server Box 通过上述诊断服务收集的。详见 [Apple 隐私政策](https://www.apple.com/legal/privacy/) 和 [Google 隐私政策](https://policies.google.com/privacy)。F-Droid 版本没有商店提供的崩溃上报渠道，这也是其默认诊断级别为**不发送**的原因之一。

## 儿童

Server Box 是服务器管理工具，不以儿童为目标用户，也不会明知地收集用于识别儿童的信息。

## 变更

如果收集方案发生实质变化，App 会再次显示诊断数据询问。旧的回答不会被视为对实质不同方案的同意。

## 联系方式

请在 [github.com/lollipopkit/flutter_server_box](https://github.com/lollipopkit/flutter_server_box/issues) 提交 issue。
