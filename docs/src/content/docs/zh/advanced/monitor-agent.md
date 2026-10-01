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

不要把它装成 root 系统服务。角色带有 `shell` 权限的账号会以 agent 的运行账户
执行命令；以 root 运行时，就等于整台机器。

给安装脚本加上 `--permissions read`（`sh -s -- install --permissions read`），
让它创建的 admin 账号初始不带任何权限。我会之后在 app 或网页面板里开启需要的
权限。

不要在 config.toml 的 `[remote_access]` 下添加 `full_access`、`listen_public`
或任何 `enabled`。agent 已经不读这些配置：每个账号能做什么由它的角色决定，角色
保存在 agent 的数据库里。

安装完成后请告诉我：
- config.toml 的路径，以及旁边 SQLite 数据库的路径
- initial-admin-credentials.txt 的路径。不要输出其中的内容。
- 它监听的地址和端口
- `loginctl show-user <user> -p Linger` 的结果。没有 linger,--user 服务会
  在我登出时停止。
- config.toml 和数据库的权限位。配置里可能有推送凭据，数据库里有面板用户表，
  两者都不应该对同组或其他用户可读。
```

</details>

<details>
<summary>准备 remote access 的服务器配置</summary>

```text
配置 <host> 上的 ServerBox Monitor agent，让账号可以被授予
<终端 / 文件浏览 / 执行命令 / 端口转发>。

修改前先说明这样做的影响，并等我同意。

请特别注意：

- 账号能做什么不在 config.toml 里。每个账号属于一个角色，角色带有若干权限：
  shell、ssh_terminal、files、connect 和 listen。admin 在 app 或网页面板里
  编辑账号和角色，编辑时需要再次输入自己的密码。不要试图通过修改 config.toml
  或数据库来授予权限。
- config.toml 仍然决定服务器一侧的配置：
  - 读取监控数据以外的所有功能都需要 TLS 或 loopback 调用方，同机反向代理也
    算 loopback。如果 agent 绑定在 127.0.0.1，或由同机代理终结 TLS，就不需要
    其他配置。只有当另一台机器通过明文连接直接访问 agent 时，才考虑设置
    `[remote_access] allow_insecure = true`；操作前请先说明。
  - files 权限在没有 `[remote_access.fs] roots` 时不提供任何文件。只写真正
    需要浏览的目录。`roots = ["/"]` 加上写权限等价于一个 shell，因为能写入
    ~/.ssh/authorized_keys 的人就能获得 shell；agent 启动时会对此发出警告。
  - 网页面板的 SSH 终端连接 `[remote_access] ssh_addr`。

修改 config.toml 后重启 agent。然后告诉我需要在 app 或面板里为哪个角色开启
哪些权限。
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

- app 显示的是 agent 允许当前登录账号使用的功能。每项权限都带有 `ok`，不可用
  时还带有 `why`：`not_granted`（账号的角色没有这项权限，admin 可以在 app 或
  面板里修改）、`insecure_transport`（需要 TLS 或 loopback 调用方，或者
  `[remote_access] allow_insecure`）、`not_configured`（files 权限没有配置
  `[remote_access.fs] roots`）。用该账号登录后请求
  `GET /api/v1/capabilities`，可以在 `grants` 下看到这些信息。
- 命令、进程、systemd、容器、代码片段、电源、计划任务、防火墙和 app 终端需要 `shell`。
  文件浏览需要 `files`；`mode = "read"` 时不能修改任何内容。远程桌面以及本地和
  动态转发需要 `connect`，它的 `allow` 列表不为空时必须包含目标地址。远程转发
  需要 `listen`；绑定 loopback 以外的地址需要开启它的 `public` 选项。
- SFTP 无法通过 agent 使用，需要在 app 里为同一台服务器另行配置 SSH。
- 角色功能之前的 agent 只上报 `remote_access`；早于 relay 或监听端点的 agent
  不提供端口转发和远程桌面。请更新 agent。
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
| 终端、命令和文件浏览 | 支持 | 取决于账号的角色 |
| SFTP 传输 | 支持 | 不支持 |
| 端口转发（本地、动态、远程）和远程桌面 | 支持 | 需要 `connect` 或 `listen` 权限 |
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

若要让 admin 账号初始不带任何权限，加上 `--permissions read`：

```sh
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install --permissions read
```

`--permissions full|read` 决定全新安装时 admin 账号的初始权限：全部权限（`full`，默认值），或不带任何权限（`read`），之后再在 App 或面板中开启。该参数通过服务环境变量 `SBM_INIT_PERMISSIONS` 传给 agent；自行运行二进制文件时，使用 `serve --init-permissions read`。它只在 agent 创建第一个账号时生效，已有的安装会保留现有角色。

