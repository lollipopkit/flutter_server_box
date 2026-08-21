---
title: SFTP System
description: How the SFTP file browser works
---

SFTP manages remote files over an SSH connection.

## Architecture

```
┌─────────────────────────────────────────────┐
│              SFTP UI Layer                  │
│  - File browser (remote)                    │
│  - File browser (local)                     │
│  - Transfer queue                           │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SFTP State Management              │
│  - sftpProvider                             │
│  - Path management                          │
│  - Operation queue                          │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         SFTP Protocol Layer                 │
│  - SSH subsystem                            │
│  - File operations                          │
│  - Directory listing                        │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            SSH Transport                    │
│  - Secure channel                           │
│  - Data streaming                           │
└─────────────────────────────────────────────┘
```

## Connection Establishment

### SFTP Client Creation

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. Get SSH client (reuse if available)
  final sshClient = await genClient(spi);

  // 2. Open SFTP subsystem
  final sftp = await sshClient.sftp();

  return sftp;
}
```

### Connection Reuse

SFTP reuses existing SSH connections:

```dart
class ServerProvider {
  SSHClient? _sshClient;
  SftpClient? _sftpClient;

  Future<SftpClient> getSftpClient(String spiId) async {
    _sftpClient ??= await _sshClient!.sftp();
    return _sftpClient!;
  }
}
```

## File System Operations

### Directory Listing

```dart
Future<List<SftpName>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // List directory
  final files = await sftp.listdir(path);

  // Sort based on settings; each entry exposes metadata through `attr`.
  files.sort((a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));

  // Folders first if enabled
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.attr.isDirectory);
    final regular = files.where((f) => !f.attr.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### File Metadata

`SftpClient.listdir` returns `SftpName` entries. Their `filename`, `attr`, and
the attributes' `size`, `modifyTime`, and `isDirectory` fields provide the
metadata used by the browser. An opened `SftpFile` is a separate handle used for
streaming bytes and must be closed.

## File Operations

### Upload

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  final stagingPath = '$remotePath.<unique-suffix>';
  final remote = await sftp.open(
    stagingPath,
    mode: SftpFileOpenMode.create |
        SftpFileOpenMode.write |
        SftpFileOpenMode.truncate,
  );
  try {
    await remote.write(File(localPath).openRead().map(Uint8List.fromList)).done;
    await remote.close();
    await sftp.rename(stagingPath, remotePath);
  } finally {
    await remote.close();
  }
}
```

There is no `sftp.upload` convenience method in the client used by Server Box.
The real transfer code opens an `SftpFile`, closes it explicitly, writes to a
staging path, and renames it into place. Failed transfers remove the staging
file.

### Download

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  final remote = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
  final sink = File(localPath).openWrite();
  try {
    await sink.addStream(remote.read());
  } finally {
    await remote.close();
    await sink.close();
  }
}
```

There is no `sftp.download` convenience method either. Reads stream from the
opened `SftpFile`; both the remote handle and local sink must be closed.

### Permission Editing

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // Parse permissions (e.g., "rwxr-xr-x" or "755")
  final mode = parsePermissions(permissions);

  // Set via SSH command (more reliable than SFTP)
  final ssh = await getSshClient(spiId);
  await ssh.exec('chmod $mode ${shellSingleQuote(path)}');
}
```

## Path Management

### Path Structure

```dart
class PathWithPrefix {
  final String prefix;  // e.g., "/home/user"
  final String path;    // Relative or absolute

  String get fullPath {
    if (path.startsWith('/')) {
      return path;  // Absolute path
    }
    return '$prefix/$path';  // Relative path
  }

  PathWithPrefix cd(String subPath) {
    return PathWithPrefix(
      prefix: fullPath,
      path: subPath,
    );
  }
}
```

### Navigation History

```dart
class PathHistory {
  final List<String> _history = [];
  int _index = -1;

  void push(String path) {
    // Remove forward history
    _history.removeRange(_index + 1, _history.length);
    _history.add(path);
    _index = _history.length - 1;
  }

