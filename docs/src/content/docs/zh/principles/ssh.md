---
title: SSH 连接
description: Server Box 如何建立和管理 SSH 连接
---

下文介绍 Server Box 如何建立、验证和复用 SSH 连接。通过 Monitor agent 添加的服务器不包含 SSH 凭据，因此不适用以下内容。

## 连接流程

```text
用户配置 → Spi → genClient() → SSH client → Session
```

### 配置模型

`Spi`（Server Parameter Info）包含服务器和连接信息：

```dart
class Spi {
  String id;                      // 唯一标识
  String name;                    // 服务器名称
  SshCredential? ssh;             // 未配置 SSH 时为 null
  MonitorHttpCredential? monitorHttp;
}

final class SshCredential {
  String ip;              // IP 地址或域名
  int port;               // SSH 端口，默认 22
  String user;             // 用户名
  String? pwd;             // 密码，加密存储
  String? keyId;           // SSH key ID
  String? alterUrl;        // 备用 URL
  List<String>? jumpIds;   // Jump server 链
  String? proxyCommand;    // ProxyCommand，仅桌面端
}
```

Jump server 链与 `ProxyCommand` 互斥。两者同时配置时，`Spix.validate()` 会拒绝该服务器配置。

### 创建 client

`genClient(spi)` 会创建并返回 SSH client：

```dart
Future<SSHClient> genClient(Spi spi) async {
  final ssh = spi.ssh!;
  // 1. 建立 socket；失败后尝试备用主机、用户和端口。
  SSHSocket? socket;
  var connectUser = ssh.user;
  try {
    socket = await connect(ssh.ip, ssh.port);
  } catch (_) {
    if (ssh.alterUrl == null) rethrow;
    final (alterHost, parsedUser, alterPort) = ssh.parseAlterUrl();
    socket = await connect(alterHost, alterPort);
    connectUser = parsedUser;
  }

  // 2. 身份验证
  final client = SSHClient(
    socket: socket!,
    username: connectUser,
    onPasswordRequest: () => ssh.pwd,
    onIdentityRequest: () => loadKey(ssh.keyId),
  );

  // 3. 验证 host key
  await verifyHostKey(client, spi);

  return client;
}
```

## Socket 来源

`genClient` 会从以下三种方式中选择一种。无论 socket 来源如何，建立 SSH client 后的处理都相同。

**直连**：使用 `SSHSocket.connect(ip, port)`。连接失败时，如果配置了 `alterUrl`，会尝试备用地址。

**Jump server**：按配置的候选顺序连接 jump server，再通过本地转发访问目标主机：

```dart
for (final jumpId in spi.resolvedJumpIds) {
  final jumpClient = await genClient(getJumpSpi(jumpId));
  return await jumpClient.forwardLocal(ssh.ip, ssh.port);
}
```

**ProxyCommand**：仅桌面端可用，因为它需要启动本地进程：

```dart
if (ssh.proxyCommand != null) {
  return await ProxyCommandSocket.connect(
    command: ssh.proxyCommand,
    host: ssh.ip,
    port: ssh.port,
    user: ssh.user,
  );
}
```

## 身份验证

### 密码

```dart
onPasswordRequest: () => ssh.pwd
```

密码以加密形式保存在 SQLite 中，连接时解密并发送给服务器验证。

### Private key

```dart
onIdentityRequest: () async {
  final key = await PrivateKeyStore.get(ssh.keyId);
  return decryptPem(key.pem, key.password);
}
```

Private key 的加载流程：

1. 从 `PrivateKeyStore` 读取加密的 key。
2. 解密 key 密码；根据设置可能需要生物识别或再次确认。
3. 解析 PEM 格式。
4. 统一换行符为 LF。
5. 将 key 提供给 SSH client。

### Keyboard-interactive

```dart
onUserInfoRequest: (instructions) async {
  // 处理 challenge-response
  return responses;
}
```

可用于密码、OTP token 和双因素认证（2FA）。

## Host key 验证

### 作用

首次连接时记录服务器 host key，后续连接比较已记录的 key，可帮助检测中间人（MITM）攻击。

### 存储 key

```text
{spi.id}::{keyType}
```

示例：

```text
my-server::ssh-ed25519
my-server::ecdsa-sha2-nistp256
```

### Fingerprint

App 显示并保存 OpenSSH SHA-256 格式的 fingerprint：

```text
SHA256:AbCdEf1234567890...=
```

读取旧版本保存的值时，App 会先将其转换为当前格式。

### 验证流程

```dart
Future<bool> verifyHostKey(
  HostKeyVerifier verifier,
  String keyType,
  Uint8List fingerprintBytes,
) => verifier(keyType, fingerprintBytes);
```

`HostKeyVerifier` 将收到的 fingerprint 与 `spi.id::keyType` 对应的已保存值比较。未知 key 只有在你确认提示后才会信任；key 不匹配时必须再次明确确认。拒绝会返回 `false`，SSH 连接也会被拒绝。接受的 key 会持久化，供后续连接比较。

## Session 管理

### 连接复用

`ServerProvider` 维护活动 client，在终端、命令和文件功能之间复用连接：

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-alive

客户端在空闲期间发送 keep-alive 消息：

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### 自动重连

连接丢失后，provider 会等待一段时间再尝试重连：

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## 连接生命周期

```text
┌─────────────┐
│    初始化    │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│    连接中    │ ←──┐
└──────┬──────┘   │
       │ 成功     │
       ↓          │ 失败，重试
┌─────────────┐   │
│    已连接    │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│    使用中    │ ──→ 发送命令或打开 session
└──────┬──────┘
       │
       ↓ 错误或断开
┌─────────────┐
│    已断开    │
└─────────────┘
```

## 错误处理

常见错误包括：

- **连接超时**：检查地址、端口、防火墙和网络路由。
- **身份验证失败**：检查用户名、密码、private key 或 keyboard-interactive 配置。
- **Host key 不匹配**：不要直接接受新 key。先核对服务器身份；确认服务器确实更换了 key 后，再在 Known Hosts 设置中删除旧记录并重新连接。

## 性能建议

- 在不同功能之间复用已有 client。
- 避免不必要的断开和重连。
- 通过单个 SSH 连接执行多个操作。
- 只有在确实需要多个独立 session 时才创建额外连接。
- 调整超时、keep-alive 和重试间隔时，应结合网络延迟和服务器限制测试。
