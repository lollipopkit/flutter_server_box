---
title: Monitor Agent
description: 通过 Monitor agent 访问服务器
---

Server Box Monitor 是运行在服务器上的小型监控服务，会把服务器状态报告给 App。这样无需开放 SSH 端口，也能查看服务器；即使 App 没有打开，它仍能为推送告警、主屏幕小组件和 Watch App 提供数据。

## 给 AI agent 的 prompt

下面的 prompt 可以直接交给能通过 SSH 访问服务器的 AI agent。里面写清了不该靠猜的部分：规则语法和权限开关出错时可能不会直接报错，配置看起来没问题，但告警就是收不到。

发送前请先替换尖括号里的内容。

<details>
<summary>安装 agent</summary>

```text
通过 SSH 在 <host> 上安装 ServerBox Monitor agent。

安装脚本是
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh
它会自动识别 init 系统。通过管道交给 `sh` 时，它会安装为以我的账户运行的
`systemctl --user` 服务。Alpine 上需要 `sudo sh` 才能写入 /etc/init.d，但 agent
仍然以执行 sudo 的用户运行。

不要把它装成 root 系统服务。agent 以 root 运行，正是之后 `full_access`
变得危险的原因。

请保持 `[remote_access]` 下的所有开关关闭，并在那里显式写上
`full_access = false`。

它是该小节里唯一不是默认关闭的开关：不写时取平台默认值，Linux 上就是开。它自
己不会造成什么，因为它以终端启用为前提，而终端是关的——但之后打开终端的人，会
在没有任何地方写过 `true` 的情况下打开一个免密 shell。文件里显式写 `false` 还
有粘性：`SBM_FULL_ACCESS=1` 也无法把它重新打开。

其余开关是否开启我会另行决定。

安装完成后请告诉我：
- config.toml 的路径，以及旁边 SQLite 数据库的路径
- 它监听的地址和端口
- `loginctl show-user <user> -p Linger` 的结果。没有 linger,--user 服务会
  在我登出时停止。
- config.toml 和数据库的权限位。配置里可能有推送凭据，数据库里有面板用户表，
  两者都不应该对同组或其他用户可读。
```

</details>

<details>
<summary>开启 remote access</summary>

```text
配置 <host> 上的 ServerBox Monitor agent，让 app 和面板可以
<打开终端 / 浏览文件 / 执行命令>。

修改前先说明这样做的风险，并等我同意：`full_access = true` 会让拿到面板密码的
人直接获得 agent 运行账户的 shell，中间没有 SSH 认证。

请特别注意：

- 这些开关只存在于 agent 的 config.toml 里。没有任何 API 或面板控件能打开
  它们；面板只能关闭 `full_access`。只有修改配置文件才能开启这些功能。
- `full_access` 以 `[remote_access.terminal] enabled` 为前提。只设
  full_access 不起任何作用。
- 终端和文件 API 会拒绝从网络上到达的明文请求,但对 loopback 调用方——包括
  同机反向代理——无需 TLS 即可服务。所以如果 agent 绑定在 127.0.0.1,或者由
  同机代理终结 TLS,就不需要 `allow_insecure`。只有当 agent 能被另一台机器
  直接以明文访问时才考虑它,并且动手前先说。
- `[remote_access.fs]` 没有 `roots` 就什么都不做。只写真正需要浏览的目录。
  `roots = ["/"]` 会让面板密码等价于一个 shell,因为能写
  ~/.ssh/authorized_keys 的人就有 shell,agent 启动时也会对此告警。

修改后重启 agent，并把日志里的 `Remote access:` 那一行发给我。这一行会说明实际
开启了哪些功能；如果全部关闭，就不会出现这一行。
```

</details>

<details>
<summary>添加告警规则和通知渠道</summary>

```text
给 <host> 上的 ServerBox Monitor agent 添加一条告警规则。

我想在什么情况下收到告警：<描述>

请严格使用下面的规则格式：

- 一条规则是一个 `[[monitoring.rules]]` 表,含 `name`、`monitor_type`、
  `matcher` 和 `threshold`。
- `monitor_type` 取 cpu、memory、swap、disk、network、temperature 之一。
  `mem`、`net`、`temp` 也可以使用。填入其他值时，agent 只会记录日志，这条规则
  不会触发。
- `matcher` 选取指标的哪一部分：`cpu0` 表示单个核心，memory 和 swap 用
  `used`/`free`/`avail`，network 用 `rx`/`tx`。disk 和 temperature 完全忽略
  它。
- `matcher` **不是**网卡名，也不是挂载点。写成 `matcher = "eth0"` 的 network
  规则会静默地改为测量 rx+tx 总量，而不是那块网卡。
- `threshold` 是比较符 + 数值 + 单位：`>=80%`、`<10%`、`>10m/s`、`>=70c`。
  不写比较符等于 `<`，所以 `80%` 的含义是「低于 80%」。
- 单位必须与指标相符：cpu/memory/swap/disk 用 `%`，temperature 用 `c`，
  network 用体积或体积加 `/s`。体积按 1024 进制、单位小写。不相符的组合会被
  记录到日志且永不触发。

如果我还要求配置通知渠道，请加上对应的 `[[push]]` 表。`push_rate` 在
config.toml 中按渠道限流，而不是按规则限流。

agent 只在启动时读取规则和渠道，所以修改后要重启。然后把实际写入的内容原样发给我。
```