`sh -s --` 后面的参数会传给安装脚本；执行 `uninstall` 和 `upgrade` 时也使用相同方式。仓库中也包含该脚本，可在 checkout 根目录运行 `./monitor/install.sh install`。此时使用的是 checkout 中的版本，可能与上述命令从 `main` 下载的版本不同。

默认情况下，agent 以普通用户运行。角色带有 `shell` 权限的账号会以该用户执行命令，因此这样可以限制这类账号能访问的范围，详见[账号和权限](#账号和权限)。

agent 从二进制文件所在目录读取 `config.toml`。所有可用配置项见 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)。默认监听地址是 `0.0.0.0:3770`；该目录下存在 `frontend/dist` 时，agent 也会在此提供网页面板。

无需直接编辑 `config.toml`，也可以修改采集间隔、告警规则、通知渠道、数据保留时间和允许的面板来源。在网页面板使用 **Server Settings**，或在 App 中打开已配置 agent 的服务器并点击顶部设置按钮。两个入口会修改同一个 agent 和配置文件。

只有 admin 账号能查看和修改这些设置。JWT secret、`database_url` 和 `[remote_access]`（是否允许明文、文件 roots、SSH 地址和各项限额）只能通过配置文件修改。账号能做什么不属于这两处：它由账号的角色决定，由 admin 在 App 或面板中编辑，详见[账号和权限](#账号和权限)。

编辑器不会返回文件中已保存的 secret，例如 ServerChan key、Bark key、iOS push token 或 `Authorization` header。界面会显示“已设置”，但输入框保持为空。留空表示保留原值；输入新值则会替换。

通知渠道、告警规则、采集间隔、数据保留和允许来源需要重启 agent 后生效。扩展采集周期和两个闲置暂停设置会立即生效。App 会标明哪些配置需要重启。

如果要让其他设备连接 agent，请启用 HTTPS：可配置内置 TLS（`[server.tls]`），也可使用反向代理。若使用自签名证书，需在 App 中为该服务器明确开启 **Monitor Ignore certificate**。

## App 能回溯多久

图表可选范围取决于 Monitor agent 的数据保留时长和已采集的历史数据。App 只显示 agent 能提供的范围。API 字段和历史查询行为见[Monitor agent API 与访问模型](/docs/zh/development/monitor-agent/)。

## 面板凭据

App 和网页面板使用的账户保存在 agent 的 SQLite 数据库中，不在 `config.toml` 里配置。该文件中的 `jwt_secret` 用于签署会话 token，并不是账户密码。

以下命令必须由运行 agent 的账户在其工作目录中执行：root 服务使用 `/opt/server-box-monitor`，其他情况使用 `~/.local/share/server-box-monitor`。`config.toml` 和数据库路径都相对于当前工作目录解析。如果在其他目录执行，命令会创建默认配置和空数据库，并成功修改一个实际服务不会使用的数据库。

### 首个密码

首次启动且用户表为空时，agent 会创建属于 `admin` 角色的 `admin` 用户，并生成随机密码。密码会写入数据库旁的 `initial-admin-credentials.txt`；Unix 系统上的文件权限为 0600：

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

命令会要求输入两次新密码，输入时不会回显，密码至少需要 8 个字符。如果指定的用户不存在，命令会创建该用户，并放入 `viewer` 角色；agent 还没有任何 admin 账号时，则放入 `admin` 角色。加上 `--role <名称>` 可以指定其他角色，也可以用它修改已有账号的角色。admin 也可以在 App 或面板中添加账号，见[编辑账号和角色](#编辑账号和角色)。

如需从环境变量读取密码（例如用于脚本或避免写入 shell history），请在 Bash 或 Zsh 中运行以下命令。`read -s` 不是 POSIX `sh` 的命令；后续检查可避免读取失败或密码为空时设置空密码：

```bash
read -rsp 'Password: ' SBM_PW && echo
[ -n "$SBM_PW" ] || { echo '未输入密码' >&2; exit 1; }
SBM_PW="$SBM_PW" ./server_box_monitor user set-password admin --password-env SBM_PW
```

命令不接受密码作为参数，因为命令行参数可能出现在 `ps` 输出和 shell history 中。

修改密码后，旧密码对应的访问会结束：

- **登录和已配对的设备：无论用哪种方式修改，都会立即失效。** 修改前的登录从下一次请求起被拒绝，该账号已配对的小组件和 Watch 会被解除配对。这一步不需要重启 agent，也不需要修改 `jwt_secret`。
- **已打开的终端、端口转发和监听：在 App 或面板中修改时会立即关闭。** 上面的命令只写数据库，无法通知正在运行的 agent，因此用旧密码打开的连接会一直持续到 agent 重启：systemd 使用 `systemctl --user restart server_box_monitor`，OpenRC 使用 `rc-service server-box-monitor restart`。如果是因为密码可能已经泄露而重置，请在重置后重启 agent。

每个账号也可以在 App 或面板中修改自己的密码，见[编辑账号和角色](#编辑账号和角色)。在 App 中修改时，App 会同时更新为该服务器保存的密码。

在服务器上修改密码后，请在 App 中编辑服务器并更新 **Monitor Password**，其他保存了该凭据的客户端也要同步更新。客户端不会收到密码变更通知，因此更新前无法登录。

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

## 账号和权限

每个账号都可以查看状态、图表和已保存的历史数据。其他功能都属于**权限**，账号拥有其**角色**的权限。权限和角色保存在 agent 的数据库中，在 App 或网页面板里编辑。`config.toml` 只决定服务器一侧的配置，例如文件可以来自哪些目录、是否允许明文 HTTP。

| 权限 | 允许的功能 | 选项 |
|---|---|---|
| `shell` | 以 agent 的系统账户执行命令，包括进程、systemd、容器、代码片段、电源、计划任务、防火墙和 App 终端 | 无 |
| `ssh_terminal` | 网页面板的终端，用 SSH 账户自己的凭据登录 `[remote_access] ssh_addr` 指定的 SSH server | 无 |
| `files` | 在 `[remote_access.fs] roots` 范围内浏览文件 | `read`（浏览和下载）或 `write`（另外允许上传、新建、重命名、chmod 和删除） |
| `connect` | 远程桌面（RDP、VNC）以及本地和动态端口转发，即由 agent 发起的连接 | `allow`：允许访问的地址；为空表示不限制 |
| `listen` | 远程端口转发，即由 agent 在服务器上监听端口 | `public`：允许 loopback 以外的地址；端口范围 |

`shell` 实际上包含了其他几项：能执行命令的账号可以自己读取文件、建立连接和监听端口。账号只需要某一项时，可以只授予 `files`、`connect` 或 `listen`，不授予 `shell`，例如只能访问一台远程桌面的角色。

### 角色

agent 有两个内置角色：

- **admin**：拥有为它设置的权限，并且是唯一能管理账号、角色和 agent 设置的角色。agent 设置包括告警规则、通知渠道、采集间隔和允许的来源。编辑自定义命令还需要 `shell`，因为这些命令由 agent 执行。
- **viewer**：不带任何权限，只能查看状态、图表和历史数据。

admin 可以修改两个内置角色的权限，也可以添加新角色。角色名只能包含小写字母、数字、`-` 和 `_`，最长 32 个字符。内置角色不能重命名或删除；仍有账号在使用的角色不能删除。最后一个 admin 账号不能被删除，也不能改为其他角色。

### 编辑账号和角色

在 App 中打开服务器，点击顶部的设置按钮，在**访问**下使用**账号**和**角色**。在网页面板中，它们位于**服务器设置**页面的末尾。每次修改账号或角色都需要再次输入自己的密码；输错的次数与登录共用同一个限流。

修改会立即生效。依赖某项权限的会话，例如终端、远程桌面或端口转发，在账号失去这项权限后会被关闭。已删除账号的所有会话都会立即失效。

每个账号（包括非 admin 账号）都可以查看自己的角色并修改自己的密码：在 App 中位于**访问**下，在面板中位于**你的账号**下。

### 新安装的权限

全新安装时，`admin` 账号属于 `admin` 角色，拥有全部权限：可写的 `files`、不限制地址的 `connect`、只监听 loopback 且不限端口的 `listen`、`shell` 和 `ssh_terminal`。安装时使用 `--permissions read` 可以让它初始不带任何权限，之后在 App 或面板中开启需要的权限，见[安装 Monitor agent](#安装-monitor-agent)。

如果 agent 启动时读取的 `config.toml` 仍然设置了旧开关（`full_access`、`[remote_access.terminal] enabled`、`[remote_access.fs] enabled`、`listen_public`），例如在新的数据卷上挂载了旧配置，或复制了旧的示例配置，全新安装也会遵守这些开关：`admin` 角色只获得它们同样允许的权限，日志中会说明这一点。

`files` 仍然需要配置 `[remote_access.fs] roots`。在配置之前，App 会提示 agent 上未配置文件浏览。无论 `roots` 如何设置，文件 API 都无法访问 agent 自己的文件，包括数据库、`jwt.secret`、`config.toml` 及其备份、`.env`、TLS 密钥和证书、自定义命令，因为读取这些文件就等于拿到 admin 登录。

**角色带有 `shell` 的账号，相当于拥有 agent 运行账户的 shell。** 因此 `install.sh` 默认以普通用户运行 agent。若选择以 root 运行，请先考虑这一点。

### 从没有角色的 agent 升级

之前的 agent 使用 `config.toml` 中的开关，而不是角色。带有角色的 agent 首次启动时会转换一次：所有已有账号都成为 admin，`admin` 角色获得旧开关实际允许的权限。

| 旧配置 | 转换结果 |
|---|---|
| `[remote_access.terminal] enabled` | `ssh_terminal` |
| `full_access`（包括平台默认值和 `SBM_FULL_ACCESS`），仅在终端开启时计入 | `shell`、不限制地址的 `connect`，以及 `listen` |
| `listen_public` | 开启 `public` 的 `listen` |
| `[remote_access.fs] enabled` 且 `roots` 非空 | 可写的 `files` |

之后 agent 不再读取这些配置，并在日志中提示一次可以删除它们。在面板首次使用提示中关闭 shell 访问，会从所有角色中移除 `shell`、`connect` 和 `listen`。

### 明文 HTTP

读取监控数据以外的所有功能都需要 HTTPS，或来自同一台主机的调用方（包括同机反向代理）。在已经对流量加密的私有网络（例如 Tailscale）中，可以设置 `[remote_access] allow_insecure = true`，并在 App 中为该服务器开启**允许不安全 HTTP**；两者缺一不可。旧的 key 仍然有效，但只对原来覆盖的范围生效：`[remote_access.terminal] allow_insecure` 对应 shell、终端、connect 和 listen，`[remote_access.fs] allow_insecure` 只对应文件。

### 连接和监听的限制

`connect.allow` 每行一项：IP 地址或 CIDR 网段，后面可以跟端口或端口范围，例如 `127.0.0.1:3389`、`10.0.0.0/8` 或 `[::1]:5900-5910`。连接使用主机名时，agent 会先解析主机名，解析得到的每个地址都必须在允许范围内。`localhost` 通常同时解析为 `127.0.0.1` 和 `::1`，只允许其中一个会导致 `localhost` 被拒绝；请在 App 中直接填写地址。

和 sshd 的 `GatewayPorts no` 一样，远程转发默认只绑定 loopback 地址，除非角色的 `listen` 开启了 **public**。`listen` 上的端口范围限制可以绑定的端口。

路径校验、endpoint 行为和错误码见[Monitor agent API 与访问模型](/docs/zh/development/monitor-agent/)。

## 不支持的功能

Monitor HTTP 连接不支持 SFTP：SFTP 运行在 SSH channel 上。文件 API 支持**浏览**，通过传输文件内容工作，不提供通用字节流。

以 agent 为主的服务器（只配置了 agent，或同时配置了 SSH 但优先 agent）的所有端口转发都只经过 agent，不会回退到 SSH。动态转发是本机上的 SOCKS5 代理，每条连接都从服务器发起。

要使用 SFTP，请同时在 App 中为该服务器配置 SSH。早于 relay 或监听端点的 agent 不提供远程桌面和端口转发；请更新 agent。

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

**功能缺失或显示为灰色。** App 显示的是 agent 允许当前登录账号使用的功能，不可用时会说明原因：账号的角色没有这项权限（admin 可以修改）、连接需要 HTTPS，或 agent 运维人员尚未配置（例如文件 `roots`）。见[账号和权限](#账号和权限)。角色修改会立即生效；修改 `config.toml` 后需要重启 agent。

**无法修改设置。** 只有 admin 账号能查看和修改 agent 的设置、通知渠道和告警规则。请使用 admin 账号登录，或请 admin 修改你的角色。

**证书错误。** 配置有效的 TLS，将 agent 放在反向代理后，或为该服务器开启 **Monitor Ignore certificate**。

**面板使用不同的 origin。** 在 `config.toml` 的 `cors_allowed_origins` 或环境变量 `SBM_CORS_ORIGINS` 中添加该 origin。

**登录被拒绝，或密码丢失。** 在服务器上用 `user set-password` 重置，见[面板凭据](#面板凭据)。连续失败会被限流，所以密码错误也可能表现为 agent 变慢或不响应。

**请求无响应。** 确认 agent 正在运行且端口可达，再检查数据库中的 `access_log` 表。该表记录访问者、时间、来源、请求资源和结果，不保存凭据。
