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
请前往 [Wiki](https://github.com/lollipopkit/server_box_monitor/wiki/%E4%B8%BB%E9%A1%B5) 获取更多信息.

## 🔐 远程访问（可选，默认关闭）

有两个 WebSocket 端点可以访问本机的 SSH 服务。二者默认关闭，需要在
`config.toml` 中显式开启，且都无法从面板打开——参见 `config.example.toml`
里的 `[remote_access]`。

**`tunnel_enabled`** 让 ServerBox App 经它已经在轮询的同一个 HTTPS 端点访问
SSH，适用于 SSH 端口无法直接连通的主机。开启后 App 基于 SSH 的功能全部可用：
终端、SFTP、容器、进程、端口转发。代理只搬运字节——SSH 会话由 App 与 sshd
端到端协商，host key 由 App 自己校验，本进程即使想读也读不到会话内容。它不接受
目标参数：代理只连 `ssh_addr`，这正是它无法被用来访问所在网络其他主机的原因。
要访问第二台机器，请在 App 中把这台配成它的跳板机，让那一跳由 SSH 授权而不是由
代理授权。

**`terminal_enabled`** 为面板增加网页内终端。代理作为 SSH 客户端连接
`ssh_addr`，因此会话权限完全等同于浏览器登录的那个 SSH 账号——仅有面板密码不会
获得 shell，sshd 自身的日志、`AllowUsers`、两步验证提示也都照常生效。会话在连接
断开后会保留几分钟，手机切换网络后可以接回同一个 shell 而不是丢失它。

**`passwordless_terminal`** 去掉 SSH 登录这一步：任何登录了面板的人都能拿到
shell，身份是代理进程所属的账号。不设置时跟随平台——Linux 默认开启，macOS 与
Windows 默认关闭。**此时面板密码就等于本机的一个 shell**，这也是 `install.sh`
默认安装 *user* systemd 服务的原因；如果你以 root 运行代理，请关掉它。SSH 登录
方式始终并存。也可用 `SBM_PASSWORDLESS_TERMINAL=0/1` 设置；面板的首次使用提示
可以关闭它，但永远无法开启。

补充：

- 终端拒绝在明文监听上运行，因为它的第一条消息就带着 SSH 密码。配置 TLS 可满足
  该要求；同机反向代理同样可以，因为 loopback 流量无法在网络上被读取。
  `allow_insecure = true` 可以覆盖这一限制。隧道不受影响——它承载的内容本身已加密。
- 代理会在首次连接时固定 sshd 的 host key，之后不匹配即拒绝，而不是静默重新固定。
  清除固定需要手动操作：删除 `ssh_known_hosts` 中对应的记录。
- `access_log` 记录谁在何时从何处打开了什么、结果如何，不记录任何凭据。
- 登录失败按来源地址和用户名双重限流。

## 🔖 许可证
`GPL v3. lollipopkit 2023`