</details>

<details>
<summary>排查 app 里某个功能为什么不出现</summary>

```text
ServerBox app 没有为 <host> 上的 Monitor agent 提供 <功能>。请先查清原因，
不要直接修改配置；先告诉我你的结论。

请先检查这些地方：

- app 只显示 agent 在 `GET /api/v1/capabilities` 上声明的内容。终端、命令、
  容器、进程、systemd、电源和计划任务都需要 `full_access`,而它本身以
  `[remote_access.terminal] enabled` 为前提。文件浏览需要
  `[remote_access.fs] enabled` 加上非空的 `roots`。
- SFTP 和端口转发在 agent 上根本不存在。没有任何 endpoint 能把连接中继到
  app 指定的地址,所以这两项需要在 app 里为同一台服务器另行配置 SSH。
- 终端和文件 API 会拒绝从网络上到达的明文请求。loopback 调用方和同机反向
  代理无需 TLS。
- 只要该小节下有任何开关开启，agent 启动时就会记录一行 `Remote access:`
  汇总；全部关闭时则不会记录。
- agent 的 SQLite 数据库里的 `access_log` 表记录访问者、时间、来源、请求的
  资源和结果，不记录凭据。
```

</details>

## 选择 SSH 还是 Monitor agent

| | SSH | Monitor agent |
|---|---|---|
| 需要在服务器上安装额外软件 | 否 | 是 |
| 查看状态和图表 | 支持 | 支持 |
| 查看 App 连接前的历史数据 | 不支持 | 支持 |
| 终端、命令和文件浏览 | 支持 | 取决于 agent 开启的功能 |
| SFTP 传输和端口转发 | 支持 | 不支持 |
| 推送告警、主屏幕小组件和 Watch App | 不支持 | 支持 |

通常直接使用 SSH 即可。以下情况适合使用 Monitor agent：SSH 端口从当前网络不可达；希望在打开 App 前就有历史图表；或者希望接收服务器告警。

两种方式可以同时使用：服务器可以在 App 中配置 SSH，同时运行 Monitor agent 为主屏幕小组件和 Watch App 提供数据。

## 安装 Monitor agent

如果仓库已有 `monitor-v*` release，可以从发布页下载；否则请自行构建。发布 workflow 需要手动触发。未发布版本或离线安装时，请使用本地构建包和 `SBM_INSTALL_PKG`。

安装脚本会自动识别 init 系统：

```sh
# systemd：安装为 `systemctl --user` 服务，以当前用户运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install

# 没有可下载的 release，或进行离线安装
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | SBM_INSTALL_PKG=/path/to/server-box-monitor sh -s -- install

# OpenRC（Alpine）：写入 /etc/init.d 需要 root，但 agent 仍以执行 sudo 前的用户运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install
```

`sh -s --` 之后的内容都会传给脚本，`uninstall` 和 `upgrade` 同理。脚本本身也在
仓库里，在 checkout 根目录执行 `./monitor/install.sh install` 做同样的事——用的
是这份 checkout 里的脚本，不一定和上面命令拉取的 `main` 版本相同。

默认情况下，agent 以普通用户运行。这样可以限制 `full_access` 开启时的权限范围，详见[权限开关](#权限开关)。

配置文件位于二进制文件旁边的 `config.toml`。所有配置项都在 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml) 中说明。agent 默认监听 `0.0.0.0:3770`；如果存在 `frontend/dist`，还会在该地址提供网页面板。

其中一部分不必打开文件也能修改。采集间隔、告警规则、通知渠道、数据保留和允许的面板来源，可以在网页面板的 **Server Settings** 页编辑；App 里打开配置了 agent 的服务器，点右上角的设置按钮即可。两者连的是同一个 agent，写的是同一个文件。不开放编辑的部分是有意为之：JWT secret、`database_url` 和 `[remote_access]` 开关只能改文件，这样面板密码永远无法扩大 agent 的暴露面。

