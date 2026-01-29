---
title: SFTP システム
description: SFTP ファイルブラウザの仕組み
---

SFTP システムは、SSH を介したファイル管理機能を提供します。

## アーキテクチャ

```
┌─────────────────────────────────────────────┐
│              SFTP UI レイヤー               │
│  - ファイルブラウザ (リモート)              │
│  - ファイルブラウザ (ローカル)              │
│  - 転送キュー                               │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SFTP 状態管理                      │
│  - sftpProvider                             │
│  - パス管理                                 │
│  - 操作キュー                               │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         SFTP プロトコルレイヤー             │
│  - SSH サブシステム                         │
│  - ファイル操作                             │
│  - ディレクトリ一覧取得                     │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            SSH 転送                         │
│  - セキュアチャネル                         │
│  - データストリーミング                     │
└─────────────────────────────────────────────┘
```

## 接続の確立

### SFTP クライアントの作成

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. SSH クライアントを取得 (利用可能な場合は再利用)
  final sshClient = await genClient(spi);

  // 2. SFTP サブシステムを開く
  final sftp = await sshClient.openSftp();

  return sftp;
}
```

### 接続の再利用

SFTP は既存の SSH 接続を再利用します。

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

## ファイルシステム操作

### ディレクトリ一覧取得

```dart
Future<List<SftpFile>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // ディレクトリ一覧を取得
  final files = await sftp.listDir(path);

  // 設定に基づいてソート
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

  // 設定されている場合はフォルダを先に表示
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.isDirectory);
    final regular = files.where((f) => !f.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### ファイルメタデータ

```dart
class SftpFile {
  final String name;
  final String path;
  final int size;           // バイト
  final int modified;       // Unix タイムスタンプ
  final String permissions;  // 例: "rwxr-xr-x"
  final String owner;
  final String group;
  final bool isDirectory;
  final bool isSymlink;

  String get sizeFormatted => formatBytes(size);
  String get modifiedFormatted => formatDate(modified);
}
```

## ファイル操作

### アップロード

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  // リクエストを作成
  final req = SftpReq(
    spi: spi,
    remotePath: remotePath,
    localPath: localPath,
    type: SftpReqType.upload,
  );

  // キューに追加
  _transferQueue.add(req);

  // プログレス付きで転送を実行
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

  // 完了
  _transferQueue.remove(req);
}
```

### ダウンロード

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  // ローカルファイルを作成
  final file = File(localPath);
  final sink = file.openWrite();

  // プログレス付きでダウンロード
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

### 権限の編集

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // 権限をパース (例: "rwxr-xr-x" または "755")
  final mode = parsePermissions(permissions);

  // SSH コマンド経由で設定 (SFTP より信頼性が高い)
  final ssh = await getSshClient(spiId);
  await ssh.exec('chmod $mode "$path"');
}
```

## パス管理

### パス構造

```dart
class PathWithPrefix {
  final String prefix;  // 例: "/home/user"
  final String path;    // 相対パスまたは絶対パス

  String get fullPath {
    if (path.startsWith('/')) {
      return path;  // 絶対パス
    }
    return '$prefix/$path';  // 相対パス
  }

  PathWithPrefix cd(String subPath) {
    return PathWithPrefix(
      prefix: fullPath,
      path: subPath,
    );
  }
}
```

### ナビゲーション履歴

```dart
class PathHistory {
  final List<String> _history = [];
  int _index = -1;

  void push(String path) {
    // 前方の履歴を削除
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

## 転送システム

### 転送リクエスト

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

### プログレス追跡

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

### キュー管理

```dart
class TransferQueue {
  final List<SftpReq> _queue = [];
  final Map<String, TransferProgress> _progress = {};
  int _concurrent = 3;  // 最大同時転送数

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

## ローカルストレージパターン

### ダウンロードキャッシュ

ダウンロードされたファイルは以下に保存されます。

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final normalized = remotePath.replaceAll('/', '_');
  return 'Paths.file/$spiId/$normalized';
}
```

例:
- リモート: `/var/log/nginx/access.log`
- spiId: `server-123`
- ローカル: `Paths.file/server-123/_var_log_nginx_access.log`

## ファイル編集

### 編集ワークフロー

```dart
Future<void> editFile(String path) async {
  final sftp = await getSftpClient(spiId);

  // 1. サイズチェック
  final stat = await sftp.stat(path);
  if (stat.size > editorMaxSize) {
    showWarning('ファイルが大きすぎるため、内蔵エディタで開けません');
    return;
  }

  // 2. 一時ディレクトリにダウンロード
  final temp = await downloadToTemp(path);

  // 3. エディタで開く
  final content = await openEditor(temp.path);

  // 4. アップロードして戻す
  await uploadFile(temp.path, path);

  // 5. クリーンアップ
  await temp.delete();
}
```

### 外部エディタとの統合

```dart
Future<void> editInExternalEditor(String path) async {
  final ssh = await getSshClient(spiId);

  // エディタを使用してターミナルを開く
  final editor = getSetting('sftpEditor', 'vim');
  await ssh.exec('$editor "$path"');

  // ユーザーがターミナルで編集
  // 保存後、SFTP ビューを更新
}
```

## エラーハンドリング

### 権限エラー

```dart
try {
  await sftp.upload(...);
} on SftpPermissionException {
  showError('アクセスが拒否されました: ${stat.path}');
  showHint('ファイルの権限と所有者を確認してください');
}
```

### 接続エラー

```dart
try {
  await sftp.listDir(path);
} on SftpConnectionException {
  showError('接続が失われました');
  await reconnect();
}
```

### スペースエラー

```dart
try {
  await sftp.upload(...);
} on SftpNoSpaceException {
  showError('リモートサーバーのディスク容量が不足しています');
}
```

## パフォーマンスの最適化

### ディレクトリキャッシュ

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

### レイジーロード

巨大なディレクトリ (>1000 アイテム) の場合:

```dart
List<SftpFile> loadPage(String path, int page, int pageSize) {
  final all = cache[path] ?? [];
  final start = page * pageSize;
  final end = start + pageSize;
  return all.sublist(start, end.clamp(0, all.length));
}
```

### ページネーション

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
