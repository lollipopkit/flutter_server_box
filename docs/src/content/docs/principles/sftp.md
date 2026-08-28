---
title: SFTP and SCP File Transfer
description: How Server Box browses and transfers remote files
---

Server Box provides remote file access over SSH. SFTP is the default. SCP can be selected for devices that do not provide an SFTP subsystem but do provide `scp` and a shell.

## File access architecture

```text
┌─────────────────────────────────────────────┐
│ File UI layer                                │
│ Remote browser, local browser, transfer queue│
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ State management                             │
│ sftpProvider, paths, operation queue         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ FileBackend                                  │
│ SFTP or SCP + shell                          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ SSH transport                               │
│ Encrypted connection and byte streams        │
└─────────────────────────────────────────────┘
```

The file browser and transfer engine depend on `FileBackend` rather than a concrete backend class. After the SSH connection is established, `openSshFileBackend` selects SFTP or SCP from `SshCredential.fileTransport`.

## SFTP

### Establishing a client

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. Get the SSH client; reuse an existing connection when available.
  final sshClient = await genClient(spi);

  // 2. Open the SFTP subsystem.
  final sftp = await sshClient.sftp();

  return sftp;
}
```

SFTP shares the underlying SSH connection with other SSH features, but uses its own channel:

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

If SSH connects but the SFTP subsystem cannot be opened, the App reports that SFTP is unavailable. It does not interpret every SFTP failure as proof that the server lacks the subsystem, and it does not silently switch to SCP. Select SCP explicitly in the server editor.

### Directory listings and metadata

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

`SftpClient.listdir` returns `SftpName` entries. The browser uses `filename` and attributes such as `size`, `modifyTime`, and `isDirectory`. An opened `SftpFile` is a separate handle for streaming reads and writes and must be closed when finished.

### File permissions

```dart
Future<void> setPermissions(String path, String permissions) async {
  final sftp = await getSftpClient(spiId);
  final mode = parsePermissions(permissions);
  await sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode)));
}
```

Permission changes normally use SFTP `setStat` and do not require a shell. If the server refuses the operation and SSH escalation is configured, the backend can retry with `sudo chmod`. That fallback requires a shell and is not part of the normal SFTP path.

## SCP

SCP is intended for hosts without an SFTP subsystem but with a shell and an `scp` command, such as some OpenWrt routers running dropbear or other embedded systems.

The SCP protocol transfers the contents of one file. It does not list directories or provide stat, rename, mkdir, or permission operations. `ScpFileBackend` therefore uses `scp -f`/`scp -t` for reads and writes, and shell commands for the other operations, each through an SSH channel.

SCP is an explicit per-server choice. A failed SFTP connection does not automatically enable it, because that would confuse a missing subsystem with a failed SSH connection or locked account.

## Uploads and downloads

### Uploads

Both SFTP and SCP use a staged write: create a uniquely named temporary file beside the destination, finish the transfer and close the handle, then rename the temporary file into place.

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

The implementation uses unique transfer IDs across the process and each isolate, so concurrent transfers cannot use the same staging file. Failed writes, closes, and renames clean up the staging file; the destination is not truncated before the new contents are complete.

### Downloads

Downloads also use a local staging file and rename it over the destination only after the complete file has been received and closed:

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

If a download fails, its staging file is removed, so partial content cannot replace the local destination.

### Preserving permissions

When replacing an existing file, the App reads its POSIX permission bits and applies the same mode to the staging file. Saving a `0755` script therefore does not change it to `0644`, and replacing a `0600` file does not make it more readable because of the remote umask.

Permission copying is best effort. A server that will not report or set a mode does not cause already transferred contents to be discarded. Backends without a permission model, such as the local backend, skip this step. Monitor agent's file API follows the same policy.

## Path management

File backend paths use absolute POSIX-style paths. Relative paths are resolved against the current directory.

```dart
class PathWithPrefix {
  final String prefix;  // e.g. "/home/user"
  final String path;    // Relative or absolute

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

The browser maintains back/forward navigation history. Entering a new path removes the old forward history.

## Transfer system

Transfers are managed by the keep-alive `FileTransferNotifier`. Each `FileTransferStatus` represents one transfer task. A task can use its own worker or run in the current isolate; the notifier manages adding, cancellation, progress, completion, and cleanup.

Large transfers use a background isolate so they do not block the UI. The transfer system does not use the old fixed-concurrency `TransferQueue`.

## Local download location

Downloaded files are stored using the server ID and each component of the remote path, while retaining the directory structure locally:

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final parts = remotePath.split('/').where((part) => part.isNotEmpty);
  return parts.fold(
    Paths.file.joinPath(spiId),
    (path, part) => path.joinPath(_safeLocalPathPart(part)),
  );
}
```

For example:

- Remote path: `/var/log/nginx/access.log`
- Server ID: `server-123`
- Local path: `Paths.file/server-123/var/log/nginx/access.log`

## File editing

The built-in editor follows this workflow:

1. Read remote metadata and check the file size.
2. Download the file to a local temporary directory.
3. Open the temporary file in the editor.
4. Upload it back to the original path with a staged write after saving.
5. Delete the temporary file.

Files over the editor's size limit are not opened directly. Use an external editor or edit them from a terminal instead.

## Error handling

- **Permission errors**: Check the remote owner, permission bits, and SSH user. If configured, retry through the sudo escalation path.
- **Connection errors**: Check whether the SSH connection is still valid before reconnecting. Do not treat a dropped connection as evidence that SFTP is unavailable.
- **SFTP unavailable**: Change the server's file transport to SCP, provided the host has `scp` and a shell.
- **Insufficient space**: Check free space on the remote filesystem. A staged write may need room for both the existing file and the temporary file.

## Performance and limitations

- SFTP reuses the existing SSH connection and does not establish a new connection for every file operation.
- Directory listings are fetched when entering a directory and refreshed on demand; there is no TTL cache.
- SFTP supports random access. SCP implements `read` offsets by discarding the initial bytes locally, so the protocol still transfers from the beginning.
- A staged write prevents readers from seeing a partially written file, but a network timeout can leave the result of a rename unknown. The App does not automatically retry a rename whose result is unknown.
