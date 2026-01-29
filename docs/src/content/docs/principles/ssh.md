---
title: SSH Connection
description: How SSH connections are established and managed
---

Understanding SSH connections in Server Box.

## Connection Flow

```
User Input → Spi Config → genClient() → SSH Client → Session
```

### Step 1: Configuration

The `Spi` (Server Parameter Info) model contains:

```dart
class Spi {
  String name;       // Server name
  String ip;         // IP address
  int port;          // SSH port (default 22)
  String user;       // Username
  String? pwd;       // Password (encrypted)
  String? keyId;     // SSH key ID
  String? jumpId;    // Jump server ID
  String? alterUrl;  // Alternative URL
}
```

### Step 2: Client Generation

`genClient(spi)` creates SSH client:

```dart
Future<SSHClient> genClient(Spi spi) async {
  // 1. Establish socket
  final socket = await connect(spi.ip, spi.port);

  // 2. Try alternative URL if failed
  if (socket == null && spi.alterUrl != null) {
    socket = await connect(spi.alterUrl, spi.port);
  }

  // 3. Authenticate
  final client = SSHClient(
    socket: socket,
    username: spi.user,
    onPasswordRequest: () => spi.pwd,
    onIdentityRequest: () => loadKey(spi.keyId),
  );

  // 4. Verify host key
  await verifyHostKey(client, spi);

  return client;
}
```

### Step 3: Jump Server (if configured)

For jump servers, recursive connection:

```dart
if (spi.jumpId != null) {
  final jumpClient = await genClient(getJumpSpi(spi.jumpId));
  final forwarded = await jumpClient.forwardLocal(
    spi.ip,
    spi.port,
  );
  // Connect through forwarded socket
}
```

## Authentication Methods

### Password Authentication

```dart
onPasswordRequest: () => spi.pwd
```

- Password stored encrypted in Hive
- Decrypted on connection
- Sent to server for verification

### Private Key Authentication

```dart
onIdentityRequest: () async {
  final key = await KeyStore.get(spi.keyId);
  return decyptPem(key.pem, key.password);
}
```

**Key Loading Process:**
1. Retrieve encrypted key from `KeyStore`
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

Prevents **Man-in-the-Middle (MITM)** attacks by ensuring you're connecting to the same server.

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

  final stored = SettingStore.sshKnownHostsFingerprints
      ['$keyId::$keyType'];

  if (stored == null) {
    // New host - prompt user
    final trust = await promptUser(
      'Unknown host',
      'Fingerprint: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostsFingerprints
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

Active clients maintained in `ServerProvider`:

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-Alive

Maintain connection during inactivity:

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
