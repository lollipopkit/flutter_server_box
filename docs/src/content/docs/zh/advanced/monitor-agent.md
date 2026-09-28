---
title: Monitor Agent
description: 通过 Monitor agent 访问服务器
---

Server Box Monitor 运行在服务器上，并将状态发送给 App。你无需开放 SSH 端口即可监控主机；即使 App 处于关闭状态，它也能继续为推送告警、主屏幕小组件和 Watch App 提供数据。

## 给 AI agent 的 prompt

下面的 prompt 可交给能够通过 SSH 访问服务器的 AI agent。内容明确列出了容易出错的配置细节。例如，告警规则无效时可能只记录日志而不触发，导致你收不到预期告警。

发送前请替换所有尖括号占位内容。

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
- 终端和文件 API 会拒绝从网络上到达的明文请求，但对 loopback 调用方——包括
  同机反向代理——无需 TLS 即可服务。因此，如果 agent 绑定在 127.0.0.1，或由
  同机代理终结 TLS，就不需要 `allow_insecure`。只有当另一台机器可以
  通过明文连接直接访问 agent 时，才应考虑开启它；操作前请先说明风险。
- `[remote_access.fs]` 没有 `roots` 就什么都不做。只写真正需要浏览的目录。
  `roots = ["/"]` 会让面板密码等价于一个 shell，因为能写入
  `~/.ssh/authorized_keys` 的人就能获得 shell。agent 启动时也会对此发出警告。

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

- app 只显示 agent 当前启用的功能。终端、命令、
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

SSH 通常是最简单的连接方式。若当前网络无法访问 SSH 端口、希望图表包含 App 连接前采集的历史数据，或希望在手机上接收服务器告警，可以使用 Monitor agent。

同一台服务器可以同时使用两种方式：在 App 中配置 SSH，并在服务器上运行 Monitor agent，为小组件、Watch App 和推送告警提供数据。

## 安装 Monitor agent

有 `monitor-v*` release 时可直接安装；否则请从源码构建。发布需要手动触发 workflow。安装未发布版本或进行离线安装时，可通过 `SBM_INSTALL_PKG` 指定本地安装包。

安装脚本会自动识别 init 系统：

```sh
# systemd：安装为 `systemctl --user` 服务，以当前用户运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install

# 没有可下载的 release，或进行离线安装
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | SBM_INSTALL_PKG=/path/to/server-box-monitor sh -s -- install

# OpenRC（Alpine）：写入 /etc/init.d 需要 root，但 agent 仍以执行 sudo 前的用户运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install
```

`sh -s --` 后面的参数会传给安装脚本；执行 `uninstall` 和 `upgrade` 时也使用相同方式。仓库中也包含该脚本，可在 checkout 根目录运行 `./monitor/install.sh install`。此时使用的是 checkout 中的版本，可能与上述命令从 `main` 下载的版本不同。

默认情况下，agent 以普通用户运行。这样可以限制 `full_access` 开启时的权限范围，详见[权限开关](#权限开关)。

agent 从二进制文件所在目录读取 `config.toml`。所有可用配置项见 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)。默认监听地址是 `0.0.0.0:3770`；该目录下存在 `frontend/dist` 时，agent 也会在此提供网页面板。

无需直接编辑 `config.toml`，也可以修改采集间隔、告警规则、通知渠道、数据保留时间和允许的面板来源。在网页面板使用 **Server Settings**，或在 App 中打开已配置 agent 的服务器并点击顶部设置按钮。两个入口会修改同一个 agent 和配置文件。

JWT secret、`database_url` 和 `[remote_access]` 开关只能通过配置文件修改。这样，即使面板密码泄露，攻击者也不能通过面板扩大 agent 暴露的功能。

编辑器不会返回文件中已保存的 secret，例如 ServerChan key、Bark key、iOS push token 或 `Authorization` header。界面会显示“已设置”，但输入框保持为空。留空表示保留原值；输入新值则会替换。

