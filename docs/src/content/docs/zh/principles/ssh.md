---
title: SSH 连接
description: SSH 连接是如何建立和管理的
---

了解 Flutter Server Box 中的 SSH 连接机制。

## 连接流程

```
用户输入 → Spi 配置 → genClient() → SSH 客户端 → 会话 (Session)
```

### 第一步：配置

`Spi` (Server Parameter Info) 模型包含：

```dart
class Spi {
  String name;       // 服务器名称
  String ip;         // IP 地址
  int port;          // SSH 端口 (默认 22)
  String user;       // 用户名
  String? pwd;       // 密码 (加密存储)
  String? keyId;     // SSH 密钥 ID
  String? jumpId;    // 跳板机 ID
  String? alterUrl;  // 备用 URL
}
```

### 第二步：生成客户端

`genClient(spi)` 创建 SSH 客户端：

```dart
Future<SSHClient> genClient(Spi spi) async {
  // 1. 建立 socket
  final socket = await connect(spi.ip, spi.port);

  // 2. 如果失败，尝试备用 URL
  if (socket == null && spi.alterUrl != null) {
    socket = await connect(spi.alterUrl, spi.port);
  }

  // 3. 身份验证
  final client = SSHClient(
    socket: socket,
    username: spi.user,
    onPasswordRequest: () => spi.pwd,
    onIdentityRequest: () => loadKey(spi.keyId),
  );

  // 4. 验证主机密钥
  await verifyHostKey(client, spi);

  return client;
}
```

### 第三步：跳板机 (如果已配置)

对于跳板机，采用递归连接：

```dart
if (spi.jumpId != null) {
  final jumpClient = await genClient(getJumpSpi(spi.jumpId));
  final forwarded = await jumpClient.forwardLocal(
    spi.ip,
    spi.port,
  );
  // 通过转发的 socket 进行连接
}
```

## 身份验证方式

### 密码验证

```dart
onPasswordRequest: () => spi.pwd
```

- 密码以加密形式存储在 Hive 中
- 连接时解密
- 发送到服务器进行验证

### 私钥验证

```dart
onIdentityRequest: () async {
  final key = await KeyStore.get(spi.keyId);
  return decyptPem(key.pem, key.password);
}
```

**密钥加载流程：**
1. 从 `KeyStore` 获取加密的密钥
2. 解密密码（通过生物识别或提示）
3. 解析 PEM 格式
4. 标准化换行符 (LF)
5. 返回用于身份验证

### 键盘交互式 (Keyboard-Interactive)

```dart
onUserInfoRequest: (instructions) async {
  // 处理挑战-响应 (Challenge-Response)
  return responses;
}
```

支持：
- 密码验证
- OTP 令牌
- 双因子认证 (2FA)

## 主机密钥验证

### 为什么要验证主机密钥？

通过确保连接的是同一个服务器，防止**中间人 (MITM)** 攻击。

### 存储格式

```
{spi.id}::{keyType}
```

示例：
```
my-server::ssh-ed25519
my-server::ecdsa-sha2-nistp256
```

### 指纹格式

**MD5 十六进制：**
```
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64：**
```
SHA256:AbCdEf1234567890...=
```

### 验证流程

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final fingerprint = md5Hex(key); // 或 base64

  final stored = SettingStore.sshKnownHostsFingerprints
      ['$keyId::$keyType'];

  if (stored == null) {
    // 新主机 - 提示用户
    final trust = await promptUser(
      '未知主机',
      '指纹: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostsFingerprints
          ['$keyId::$keyType'] = fingerprint;
    }
  } else if (stored != fingerprint) {
    // 已更改 - 警告用户
    await warnUser(
      '主机密钥已更改！',
      '可能存在中间人攻击',
    );
  }
}
```

## 会话管理

### 连接池

在 `ServerProvider` 中维护活动的客户端：

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### 心跳检测 (Keep-Alive)

在闲置期间维持连接：

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### 自动重连

连接丢失时：

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## 连接生命周期

```
┌─────────────┐
│    初始化   │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│    连接中   │ ←──┐
└──────┬──────┘   │
       │ 成功     │
       ↓          │ 失败 (重试)
┌─────────────┐   │
│    已连接   │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│    活跃中   │ ──→ 发送命令
└──────┬──────┘
       │
       ↓ (错误/断开)
┌─────────────┐
│    已断开   │
└─────────────┘
```

## 错误处理

### 连接超时

```dart
try {
  await client.connect().timeout(
    Duration(seconds: 30),
  );
} on TimeoutException {
  throw ConnectionException('连接超时');
}
```

### 身份验证失败

```dart
onAuthFail: (error) {
  if (error.contains('password')) {
    return '密码无效';
  } else if (error.contains('key')) {
    return 'SSH 密钥无效';
  }
  return '身份验证失败';
}
```

### 主机密钥不匹配

```dart
onHostKeyMismatch: (stored, current) {
  showSecurityWarning(
    '主机密钥已更改！',
    '可能存在中间人攻击',
  );
}
```

## 性能考量

### 连接复用

- 在不同功能间复用客户端
- 避免不必要的断开和重连
- 为并发操作建立连接池

### 最佳设置

- **超时时间**：30 秒 (可调)
- **心跳频率**：每 30 秒一次
- **重试延迟**：5 秒

### 网络效率

- 单个连接处理多个操作
- 尽可能使用管道 (Pipeline) 命令
- 避免打开多个连接