  String? back() {
    if (_index > 0) {
      _index--;
      return _history[_index];
    }
    return null;
  }

  String? forward() {
    if (_index < _history.length - 1) {
      _index++;
      return _history[_index];
    }
    return null;
  }
}
```

## Transfer System

### Transfer Request

```dart
class SftpReq {
  final Spi spi;
  final String remotePath;
  final String localPath;
  final SftpReqType type;
  final DateTime createdAt;

  int? totalBytes;
  int? transferredBytes;
  String? error;
}
```

### Progress Tracking

```dart
class TransferProgress {
  final SftpReq request;
  final int total;
  final int transferred;
  final DateTime startTime;

  double get percentage => (transferred / total) * 100;
  Duration get elapsed => DateTime.now().difference(startTime);

  String get speedFormatted {
    final bytesPerSecond = transferred / elapsed.inSeconds;
    return formatSpeed(bytesPerSecond);
  }
}
```

### Queue Management

```dart
class TransferQueue {
  final List<SftpReq> _queue = [];
  final Map<String, TransferProgress> _progress = {};
  int _concurrent = 3;  // Max concurrent transfers

  Future<void> process() async {
    final active = _progress.values.where((p) => p.isInProgress);
    if (active.length >= _concurrent) return;

    final pending = _queue.where((r) => !_progress.containsKey(r.id));
    for (final req in pending.take(_concurrent - active.length)) {
      _executeTransfer(req);
    }
  }

  Future<void> _executeTransfer(SftpReq req) async {
    try {
      _progress[req.id] = TransferProgress.inProgress(req);

      if (req.type == SftpReqType.upload) {
        await uploadFile(req.localPath, req.remotePath);
      } else {
        await downloadFile(req.remotePath, req.localPath);
      }

      _progress[req.id] = TransferProgress.completed(req);
    } catch (e) {
      _progress[req.id] = TransferProgress.failed(req, e);
    }
  }
}
```

## Local Storage Pattern

### Downloaded File Location

Downloaded files are stored at:

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final normalized = remotePath.replaceAll('/', '_');
  return 'Paths.file/$spiId/$normalized';
}
```

Example:
- Remote: `/var/log/nginx/access.log`
- spiId: `server-123`
- Local: `Paths.file/server-123/_var_log_nginx_access.log`

## File Editing

### Edit Workflow

```dart
Future<void> editFile(String path) async {
  final sftp = await getSftpClient(spiId);

  // 1. Check size
  final stat = await sftp.stat(path);
  if (stat.size > editorMaxSize) {
    showWarning('File too large for built-in editor');
    return;
  }

  // 2. Download to temp
  final temp = await downloadToTemp(path);

  // 3. Open in editor
  final content = await openEditor(temp.path);

  // 4. Upload back
  await uploadFile(temp.path, path);

  // 5. Cleanup
  await temp.delete();
}
```

### External Editor Integration

```dart
Future<void> editInExternalEditor(String path, {bool useSudo = false}) async {
  final ssh = await getSshClient(spiId);

  // Open terminal with editor
  final editor = getSetting('sftpEditor', 'vim');
  final command = '${useSudo ? 'sudo ' : ''}$editor ${shellSingleQuote(path)}';
  await ssh.exec(command);

  // User edits in terminal
  // After save, refresh SFTP view
}
```

## Error Handling

### Permission Errors

```dart
try {
  await uploadFile(localPath, remotePath);
} on SftpPermissionException {
  showError('Permission denied: ${stat.path}');
  showHint('Check file permissions and ownership');
}
```

### Connection Errors

```dart
try {
  await sftp.listdir(path);
} on SftpStatusError {
  showError('Connection lost');
  await reconnect();
}
```

### Space Errors

```dart
try {
  await uploadFile(localPath, remotePath);
} on SftpStatusError {
  showError('Disk full on remote server');
}
```

## Performance Notes

- The SSH connection is reused for SFTP; no separate connection is opened.
- Directory listings are fetched on navigation and refreshed on demand. There is
  no TTL cache layer.
- Large transfers run in a background isolate.
