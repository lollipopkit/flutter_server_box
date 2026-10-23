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

不要把它装成 root 系统服务。登录 agent 后可以做它运行所用的账户能做的一切；
以 root 运行时，就等于整台机器。

不要在 config.toml 的 `[remote_access]` 下添加 `full_access`、`listen_public`、
`roots` 或任何 `enabled`。agent 不读这些配置：没有需要配置的按功能权限。

安装完成后请告诉我：
- config.toml 的路径，以及旁边 SQLite 数据库的路径
- initial-admin-credentials.txt 的路径。不要输出其中的内容。
- 它监听的地址和端口
- `loginctl show-user <user> -p Linger` 的结果。没有 linger,--user 服务会
  在我登出时停止。
- config.toml 和数据库的权限位。配置里可能有推送凭据，数据库里有 agent 的
  密码哈希，两者都不应该对同组或其他用户可读。
```

</details>

<details>
<summary>准备 remote access 的服务器配置</summary>

```text
配置 <host> 上的 ServerBox Monitor agent，让 app 可以使用
<终端 / 文件浏览 / 执行命令 / 端口转发>。

修改前先说明这样做的影响，并等我同意。

请特别注意：

- 没有需要开启的权限。登录 agent 后可以做 agent 运行所用的系统账户能做的
  一切。不要为了让某项功能可用而改用 root 运行；请告诉我该账户缺少什么。
- 读取监控数据以外的所有功能都需要 TLS 或 loopback 调用方，同机反向代理也
  算 loopback。如果 agent 绑定在 127.0.0.1，或由同机代理终结 TLS，就不需要
  其他配置。只有当另一台机器通过明文连接直接访问 agent 时，才考虑设置
  `[remote_access] allow_insecure = true`；操作前请先说明。

修改 config.toml 后重启 agent。然后告诉我你改了什么。
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

- app 显示的是 agent 上报的功能。登录后请求 `GET /api/v1/capabilities`，
  `access` 下有 `ok`，为 false 时还有 `why`。`insecure_transport` 表示需要
  TLS 或 loopback 调用方，或者 `[remote_access] allow_insecure`。agent 提供的
  机器页面列在 `features` 下。
- 登录后可以做 agent 运行所用的系统账户能做的事。该账户访问不到的命令、文件
  或端口会失败。
- SFTP 无法通过 agent 使用，需要在 app 里为同一台服务器另行配置 SSH。
- 早于 relay 或监听端点的 agent 不提供端口转发和远程桌面。请更新 agent。
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
| 终端、命令和文件浏览 | 支持 | 支持，以 agent 运行所用的账户执行 |
| SFTP 传输 | 支持 | 不支持 |
| 端口转发（本地、动态、远程）和远程桌面 | 支持 | 支持 |
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

默认情况下，agent 以普通用户运行。登录后可以做该用户能做的一切，因此 agent 运行所用的账户决定了上限，详见[访问](#访问)。加上 `--system`（配合 `sudo`）则安装为 root 服务，登录后就是 root shell。

agent 从二进制文件所在目录读取 `config.toml`。所有可用配置项见 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)。默认监听地址是 `0.0.0.0:3770`；该目录下存在 `frontend/dist` 时，agent 也会在此提供网页面板。

无需直接编辑 `config.toml`，也可以修改采集间隔、告警规则、通知渠道、数据保留时间和允许的面板来源。在网页面板使用 **Server Settings**，或在 App 中打开已配置 agent 的服务器并点击顶部设置按钮。两个入口会修改同一个 agent 和配置文件。

JWT secret、`database_url` 和 `[remote_access]`（是否允许明文、SSH 地址和各项限额）只能通过配置文件修改。

编辑器不会返回文件中已保存的 secret，例如 ServerChan key、Bark key、iOS push token、`Authorization` header、SMTP 密码、Telegram bot token、Discord webhook URL 或 ntfy token。界面会显示“已设置”，但输入框保持为空。留空表示保留原值；输入新值则会替换。

通知渠道、告警规则、采集间隔、数据保留和允许来源需要重启 agent 后生效。扩展采集周期和两个闲置暂停设置会立即生效。App 会标明哪些配置需要重启。