通知渠道、告警规则、采集间隔、数据保留和允许来源需要重启 agent 后生效。扩展采集周期和两个闲置暂停设置会立即生效。App 会标明哪些配置需要重启。

如果要让其他设备连接 agent，请启用 HTTPS：可配置内置 TLS（`[server.tls]`），也可使用反向代理。若使用自签名证书，需在 App 中为该服务器明确开启 **Monitor Ignore certificate**。

## App 能回溯多久

图表可选范围取决于 Monitor agent 的数据保留时长和已采集的历史数据。App 只显示 agent 能提供的范围。API 字段和历史查询行为见[Monitor agent API 与访问模型](/docs/zh/development/monitor-agent/)。

## 面板凭据

App 和网页面板使用的账户保存在 agent 的 SQLite 数据库中，不在 `config.toml` 里配置。该文件中的 `jwt_secret` 用于签署会话 token，并不是账户密码。

以下命令必须由运行 agent 的账户在其工作目录中执行：root 服务使用 `/opt/server-box-monitor`，其他情况使用 `~/.local/share/server-box-monitor`。`config.toml` 和数据库路径都相对于当前工作目录解析。如果在其他目录执行，命令会创建默认配置和空数据库，并成功修改一个实际服务不会使用的数据库。

### 首个密码

首次启动且用户表为空时，agent 会创建 `admin` 用户并生成随机密码。密码会写入数据库旁的 `initial-admin-credentials.txt`；Unix 系统上的文件权限为 0600：

```sh
cd /opt/server-box-monitor
cat initial-admin-credentials.txt
```

设置新密码后请删除此文件。如果数据库之后被删除或移走，导致用户表为空，而该文件仍存在，agent 会报错退出，不会覆盖原凭据并生成另一组密码。

### 修改或重置密码

```sh
cd /opt/server-box-monitor
./server_box_monitor user set-password admin
```

命令会要求输入两次新密码，输入时不会回显，密码至少需要 8 个字符。如果指定的用户不存在，命令会创建该用户；添加其他账户也使用此命令。

如需从环境变量读取密码（例如用于脚本或避免写入 shell history），请在 Bash 或 Zsh 中运行以下命令。`read -s` 不是 POSIX `sh` 的命令；后续检查可避免读取失败或密码为空时设置空密码：

```bash
read -rsp 'Password: ' SBM_PW && echo
[ -n "$SBM_PW" ] || { echo '未输入密码' >&2; exit 1; }
SBM_PW="$SBM_PW" ./server_box_monitor user set-password admin --password-env SBM_PW
```

命令不接受密码作为参数，因为命令行参数可能出现在 `ps` 输出和 shell history 中。

新密码从下一次登录起生效，无需重启 agent，因为每次登录都会读取用户表。已登录会话最多还能持续一小时（token 的有效期）。如需立即结束所有会话，请修改 `config.toml` 中的 `jwt_secret` 并重启 agent：systemd 使用 `systemctl --user restart server_box_monitor`，OpenRC 使用 `rc-service server-box-monitor restart`。重启后此前签发的 token 全部失效。

之后在 App 中编辑服务器并更新 **Monitor Password**，其他保存了该凭据的客户端也要同步更新。客户端不会收到密码变更通知，因此更新前无法登录。

### 忘记密码

网页面板不提供密码找回功能。请在服务器上运行上面的命令重置密码。

登录失败会按来源地址和用户名分别限流：前三次失败不会延迟，之后等待时间从 1 秒开始逐次翻倍，最长为 5 分钟。因此，密码错误也可能让 agent 看起来响应缓慢或没有响应。

## 在 App 中添加

