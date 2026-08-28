---
title: 批量导入服务器
description: 从 JSON 文件导入多个服务器配置
---

你可以使用 JSON 文件一次导入多个服务器配置。

## JSON 格式

:::danger[安全警告]
**不要在文件中保存明文密码。** 以下示例仅用于说明格式，因此包含示例密码。实际使用时：

- **优先使用 SSH key**（`pubKeyId`），不要在 JSON 中保存密码。
- 如果必须使用密码，请通过密码管理器或环境变量生成文件。
- 导入完成后立即删除文件。
- 将文件加入 `.gitignore`，不要把凭据文件提交到版本控制系统。
:::

```json
[
  {
    "name": "My Server",
    "ssh": {
      "ip": "example.com",
      "port": 22,
      "user": "root",
      "pwd": "password",
      "pubKeyId": ""
    },
    "tags": ["production"],
    "autoConnect": false
  }
]
```

SSH 相关字段放在 `ssh` 对象中。这是 App 导出的格式，也是导入对话框显示的示例格式。

旧版扁平格式（`ip`、`port`、`user` 等字段直接位于顶层）仍然可以解析，因此旧版本导出的文件和 `~/.ssh/config` 导入结果仍可使用。当前版本不会再写出这种格式。

## 字段说明

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `name` | 是 | 在 App 中显示的服务器名称 |
| `ssh` | 否 | SSH 配置，见下表；纯 Monitor 服务器可以省略 |
| `monitorHttp` | 否 | Monitor agent 配置：`addr`、`user`、`pwd`、`ignoreCert`、`allowInsecure` |
| `preferredTransport` | 否 | 同时配置 SSH 和 Monitor HTTP 时优先使用哪一个：`ssh` 或 `monitorHttp`。省略时优先 SSH |
| `tags` | 否 | 用于分组服务器的标签 |
| `autoConnect` | 否 | App 启动时自动连接 |
| `custom` | 否 | 当前服务器的附加配置，例如 `pveAddr`、`preferTempDev`、`logoUrl` |
| `wolCfg` | 否 | Wake-on-LAN 配置 |
| `envs` | 否 | 环境变量，仅对 SSH 终端生效 |
| `customSystemType` | 否 | 跳过系统类型自动检测 |
| `disabledCmdTypes` | 否 | 在该服务器上跳过的状态命令 |
| `id` | 否 | 稳定的服务器 ID；省略或为空时由 App 在导入时生成 |

`ssh` 对象中的字段：

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `ip` | 是 | 域名或 IP 地址 |
| `port` | 是 | SSH 端口，通常为 `22` |
| `user` | 是 | SSH 用户名 |
| `pwd` | 否 | 密码，不推荐；建议使用 SSH key |
| `pubKeyId` | 否 | App 中已保存的 private key 记录 ID，不是 PEM 文件路径 |
| `keyPath` | 否 | 仅桌面端使用的 private key 文件路径，由 `~/.ssh/config` 导入生成；连接时从该文件读取 |
| `alterUrl` | 否 | 备用地址，格式为 `user@ip:port` |
| `jumpIds` | 否 | Jump server 链，按服务器 ID 指定 |
| `proxyCommand` | 否 | ProxyCommand；仅桌面端可用，且与 `jumpIds` 互斥 |

如果记录同时省略 `ssh` 和 `monitorHttp`，导入后将无法连接。请至少提供其中一个。

`allowInsecure` 默认为 `false`。只有明确允许该 Monitor 连接使用明文 HTTP 时，才将其设为 `true`；这也包括非 loopback 的私有地址。Monitor agent 还会根据自身配置，单独检查敏感端点是否允许不安全连接。

## 导入步骤

1. 创建包含服务器配置的 JSON 文件。
2. 打开 **设置 → 备份 → 导入 → 服务器**。
3. 选择 JSON 文件。
4. 确认导入数量。
5. 导入完成后删除 JSON 文件。

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
      "user": "admin",
      "pwd": "panel-password"
    },
    "tags": ["monitor"]
  }
]
```

## 建议

- 优先使用 SSH key，而不是密码。
- 导入后测试每台服务器的连接。
- 使用标签对服务器分类。
- 导入完成后删除 JSON 文件。
- 不要将包含凭据的 JSON 文件提交到版本控制系统。