文件中已有的密钥和 token —— ServerChan key、Bark key、iOS push token、`Authorization` header —— 不会回传给编辑器。它们显示为「已设置」且输入框为空；留空即保持原值，输入新值则替换。保存后的通知渠道要等 agent 下次启动才进入规则引擎，告警规则、采集间隔、数据保留和允许来源同理。只有扩展采集周期和两个闲置暂停设置是立即生效的。App 会标出需要重启的字段。

如果 agent 需要从其他设备访问，请使用 HTTPS：可以配置内置 TLS（`[server.tls]`），也可以放在反向代理后面。App 支持自签名证书，但必须由你明确开启相关选项。

## 在 App 中添加

1. 点击 **+** 添加服务器。
2. 打开 **Monitor HTTP** 开关。
3. 填写：
   - **URL**：例如 `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**：agent 网页面板的登录凭据
   - **Monitor Ignore certificate**：仅在使用自签名证书时开启
4. 保存配置。

通过 Monitor HTTP 添加的服务器**不包含 SSH 凭据**。除了 agent 明确提供的功能外，App 没有其他方式访问这台服务器。

## 权限开关

agent 会通过 `GET /api/v1/capabilities` 告诉 App 当前允许的功能，App 只显示这些功能。网页面板中的文件 API 和终端默认关闭，只能由运维人员在 `config.toml` 中开启。

**状态、图表和历史数据**只需要面板登录凭据。

**`full_access`** 允许已登录用户直接获得 agent 所属用户的 shell，并执行命令。因此，进程、systemd 单元、容器、代码片段、电源控制和终端等功能都依赖它。

`full_access` 只有一个开关：能获得 shell 的用户也能在 shell 中执行任意命令，因此无法通过单独关闭“命令”来缩小权限范围。Linux 默认开启，macOS 和 Windows 默认关闭。面板可以关闭它，但不能重新开启；重新开启必须修改配置文件。

**面板密码等同于 agent 用户的 shell 访问权限。** 因此 `install.sh` 默认以普通用户运行 agent。如果确实需要以 root 用户运行，请关闭 `full_access`。

**`[remote_access.fs]`** 提供文件浏览，访问范围限制在 `roots` 指定的目录中。它独立于 `full_access`，因为文件 API 只授予目录范围内的访问，而 `full_access` 授予的是 shell。`roots` 没有默认值；启用文件 API 时必须明确指定目录。

agent 会将请求解析为真实路径，跟随 symlink，并拒绝 `..` 路径。解析后的路径必须位于 `roots` 内部，因此指向 `/etc` 的 symlink 也不能绕过限制。将 `roots` 设为 `['/']` 几乎等同于授予 shell，agent 启动时会对此发出警告。

除非配置 `[remote_access.fs] allow_insecure = true`，文件 API 也不会在明文 HTTP 上运行。只设置 `enabled` 和 `roots` 而没有 TLS，它仍然是关闭的。

**`[remote_access.terminal]`** 同时为 App 和网页面板开启终端 endpoint。网页面板终端通过 SSH 连接 `ssh_addr`，权限与对应 SSH 账号相同；App 的无密码终端则在 `full_access` 开启时使用 agent 用户的本地 shell。仅有面板登录凭据并不会自动获得 shell。

除非配置 `[remote_access.terminal] allow_insecure = true`，终端不会在明文 HTTP 上运行，因为第一条消息可能包含 SSH 密码。配置 TLS 或使用同机反向代理即可满足要求。App 还必须针对该服务器开启 **允许不安全 HTTP**；两端的设置都必须开启。

## 不支持的功能

仅配置 Monitor HTTP 的服务器不提供 SFTP 和端口转发。agent 没有把连接中继到 App 指定地址的 endpoint，因此无法承载这两种功能。文件**浏览**可以通过 agent 的文件 API 工作，但它传输的是文件内容，而不是提供任意 TCP 字节流。

如果需要 SFTP 或端口转发，请在 App 中同时为该服务器配置 SSH。

## 小组件、推送和 Watch App

这些功能直接从 Monitor agent 获取数据，不依赖 App 在前台运行：

- **主屏幕小组件**：安装 Monitor agent 后，在 App 中配置服务器；小组件从 App 发布的服务器列表中选择目标，不需要手动填写 URL。
- **Watch App**：只能显示已配置 Monitor agent 的服务器。默认会同步这些服务器，也可以在 iOS 设置中排除指定服务器。
- **推送告警**：规则决定何时告警，渠道决定发往哪里 —— 即 `config.toml` 中的 `[[monitoring.rules]]` 和 `[[push]]`，也可以在 App 和网页面板里编辑这两个列表，渠道还带一个 **发送测试** 按钮。规则怎么写见 [告警规则](#告警规则)。

## 告警规则

一条规则有四个字段。**指标** 决定读什么，**匹配** 决定读它的哪一部分，**阈值** 决定这个读数何时值得告警。

```toml
[[monitoring.rules]]
name = "CPU busy"
monitor_type = "cpu"
matcher = "cpu"
threshold = ">=80%"
```

### 指标与匹配

| 指标 | 匹配 | 读数 |
| --- | --- | --- |
| `cpu` | `cpu` 或留空 | 全部核心的占用率 |
| `cpu` | `cpu0`、`cpu1`…… | 单个核心的占用率 |
| `memory` | `used`、`memory` 或留空 | 已用百分比 |
| `memory` | `free` | 未用百分比 |
| `memory` | `avail` | 可用百分比 |
| `swap` | `used`、`swap` 或留空 | 已用百分比 |
| `swap` | `free` | 未用百分比 |
| `disk` | 忽略 | 全部文件系统合计的已用百分比 |
| `network` | `rx` 或 `in` | 接收速度 |
| `network` | `tx` 或 `out` | 发送速度 |
| `network` | 留空或其他值 | 接收加发送 |
| `temperature` | 忽略 | agent 上报的机器温度 |

`mem`、`net`、`temp` 同样被接受，因此从 Go agent 迁移过来的配置可以继续使用。其他指标每个采集周期在 agent 日志里记录一次，规则不会触发。

### 阈值

一个比较符、一个数值、一个单位：`>=80%`、`<10%`、`>10m/s`、`>=70c`。

| 比较符 | 触发条件：读数 |
| --- | --- |
| `>=` | 大于等于该值 |
| `>` | 大于该值 |
| `<=` | 小于等于该值 |
| `<` | 小于该值 |
| `=` | 等于该值 |

**不写比较符等于 `<`。** `80%` 的含义是「低于 80%」而不是「高于」——常见写法应该是 `>=80%`。

单位决定阈值的类型，类型必须与指标相符：

| 单位 | 类型 | 适用指标 |
| --- | --- | --- |
| `%` | 百分比 | `cpu`、`memory`、`swap`、`disk` |
| `c` | 温度 | `temperature` |
| 体积后加 `/s`，如 `10m/s` | 速度 | `network` |
| `b`、`k`、`m`、`g`、`t` | 体积 | `network` |

体积按 1024 进制，单位小写。单位与指标不符的阈值 —— 例如 `network` 规则写 `>=80%` —— 会被写入日志且永不触发，也就是说这条规则处于静默失效状态，而不是判断错误。

### 示例

```toml
[[monitoring.rules]]
name = "Core 0 pinned"
monitor_type = "cpu"
matcher = "cpu0"
threshold = ">=95%"