如果要让其他设备连接 agent，请启用 HTTPS：可配置内置 TLS（`[server.tls]`），也可使用反向代理。若使用自签名证书，需在 App 中为该服务器明确开启 **Monitor Ignore certificate**。

### 升级

在服务器上，以安装 agent 时所用的账户运行：

```sh
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- upgrade
```

它会安装最新的 `monitor-v*` release，保留 `config.toml` 和数据库。不加 `--user` 或 `--system` 时，安装脚本会自行识别已安装的形式：`systemctl --user` unit、系统 unit 或 OpenRC 服务。后两种会通过 `sudo` 重新运行自身，并要求输入密码。找不到已安装的 agent 时（例如运行在 Docker 中）不做任何修改；Docker 请拉取新镜像并重建容器。

升级在 agent 运行时原地进行：先替换文件，最后重启。因此这条命令可以在 agent 自己打开的终端里运行；agent 重启时该终端会关闭，agent 几秒后恢复。

#### 在面板或 App 中更新

agent 每 12 小时检查一次 release，有新版本时留下一条通知。agent 知道自己的安装方式：`install.sh`、容器、NixOS 模块或其他。只有 `install.sh` 安装的可以自行更新，其他方式会说明各自的更新方法。

更新在 agent 之外运行：systemd 下是一个独立的临时服务（`systemd-run`），其他情况下是一个独立的会话。agent 重启会断开经由它的所有连接（包括面板和 App 的连接），但不会中断更新。输出写入 agent 目录下的 `update.log`，重启后的 agent 会报告更新结果。OpenRC 下安装脚本需要 root，agent 会要求输入 sudo 密码；密码只用一次，不会保存。

- **面板**：**设置 → 服务器 → ServerBox Monitor** 显示当前版本和最新 release，可点 **立即检查** 和 **立即更新**。更新期间页面显示输出，agent 重启时会提示，恢复后显示新版本。点击通知会打开此页面。
- **App**：**Monitor** 标签页会标出有新 release 的 agent，以及因版本过旧 App 无法登录的 agent。点击标记会打开同样的步骤，可点 **立即更新**。只用密码无法登录的旧 agent 仍需账户名：App 会请你填写账户名（通常是 `admin`），用它和已保存的密码登录一次，通过该 agent 的命令接口启动同样的更新。账户名不会保存。App 通过 SSH 连接服务器、而 agent 无法自行启动更新时，App 会在 SSH 终端中运行命令，重启不影响该终端。

## App 能回溯多久

图表可选范围取决于 Monitor agent 的数据保留时长和已采集的历史数据。App 只显示 agent 能提供的范围。API 字段和历史查询行为见[Monitor agent API 与访问模型](/docs/zh/development/monitor-agent/)。

## 面板凭据

agent 只有一个账号，只用密码登录，没有用户名。密码保存在 agent 的 SQLite 数据库中，不在 `config.toml` 里配置。该文件中的 `jwt_secret` 用于签署会话 token，并不是密码。

以下命令必须由运行 agent 的账户在其工作目录中执行：root 服务使用 `/opt/server-box-monitor`，其他情况使用 `~/.local/share/server-box-monitor`。`config.toml` 和数据库路径都相对于当前工作目录解析。如果在其他目录执行，命令会创建默认配置和空数据库，并成功修改一个实际服务不会使用的数据库。

### 首个密码

首次启动时，agent 会生成随机密码，并写入数据库旁的 `initial-admin-credentials.txt`；Unix 系统上的文件权限为 0600：

```sh
cd /opt/server-box-monitor
cat initial-admin-credentials.txt
```

设置新密码后请删除此文件。如果数据库之后被删除或移走，导致数据库中没有账号，而该文件仍存在，agent 会报错退出，不会覆盖原凭据并生成另一组密码。

### 修改或重置密码

```sh
cd /opt/server-box-monitor
./server_box_monitor password
```

命令会要求输入两次新密码，输入时不会回显，密码至少需要 8 个字符。数据库中还没有账号时，命令会创建它。

如需从环境变量读取密码（例如用于脚本或避免写入 shell history），请在 Bash 或 Zsh 中运行以下命令。`read -s` 不是 POSIX `sh` 的命令；后续检查可避免读取失败或密码为空时设置空密码：

