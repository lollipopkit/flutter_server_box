---
title: 批量导入服务器
description: 从 JSON 文件中导入多个服务器
---

使用 JSON 文件导入多个服务器配置。

## JSON 格式

:::danger[安全警告]
**切勿在文件中存储明文密码！** 此 JSON 示例仅用于演示，因此包含密码字段。你应该：

- **优先使用 SSH 密钥**（`pubKeyId`）而不是 `pwd`，避免在文件中存储密码
- 如果必须使用密码，请使用**密码管理器**或环境变量
- 导入后**删除文件**，不要保留明文凭据
- **添加到 .gitignore** - 切勿将凭证文件提交到版本控制
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

SSH 相关字段嵌套在 `ssh` 下。这是 App 写出的格式，也是导入对话框展示给你的示例。

旧的扁平格式（`ip`/`port`/`user`/… 直接放在顶层）仍然可以解析，因此旧版本导出的
文件和 `~/.ssh/config` 导入都还能用。现在已经没有任何地方会写出它。

## 字段说明

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `name` | 是 | 显示名称 |
| `ssh` | 否 | SSH 配置，见下表。纯 monitor 服务器可省略 |
| `monitorHttp` | 否 | monitor agent：`addr`、`user`、`pwd`、`ignoreCert` |
| `tags` | 否 | 用于分组服务器的标签 |
| `autoConnect` | 否 | 启动时自动连接 |
| `custom` | 否 | 单服务器附加项：`pveAddr`、`preferTempDev`、`logoUrl` 等 |
| `wolCfg` | 否 | Wake-on-LAN 配置 |
| `envs` | 否 | 环境变量，仅对 SSH 终端生效 |
| `customSystemType` | 否 | 跳过系统自动检测 |
| `disabledCmdTypes` | 否 | 该服务器上跳过的状态命令 |
| `id` | 否 | 稳定的服务器 id；省略或为空时会在导入时生成 |

`ssh` 内部：

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `ip` | 是 | 域名或 IP 地址 |
| `port` | 是 | SSH 端口（通常为 22） |
| `user` | 是 | SSH 用户名 |
| `pwd` | 否 | 密码（不建议使用，请改用 SSH 密钥） |
| `pubKeyId` | 否 | 私钥记录 id（来自“私钥” - 推荐） |
| `alterUrl` | 否 | 备用地址，`user@ip:port` |
| `jumpIds` | 否 | 跳板机链，按服务器 id 指定 |
| `proxyCommand` | 否 | ProxyCommand；仅桌面端，且与 `jumpIds` 互斥 |

既没有 `ssh` 也没有 `monitorHttp` 的记录，导入后将成为无法访问的服务器。请至少提供其中一个。

## 导入步骤

1. 创建包含服务器配置的 JSON 文件
2. 设置 → **备份** → 导入 → **服务器**
3. 选择你的 JSON 文件
4. 确认导入数量

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

## 提示

- **优先使用 SSH 密钥**代替密码
- 导入后**测试连接是否成功**
- **使用标签进行分类**，便于管理
- 导入后**删除 JSON 文件**
- **切勿提交**包含凭据的 JSON 文件到版本控制
