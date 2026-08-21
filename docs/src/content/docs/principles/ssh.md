---
title: SSH Connection
description: How SSH connections are established and managed
---

This page describes how Server Box establishes and manages SSH connections.

This page covers servers added over SSH. A server can instead be added through
a monitor agent's HTTP API, in which case it carries no SSH credential at all
and nothing here applies to it.

## Connection Flow

```
User Input → Spi Config → genClient() → SSH Client → Session
```

### Step 1: Configuration

The `Spi` (Server Parameter Info) model holds the SSH settings in a nullable
`SshCredential`. It is null for a server reached through a monitor agent:

```dart
class Spi {
  String name;                    // Server name
  SshCredential? ssh;             // null for a monitor server
  MonitorHttpCredential? monitorHttp;
}

final class SshCredential {
  String ip;              // IP address
  int port;               // SSH port (default 22)
  String user;            // Username
  String? pwd;            // Password (encrypted)
  String? keyId;          // SSH key ID
  String? alterUrl;       // Alternative URL
  List<String>? jumpIds;  // Jump server chain
  String? proxyCommand;   // ProxyCommand, desktop only
}
```

A jump chain and a `ProxyCommand` are mutually exclusive; `Spix.validate()`
rejects a server that sets both.

### Step 2: Client Generation

`genClient(spi)` creates SSH client:

```dart
Future<SSHClient> genClient(Spi spi) async {
  final ssh = spi.ssh!;
  // 1. Establish socket
  final socket = await connect(ssh.ip, ssh.port);

  // 2. Try alternative URL if failed
  if (socket == null && ssh.alterUrl != null) {
    socket = await connect(ssh.alterUrl, ssh.port);
  }

  // 3. Authenticate
  final client = SSHClient(
    socket: socket,
    username: ssh.user,
    onPasswordRequest: () => ssh.pwd,
    onIdentityRequest: () => loadKey(ssh.keyId),
  );

  // 4. Verify host key
  await verifyHostKey(client, spi);

  return client;
}
```

### Step 3: Where the socket comes from

`genClient` resolves one of three sources, then everything above `SSHSocket` is
the same in each case:

**Direct**: the default, `SSHSocket.connect(ip, port)`, falling back to
`alterUrl` when it fails.

**Jump server**: recursive connection, then a local forward:

```dart
for (final jumpId in spi.resolvedJumpIds) {
  final jumpClient = await genClient(getJumpSpi(jumpId));
  return await jumpClient.forwardLocal(ssh.ip, ssh.port);
}
```

**ProxyCommand**: desktop only, since it spawns a process:

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

## Authentication Methods

### Password Authentication

```dart
onPasswordRequest: () => ssh.pwd
```

- Password stored in the encrypted SQLite database
- Decrypted on connection
- Sent to server for verification

### Private Key Authentication

```dart
onIdentityRequest: () async {
  final key = await PrivateKeyStore.get(ssh.keyId);
  return decyptPem(key.pem, key.password);
}
```

**Key Loading Process:**
1. Retrieve encrypted key from `PrivateKeyStore`
2. Decrypt password (biometric/prompt)
3. Parse PEM format
4. Standardize line endings (LF)
5. Return for authentication

### Keyboard-Interactive

```dart
onUserInfoRequest: (instructions) async {
  // Handle challenge-response
  return responses;
}
```

Supports:
- Password authentication
- OTP tokens
- Two-factor authentication

## Host Key Verification

### Why Verify Host Keys?

Helps detect a possible man-in-the-middle (MITM) attack by comparing the server's host key.

### Storage Format

```
{spi.id}::{keyType}
```

Example:
```
my-server::ssh-ed25519
my-server::ecdsa-sha2-nistp256
```

### Fingerprint Formats

**MD5 Hex:**
```
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64:**
```
SHA256:AbCdEf1234567890...=
```

### Verification Flow

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final fingerprint = md5Hex(key); // or base64

  final stored = SettingStore.sshKnownHostFingerprints
      ['$keyId::$keyType'];

  if (stored == null) {
    // New host - prompt user
    final trust = await promptUser(
      'Unknown host',
      'Fingerprint: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostFingerprints
          ['$keyId::$keyType'] = fingerprint;
    }
  } else if (stored != fingerprint) {
    // Changed - warn user
    await warnUser(
      'Host key changed!',
      'Possible MITM attack',
    );
  }
}
```

## Session Management

### Connection Pooling

`ServerProvider` maintains active clients:

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-Alive

The client sends keep-alive messages during inactivity:

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### Auto-Reconnect

On connection loss:

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## Connection Lifecycle

```
┌─────────────┐
│   Initial   │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│ Connecting  │ ←──┐
└──────┬──────┘   │
       │ success  │
       ↓          │ fail (retry)
┌─────────────┐   │
│ Connected   │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│   Active    │ ──→ Send commands
└──────┬──────┘
       │
       ↓ (error/disconnect)
┌─────────────┐
│ Disconnected│
└─────────────┘
```

## Error Handling

### Connection Timeout

```dart
try {
  await client.connect().timeout(
    Duration(seconds: 30),
  );
} on TimeoutException {
  throw ConnectionException('Connection timeout');
}
```

### Authentication Failure

```dart
onAuthFail: (error) {
  if (error.contains('password')) {
    return 'Invalid password';
  } else if (error.contains('key')) {
    return 'Invalid SSH key';
  }
  return 'Authentication failed';
}
```

### Host Key Mismatch

```dart
onHostKeyMismatch: (stored, current) {
  showSecurityWarning(
    'Host key has changed!',
    'Possible MITM attack',
  );
}
```

## Performance Considerations

### Connection Reuse

- Reuse clients across features
- Don't disconnect/reconnect unnecessarily
- Pool connections for concurrent operations

### Optimal Settings

- **Timeout**: 30 seconds (adjustable)
- **Keep-alive**: Every 30 seconds
- **Retry delay**: 5 seconds

### Network Efficiency

- Single connection for multiple operations
- Pipeline commands when possible
- Avoid opening multiple connections
