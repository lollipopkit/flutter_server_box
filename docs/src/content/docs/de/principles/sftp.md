---
title: SFTP-System
description: Wie der SFTP-Dateibrowser funktioniert
---

Das SFTP-System bietet Dateimanagement-Funktionen über SSH.

## Architektur

```
┌─────────────────────────────────────────────┐
│              SFTP UI Schicht                │
│  - Dateibrowser (remote)                    │
│  - Dateibrowser (lokal)                     │
│  - Transfer-Warteschlange                   │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          SFTP-Zustandsverwaltung            │
│  - sftpProvider                             │
│  - Pfadverwaltung                           │
│  - Operations-Warteschlange                 │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         SFTP-Protokollschicht               │
│  - SSH-Subsystem                            │
│  - Dateioperationen                         │
│  - Verzeichnisauflistung                    │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            SSH-Transport                    │
│  - Sicherer Kanal                           │
│  - Daten-Streaming                          │
└─────────────────────────────────────────────┘
```

## Verbindungsaufbau

### Erstellung des SFTP-Clients

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. SSH-Client abrufen (wiederverwenden, falls verfügbar)
  final sshClient = await genClient(spi);

  // 2. SFTP-Subsystem öffnen
  final sftp = await sshClient.openSftp();

  return sftp;
}
```

### Wiederverwendung von Verbindungen

SFTP verwendet bestehende SSH-Verbindungen wieder:

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

## Dateisystem-Operationen

### Verzeichnisauflistung

```dart
Future<List<SftpFile>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // Verzeichnis auflisten
  final files = await sftp.listDir(path);

  // Basierend auf Einstellungen sortieren
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

  // Ordner zuerst, falls aktiviert
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.isDirectory);
    final regular = files.where((f) => !f.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### Dateimetadaten

```dart
class SftpFile {
  final String name;
  final String path;
  final int size;           // Bytes
  final int modified;       // Unix-Zeitstempel
  final String permissions;  // z.B. "rwxr-xr-x"
  final String owner;
  final String group;
  final bool isDirectory;
  final bool isSymlink;

  String get sizeFormatted => formatBytes(size);
  String get modifiedFormatted => formatDate(modified);
}
```

## Dateioperationen

### Hochladen

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  // Anfrage erstellen
  final req = SftpReq(
    spi: spi,
    remotePath: remotePath,
    localPath: localPath,
    type: SftpReqType.upload,
  );

  // Zur Warteschlange hinzufügen
  _transferQueue.add(req);

  // Transfer mit Fortschritt ausführen
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

  // Fertigstellen
  _transferQueue.remove(req);
}
```

### Herunterladen

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  // Lokale Datei erstellen
  final file = File(localPath);
  final sink = file.openWrite();

  // Herunterladen mit Fortschritt
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

### Berechtigungen bearbeiten

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // Berechtigungen parsen (z.B. "rwxr-xr-x" oder "755")
  final mode = parsePermissions(permissions);

  // Über SSH-Befehl setzen (zuverlässiger als SFTP)
  final ssh = await getSshClient(spiId);
  await ssh.exec('chmod $mode "$path"');
}
```

## Pfadverwaltung

### Pfadstruktur

```dart
class PathWithPrefix {
  final String prefix;  // z.B. "/home/user"
  final String path;    // Relativ oder absolut

  String get fullPath {
    if (path.startsWith('/')) {
      return path;  // Absoluter Pfad
    }
    return '$prefix/$path';  // Relativer Pfad
  }

  PathWithPrefix cd(String subPath) {
    return PathWithPrefix(
      prefix: fullPath,
      path: subPath,
    );
  }
}
```

### Navigationsverlauf

```dart
class PathHistory {
  final List<String> _history = [];
  int _index = -1;

  void push(String path) {
    // Vorwärtsverlauf entfernen
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

## Transfersystem

### Transfer-Anfrage

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

### Fortschrittsverfolgung

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

### Warteschlangen-Management

```dart
class TransferQueue {
  final List<SftpReq> _queue = [];
  final Map<String, TransferProgress> _progress = {};
  int _concurrent = 3;  // Max. gleichzeitige Transfers

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

## Lokales Speichermuster

### Download-Cache

Heruntergeladene Dateien werden gespeichert unter:

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final normalized = remotePath.replaceAll('/', '_');
  return 'Paths.file/$spiId/$normalized';
}
```

Beispiel:
- Remote: `/var/log/nginx/access.log`
- spiId: `server-123`
- Lokal: `Paths.file/server-123/_var_log_nginx_access.log`

## Dateibearbeitung

### Bearbeitungs-Workflow

```dart
Future<void> editFile(String path) async {
  final sftp = await getSftpClient(spiId);

  // 1. Größe prüfen
  final stat = await sftp.stat(path);
  if (stat.size > editorMaxSize) {
    showWarning('Datei zu groß für den integrierten Editor');
    return;
  }

  // 2. Temporär herunterladen
  final temp = await downloadToTemp(path);

  // 3. Im Editor öffnen
  final content = await openEditor(temp.path);

  // 4. Zurück hochladen
  await uploadFile(temp.path, path);

  // 5. Aufräumen
  await temp.delete();
}
```

### Integration externer Editoren

```dart
Future<void> editInExternalEditor(String path) async {
  final ssh = await getSshClient(spiId);

  // Terminal mit Editor öffnen
  final editor = getSetting('sftpEditor', 'vim');
  await ssh.exec('$editor "$path"');

  // Benutzer bearbeitet im Terminal
  // Nach dem Speichern die SFTP-Ansicht aktualisieren
}
```

## Fehlerbehandlung

### Berechtigungsfehler

```dart
try {
  await sftp.upload(...);
} on SftpPermissionException {
  showError('Berechtigung verweigert: ${stat.path}');
  showHint('Prüfen Sie Dateiberechtigungen und Eigentümerschaft');
}
```

### Verbindungsfehler

```dart
try {
  await sftp.listDir(path);
} on SftpConnectionException {
  showError('Verbindung verloren');
  await reconnect();
}
```

### Speicherplatzfehler

```dart
try {
  await sftp.upload(...);
} on SftpNoSpaceException {
  showError('Festplatte auf dem Remote-Server voll');
}
```

## Leistungsoptimierungen

### Verzeichnis-Caching

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

Für große Verzeichnisse (>1000 Einträge):

```dart
List<SftpFile> loadPage(String path, int page, int pageSize) {
  final all = cache[path] ?? [];
  final start = page * pageSize;
  final end = start + pageSize;
  return all.sublist(start, end.clamp(0, all.length));
}
```

### Paginierung

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
