---
title: 批量导入服务器
description: 从 JSON 文件导入多个服务器配置
---

使用 JSON 文件可以一次添加多台服务器。数组中的每个对象代表一台服务器，并可包含连接方式、
分组标签和启动行为等设置。

## JSON 格式

:::danger[安全警告]
导入文件是明文文件，可能包含凭据。请勿将它放在共享目录或提交到版本控制，并在导入完成后
尽快删除。

- 优先使用已保存在 App 中的 SSH key，并通过 `pubKeyId` 引用；不要把 private key 内容写入文件。
- 如果必须在文件中填写密码或 token，请限制文件访问权限，并在导入后立即删除。
- 将导入文件加入 `.gitignore`。即使凭据是临时的，也不要提交到版本控制系统。
:::

```json
[
  {
    "name": "My Server",
    "ssh": {
      "ip": "example.com",
      "port": 22,
      "user": "root",
      "pubKeyId": ""
    },
    "tags": ["production"],
    "autoConnect": false
  }
]
```

SSH 配置放在 `ssh` 对象中。App 导出和导入对话框中的示例都使用这种嵌套格式。

为兼容旧数据，导入也接受扁平格式，即 `ip`、`port`、`user` 等字段直接位于顶层。因此旧版
导出文件和从 `~/.ssh/config` 导入的文件仍可使用。新版导出使用上面的嵌套格式。

## 字段说明

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `name` | 是 | 在 App 中显示的服务器名称 |
| `ssh` | 否 | SSH 配置，见下表；纯 Monitor 服务器可以省略 |
| `monitorHttp` | 否 | Monitor agent 配置：`addr`、`user`、`pwd`、`ignoreCert`、`allowInsecure` |
| `preferredTransport` | 否 | 同时配置 SSH 和 Monitor HTTP 时优先使用哪一个：`ssh` 或 `monitorHttp`。省略时优先 SSH |
| `tags` | 否 | 用于分组服务器的标签 |
| `autoConnect` | 否 | App 启动时自动连接 |
| `custom` | 否 | 当前服务器的附加配置，例如 `preferTempDev`、`logoUrl` |
| `pve` | 否 | Proxmox VE 配置，见下文 |
| `wolCfg` | 否 | Wake-on-LAN 配置 |
| `envs` | 否 | 环境变量，仅对 SSH 终端生效 |
| `customSystemType` | 否 | 跳过系统类型自动检测 |
| `disabledCmdTypes` | 否 | 在该服务器上跳过的状态命令 |
| `id` | 否 | 稳定的服务器 ID；省略或为空时由 App 在导入时生成 |

以下字段放在 `ssh` 对象中：

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `ip` | 是 | 域名或 IP 地址 |
| `port` | 是 | SSH 端口，通常为 `22` |
| `user` | 是 | SSH 用户名 |
| `pwd` | 否 | 密码，不推荐；建议使用 SSH key |
| `fileTransport` | 否 | 文件传输使用的协议：`sftp` 或 `scp`。默认 `sftp`；不提供 SFTP subsystem 的主机使用 `scp` |
| `pubKeyId` | 否 | App 中已保存的 private key 记录 ID，不是 PEM 文件路径 |
| `keyPath` | 否 | 仅桌面端使用的 private key 文件路径，由 `~/.ssh/config` 导入生成；连接时从该文件读取 |
| `alterUrl` | 否 | 备用地址，格式为 `user@ip:port` |
| `jumpIds` | 否 | Jump server 链，按服务器 ID 指定 |
| `proxyCommand` | 否 | ProxyCommand；仅桌面端可用，且与 `jumpIds` 互斥 |

以下字段放在 `pve` 对象中：

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `addr` | 是 | PVE Web 地址，例如 `https://127.0.0.1:8006`；主机名在服务器一侧解析 |
| `auth` | 否 | `token` 或 `password`，默认 `password` |
| `tokenId` | `token` 时必填 | API token ID，格式为 `user@realm!tokenid` |
| `tokenSecret` | `token` 时必填 | Token 的 secret；属于凭据，文件需按凭据处理 |
| `pwd` | 否 | `password` 时使用：SSH 用户在 `pam` realm 下的 PVE 密码。省略时使用 SSH 密码 |
| `certSha256` | 否 | 信任的证书 SHA-256，小写十六进制。省略时，首次连接会请求确认证书 |

旧版导出文件可能把 `pveAddr`、`pveIgnoreCert` 和 `pvePwd` 放在 `custom` 中。导入仍会识别这些
字段，并转换为未固定证书的 password authentication 配置。此格式仅用于兼容旧文件；新版导出
使用 `pve` 对象。

每台服务器都必须至少配置一种连接方式。如果同时省略 `ssh` 和 `monitorHttp`，导入后将无法
连接主机。

`allowInsecure` 默认为 `false`。只有确实要让该 Monitor 连接使用明文 HTTP 时才设为 `true`，
包括连接非 loopback 的私有 IP 地址。Monitor agent 还会根据自身的 `allow_insecure` 设置，
单独检查敏感 endpoint 是否允许不安全连接。

## 导入步骤

1. 创建 JSON array，并在其中添加服务器配置对象。
2. 打开 **设置 → 备份 → 导入 → 服务器**。
3. 选择 JSON 文件。
4. 检查页面显示的服务器数量并确认导入。
5. 导入结束后删除 JSON 文件及其副本。

## 示例

```json
[
  {
    "name": "Production",
    "ssh": {
      "ip": "prod.example.com",
      "port": 22,
      "user": "admin",
      "pubKeyId": "my-key"
    },
    "tags": ["production", "web"]
  },
  {
    "name": "Development",
    "ssh": {
      "ip": "dev.example.com",
      "port": 2222,
      "user": "dev",
      "pubKeyId": "dev-key"
    },
    "tags": ["development"]
  },
  {
    "name": "Behind NAT",
    "monitorHttp": {
      "addr": "https://10.0.0.5:3770",
      "user": "admin"
    },
    "tags": ["monitor"]
  }
]
```

导入后请逐一测试服务器连接，并确认服务器记录中的标签和 transport 设置符合预期。
