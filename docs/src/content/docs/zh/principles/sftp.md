---
title: SFTP 和 SCP 文件传输
description: Server Box 如何浏览和传输远程文件
---

Server Box 通过 SSH 提供远程文件访问。默认使用 SFTP；对于不提供 SFTP subsystem、但支持 `scp` 和 shell 的设备，可以选择 SCP。

## 文件访问架构

```text
┌─────────────────────────────────────────────┐
│ 文件 UI 层                                   │
│ 远程文件浏览器、本地文件浏览器、传输队列      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 状态管理层                                   │
│ sftpProvider、路径管理、操作队列              │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ FileBackend                                  │
│ SFTP 或 SCP + shell                          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ SSH 传输层                                   │
│ 加密连接和数据流                             │
└─────────────────────────────────────────────┘
```

文件浏览器和传输引擎只依赖 `FileBackend`，不直接判断具体 backend class。SSH 连接建立后，`openSshFileBackend` 根据服务器的 `SshCredential.fileTransport` 选择 SFTP 或 SCP。

## SFTP

### 建立连接

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. 获取 SSH client；如果已有连接则复用
  final sshClient = await genClient(spi);

  // 2. 打开 SFTP subsystem
  final sftp = await sshClient.sftp();

  return sftp;
}
```

SFTP 与其他 SSH 功能共用同一 SSH 连接，但使用独立的 SFTP channel：

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

如果 SSH 连接成功但 SFTP subsystem 无法打开，App 会报告 SFTP 不可用。App 不会把任意 SFTP 连接失败都解释为“服务器没有 SFTP”，也不会自动切换到 SCP；你可以在服务器编辑页明确选择 SCP。

### 目录列表和元数据

```dart
Future<List<SftpName>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);
  final files = await sftp.listdir(path);

  files.sort((a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));
  if (showFoldersFirst) {
    final dirs = files.where((file) => file.attr.isDirectory);
    final regular = files.where((file) => !file.attr.isDirectory);
    return [...dirs, ...regular];
  }
  return files;
}
```

`SftpClient.listdir` 返回 `SftpName` 条目。浏览器使用 `filename` 和 `attr` 中的 `size`、`modifyTime`、`isDirectory` 等字段。用于流式读写的 `SftpFile` 是独立句柄，使用后必须关闭。

### 文件权限

```dart
Future<void> setPermissions(String path, String permissions) async {
  final sftp = await getSftpClient(spiId);
  final mode = parsePermissions(permissions);
  await sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode)));
}
```

权限修改通常通过 SFTP `setStat` 完成，不需要 shell。如果服务器拒绝该操作且已配置 SSH 提权，App 才会使用 `sudo chmod` 重试。这个回退需要 shell，不属于普通 SFTP protocol。

## SCP

SCP 适用于没有 SFTP subsystem、但有 shell 和 `scp` 命令的设备，例如某些运行 dropbear 的 OpenWrt 路由器或嵌入式系统。

SCP protocol 只负责传输单个文件的内容，不负责目录列表、stat、rename、mkdir 或权限管理。因此 `ScpFileBackend` 使用 `scp -f`/`scp -t` 读取和写入文件，其他操作使用 shell 命令。它通过 SSH channel 执行这些操作。

SCP 是服务器级别的明确选择，不会因为一次 SFTP 连接失败而自动启用。这样可以区分“服务器没有 SFTP”和“本次 SSH 连接或账户失败”。

## 上传和下载

### 上传

无论 SFTP 还是 SCP，App 都采用 staged write：先在目标旁边创建带唯一后缀的临时文件，完成写入并关闭句柄后，再 rename 到目标路径。

```dart
Future<void> uploadFile(String localPath, String remotePath) async {
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

实际实现使用进程级和 isolate 级的唯一 transfer ID，避免并行传输使用同一个临时文件。写入、关闭或 rename 失败时会清理临时文件；目标文件在新内容完成前不会被截断。

### 下载

下载也先写入本地临时文件，完整关闭文件后再 rename 覆盖目标：

```dart
Future<void> downloadFile(String remotePath, String localPath) async {
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

失败时清理临时文件，因此部分下载不会覆盖本地目标文件。

### 文件权限保持不变

替换已有文件时，App 会先读取目标文件的 POSIX permission bits，再将相同 mode 应用到 staged file。这样保存 0755 的脚本不会变成 0644，替换 0600 文件也不会因为远端 umask 而扩大可读范围。

权限复制是 best effort，不会因为服务器拒绝读取或设置 mode 而丢弃已经传输的内容。没有权限概念的 backend（例如 local backend）不会执行这一步。Monitor agent 的文件 API 也采用相同策略。

## 路径管理

文件 backend 的路径使用绝对 POSIX 风格路径。相对路径由当前目录解析。

```dart
class PathWithPrefix {
  final String prefix;  // 例如 "/home/user"
  final String path;    // 相对或绝对路径

  String get fullPath {
    if (path.startsWith('/')) return path;
    return '$prefix/$path';
  }

  PathWithPrefix cd(String subPath) => PathWithPrefix(
    prefix: fullPath,
    path: subPath,
  );
}
```

浏览器保存 back/forward 导航历史。进入新路径后，旧的 forward history 会被移除。

## 传输系统

传输由常驻的 `FileTransferNotifier` 管理，每个 `FileTransferStatus` 对应一个传输任务。任务可以使用独立 worker，也可以在当前 isolate 中执行。Notifier 负责添加、取消、报告进度、完成和清理。

大文件传输使用后台 isolate，避免阻塞 UI。传输队列不使用固定并发数的旧版 `TransferQueue`。

## 本地下载位置

下载文件按 server ID 和远程路径的各级组件保存，并在本地保持目录结构：

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final parts = remotePath.split('/').where((part) => part.isNotEmpty);
  return parts.fold(
    Paths.file.joinPath(spiId),
    (path, part) => path.joinPath(_safeLocalPathPart(part)),
  );
}
```

例如：

- 远程路径：`/var/log/nginx/access.log`
- Server ID：`server-123`
- 本地路径：`Paths.file/server-123/var/log/nginx/access.log`

## 文件编辑

内置编辑器的流程是：

1. 读取远程文件 metadata，检查文件大小。
2. 将文件下载到本地临时目录。
3. 在编辑器中打开临时文件。
4. 保存后，以 staged write 方式上传回原路径。
5. 删除临时文件。

超过编辑器大小限制的文件不会直接打开；可以使用外部编辑器，或在终端中执行编辑命令。

## 错误处理

- **权限错误**：检查远程文件的 owner、permission bits 和 SSH 用户；配置提权后可以重试 sudo 路径。
- **连接错误**：先检查 SSH 连接是否仍然有效，再重连；不要把连接中断误判为 SFTP subsystem 缺失。
- **SFTP 不可用**：在服务器编辑页将 file transport 改为 SCP，前提是服务器提供 `scp` 和 shell。
- **空间不足**：检查远程文件系统剩余空间。staged write 可能需要同时容纳旧文件和临时文件。

## 性能和限制

- SFTP 复用现有 SSH 连接，不会为每个文件操作重新建立 SSH connection。
- 目录列表在进入目录时获取，并按需刷新；不使用 TTL cache。
- SFTP 支持随机访问；SCP 的 `read` offset 通过本地丢弃开头字节实现，protocol 本身仍从文件开头传输。
- staged write 保证读者不会看到半写入文件，但网络超时后可能无法确定 rename 是否成功；App 不会自动重试结果未知的 rename。
