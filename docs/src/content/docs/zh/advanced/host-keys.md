---
title: 主机密钥与证书
description: Server Box 如何验证服务器，以及如何信任主机证书颁发机构
---

Server Box 在发送密码或密钥之前，会先验证每台 SSH 服务器。

## 首次连接

首次连接某台服务器时，Server Box 会显示主机密钥类型和指纹（`SHA256:...`），并询问是否信任。请与服务器上显示的指纹对照：

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

确认后，Server Box 会记住这台服务器的密钥。之后如果服务器出示了不同的密钥，Server Box 会在连接前提示。

## 主机证书

服务器可以出示 OpenSSH 主机证书（`ssh-ed25519-cert-v01@openssh.com` 等），代替普通主机密钥。Server Box 支持 Ed25519、ECDSA 和 RSA 证书。

没有可信的证书颁发机构时，Server Box 处理证书的方式与 OpenSSH 相同：使用证书中的公钥，并在首次连接时按上文的方式询问。显示的指纹是这把公钥的指纹，与 `ssh -v` 输出中 `Server host certificate: ... SHA256:...` 一行一致。

## 可信的证书颁发机构

如果服务器的主机密钥由证书颁发机构（CA）签发，可以只信任一次这个 CA，而不必逐台确认。这等同于 OpenSSH `known_hosts` 中的 `@cert-authority` 行。

打开 **设置 → SSH → 通用 → 主机证书颁发机构**，点击 **添加**：

- **密钥**：CA 的公钥行，例如 `ca.pub` 的内容：`ssh-ed25519 AAAA... ca@example.com`。支持 Ed25519、ECDSA 和 RSA 公钥。也可以直接粘贴 `known_hosts` 中的整行 `@cert-authority *.example.com ssh-ed25519 AAAA...`，主机会从这一行中读取。
- **主机**：这个 CA 为哪些服务器担保。默认值 `*` 匹配所有服务器，不能为空。

服务器的证书由匹配的 CA 签发且有效时，会直接连接，不再询问。有效指：是主机证书、在有效期内、没有 critical option、不是用 SHA-1（`ssh-rsa`）签名，并且 principals 中包含这台服务器。principals 会与 Server Box 实际连接的地址、以及服务器配置中的地址比较；没有 principals 的证书对任何主机都有效，principal 中可以使用 `*` 和 `?`。

其他情况下，服务器仍按上文的方式在首次连接时询问，使用证书中的公钥。这包括由匹配的 CA 签发、但已过期或签给其他主机的证书，OpenSSH 的处理方式相同。

### 主机匹配规则

**主机** 一栏使用 `known_hosts` 的匹配语法：

| 规则 | 匹配 |
|---|---|
| `*` | 所有服务器 |
| `*.example.com` | `web.example.com`、`db.example.com` |
| `web-?.example.com` | `web-1.example.com`，不匹配 `web-10.example.com` |
| `10.0.0.*` | `10.0.0.0` 到 `10.0.0.255` 的地址 |
| `*.example.com,!bastion.example.com` | 除 `bastion` 外的所有 `example.com` 主机 |

多个规则用逗号分隔。以 `!` 开头的规则排除它匹配的主机。匹配不区分大小写。

非 22 端口的服务器按 `[host]:port` 匹配，与 OpenSSH 一致。例如 `[*.example.com]:2222` 匹配 2222 端口上的 `web.example.com`，而 `*.example.com` 不匹配。