[[monitoring.rules]]
name = "Memory running out"
monitor_type = "memory"
matcher = "avail"
threshold = "<10%"

[[monitoring.rules]]
name = "Disk filling up"
monitor_type = "disk"
matcher = ""
threshold = ">=90%"

[[monitoring.rules]]
name = "Download burst"
monitor_type = "network"
matcher = "rx"
threshold = ">10m/s"

[[monitoring.rules]]
name = "Running hot"
monitor_type = "temperature"
matcher = ""
threshold = ">=70c"
```

### 规则不触发的情况

- **network 规则在第一个采集周期不会触发**：agent 刚启动、采集中断过、或网卡刚出现时都是如此。速度是两次采样之差，第二次采样落地之前没有速度可言。
- **读不到数据的周期会被跳过，而不是按 0 判断。** 内存或磁盘读不到时规则直接跳过；否则 `>=90%` 的规则会在磁盘正在写满的机器上保持沉默，`<10%` 的规则会在正常机器上误报。
- **temperature 规则需要有温度读数。** 并非所有机器都上报温度。

限流按渠道计算，不按规则计算：见 `config.toml` 中的 `push_rate`，或 App 里的 **限流**。

## 故障排除

**服务器页面缺少功能按钮。** App 显示的是 agent 声明允许的功能。命令和终端需要 `full_access` 以及 terminal endpoint；文件浏览需要 `[remote_access.fs]` 和 `roots`。修改配置后重启 agent。

**证书错误。** 配置有效的 TLS，将 agent 放在反向代理后，或为该服务器开启 **Monitor Ignore certificate**。

**面板由其他 origin 提供。** 在 `config.toml` 的 `cors_allowed_origins` 或环境变量 `SBM_CORS_ORIGINS` 中明确允许该 origin。

**请求没有响应。** 先确认 agent 正在运行、端口可达，再检查数据库中的 `access_log`。日志记录访问者、时间、来源、访问内容和结果，不记录凭据。
