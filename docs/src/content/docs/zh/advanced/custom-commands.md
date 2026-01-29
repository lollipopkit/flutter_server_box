---
title: 自定义命令
description: 在服务器页面上显示自定义命令输出
---

添加自定义 shell 命令，以在服务器详情页面上显示其输出。

## 设置步骤

1. 服务器设置 → 自定义命令
2. 以 JSON 格式输入命令

## 基础格式

```json
{
  "显示名称": "shell 命令"
}
```

**示例：**
```json
{
  "内存": "free -h",
  "磁盘": "df -h",
  "运行时间": "uptime"
}
```

## 查看结果

设置完成后，自定义命令将显示在服务器详情页面上，并自动刷新。

## 特殊命令名称

### server_card_top_right

显示在首页服务器卡片的右上角：

```json
{
  "server_card_top_right": "你的命令"
}
```

## 提示

**使用绝对路径：**
```json
{"我的脚本": "/usr/local/bin/my-script.sh"}
```

**管道命令：**
```json
{"占用最高进程": "ps aux | sort -rk 3 | head -5"}
```

**格式化输出：**
```json
{"CPU 负载": "uptime | awk -F'load average:' '{print $2}'"}
```

**保持命令快速执行：** 最好在 5 秒内完成，以获得最佳体验。

**限制输出内容：**
```json
{"日志": "tail -20 /var/log/syslog"}
```

## 安全性

命令以 SSH 用户的权限运行。避免使用修改系统状态的命令。