1. 点击 **+** 添加服务器。
2. 打开 **Monitor HTTP**。它与 SSH 相互独立，可以单独启用，也可以同时启用两种连接方式。若两者都启用，在 **Preferred transport** 中选择 App 优先尝试的方式。
3. 填写：
   - **URL**：例如 `https://1.2.3.4:3770`
   - **Monitor User** / **Monitor Password**：agent 网页面板的登录凭据，见[面板凭据](#面板凭据)
   - **Monitor Ignore certificate**：仅在使用自签名证书时开启
4. 保存配置。

Monitor HTTP 配置不会添加 SSH 凭据。若没有另外配置 SSH，App 只能使用 Monitor agent 明确提供的功能访问服务器。

## 集成显卡监控

在 Linux 上，agent 通过内核 DRM/sysfs 接口读取 AMD 集成显卡数据；APU 无需安装 ROCm、`amd-smi` 或 `rocm-smi` 即可报告利用率。Intel GPU 利用率需要 `intel_gpu_top`，通常由 `intel-gpu-tools` 软件包提供。

App 和 Monitor agent 采集数据时都不会等待交互式 `sudo` 输入。如果 SSH 账户或 agent 账户无权读取 Intel GPU 性能计数器，GPU 仍会列出，但不会显示无法读取的指标。若要采集利用率，请按 Linux 发行版的方式为该账户授予 GPU PMU 访问权限。

每块 Linux GPU 都以 PCI 地址标识，例如 `0000:00:02.0`。因此，多块集成或独立 GPU 会分别显示为稳定条目。

## 权限开关

App 只显示 Monitor agent 运维人员开启的功能。文件 API 和网页面板终端默认关闭，必须在 `config.toml` 中启用。

**状态、图表和已保存的历史数据**：登录面板后即可查看。

**`full_access`** 允许已登录用户以运行 agent 的系统账户访问 shell 并执行命令。App 中的进程、systemd、容器、代码片段、电源控制、终端和远程桌面（RDP、VNC）都依赖此权限。获得 shell 的人也可以运行任意命令或转发端口。

只有启用 `[remote_access.terminal] enabled = true` 后，`full_access` 才会生效。

agent 只有一个 `full_access` 开关。获得 shell 的用户也能执行任意命令，单独设置“命令”开关无法限制这项权限。Linux 默认开启，macOS 和 Windows 默认关闭。面板可以关闭此权限；要重新开启，必须修改配置文件。

**启用 `full_access` 时，面板密码相当于运行 agent 的账户的 shell 凭据。** 因此 `install.sh` 默认以普通用户运行 agent。若选择以 root 运行，请关闭 `full_access`。

**`[remote_access.fs]`** 开启文件浏览，并将访问限制在 `roots` 列出的目录中。该设置只授予指定路径的访问；`full_access` 则授予 shell。`roots` 默认为空，启用文件 API 时必须明确列出目录。

设置 `roots = ["/"]` 会开放整个文件系统，权限接近 shell；agent 启动时会对此发出警告。从其他设备通过明文 HTTP 使用 File API 时，还必须设置 `[remote_access.fs] allow_insecure = true`。路径校验和 transport 详情见[Monitor agent API 与访问模型](/docs/zh/development/monitor-agent/)。

**`[remote_access.terminal]`** 为 App 和网页面板开启终端。网页面板连接配置的 SSH server，并使用该 SSH 账户的权限。启用 `full_access` 后，App 终端使用 agent 账户的本地 shell。仅有面板登录凭据不会授予 shell 权限。

终端连接应使用 HTTPS。若使用明文 HTTP，必须同时在 agent 配置中设置 `[remote_access.terminal] allow_insecure = true`，并在 App 中为该服务器开启**允许不安全 HTTP**。transport 要求和 endpoint 行为见[Monitor agent API 与访问模型](/docs/zh/development/monitor-agent/)。

## 不支持的功能

Monitor HTTP 连接不支持 SFTP 或端口转发。agent 没有将任意 TCP 连接中继到 App 指定地址的 endpoint，因此无法承载这些功能。文件 API 支持**浏览**，通过传输文件内容工作，不提供通用字节流。

要使用 SFTP 或端口转发，请同时在 App 中为该服务器配置 SSH。

## 小组件、推送和 Watch App

小组件、推送通知和 Watch App 都直接读取 Monitor agent，因此 App 无需保持在前台：

- **主屏幕小组件**：安装 Monitor agent 后，在 App 中配置服务器；小组件从 App 发布的服务器列表中选择目标，不需要手动填写 URL。
- **Watch App**：只能显示已配置 Monitor agent 的服务器。默认会同步这些服务器，也可以在 iOS 设置中排除指定服务器。
- **推送告警**：规则决定何时告警，渠道决定发往哪里 —— 即 `config.toml` 中的 `[[monitoring.rules]]` 和 `[[push]]`，也可以在 App 和网页面板里编辑这两个列表，渠道还带一个 **发送测试** 按钮。规则怎么写见 [告警规则](#告警规则)。

## 告警规则

每条规则由 `name`、`monitor_type`、`matcher` 和 `threshold` 四个字段组成。指标指定要测量的内容，matcher 选出要判断的部分，threshold 则设定触发告警的条件。

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

从 Go agent 迁移的配置也可以使用 `mem`、`net` 和 `temp` 这几个别名。其他指标每个采集周期都会记入 agent 日志，对应规则不会触发。

### 阈值

阈值由比较符、数值和单位组成，例如 `>=80%`、`<10%`、`>10m/s` 或 `>=70c`。

| 比较符 | 触发条件：读数 |
| --- | --- |
| `>=` | 大于等于该值 |
| `>` | 大于该值 |
| `<=` | 小于等于该值 |
| `<` | 小于该值 |
| `=` | 等于该值 |

省略比较符时默认使用 `<`。因此 `80%` 表示“低于 80%”；若要在读数达到或超过 80% 时告警，应写 `>=80%`。

单位必须与指标相符：

| 单位 | 类型 | 适用指标 |
| --- | --- | --- |
| `%` | 百分比 | `cpu`、`memory`、`swap`、`disk` |
| `c` | 温度 | `temperature` |
| 体积后加 `/s`，如 `10m/s` | 速度 | `network` |
| `b`、`k`、`m`、`g`、`t` | 体积 | `network` |

network 的体积单位使用 1024 进制并采用小写。单位与指标不匹配时（例如 `network` 规则使用 `>=80%`），agent 会记录错误日志，但规则不会触发。

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

- **network 规则需要两次采样。** agent 启动、采集间断或检测到新网卡后，第一次采样无法计算速度；收到下一次采样后才会判断规则。
- **缺少读数时会跳过该周期。** 内存或磁盘数据不可用时，agent 不会把读数当成 0 来判断规则。
- **temperature 规则需要温度数据。** 部分机器不会上报温度。

限流按通知渠道计算。请查看 `config.toml` 中的 `push_rate` 或 App 中的 **限流** 设置。

## 故障排除

**服务器页缺少功能。** App 只显示 agent 上报的能力。命令和终端需要 `full_access` 及 terminal endpoint；文件浏览需要启用 `[remote_access.fs]` 并配置 `roots`。改完配置后重启 agent。

**证书错误。** 配置有效的 TLS，将 agent 放在反向代理后，或为该服务器开启 **Monitor Ignore certificate**。

**面板使用不同的 origin。** 在 `config.toml` 的 `cors_allowed_origins` 或环境变量 `SBM_CORS_ORIGINS` 中添加该 origin。

**登录被拒绝，或密码丢失。** 在服务器上用 `user set-password` 重置，见[面板凭据](#面板凭据)。连续失败会被限流，所以密码错误也可能表现为 agent 变慢或不响应。

**请求无响应。** 确认 agent 正在运行且端口可达，再检查数据库中的 `access_log` 表。该表记录访问者、时间、来源、请求资源和结果，不保存凭据。