```bash
read -rsp 'Password: ' SBM_PW && echo
[ -n "$SBM_PW" ] || { echo '未输入密码' >&2; exit 1; }
SBM_PW="$SBM_PW" ./server_box_monitor password --password-env SBM_PW
```

命令不接受密码作为参数，因为命令行参数可能出现在 `ps` 输出和 shell history 中。

修改密码会注销其他所有访问：

- **登录和已配对的设备：无论用哪种方式修改，都会立即失效。** 修改前的登录从下一次请求起被拒绝，已配对的小组件和 Watch 会被解除配对。这一步不需要重启 agent，也不需要修改 `jwt_secret`。
- **已打开的终端、端口转发和监听：** 在 App 或面板中修改密码时会立即关闭。上面的命令只更新数据库，不会通知正在运行的 agent；旧密码建立的连接会一直保持到 agent 重启。systemd 使用 `systemctl --user restart server_box_monitor`，OpenRC 使用 `rc-service server-box-monitor restart`。如果重置密码是因为它可能已泄露，请随后重启 agent。

也可以在 App（服务器页面顶部的设置按钮，然后选择**访问**）或面板中修改密码，两处都需要输入当前密码。在 App 中修改时，App 会同时更新为该服务器保存的密码。

在服务器上修改密码后，请在 App 中编辑服务器并更新 **Monitor Password**，其他保存了该密码的客户端也要同步更新。客户端不会收到密码变更通知，因此更新前无法登录。

### 忘记密码

网页面板不提供密码找回功能。请在服务器上运行上面的命令重置密码。

登录有限流。每次登录成功后，App 或浏览器会得到一个设备 token，之后每次登录都会带上它。登录过的设备按来源地址和该设备自身限流，其他地方的失败尝试不会把它锁住；其他客户端按来源地址和一个它们共用的计数限流。按地址和按设备计数时，前三次失败不会延迟；共用计数允许二十次。此后等待时间从 1 秒开始逐次翻倍，最长 5 分钟。连续输错密码时，agent 可能因此响应缓慢，甚至暂时没有响应。修改密码会让所有设备 token 失效。

## 在 App 中添加

