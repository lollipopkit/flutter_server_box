---
title: Monitor 设置备份
description: 把 Monitor 的设置备份到 WebDAV 文件夹，用你的口令加密，并从备份恢复
---

Monitor 可以把自己的设置备份到 WebDAV 文件夹：账号密码、代码片段、远程桌面、BMC 与 PVE 连接、桌面偏好和主题、Agent 模式设置、推送渠道和监控规则。不包含指标历史、审计日志、会话、已安装的应用包和已部署的 Web 应用。

在面板中打开 **设置 → 设置备份**。

## 设置

1. 填写文件夹地址（每台服务器一个文件夹，例如 `https://dav.example.com/serverbox/web-1/`）、用户名和密码，点击 **测试**。文件夹会在首次备份时创建。
2. 点击 **保存**，输入面板密码。
3. 点击 **设置口令**。设置后会立即进行首次备份。

地址必须是 HTTPS。明文 HTTP 只能用于本机，或在打开 **允许明文 HTTP** 后用于其他机器；备份依然加密，但 WebDAV 密码会以明文发送。

## 备份方式

- 每 10 分钟检查一次设置。设置有变化时备份；只有自动变化的值变化时（计划任务的上次运行时间、刷新的登录令牌），每天备份一次。
- 保留最新的 10 份（可在 **保留份数** 中修改）。单份备份最大 100 MB。每台服务器的文件名带有自己的 id（`<server>`），多台服务器共用一个文件夹时不会删除彼此的备份。
- 备份失败时，桌面和推送渠道各提醒一次；恢复正常后桌面会再提醒一次。

## 加密

每份备份是加密到一个密钥的 [age](https://age-encryption.org) 文件。密钥的私钥也存放在文件夹中，即 `serverbox-monitor-key-<server>-<id>.age`，用你的口令加密。Monitor 只保留公钥，因此无需口令即可备份，也无法读取自己的备份。

**口令丢失后备份无法恢复。** 新口令只用于之后的备份，之前的备份仍使用当时的口令。

这些文件是标准的 age 格式，不依赖 ServerBox 也能打开：

```sh
age -d serverbox-monitor-key-<server>-<id>.age > key.txt   # 会询问口令
age -d -i key.txt serverbox-monitor-<server>-<time>-<id>.tar.gz.age | tar -xz
```

压缩包内有 `manifest.json`、`config.toml`、`settings.db`（SQLite）以及设置引用的文件（`blobs/`）。

## 恢复

在面板中点击某份备份旁的 **恢复**，输入它的口令，再输入面板密码。设置会被替换；这台服务器的历史记录、监听地址、TLS 文件、数据库位置和备份位置保留。账号密码会变为备份中的密码，所有设备需要重新登录。作为 systemd 服务（安装脚本的默认方式）或在 OpenRC 下运行的 Monitor 会自动重启；其他情况（包括容器）请手动重启。

在新机器上，可以在 Monitor 的工作目录中用命令行恢复（安装前后均可）：

```sh
server_box_monitor backup restore --url https://dav.example.com/serverbox/web-1/ --user me
```

它会询问 WebDAV 密码和口令（也可以通过 `--password-env`、`--passphrase-env` 指定的环境变量读取），恢复最新的备份（`--name` 可指定其他；多台服务器共用的文件夹必须指定），并以那台服务器的身份继续备份到同一个文件夹。`server_box_monitor backup list` 列出备份，`backup run` 立即备份一次。
