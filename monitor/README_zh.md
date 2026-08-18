[English](README.md) | 简体中文

## ServerBox 监测器
这个应用程序运行在服务器端, 监测服务器状态.  
这是 [ServerBox](https://github.com/lollipopkit/flutter_server_box) 项目的一部分.
**正处于活跃开发中，你可能需要在更新后重新配置.**

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

## 📖 使用方法

```sh
# systemd: 安装为 `systemctl --user` 服务, 以你自己的账号运行
./install.sh install

# OpenRC (Alpine): 写 /etc/init.d 需要 root, 但 agent 仍以你 sudo 前的账号运行
sudo ./install.sh install

# 两种 init 系统, 都以 root 运行
sudo ./install.sh install --system

# 没有可下载的 release 时 —— 离线, 或使用未发布的构建
SBM_INSTALL_PKG=/path/to/server-box-monitor ./install.sh install
```

`install.sh install` 会下载本仓库最新的 `monitor-v*` release。release 由
`monitor-release.yml` workflow 发布，该 workflow 仅支持 `workflow_dispatch`；
若尚无对应 release，请用 `SBM_INSTALL_PKG` 指向本地构建的包，或使用
[Docker](Dockerfile)。

配置文件是二进制旁边的 `config.toml`。所有配置项及其注释都在
[`config.example.toml`](config.example.toml) 里；`cargo run -- config` 会打印
解析后的值。agent 默认监听 `0.0.0.0:3770`，当 `frontend/dist` 存在时同时在该
地址提供面板。

### ServerBox App 需要开启什么

在 App 里以 **monitor** 方式添加的服务器，只通过这个 agent 的 HTTP API 访问，
不携带任何 SSH 凭据。agent 在 `GET /api/v1/capabilities` 上报它接受什么，App
就只提供什么：

| App 功能 | 需要 |
|---|---|
| 状态、图表、历史曲线 | 只需登录 |
| 进程、systemd、容器、snippet、电源 | `full_access`(`POST /api/v1/exec`) |
| 终端 | `full_access`(`/api/v1/terminal/ws`) |
| 文件浏览 | `[remote_access.fs] enabled` + `roots` |

monitor 服务器不提供 SFTP 和端口转发：agent 没有任何端点可以把连接中继到 App
指定的地址。需要这两项请以 SSH 方式添加该服务器。

## 🔐 远程访问（可选，默认关闭）

有两个 WebSocket 端点可以访问本机的 SSH 服务。二者默认关闭，需要在
`config.toml` 中显式开启，且都无法从面板打开——参见 `config.example.toml`
里的 `[remote_access]`。

**`[remote_access.tunnel] enabled`** 把 SSH 字节流中继到 `ssh_addr`。代理只
搬运字节——SSH 会话由客户端与 sshd 端到端协商，本进程即使想读也读不到会话
内容。它不接受目标参数：代理只连 `ssh_addr`，这正是它无法被用来访问所在网络
其他主机的原因。

TODO: **目前没有任何调用方。** ServerBox App 曾经通过它访问 sshd；现在 App 访问
monitor 服务器走的是 `/api/v1/exec`、`/api/v1/terminal/ws` 和 `/api/v1/fs/*`，
tunnel 客户端已经删除。现在打开这个开关不会有任何效果。需要删除该端点，或恢复
一个调用方。

**`[remote_access.terminal] enabled`** 为面板增加网页内终端。代理作为 SSH 客户端连接
`ssh_addr`，因此会话权限完全等同于浏览器登录的那个 SSH 账号——仅有面板密码不会
获得 shell，sshd 自身的日志、`AllowUsers`、两步验证提示也都照常生效。会话在连接
断开后会保留几分钟，手机切换网络后可以接回同一个 shell 而不是丢失它。

**`full_access`** 去掉 SSH 登录这一步：任何登录了面板的人都能拿到
shell，身份是代理进程所属的账号。不设置时跟随平台——Linux 默认开启，macOS 与
Windows 默认关闭。**此时面板密码就等于本机的一个 shell**，这也是 `install.sh`
默认安装 *user* systemd 服务的原因；如果你以 root 运行代理，请关掉它。SSH 登录
方式始终并存。也可用 `SBM_FULL_ACCESS=0/1` 设置；面板的首次使用提示
可以关闭它，但永远无法开启。

补充：

- 终端拒绝在明文监听上运行，因为它的第一条消息就带着 SSH 密码。配置 TLS 可满足
  该要求；同机反向代理同样可以，因为 loopback 流量无法在网络上被读取。
  `[remote_access.terminal] allow_insecure = true` 可以覆盖这一限制。隧道不受影响——它承载的内容本身已加密。
- 代理会在首次连接时固定 sshd 的 host key，之后不匹配即拒绝，而不是静默重新固定。
  清除固定需要手动操作：删除 `ssh_known_hosts` 中对应的记录。
- `access_log` 记录谁在何时从何处打开了什么、结果如何，不记录任何凭据。
- 登录失败按来源地址和用户名双重限流。

## 🔖 许可证
`GPL v3. lollipopkit 2023`