---
title: SFTP 系统
description: SFTP 文件浏览器的工作原理
---

SFTP 通过 SSH 管理远程文件。

## 架构

```text
┌─────────────────────────────────────────────┐
│              SFTP UI 层                     │
│  - 远程文件浏览器                           │
│  - 本地文件浏览器                           │
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
  final sftp = await sshClient.sftp();

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
    _sftpClient ??= await _sshClient!.sftp();
    return _sftpClient!;
  }
}
```

## 文件系统操作

### 目录列表

```dart
Future<List<SftpName>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // 获取目录列表
  final files = await sftp.listdir(path);

  // 根据设置排序
  // 每个条目通过 `attr` 暴露元数据；此处按名称排序。
  files.sort((a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));

  // 如果启用，文件夹优先
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.attr.isDirectory);
    final regular = files.where((f) => !f.attr.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### 文件元数据

`SftpClient.listdir` 返回 `SftpName` 条目。浏览器使用其 `filename`、`attr` 以及属性中
的 `size`、`modifyTime` 和 `isDirectory` 字段。已打开的 `SftpFile` 是用于流式读写的
独立句柄，使用后必须关闭。

## 文件操作

### 上传

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  final stagingPath = '$remotePath.sb-part-${nextTransferId()}';
  SftpFile? remote;
  String? pendingStagingPath = stagingPath;
  try {
    remote = await sftp.open(
      stagingPath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await remote.write(File(localPath).openRead().map(Uint8List.fromList)).done;
    await remote.close();
    remote = null;
    await sftp.rename(stagingPath, remotePath);
    pendingStagingPath = null;
  } finally {
    try {
      await remote?.close();
    } catch (_) {}
    if (pendingStagingPath != null) {
      try {
        await sftp.remove(pendingStagingPath!);
      } catch (_) {}
    }
  }
}
```

`nextTransferId()` 是进程级计数器。实际实现使用同样的计数器生成不同的
`.sb-part-<number>` 路径，即使两个传输指向同一个目标文件也不会互相覆盖。

客户端没有 `sftp.upload` 便捷方法。实际传输会打开 `SftpFile` 并显式关闭，先写入
目标旁边带唯一后缀的临时路径，并在重命名之前关闭句柄；打开、写入、关闭或重命名失败
时都会删除临时文件。新内容完成之前不会截断目标文件。

### 下载

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  SftpFile? remote;
  File? staging;
  IOSink? sink;
  try {
    remote = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    staging = File('$localPath.sb-part-${nextTransferId()}');
    sink = staging!.openWrite();
    await sink.addStream(remote.read());
    await sink.close();
    sink = null;
    await remote.close();
    remote = null;
    await staging!.rename(localPath);
  } finally {
    try {
      await remote?.close();
    } catch (_) {}
    try {
      await sink?.close();
    } catch (_) {}
    if (staging != null && await staging!.exists()) {
      try {
        await staging!.delete();
      } catch (_) {}
    }
  }
}
```

客户端也没有 `sftp.download` 便捷方法。读取通过已打开的 `SftpFile` 流式进行；远端
句柄和本地 sink 都必须显式关闭。内容先写入本地临时文件，关闭后才重命名覆盖目标；
失败时会删除临时文件，因此部分下载不会替换原文件。

### 权限编辑

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // 解析权限 (例如 "rwxr-xr-x" 或 "755")
  final mode = parsePermissions(permissions);

  // 通常通过 SFTP 的 set-stat 操作设置权限。
  await sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode)));
}
```

权限修改通常使用 SFTP `setStat`，不需要 shell。如果服务器拒绝该操作且存在
SSH 提权处理器，backend 才会用 `sudo chmod` 重试。这个回退需要 shell，并非普通的
SFTP 路径。

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

### 队列管理

App 并不使用固定三并发的 `TransferQueue`。传输由常驻的
`FileTransferNotifier` 中的 `FileTransferStatus` 表示；每个状态会拥有自己的 worker，
或直接在当前 isolate 中运行。notifier 通过这一生命周期提供添加、取消、进度、完成和清理。

## 本地存储模式

### 下载文件位置

下载的文件按服务器 id 和远程路径各级组件存储。组件会按本机平台进行清理，但目录结构
会保留：

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final parts = remotePath.split('/').where((part) => part.isNotEmpty);
  return parts.fold(
    Paths.file.joinPath(spiId),
    (path, part) => path.joinPath(_safeLocalPathPart(part)),
  );
}
```

示例：
- 远程：`/var/log/nginx/access.log`
- spiId：`server-123`
- 本地：`Paths.file/server-123/var/log/nginx/access.log`

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
Future<void> editInExternalEditor(String path, {bool useSudo = false}) async {
  final ssh = await getSshClient(spiId);

  // 使用编辑器打开终端
  final editor = getSetting('sftpEditor', 'vim');
  final command = '${useSudo ? 'sudo ' : ''}$editor ${shellSingleQuote(path)}';
  await ssh.exec(command);

  // 用户在终端中编辑
  // 保存后，刷新 SFTP 视图
}
```

## 错误处理

### 权限错误

```dart
try {
  await uploadFile(localPath, remotePath);
} on SftpPermissionException {
  showError('拒绝访问：${stat.path}');
  showHint('请检查文件权限和所有权');
}
```

### 连接错误

```dart
try {
  await sftp.listdir(path);
} on SftpStatusError {
  showError('连接丢失');
  await reconnect();
}
```

### 空间错误

```dart
try {
  await uploadFile(localPath, remotePath);
} on SftpStatusError {
  showError('远程服务器磁盘空间不足');
}
```

## 性能说明

- SFTP 复用现有 SSH 连接,不会另建连接。
- 目录列表在导航时获取，并按需刷新，不使用 TTL 缓存层。
- 大文件传输在后台 isolate 中执行，不阻塞 UI。
