---
title: SSH Connection
description: How Server Box establishes and manages SSH connections
---

This page describes how Server Box establishes, verifies, and reuses SSH connections. A server configured only through Monitor HTTP has no SSH credentials and is not covered here.

## Connection flow

```text
User configuration → Spi → genClient() → SSH client → Session
```

### Configuration

`Spi` (Server Parameter Info) contains the server and connection settings:

```dart
class Spi {
  String id;                      // Unique identifier
  String name;                    // Server name
  SshCredential? ssh;             // null when SSH is not configured
  MonitorHttpCredential? monitorHttp;
}

final class SshCredential {
  String ip;              // IP address or hostname
  int port;               // SSH port, default 22
  String user;             // Username
  String? pwd;             // Password, encrypted at rest
  String? keyId;           // SSH key ID
  String? alterUrl;        // Fallback URL
  List<String>? jumpIds;   // Jump-server candidates
  String? proxyCommand;    // ProxyCommand, desktop only
}
```

Jump-server candidates and `ProxyCommand` are mutually exclusive. `Spix.validate()` rejects a server that configures both.

### Creating the client

`genClient(spi)` creates and returns an SSH client:

```dart
Future<SSHClient> genClient(Spi spi) async {
  final ssh = spi.ssh!;
  // 1. Establish the socket; try the parsed fallback URL if it fails.
  SSHSocket? socket;
  var connectUser = ssh.user;
  try {
    socket = await connect(ssh.ip, ssh.port);
  } catch (_) {
    if (ssh.alterUrl == null) rethrow;
    final (fallbackHost, fallbackUser, fallbackPort) = ssh.parseAlterUrl();
    socket = await connect(fallbackHost, fallbackPort);
    connectUser = fallbackUser;
  }

  // 2. Authenticate
  final client = SSHClient(
    socket: socket!,
    username: connectUser,
    onPasswordRequest: () => ssh.pwd,
    onIdentityRequest: () => loadKey(ssh.keyId),
  );

  // 3. Verify the host key
  await verifyHostKey(client, spi);

  return client;
}
```

## Socket sources

`genClient` selects one of the following socket sources. Once the socket exists, SSH client setup and host-key verification are the same in every case.

**Direct connection** uses `SSHSocket.connect(ip, port)`. If it fails and `alterUrl` is configured, the App tries the fallback address, user, and port.

**Jump server** connects through jump-server candidates in order, then creates a local forward to the target:

```dart
for (final jumpId in spi.resolvedJumpIds) {
  final jumpClient = await genClient(getJumpSpi(jumpId));
  return await jumpClient.forwardLocal(ssh.ip, ssh.port);
}
```

**ProxyCommand** is available on desktop only because it starts a local process:

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

The SSH client above these socket sources still authenticates to and verifies the target server. A jump server or ProxyCommand only changes how the byte stream reaches it.

## Authentication

### Password

```dart
onPasswordRequest: () => ssh.pwd
```

The password is stored in encrypted SQLite, decrypted when needed, and sent to the server for authentication.

### Private key

```dart
onIdentityRequest: () async {
  final key = await PrivateKeyStore.get(ssh.keyId);
  return decryptPem(key.pem, key.password);
}
```

The private-key loading flow is:

1. Read the encrypted key from `PrivateKeyStore`.
2. Unlock it; depending on settings, this may require biometrics or confirmation.
3. Parse the PEM data.
4. Normalize line endings to LF.
5. Pass the key to the SSH client.

Desktop imports from `~/.ssh/config` can also reference a private-key file. The App reads that path when connecting instead of copying the file into its store.

### Keyboard-interactive

```dart
onUserInfoRequest: (instructions) async {
  // Handle challenge-response prompts
  return responses;
}
```

This can support passwords, OTP tokens, and two-factor authentication.

## Host-key verification

### Why verify host keys?

The App records a server's host key and compares it on later connections. This helps detect man-in-the-middle (MITM) attacks.

### Storage key

```text
{spi.id}::{keyType}
```

For example:

```text
my-server::ssh-ed25519
my-server::ecdsa-sha2-nistp256
```

### Fingerprint format

The App displays and stores fingerprints in the OpenSSH SHA-256 format:

```text
SHA256:AbCdEf1234567890...=
```

Legacy stored values are normalized when read.

### Verification flow

```dart
Future<bool> verifyHostKey(
  HostKeyVerifier verifier,
  String keyType,
  Uint8List fingerprintBytes,
) => verifier(keyType, fingerprintBytes);
```

`HostKeyVerifier` compares the received fingerprint with the value stored under `spi.id::keyType`. An unknown key is trusted only after you accept the prompt. A mismatch requires explicit re-approval; declining returns `false` and rejects the SSH connection. Accepted fingerprints are persisted for future connections.

## Session management

### Connection reuse

`ServerNotifier` owns the per-server client and reuses it across status collection and other SSH features:

```dart
final state = ref.watch(serverProvider(serverId));
final client = state.client;
```

The exact operation that needs a client asks the server provider for it; pages should not create a separate client for every action.

### Keep-alive

The SSH client sends protocol-level keep-alive messages during inactivity. These messages are separate from terminal input and output.

### Reconnection

When a connection fails, the server provider can recreate it on a later refresh. A failed status request should not be treated as proof that the host has no SFTP subsystem or no other capability.

## Connection lifecycle

```text
┌─────────────┐
│   Initial   │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│ Connecting  │ ←──┐
└──────┬──────┘   │
       │ success  │ failure, retry later
       ↓          │
┌─────────────┐   │
│ Connected   │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│ In use      │ ──→ Run commands or open sessions
└──────┬──────┘
       │
       ↓ error or disconnect
┌─────────────┐
│ Disconnected│
└─────────────┘
```

## Error handling

- **Connection timeout**: Check the host, port, firewall, and network route.
- **Authentication failure**: Check the username, password, private key, or keyboard-interactive configuration.
- **Host-key mismatch**: Do not accept a new key automatically. Verify the server identity first. If the server really replaced its key, remove the old entry from Known Hosts and reconnect.
- **Missing private key**: Confirm that the configured key ID still exists, or that the imported `keyPath` is readable on the desktop.

## Performance guidance

- Reuse an existing client across features.
- Avoid unnecessary disconnect/reconnect cycles.
- Use one SSH connection for multiple operations where possible.
- Create additional independent sessions only when a feature requires them.
- Tune timeouts, keep-alive intervals, and retry behavior for the actual network and server.
