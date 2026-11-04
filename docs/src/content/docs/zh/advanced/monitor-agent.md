---
title: Monitor
description: 通过 Monitor 访问服务器
---

Server Box Monitor 运行在服务器上，并将状态发送给 App。你无需开放 SSH 端口即可监控主机；即使 App 处于关闭状态，它也能继续为推送告警、主屏幕小组件和 Watch App 提供数据。

## 给 AI agent 的 prompt

下面的 prompt 可交给能够通过 SSH 访问服务器的 AI agent。内容明确列出了容易出错的配置细节。例如，告警规则无效时可能只记录日志而不触发，导致你收不到预期告警。

发送前请替换所有尖括号占位内容。

<details>
<summary>安装 Monitor</summary>

```text
通过 SSH 在 <host> 上安装 ServerBox Monitor。

安装脚本是
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh
它会自动识别 init 系统。通过管道交给 `sh` 时，默认会安装为当前用户的 `systemctl --user`
服务。Alpine 上需要 `sudo sh` 才能写入 /etc/init.d，但 Monitor 仍以执行 sudo 的普通用户身份运行。

请勿将其安装为 root 系统服务。登录 Monitor 后即拥有其运行账户的全部系统权限；若以 root
运行，登录者将拥有整台机器的最高权限。

请勿在 config.toml 的 `[remote_access]` 下添加 `full_access`、`listen_public`、`roots`
或 `enabled`。新版 Monitor 不再使用按功能细分的权限配置。

安装完成后请告诉我：
- config.toml 的路径，以及同目录下 SQLite 数据库的路径
- initial-admin-credentials.txt 的路径（请勿输出其中的密码内容）
- 监听的地址和端口
- `loginctl show-user <user> -p Linger` 的结果（若未开启 linger，用户登出后 `--user` 服务会自动停止）
- config.toml 和数据库文件的权限位（配置文件可能包含推送凭据，数据库存有密码哈希，均不应对同组或其他用户可读）
```

</details>

<details>
<summary>准备远程访问的服务器配置</summary>

```text
配置 <host> 上的 ServerBox Monitor，使 App 可以使用
<终端 / 文件浏览 / 执行命令 / 端口转发>。

修改前请先说明影响，并等待我确认。

请注意：

- Monitor 不设按功能细分的权限开关，登录者拥有 Monitor 运行账户的全部系统权限。请勿为了开启某项功能而直接改用 root 运行；如果当前账户权限不足，请先告知具体缺少哪项权限。
- 除读取监控指标外，所有操作均要求使用 TLS 或由本机回环地址发起请求（包括同机反向代理）。如果 Monitor 监听在 127.0.0.1，或由同机反向代理终结 TLS，则无需额外配置。仅当跨机器直接通过明文 HTTP 访问时，才需考虑设置 `[remote_access] allow_insecure = true`，操作前请先向我说明风险。

修改 config.toml 后请重启 Monitor，并告知所做的改动。
```

</details>

<details>
<summary>添加告警规则和通知渠道</summary>

```text
为 <host> 上的 ServerBox Monitor 添加一条告警规则。

触发条件：<描述>

请严格遵循以下规则格式：

- 每条规则为一个 `[[monitoring.rules]]` 表，包含 `name`、`monitor_type`、`matcher` 和 `threshold` 四个字段。
- `monitor_type` 可取 cpu、memory、swap、disk、network、temperature（也兼容 `mem`、`net`、`temp`）。填写其他值时，Monitor 仅记录日志，规则不会触发。
- `matcher` 指定要评估的指标子项：`cpu0` 表示单个核心，memory 和 swap 可填 `used`/`free`/`avail`，network 可填 `rx`/`tx`，disk 和 temperature 忽略此字段。
- `matcher` **不是**网卡名或挂载点。若将 network 规则写为 `matcher = "eth0"`，Monitor 会将其视作统计全部网卡的收发总和，而非单独统计 eth0。
- `threshold` 格式为“比较符 + 数值 + 单位”，例如 `>=80%`、`<10%`、`>10m/s`、`>=70c`。省略比较符时默认为 `<`（即 `80%` 表示“低于 80%”）。
- 单位必须与指标类型匹配：cpu/memory/swap/disk 使用 `%`，temperature 使用 `c`，network 使用容量单位或带 `/s` 的速率单位（1024 进制、小写字母）。单位不匹配时仅记录日志，规则不会触发。

如果还需要配置通知渠道，请添加对应的 `[[push]]` 表。`push_rate` 在渠道级别限流，而非按单条规则限流。

Monitor 仅在启动时加载规则和渠道配置，修改后请重启服务，并将实际写入的配置发给我确认。
```

