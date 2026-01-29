---
title: SFTP 系统
description: SFTP 文件浏览器的工作原理
---

SFTP 系统通过 SSH 提供文件管理功能。

## 架构

```
┌─────────────────────────────────────────────┐
│              SFTP UI 层                     │
│  - 文件浏览器 (远程)                        │
│  - 文件浏览器 (本地)                        │
│  - 传输队列                                 │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SFTP 状态管理                      │
│  - sftpProvider                             │
│  - 路径管理                                 │
│  - 操作队列                                 │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         SFTP 协议层                         │
│  - SSH 子系统                               │
│  - 文件操作                                 │
│  - 目录列表                                 │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            SSH 传输层                       │
│  - 安全通道                                 │
│  - 数据流                                   │
└─────────────────────────────────────────────┘
```

## 连接建立

### 创建 SFTP 客户端

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. 获取 SSH 客户端 (如果可用则复用)
  final sshClient = await genClient(spi);

  // 2. 打开 SFTP 子系统
  final sftp = await sshClient.openSftp();

  return sftp;
}
```

### 连接复用

SFTP 复用现有的 SSH 连接：

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

## 文件系统操作

### 目录列表

```dart
Future<List<SftpFile>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // 获取目录列表
  final files = await sftp.listDir(path);

  // 根据设置排序
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

  // 如果启用，文件夹优先
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.isDirectory);
    final regular = files.where((f) => !f.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### 文件元数据

```dart
class SftpFile {
  final String name;
  final String path;
  final int size;           // 字节
  final int modified;       // Unix 时间戳
  final String permissions;  // 例如 "rwxr-xr-x"
  final String owner;
  final String group;
  final bool isDirectory;
  final bool isSymlink;

  String get sizeFormatted => formatBytes(size);
  String get modifiedFormatted => formatDate(modified);
}
```

## 文件操作

### 上传

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  // 创建请求
  final req = SftpReq(
    spi: spi,
    remotePath: remotePath,
    localPath: localPath,
    type: SftpReqType.upload,
  );

  // 添加到队列
  _transferQueue.add(req);

  // 执行带进度的传输
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

  // 完成
  _transferQueue.remove(req);
}
```

### 下载

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  // 创建本地文件
  final file = File(localPath);
  final sink = file.openWrite();

  // 执行带进度的下载
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

### 权限编辑

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // 解析权限 (例如 "rwxr-xr-x" 或 "755")
  final mode = parsePermissions(permissions);

  // 通过 SSH 命令设置 (比 SFTP 更可靠)
  final ssh = await getSshClient(spiId);
  await ssh.exec('chmod $mode "$path"');
}
```

## 路径管理

### 路径结构

```dart
class PathWithPrefix {
  final String prefix;  // 例如 "/home/user"
  final String path;    // 相对或绝对路径

  String get fullPath {
    if (path.startsWith('/')) {
      return path;  // 绝对路径
    }
    return '$prefix/$path';  // 相对路径
  }

  PathWithPrefix cd(String subPath) {
    return PathWithPrefix(
      prefix: fullPath,
      path: subPath,
    );
  }
}
```

### 导航历史

```dart
class PathHistory {
  final List<String> _history = [];
  int _index = -1;

  void push(String path) {
    // 移除前进历史
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

## 传输系统

### 传输请求

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

### 进度跟踪

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

### 队列管理

```dart
class TransferQueue {
  final List<SftpReq> _queue = [];
  final Map<String, TransferProgress> _progress = {};
  int _concurrent = 3;  // 最大并发传输数

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

## 本地存储模式

### 下载缓存

下载的文件存储在：

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final normalized = remotePath.replaceAll('/', '_');
  return 'Paths.file/$spiId/$normalized';
}
```

示例：
- 远程：`/var/log/nginx/access.log`
- spiId：`server-123`
- 本地：`Paths.file/server-123/_var_log_nginx_access.log`

## 文件编辑

### 编辑工作流

```dart
Future<void> editFile(String path) async {
  final sftp = await getSftpClient(spiId);

  // 1. 检查大小
  final stat = await sftp.stat(path);
  if (stat.size > editorMaxSize) {
    showWarning('文件太大，内置编辑器无法打开');
    return;
  }

  // 2. 下载到临时目录
  final temp = await downloadToTemp(path);

  // 3. 在编辑器中打开
  final content = await openEditor(temp.path);

  // 4. 上传回服务器
  await uploadFile(temp.path, path);

  // 5. 清理
  await temp.delete();
}
```

### 外部编辑器集成

```dart
Future<void> editInExternalEditor(String path) async {
  final ssh = await getSshClient(spiId);

  // 使用编辑器打开终端
  final editor = getSetting('sftpEditor', 'vim');
  await ssh.exec('$editor "$path"');

  // 用户在终端中编辑
  // 保存后，刷新 SFTP 视图
}
```

## 错误处理

### 权限错误

```dart
try {
  await sftp.upload(...);
} on SftpPermissionException {
  showError('拒绝访问：${stat.path}');
  showHint('请检查文件权限和所有权');
}
```

### 连接错误

```dart
try {
  await sftp.listDir(path);
} on SftpConnectionException {
  showError('连接丢失');
  await reconnect();
}
```

### 空间错误

```dart
try {
  await sftp.upload(...);
} on SftpNoSpaceException {
  showError('远程服务器磁盘空间不足');
}
```

## 性能优化

### 目录缓存

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

### 懒加载

对于大型目录（>1000 个项目）：

```dart
List<SftpFile> loadPage(String path, int page, int pageSize) {
  final all = cache[path] ?? [];
  final start = page * pageSize;
  final end = start + pageSize;
  return all.sublist(start, end.clamp(0, all.length));
}
```

### 分页

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
