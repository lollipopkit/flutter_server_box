---
title: 批量导入服务器
description: 从 JSON 文件中导入多个服务器
---

使用 JSON 文件一次性导入多个服务器配置。

## JSON 格式

:::danger[安全警告]
**切勿在文件中存储明文密码！** 此 JSON 示例仅为了演示显示了密码字段，但你应该：

- **优先使用 SSH 密钥** (`keyId`) 而不是 `pwd` - 它们更安全
- 如果必须使用密码，请使用**密码管理器**或环境变量
- 导入后**立即删除文件** - 不要让凭据散落在各处
- **添加到 .gitignore** - 切勿将凭证文件提交到版本控制
:::

```json
[
  {
    "name": "My Server",
    "ip": "example.com",
    "port": 22,
    "user": "root",
    "pwd": "password",
    "keyId": "",
    "tags": ["production"],
    "autoConnect": false
  }
]
```

## 字段说明

| 字段 | 必填 | 说明 |
|-------|----------|-------------|
| `name` | 是 | 显示名称 |
| `ip` | 是 | 域名或 IP 地址 |
| `port` | 是 | SSH 端口 (通常为 22) |
| `user` | 是 | SSH 用户名 |
| `pwd` | 否 | 密码 (不建议使用 - 请改用 SSH 密钥) |
| `keyId` | 否 | SSH 密钥名称 (来自“私钥” - 推荐) |
| `tags` | 否 | 组织标签 |
| `autoConnect` | 否 | 启动时自动连接 |

## 导入步骤

1. 创建包含服务器配置的 JSON 文件
2. 设置 → 备份 → 批量导入服务器
3. 选择你的 JSON 文件
4. 确认导入

## 示例

```json
[
  {
    "name": "Production",
    "ip": "prod.example.com",
    "port": 22,
    "user": "admin",
    "keyId": "my-key",
    "tags": ["production", "web"]
  },
  {
    "name": "Development",
    "ip": "dev.example.com",
    "port": 2222,
    "user": "dev",
    "keyId": "dev-key",
    "tags": ["development"]
  }
]
```

## 提示

- 尽可能**使用 SSH 密钥**代替密码
- 导入后**测试连接**
- **使用标签组织**以便于管理
- 导入后**删除 JSON 文件**
- **切勿提交**包含凭据的 JSON 文件到版本控制
