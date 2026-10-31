[English](README.md) | 简体中文

# ServerBox Monitor

ServerBox Monitor 是
[ServerBox](https://github.com/lollipopkit/flutter_server_box) 的服务端 agent，
负责记录服务器指标、提供 Monitor HTTP API，并在需要时托管网页面板。
不同版本之间可能会调整配置格式，升级后请重新检查 `config.example.toml`。

## 🖥️ 截图
<table>
  <tr>
    <td>
	    <h5 align="center">iOS 推送</h5>
    </td>
    <td>
	    <h5 align="center">Webhook 推送 (QQ)</h5>
    </td>
    <td>
	    <h5 align="center">iOS 桌面部件</h5>
    </td>
  </tr>
  <tr>
    <td>
	    <img width="107px" src="doc/imgs/ios-push.png">
    </td>
    <td>
	    <img width="307px" src="doc/imgs/webhook.png">
    </td>
    <td>
	    <img width="197px" src="doc/imgs/ios-widget.png">
    </td>
  </tr>
</table>

## 安装和运行

```sh
# systemd: 安装为 `systemctl --user` 服务, 以你自己的账号运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sh -s -- install

# OpenRC (Alpine): 写 /etc/init.d 需要 root, 但 agent 仍以你 sudo 前的账号运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install

# 两种 init 系统, 都以 root 运行
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | sudo sh -s -- install --system

# 没有可下载的 release 时 —— 离线, 或使用未发布的构建
curl -fsSL https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/monitor/install.sh | SBM_INSTALL_PKG=/path/to/server-box-monitor sh -s -- install
```

`sh -s --` 之后的都是传给脚本的参数, `uninstall` 和 `upgrade` 同理。脚本本身
也在本仓库里, 在本目录执行 `./install.sh install` 效果相同——但使用的是当前
checkout 中的脚本, 不一定与上面命令下载的 `main` 上的版本一致。

`install.sh install` 会下载本仓库最新的 `monitor-v*` release。release 由
`monitor-release.yml` workflow 发布，该 workflow 仅支持 `workflow_dispatch`；
若尚无对应 release，请用 `SBM_INSTALL_PKG` 指向本地构建的包，或使用
[Docker](Dockerfile)。

没有操作系统的机器可以直接启动 **sbOS**：每个 release 附带内含 agent、面板和
Docker 的系统镜像，分别基于 Alpine Linux（`sbOS_musl_*`）和 Debian
（`sbOS_GNU_*`），支持 x64 和 arm64。写入 U 盘后启动，或者运行 `sbm-install`
把系统装到磁盘上——见 [`os/README.md`](os/README.md)。

配置文件是二进制旁边的 `config.toml`。所有配置项及其注释都在
[`config.example.toml`](config.example.toml) 里；`cargo run -- config` 会打印
解析后的值。agent 默认监听 `0.0.0.0:3770`，当 `frontend/dist` 存在时同时在该
地址提供面板。

### 登录

agent 只有一个账号，只用密码登录。账号保存在 SQLite 数据库中，不在 `config.toml`
里——那里的 `jwt_secret` 用于签发 token，不是密码。首次启动时 agent 会设置一个随机
密码，写到数据库旁边的 `initial-admin-credentials.txt`（0600）。请修改密码并删除
该文件：

```sh
cd /opt/server-box-monitor   # 或 ~/.local/share/server-box-monitor
./server_box_monitor password
```

它会无回显地提示输入两次；`--password-env VAR` 改为从环境变量读取密码。没有通过
参数传入密码的方式，因为命令行会出现在 `ps` 和 shell 历史中。App 和面板也可以修改
密码。请在 agent 自己的目录下运行：`config.toml` 和数据库路径都相对于工作目录，在
其他目录运行会在一个新的空数据库里设置密码，且不会有任何提示。

### ServerBox App 需要什么

在 App 里以 **monitor** 方式添加的服务器，只通过这个 agent 的 HTTP API 访问，
不携带任何 SSH 凭据。agent 在 `GET /api/v1/capabilities` 上报它提供什么，App
就只提供什么：

| App 功能 | 端点 |
|---|---|
| 状态、图表、历史曲线 | `/api/v1/metrics*`（watch token 也可以读取） |
| 进程、systemd、容器、snippet、电源、App 终端 | `POST /api/v1/exec`、`/api/v1/terminal/ws` |
| 文件浏览 | `/api/v1/fs/*` |
| 远程桌面、本地和动态端口转发 | `/api/v1/stream/ws` |
| 远程端口转发 | `/api/v1/listen/ws` |
| 面板里的远程桌面（VNC、RDP） | `/api/v1/stream/ws`、`/api/v1/rdp/ws` |
| 备份同步到这个 agent、面板的备份页面 | `/api/v1/backup` |

`/api/v1/stream/ws` 以 agent 进程所属的账号从本机向 App 指定的地址发起一条 TCP
连接并中继。`/api/v1/listen/ws` 方向相反：agent 在本机监听一个端口，把每条进来的
连接交给 App，App 再通过一条 `stream` 连接接管。

monitor 服务器不提供 SFTP：agent 的文件 API 传输的是文件内容，不是 SSH 字节流。

## 访问

**登录后可以做 agent 进程所属的系统账号能做的一切**：shell、它的文件、从本机发起
连接、在本机端口上监听。没有角色，也没有按功能划分的权限：agent 安装时使用的账号
就是上限。因此 `install.sh` 默认以普通账号运行 agent：systemd 下是
`systemctl --user` 服务，OpenRC 下是带 `command_user` 的 `/etc/init.d` 脚本；
`--system`（root）则意味着登录后就是 root shell。完整的 API 约定见
[`docs/dev/monitor-permissions.md`](../docs/dev/monitor-permissions.md)。

终端（App 的和面板的）就是 PTY 上的这个 shell。会话在连接断开后会保留几分钟，手机
切换网络后可以接回同一个 shell 而不是丢失它。

修改密码会注销其他所有会话：之前签发的 token 失效，已配对的手表和小组件被解除配对，
打开的终端、relay 和监听被关闭。

从有多个账号的 agent 升级时，保留最早的 admin 账号的密码，其他账号的 Agent mode
任务、memory 和桌面主题转移给它。

补充：

- 读取监控数据以外的所有功能都需要 TLS 或 loopback 调用方；同机反向代理同样可以，
  因为 loopback 流量无法在网络上被读取。在 HTTP 之外已具备传输加密的可信私有网络中
  （例如 Tailscale），运维人员可设置 `[remote_access] allow_insecure = true`（旧的
  `terminal.allow_insecure` 和 `fs.allow_insecure` 与之等效）。App 还必须对该
  Monitor 连接单独开启「允许不安全 HTTP」；两端开关缺一不可。否则凭据、终端流量和
  文件内容会以明文传输，不应在普通局域网或不受控制的网络中使用。
- 文件 API 从不提供 agent 自身的状态：数据库、`jwt.secret`、`config.toml`、`.env`、
  TLS 私钥等。
- `access_log` 记录打开了什么、从何处、结果如何，不记录任何凭据。
- 登录失败按来源地址限流；没有登录过的客户端还共用一个计数。登录成功后设备会得到一个 token，带着它登录的设备单独计数，其他地方的失败不会把它锁住。修改密码会让所有设备 token 失效。

## 许可证
`GPL v3. lollipopkit 2023`