</details>

<details>
<summary>排查 App 中某项功能为何未显示</summary>

```text
ServerBox App 中未显示 <host> 上 Monitor 的 <功能>。请先排查原因并告知结论，暂勿直接修改配置：

- App 根据 Monitor 上报的 capabilities 展示功能。登录后请求 `GET /api/v1/capabilities`，检查 `access.ok` 及 `access.why`（若为 `insecure_transport`，说明需要启用 TLS、走同机反向代理，或配置 `[remote_access] allow_insecure`），并查看 `features` 列表。
- 登录后可执行的操作受限于 Monitor 运行所用的系统账户；该账户无权访问的命令、文件或端口均会执行失败。
- Monitor HTTP 连接不支持 SFTP，如需使用 SFTP，请在 App 中同时为该服务器配置 SSH。
- 旧版 Monitor 若未包含 relay 或监听端点，则不支持端口转发和远程桌面，需升级 Monitor。
- Monitor 的 SQLite 数据库 `access_log` 表记录了访问时间、来源地址、请求资源与结果（不含敏感凭据），可用于辅助排查。
```

</details>

## 选择 SSH 还是 Monitor

| | SSH | Monitor |
|---|---|---|
| 需要在服务器上安装额外软件 | 否 | 是 |
| 查看状态和图表 | 支持 | 支持 |
| 查看 App 连接前的历史数据 | 不支持 | 支持 |
| 终端、命令和文件浏览 | 支持 | 支持，以 Monitor 运行所用的账户执行 |
| SFTP 传输 | 支持 | 不支持 |
| 端口转发（本地、动态、远程）和远程桌面 | 支持 | 支持 |
| 推送告警、主屏幕小组件和 Watch App | 不支持 | 支持 |

SSH 通常是最简单的连接方式。若当前网络无法访问 SSH 端口、希望图表包含 App 连接前采集的历史数据，或希望在手机上接收服务器告警，可以使用 Monitor。

同一台服务器可以同时使用两种方式：在 App 中配置 SSH，并在服务器上运行 Monitor，为小组件、Watch App 和推送告警提供数据。

## 安装 Monitor

有 `monitor-v*` release 时可直接安装；否则请从源码构建。发布需要手动触发 workflow。安装未发布版本或进行离线安装时，可通过 `SBM_INSTALL_PKG` 指定本地安装包。

安装脚本会自动识别 init 系统：

```sh
# systemd：安装为 `systemctl --user` 服务，以当前用户运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install

# 没有可下载的 release，或进行离线安装
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | SBM_INSTALL_PKG=/path/to/server-box-monitor sh -s -- install

# OpenRC（Alpine）：写入 /etc/init.d 需要 root，但 Monitor 仍以执行 sudo 前的用户运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install
```

`sh -s --` 后面的参数会传给安装脚本；执行 `uninstall` 和 `upgrade` 时也使用相同方式。仓库中也包含该脚本，可在 checkout 根目录运行 `./monitor/install.sh install`。此时使用的是 checkout 中的版本，可能与上述命令从 `main` 下载的版本不同。

