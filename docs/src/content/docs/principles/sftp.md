---
title: SFTP System
description: How the SFTP file browser works
---

The SFTP system provides file management capabilities over SSH.

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
  final sftp = await sshClient.openSftp();

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
    _sftpClient ??= await _sshClient!.openSftp();
    return _sftpClient!;
  }
}
```

## File System Operations

### Directory Listing

```dart
Future<List<SftpFile>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // List directory
  final files = await sftp.listDir(path);

  // Sort based on settings
  files.sort((a, b) {
    switch (sortOption) {
      case SortOption.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortOption.size:
        return a.size.compareTo(b.size);
      case SortOption.time:
        return a.modified.compareTo(b.modified);
    }
  });

  // Folders first if enabled
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.isDirectory);
    final regular = files.where((f) => !f.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### File Metadata

```dart
class SftpFile {
  final String name;
  final String path;
  final int size;           // Bytes
  final int modified;       // Unix timestamp
  final String permissions;  // e.g., "rwxr-xr-x"
  final String owner;
  final String group;
  final bool isDirectory;
  final bool isSymlink;

  String get sizeFormatted => formatBytes(size);
  String get modifiedFormatted => formatDate(modified);
}
```

## File Operations

### Upload

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  // Create request
  final req = SftpReq(
    spi: spi,
    remotePath: remotePath,
    localPath: localPath,
    type: SftpReqType.upload,
  );

  // Add to queue
  _transferQueue.add(req);

  // Execute transfer with progress
  final file = File(localPath);
  final size = await file.length();
  final stream = file.openRead();

  await sftp.upload(
    stream: stream,
    toPath: remotePath,
    onProgress: (transferred) {
      _updateProgress(req, transferred, size);
    },
  );

  // Complete
  _transferQueue.remove(req);
}
```

### Download

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  // Create local file
  final file = File(localPath);
  final sink = file.openWrite();

  // Download with progress
  final stat = await sftp.stat(remotePath);

  await sftp.download(
    fromPath: remotePath,
    toSink: sink,
    onProgress: (transferred) {
      _updateProgress(
        SftpReq(...),
        transferred,
        stat.size,
      );
    },
  );

  await sink.close();
}
```

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
  await ssh.exec('chmod $mode "$path"');
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

### Download Cache

Downloaded files stored at:

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
Future<void> editInExternalEditor(String path) async {
  final ssh = await getSshClient(spiId);

  // Open terminal with editor
  final editor = getSetting('sftpEditor', 'vim');
  await ssh.exec('$editor "$path"');

  // User edits in terminal
  // After save, refresh SFTP view
}
```

## Error Handling

### Permission Errors

```dart
try {
  await sftp.upload(...);
} on SftpPermissionException {
  showError('Permission denied: ${stat.path}');
  showHint('Check file permissions and ownership');
}
```

### Connection Errors

```dart
try {
  await sftp.listDir(path);
} on SftpConnectionException {
  showError('Connection lost');
  await reconnect();
}
```

### Space Errors

```dart
try {
  await sftp.upload(...);
} on SftpNoSpaceException {
  showError('Disk full on remote server');
}
```

## Performance Optimizations

### Directory Caching

```dart
class DirectoryCache {
  final Map<String, CachedDirectory> _cache = {};
  final Duration ttl = Duration(minutes: 5);

  Future<List<SftpFile>> list(String path) async {
    final cached = _cache[path];
    if (cached != null && !cached.isExpired) {
      return cached.files;
    }

    final files = await sftp.listDir(path);
    _cache[path] = CachedDirectory(files);
    return files;
  }
}
```

### Lazy Loading

For large directories (>1000 items):

```dart
List<SftpFile> loadPage(String path, int page, int pageSize) {
  final all = cache[path] ?? [];
  final start = page * pageSize;
  final end = start + pageSize;
  return all.sublist(start, end.clamp(0, all.length));
}
```

### Pagination

```dart
class PaginatedDirectory {
  static const pageSize = 100;

  Future<List<SftpFile>> getPage(int page) async {
    final offset = page * pageSize;
    return await sftp.listDir(
      path,
      offset: offset,
      limit: pageSize,
    );
  }
}
```