1. 点击 **+** 添加服务器。
2. 打开 **Monitor HTTP**。它与 SSH 相互独立，可以单独启用，也可以同时启用两种连接方式。若两者都启用，在 **Preferred transport** 中选择 App 优先尝试的方式。
3. 填写：
   - **URL**：例如 `https://1.2.3.4:3770`
   - **Monitor Password**：agent 的密码，见[面板凭据](#面板凭据)
   - **Monitor Ignore certificate**：仅在使用自签名证书时开启
4. 保存配置。

Monitor HTTP 配置不会添加 SSH 凭据。若没有另外配置 SSH，App 只能使用 Monitor agent 明确提供的功能访问服务器。

## Monitor 标签页

App 的 **Monitor** 标签页显示所有通过 Monitor agent 添加的服务器。新安装的 App 不会把它放在导航栏中：可以从 **更多** 打开，或在 **设置 › 应用 › 主页标签** 中添加。在宽屏窗口中，左侧一栏是各部分和服务器列表；在手机上，从栏上的标题切换部分，从服务器按钮切换服务器。

- **概览**：每个 agent 是否可连接、它的版本（落后时同时显示最新版本）、正在触发的[告警规则](#告警规则)及当前读数和持续时间，以及未读通知、异常或有更新的 Web 应用的入口。
- **Web 应用**：见 [Monitor Web 应用](../monitor-apps/#在-serverbox-app-中打开应用)。
- **通知**：agent 报告的事件，按时间倒序，以 App 的语言显示：规则开始触发、Web 应用停止运行、恢复或有更新、磁盘、阵列或存储池异常。已读状态与面板同步。
- **审计日志**：一次显示一台服务器。包括登录（成功和被拒绝的，以及来源地址）、终端、命令、文件写入、主机管理、部署等，可按类型和结果筛选。只有在 agent 允许操作的连接上才会显示（HTTPS、本机回环，或开启了 `allow_insecure`）。
- **会话与设备**：一次显示一台服务器。包括终端会话、经 agent 中转的连接（端口转发、远程桌面、控制台）、手表和小组件的令牌，以及用密码登录过的设备。可以结束会话或连接，也可以撤销令牌。忘记设备后，它下次登录会计入账户级的失败尝试限制；这不会让设备退出登录，因为保存了密码的设备会再次登录。要阻止某台设备，请修改密码。

agent 版本过旧、不提供某个部分时，该部分会显示提示。

## 集成显卡监控

在 Linux 上，agent 通过内核 DRM/sysfs 接口读取 AMD 集成显卡数据；APU 无需安装 ROCm、`amd-smi` 或 `rocm-smi` 即可报告利用率。Intel GPU 利用率需要 `intel_gpu_top`，通常由 `intel-gpu-tools` 软件包提供。

App 和 Monitor agent 采集数据时都不会等待交互式 `sudo` 输入。如果 SSH 账户或 agent 账户无权读取 Intel GPU 性能计数器，GPU 仍会列出，但不会显示无法读取的指标。若要采集利用率，请按 Linux 发行版的方式为该账户授予 GPU PMU 访问权限。

每块 Linux GPU 都以 PCI 地址标识，例如 `0000:00:02.0`。因此，多块集成或独立 GPU 会分别显示为稳定条目。

<a id="账号和权限"></a>

## 访问

登录 agent 后，可以做 agent 运行所用的系统账户能做的一切：执行命令、进程、systemd、容器、代码片段、电源、计划任务、防火墙、终端、文件、远程桌面、端口转发，以及网页面板中的 Proxmox VE、libvirt 和 BMC 页面。没有角色，也没有按功能划分的权限；该系统账户就是上限。

因此 `install.sh` 默认以普通用户运行 agent。使用 `--system` 时以 root 运行，登录后就是 root shell。若要限制 agent 能访问的范围，请以只能访问这些内容的账户安装它。

无论该账户能访问什么，文件 API 都不会提供 agent 自己的文件，包括数据库、`jwt.secret`、`credentials.key`、`config.toml` 及其备份、`.env`、TLS 密钥和证书、自定义命令，因为这些文件包含凭据。

agent 保存的凭据（BMC 和 Proxmox VE 密码、Agent mode 的 provider key、MCP token、WebDAV 密码）在数据库中用同目录下的 `credentials.key` 加密。手动迁移 agent 时需要把这两个文件一起复制；缺少这个密钥时，这些凭据需要重新填写。设置备份不需要这个密钥。

### 从有多个账号的 agent 升级

旧版 agent 支持多个账号，并使用角色和权限。升级后，最早的 admin 账号的密码成为 agent 的密码。其他账号的 Agent mode 任务、memory 和桌面主题转移给它；它们的桌面布局、窗口和已配对的手表会被删除。角色和权限不会保留。

该模型使用的 `config.toml` 配置项 —— `full_access`、`listen_public`、`[remote_access.terminal] enabled`、`[remote_access.fs] enabled` 和 `[remote_access.fs] roots` —— 不再读取，可以删除。

### 明文 HTTP

读取监控数据以外的功能都需要 HTTPS，或由同一台主机发起请求（包括同机反向代理）。如果私有网络本身已加密（例如 Tailscale），可设置 `[remote_access] allow_insecure = true`，并在 App 中为该服务器开启**允许不安全 HTTP**；两项都必须启用。TODO：现有配置不再需要迁移后，删除旧 `allow_insecure` key。目前 `[remote_access.terminal] allow_insecure` 和 `[remote_access.fs] allow_insecure` 与 `[remote_access] allow_insecure` 等效。

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

## 通知渠道

每个 `[[push]]` 条目包含 `name`、`push_type` 和该类型的设置。文本字段中的 `{{message}}` 和 `{{name}}`（本服务器的名称）会被替换。所有类型的示例见 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)。

| `push_type` | 必填 | 可选 |
| --- | --- | --- |
| `webhook` | `url` | `method`、`headers`、`body_template` |
| `serverchan` | `sc_key` | `title`、`desp` |
| `bark` | `key` | `server`、`title`、`subtitle`、`body`、`markdown`、`level`、`volume`、`badge`、`sound`、`icon`、`image`、`group`、`url`、`copy`、`auto_copy`、`call`、`is_archive`、`ttl`、`action`、`cipher_key` |
| `ios` | `token` | `title`、`content` |
| `smtp` | `host`、`from`、`to` | `port`、`security`、`username`、`password`、`subject`、`body` |
| `telegram` | `bot_token`、`chat_id` | `text`、`parse_mode`、`message_thread_id`、`disable_notification`、`disable_link_preview`、`api_base` |
| `discord` | `webhook_url` | `content`、`username`、`avatar_url`、`thread_id` |
| `ntfy` | `topic` | `server`、`title`、`message`、`priority`、`tags`、`click`、`icon`、`attach`、`delay`、`email`、`markdown`、`token`、`username`、`password` |

- **从环境变量读取凭据**：凭据字段（`sc_key`、Bark 的 `key` 和 `cipher_key`、iOS 的 `token`、webhook 的 header 值、SMTP 和 ntfy 的 `password`、ntfy 的 `token`、`bot_token`、`webhook_url`）可以用 `${NAME}` 引用环境变量，可以单独使用，也可以写在值中间（`Authorization = "Bearer ${HA_TOKEN}"`）。发送通知时从 agent 的环境变量或 `.env` 读取，`config.toml` 中保留引用本身。变量未设置或为空时，保存会被拒绝，发送也会失败，错误中会给出变量名。其他设置不做替换。
- **Bark**：设置 `cipher_key` 后，通知内容使用 AES-CBC 加密（16、24 或 32 个字符的 key，分别对应 AES-128/192/256）。在 Bark App 的“推送加密”中填写相同的 key 和算法。Bark 服务器只能收到 device key 和密文。
- **SMTP**：`security` 可选 `starttls`（587 端口，默认）、`tls`（465）或 `none`（25）。使用 `none` 时，只有服务器在本机才接受密码。`to` 可以填写多个地址，用逗号分隔。
- **Telegram**：设置 `parse_mode` 后，消息内容和服务器名称会按该模式转义，只有你自己写的 `text` 会被当作标记解析。
- **Discord**：文本中的提及（例如 `@everyone`）不会通知任何人。

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
| `disk` | 忽略 | 本机文件系统合计的已用百分比；NFS、SMB 等网络文件系统只有在 `[monitoring]` 下设置 `disk_counts_network = true`（也可在 Monitor 设置中开启）时才计入 |
| `network` | `rx` 或 `in` | 接收速度 |
| `network` | `tx` 或 `out` | 发送速度 |
| `network` | 留空或其他值 | 接收加发送 |
| `temperature` | 忽略 | agent 上报的机器温度 |

TODO：Go agent 迁移窗口结束后，删除 `mem`、`net` 和 `temp` 别名。目前这些旧配置仍可使用；其他未知指标会在每个采集周期写入 agent 日志，对应规则不会触发。

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

**功能缺失或显示为灰色。** App 显示的是 agent 上报的功能。读取监控数据以外的功能都需要 HTTPS 或同机调用方，见[明文 HTTP](#明文-http)。早于某项功能的 agent 不会上报它，请更新 agent。修改 `config.toml` 后需要重启 agent。

**操作因权限不足失败。** agent 以它运行的系统账户执行操作，无法访问该账户访问不到的内容。见[访问](#访问)。

**证书错误。** 配置有效的 TLS，将 agent 放在反向代理后，或为该服务器开启 **Monitor Ignore certificate**。

**面板使用不同的 origin。** 在 `config.toml` 的 `cors_allowed_origins` 或环境变量 `SBM_CORS_ORIGINS` 中添加该 origin。

**登录被拒绝，或密码丢失。** 在服务器上用 `server_box_monitor password` 重置，见[面板凭据](#面板凭据)。连续失败会被限流，所以密码错误也可能表现为 agent 变慢或不响应。

**请求无响应。** 确认 agent 正在运行且端口可达，再检查数据库中的 `access_log` 表。该表记录访问者、时间、来源、请求资源和结果，不保存凭据。