默认情况下，Monitor 以当前普通用户身份运行。登录 Monitor 后即可执行该用户权限范围内的所有操作，详见[访问权限](#访问)。若传入 `--system`（配合 `sudo`）安装为 root 系统服务，登录后即拥有 root 权限。

Monitor 从二进制文件所在目录读取 `config.toml`。所有可用配置项见 [`config.example.toml`](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/config.example.toml)。默认监听地址是 `0.0.0.0:3770`；该目录下存在 `frontend/dist` 时，Monitor 也会在此提供网页面板。

无需直接编辑 `config.toml`，也可以修改采集间隔、告警规则、通知渠道、数据保留时间和允许的面板来源。在网页面板使用 **服务器设置**，或在 App 中打开已配置 Monitor 的服务器并点击顶部设置按钮。两个入口会修改同一个 Monitor 和配置文件。

JWT secret、`database_url` 和 `[remote_access]`（是否允许明文、SSH 地址和各项限额）只能通过配置文件修改。

编辑器不会返回文件中已保存的 secret，例如 ServerChan key、Bark key、iOS push token、`Authorization` header、SMTP 密码、Telegram bot token、Discord webhook URL 或 ntfy token。界面会显示“已设置”，但输入框保持为空。留空表示保留原值；输入新值则会替换。

通知渠道、告警规则、采集间隔、数据保留和允许来源需要重启 Monitor 后生效。扩展采集周期和两个闲置暂停设置会立即生效。App 会标明哪些配置需要重启。

如果要让其他设备连接 Monitor，请启用 HTTPS：可配置内置 TLS（`[server.tls]`），也可使用反向代理。若使用自签名证书，需在 App 中为该服务器明确开启 **忽略证书**。

### 升级

在服务器上，以安装 Monitor 时所用的账户运行：

```sh
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- upgrade
```

它会安装最新的 `monitor-v*` release，保留 `config.toml` 和数据库。不加 `--user` 或 `--system` 时，安装脚本会自行识别已安装的形式：`systemctl --user` unit、系统 unit 或 OpenRC 服务。后两种会通过 `sudo` 重新运行自身，并要求输入密码。找不到已安装的 Monitor 时（例如运行在 Docker 中）不做任何修改；Docker 请拉取新镜像并重建容器。

升级在 Monitor 运行时原地进行：先替换文件，最后重启。因此这条命令可以在 Monitor 自己打开的终端里运行；Monitor 重启时该终端会关闭，Monitor 几秒后恢复。

#### 在面板或 App 中更新

Monitor 每 12 小时检查一次 release，有新版本时留下一条通知。Monitor 知道自己的安装方式：`install.sh`、容器、NixOS 模块或其他。只有 `install.sh` 安装的可以自行更新，其他方式会说明各自的更新方法。

更新在 Monitor 之外运行：systemd 下是一个独立的临时服务（`systemd-run`），其他情况下是一个独立的会话。Monitor 重启会断开经由它的所有连接（包括面板和 App 的连接），但不会中断更新。输出写入 Monitor 目录下的 `update.log`，重启后的 Monitor 会报告更新结果。OpenRC 下安装脚本需要 root，Monitor 会要求输入 sudo 密码；密码只用一次，不会保存。

- **面板**：**设置 → 服务器 → ServerBox Monitor** 显示当前版本和最新 release，可点击 **立即检查** 和 **立即更新**。更新期间页面实时显示日志，Monitor 重启后会自动重连并显示新版本。点击桌面通知也会直接打开此页面。
- **App**：**Monitor** 标签页会标出有更新的 Monitor，以及因版本过旧无法单密码登录的实例。点击标记即可按引导执行 **立即更新**。尚不支持单密码登录的旧版 Monitor 仍需验证原账户名（通常为 `admin`）：App 会结合已保存的密码完成一次登录并触发更新，不会保存该账户名。若服务器同时配置了 SSH，而 Monitor 无法自行启动更新，App 会在 SSH 终端中执行升级命令。

## App 能回溯多久

图表可选范围取决于 Monitor 的数据保留时长和已采集的历史数据。App 只显示 Monitor 能提供的范围。API 字段和历史查询行为见[Monitor API 与访问模型](/docs/zh/development/monitor-agent/)。

## 面板凭据

Monitor 只有一个账号，只用密码登录，没有用户名。密码保存在 Monitor 的 SQLite 数据库中，不在 `config.toml` 里配置。该文件中的 `jwt_secret` 用于签署会话 token，并不是密码。

以下命令必须由运行 Monitor 的账户在其工作目录中执行：root 服务使用 `/opt/server-box-monitor`，其他情况使用 `~/.local/share/server-box-monitor`。`config.toml` 和数据库路径都相对于当前工作目录解析。如果在其他目录执行，命令会创建默认配置和空数据库，并成功修改一个实际服务不会使用的数据库。

### 首个密码

首次启动时，Monitor 会生成随机密码，并写入数据库旁的 `initial-admin-credentials.txt`；Unix 系统上的文件权限为 0600：

```sh
cd /opt/server-box-monitor
cat initial-admin-credentials.txt
```

设置新密码后请删除此文件。如果数据库之后被删除或移走，导致数据库中没有账号，而该文件仍存在，Monitor 会报错退出，不会覆盖原凭据并生成另一组密码。

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

- **登录和已配对的设备：无论用哪种方式修改，都会立即失效。** 修改前的登录从下一次请求起被拒绝，已配对的小组件和 Watch 会被解除配对。这一步不需要重启 Monitor，也不需要修改 `jwt_secret`。
- **已打开的终端、端口转发和监听：** 在 App 或面板中修改密码时会立即关闭。上面的命令只更新数据库，不会通知正在运行的 Monitor；旧密码建立的连接会一直保持到 Monitor 重启。systemd 使用 `systemctl --user restart server_box_monitor`，OpenRC 使用 `rc-service server-box-monitor restart`。如果重置密码是因为它可能已泄露，请随后重启 Monitor。

也可以在 App（服务器页面顶部的设置按钮，然后选择**访问**）或面板中修改密码，两处都需要输入当前密码。在 App 中修改时，App 会同时更新为该服务器保存的密码。

在服务器上修改密码后，请在 App 中编辑服务器并更新 **Monitor 密码**，其他保存了该密码的客户端也要同步更新。客户端不会收到密码变更通知，因此更新前无法登录。

### 忘记密码

网页面板不提供密码找回功能。请在服务器上运行上面的命令重置密码。

登录有限流。每次登录成功后，App 或浏览器会得到一个设备 token，之后每次登录都会带上它。登录过的设备按来源地址和该设备自身限流，其他地方的失败尝试不会把它锁住；其他客户端按来源地址和一个它们共用的计数限流。按地址和按设备计数时，前三次失败不会延迟；共用计数允许二十次。此后等待时间从 1 秒开始逐次翻倍，最长 5 分钟。连续输错密码时，Monitor 可能因此响应缓慢，甚至暂时没有响应。修改密码会让所有设备 token 失效。

## 在 App 中添加

1. 点击 **+** 添加服务器。
2. 打开 **Monitor HTTP**。它与 SSH 相互独立，可以单独启用，也可以同时启用两种连接方式。若两者都启用，在 **优先连接方式** 中选择 App 优先尝试的方式。
3. 填写：
   - **URL**：例如 `https://1.2.3.4:3770`
   - **Monitor 密码**：Monitor 的密码，见[面板凭据](#面板凭据)
   - **忽略证书**：仅在使用自签名证书时开启
4. 保存配置。

Monitor HTTP 配置不会添加 SSH 凭据。若没有另外配置 SSH，App 只能使用 Monitor 明确提供的功能访问服务器。

## Monitor 标签页

App 的 **Monitor** 标签页显示所有通过 Monitor 添加的服务器。新安装的 App 不会把它放在导航栏中：可以从 **更多** 打开，或在 **设置 › 应用 › 主页标签** 中添加。在宽屏窗口中，左侧一栏是各部分和服务器列表；在手机上，从栏上的标题切换部分，从服务器按钮切换服务器。

- **概览**：每个 Monitor 是否可连接、它的版本（落后时同时显示最新版本）、正在触发的[告警规则](#告警规则)及当前读数和持续时间，以及未读通知、异常或有更新的 Web 应用的入口。
- **Web 应用**：见 [Monitor Web 应用](../monitor-apps/#在-serverbox-app-中打开应用)。
- **通知**：Monitor 报告的事件，按时间倒序，以 App 的语言显示：规则开始触发、Web 应用停止运行、恢复或有更新、磁盘、阵列或存储池异常。已读状态与面板同步。
- **审计日志**：一次显示一台服务器。包括登录（成功和被拒绝的，以及来源地址）、终端、命令、文件写入、主机管理、部署等，可按类型和结果筛选。只有在 Monitor 允许操作的连接上才会显示（HTTPS、本机回环，或开启了 `allow_insecure`）。
- **会话与设备**：一次显示一台服务器。包括终端会话、经 Monitor 中转的连接（端口转发、远程桌面、控制台）、手表和小组件的令牌，以及用密码登录过的设备。可以结束会话或连接，也可以撤销令牌。忘记设备后，它下次登录会计入账户级的失败尝试限制；这不会让设备退出登录，因为保存了密码的设备会再次登录。要阻止某台设备，请修改密码。

Monitor 版本过旧、不提供某个部分时，该部分会显示提示。

## 集成显卡监控

在 Linux 上，Monitor 通过内核 DRM/sysfs 接口读取 AMD 集成显卡数据；APU 无需安装 ROCm、`amd-smi` 或 `rocm-smi` 即可报告利用率。Intel GPU 利用率需要 `intel_gpu_top`，通常由 `intel-gpu-tools` 软件包提供。

App 和 Monitor 采集数据时都不会等待交互式 `sudo` 输入。如果 SSH 账户或 Monitor 账户无权读取 Intel GPU 性能计数器，GPU 仍会列出，但不会显示无法读取的指标。若要采集利用率，请按 Linux 发行版的方式为该账户授予 GPU PMU 访问权限。

每块 Linux GPU 都以 PCI 地址标识，例如 `0000:00:02.0`。因此，多块集成或独立 GPU 会分别显示为稳定条目。

<a id="账号和权限"></a>

## 访问

登录 Monitor 后，你将拥有 Monitor 运行所用系统账户的全部权限：可执行命令、管理进程与 systemd 服务、操作容器与代码片段、控制电源、配置计划任务与防火墙、打开终端、读写文件、建立远程桌面与端口转发，以及使用网页面板中的 Proxmox VE、libvirt 和 BMC 功能。Monitor 不再区分角色或按功能细分的权限，运行账户本身的权限即为边界。

因此，`install.sh` 默认以普通用户身份安装和运行 Monitor。若使用 `--system` 以 root 身份安装，登录 Monitor 即拥有 root shell。如需限制 Monitor 的访问范围，请使用专门受限的系统账户运行它。

出于安全保护，无论运行账户权限如何，文件 API 均禁止读取 Monitor 自身的敏感文件（包括数据库、`jwt.secret`、`credentials.key`、`config.toml` 及其备份、`.env`、TLS 密钥与证书，以及自定义命令目录）。

Monitor 保存的外部凭据（BMC 与 Proxmox VE 密码、Agent 模式的模型密钥、MCP 令牌、WebDAV 密码）均使用同目录下的 `credentials.key` 加密存储在数据库中。手动迁移 Monitor 时请一并复制数据库和 `credentials.key`；若缺少该密钥，迁移后需重新填写这些凭据。WebDAV 设置备份采用独立的 age 密钥加密，不依赖此文件。

### 从多账号版本升级

旧版 Monitor 支持多账号、角色与细分权限。升级后，最早创建的管理员账号密码将自动作为 Monitor 的登录密码；其他账号下的 Agent 任务、记忆文件和桌面主题会合并至该账号，原有的窗口布局与已配对 Watch 令牌则会清理，不再保留旧版的角色与权限设置。

旧版 `config.toml` 中的 `full_access`、`listen_public`、`[remote_access.terminal] enabled`、`[remote_access.fs] enabled` 和 `[remote_access.fs] roots` 字段已废弃，可直接删除。

### 明文 HTTP

除读取监控指标外，所有管理与交互功能均要求使用 HTTPS，或由本机回环地址发起请求（包括部署在同一台主机上的反向代理）。若在已加密的私有网络（如 Tailscale）中使用明文 HTTP，需在配置文件中设置 `[remote_access] allow_insecure = true`，并在 App 中为该服务器开启**允许 HTTP**（两项均需开启）。旧版配置中的 `[remote_access.terminal] allow_insecure` 和 `[remote_access.fs] allow_insecure` 仍作为兼容别名生效。

路径校验、接口行为与错误码说明详见[Monitor API 与访问模型](/docs/zh/development/monitor-agent/)。

## 不支持的功能

Monitor HTTP 连接不支持 SFTP（SFTP 依赖 SSH 通道）。不过文件标签页可通过 Monitor 的文件 API 正常浏览和传输文件。

对于优先使用 Monitor 连接的服务器（仅配置了 Monitor，或同时配置了 SSH 但将 Monitor 设为优先连接方式），所有端口转发均通过 Monitor 建立，不会自动回退到 SSH。动态端口转发会在本机启动 SOCKS5 代理，并由服务器侧发起实际连接。

如需使用 SFTP，请在 App 中同时为该服务器配置 SSH。若旧版 Monitor 提示不支持远程桌面或端口转发，请将其升级至最新版本。

## 小组件、推送和 Watch App

小组件、推送通知和 Watch App 都直接连接 Monitor 获取数据，无需保持 App 在前台运行：

- **主屏幕小组件**：安装 Monitor 并在 App 中添加服务器后，小组件可直接从 App 同步的服务器列表中选择目标，无需手动填写 URL。
- **Watch App**：仅显示已配置 Monitor 的服务器。默认自动同步全部 Monitor 服务器，也可在 iOS 的设置中按需排除。
- **推送告警**：告警规则决定触发条件，通知渠道决定发送目标（对应 `config.toml` 中的 `[[monitoring.rules]]` 和 `[[push]]`）。你也可以直接在 App 或网页面板中编辑这两项配置，并使用渠道旁的 **发送测试** 按钮验证配置。规则语法见下文[告警规则](#告警规则)。

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

- **从环境变量读取凭据**：在 `config.toml` 中，凭据字段（`sc_key`、Bark 的 `key` 和 `cipher_key`、iOS 的 `token`、webhook 的 header 值、SMTP 和 ntfy 的 `password`、ntfy 的 `token`、`bot_token`、`webhook_url`）可以用 `${NAME}` 引用环境变量，可以单独使用，也可以写在值中间（`Authorization = "Bearer ${HA_TOKEN}"`）；`$${` 表示字面的 `${`。发送通知时从 Monitor 的环境变量或 `.env` 读取，`config.toml` 中保留引用本身。变量未设置或为空时，保存会被拒绝，发送也会失败，错误中会给出变量名。其他设置不做替换。在 App 或网页面板中填写的凭据按原样保存，不会被当作引用，因此登录后无法通过这里读取 Monitor 的环境变量。
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
| `temperature` | 忽略 | Monitor 上报的机器温度 |

从 Go 版 Monitor 迁移的配置仍可使用 `mem`、`net` 和 `temp` 别名；其他未知指标名称会在每个采集周期记录一次日志，对应规则不会触发。

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

network 的体积单位使用 1024 进制并采用小写。单位与指标不匹配时（例如 `network` 规则使用 `>=80%`），Monitor 会记录错误日志，但规则不会触发。

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

- **network 规则需要两次采样。** Monitor 启动、采集间断或检测到新网卡后，第一次采样无法计算速度；收到下一次采样后才会判断规则。
- **缺少读数时会跳过该周期。** 内存或磁盘数据不可用时，Monitor 不会把读数当成 0 来判断规则。
- **temperature 规则需要温度数据。** 部分机器不会上报温度。

限流按通知渠道计算。请查看 `config.toml` 中的 `push_rate` 或 App 中的 **限流** 设置。

## 故障排除

**功能缺失或显示为灰色。** App 显示的是 Monitor 上报的功能。读取监控数据以外的功能都需要 HTTPS 或同机调用方，见[明文 HTTP](#明文-http)。早于某项功能的 Monitor 不会上报它，请更新 Monitor。修改 `config.toml` 后需要重启 Monitor。

**操作因权限不足失败。** Monitor 以它运行的系统账户执行操作，无法访问该账户访问不到的内容。见[访问](#访问)。

**证书错误。** 配置有效的 TLS，将 Monitor 放在反向代理后，或为该服务器开启 **忽略证书**。

**面板使用不同的 origin。** 在 `config.toml` 的 `cors_allowed_origins` 或环境变量 `SBM_CORS_ORIGINS` 中添加该 origin。

**登录被拒绝，或密码丢失。** 在服务器上用 `server_box_monitor password` 重置，见[面板凭据](#面板凭据)。连续失败会被限流，所以密码错误也可能表现为 Monitor 变慢或不响应。

**请求无响应。** 确认 Monitor 正在运行且端口可达，再检查数据库中的 `access_log` 表。该表记录访问者、时间、来源、请求资源和结果，不保存凭据。
