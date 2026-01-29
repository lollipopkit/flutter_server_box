---
title: Sistema SFTP
description: Cómo funciona el explorador de archivos SFTP
---

El sistema SFTP proporciona capacidades de gestión de archivos sobre SSH.

## Arquitectura

```
┌─────────────────────────────────────────────┐
│              Capa UI de SFTP                │
│  - Explorador de archivos (remoto)          │
│  - Explorador de archivos (local)           │
│  - Cola de transferencia                    │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          Gestión de Estado SFTP             │
│  - sftpProvider                             │
│  - Gestión de rutas                         │
│  - Cola de operaciones                      │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         Capa de Protocolo SFTP              │
│  - Subsistema SSH                           │
│  - Operaciones de archivos                  │
│  - Listado de directorios                   │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            Transporte SSH                   │
│  - Canal seguro                             │
│  - Streaming de datos                       │
└─────────────────────────────────────────────┘
```

## Establecimiento de la Conexión

### Creación del Cliente SFTP

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. Obtener cliente SSH (reutilizar si está disponible)
  final sshClient = await genClient(spi);

  // 2. Abrir subsistema SFTP
  final sftp = await sshClient.openSftp();

  return sftp;
}
```

### Reutilización de Conexiones

SFTP reutiliza las conexiones SSH existentes:

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

## Operaciones del Sistema de Archivos

### Listado de Directorios

```dart
Future<List<SftpFile>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // Listar directorio
  final files = await sftp.listDir(path);

  // Ordenar según ajustes
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

  // Carpetas primero si está activado
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.isDirectory);
    final regular = files.where((f) => !f.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### Metadatos de Archivo

```dart
class SftpFile {
  final String name;
  final String path;
  final int size;           // Bytes
  final int modified;       // Timestamp Unix
  final String permissions;  // ej., "rwxr-xr-x"
  final String owner;
  final String group;
  final bool isDirectory;
  final bool isSymlink;

  String get sizeFormatted => formatBytes(size);
  String get modifiedFormatted => formatDate(modified);
}
```

## Operaciones de Archivo

### Subida (Upload)

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  // Crear petición
  final req = SftpReq(
    spi: spi,
    remotePath: remotePath,
    localPath: localPath,
    type: SftpReqType.upload,
  );

  // Añadir a la cola
  _transferQueue.add(req);

  // Ejecutar transferencia con progreso
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

  // Completar
  _transferQueue.remove(req);
}
```

### Descarga (Download)

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  // Crear archivo local
  final file = File(localPath);
  final sink = file.openWrite();

  // Descargar con progreso
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

### Edición de Permisos

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // Analizar permisos (ej., "rwxr-xr-x" o "755")
  final mode = parsePermissions(permissions);

  // Establecer vía comando SSH (más fiable que SFTP)
  final ssh = await getSshClient(spiId);
  await ssh.exec('chmod $mode "$path"');
}
```

## Gestión de Rutas

### Estructura de Rutas

```dart
class PathWithPrefix {
  final String prefix;  // ej., "/home/user"
  final String path;    // Relativa o absoluta

  String get fullPath {
    if (path.startsWith('/')) {
      return path;  // Ruta absoluta
    }
    return '$prefix/$path';  // Ruta relativa
  }

  PathWithPrefix cd(String subPath) {
    return PathWithPrefix(
      prefix: fullPath,
      path: subPath,
    );
  }
}
```

### Historial de Navegación

```dart
class PathHistory {
  final List<String> _history = [];
  int _index = -1;

  void push(String path) {
    // Eliminar historial hacia adelante
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

## Sistema de Transferencia

### Petición de Transferencia

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

### Seguimiento de Progreso

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

### Gestión de Colas

```dart
class TransferQueue {
  final List<SftpReq> _queue = [];
  final Map<String, TransferProgress> _progress = {};
  int _concurrent = 3;  // Transferencias concurrentes máx.

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

## Patrón de Almacenamiento Local

### Caché de Descargas

Los archivos descargados se guardan en:

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final normalized = remotePath.replaceAll('/', '_');
  return 'Paths.file/$spiId/$normalized';
}
```

Ejemplo:
- Remoto: `/var/log/nginx/access.log`
- spiId: `server-123`
- Local: `Paths.file/server-123/_var_log_nginx_access.log`

## Edición de Archivos

### Flujo de Trabajo de Edición

```dart
Future<void> editFile(String path) async {
  final sftp = await getSftpClient(spiId);

  // 1. Comprobar tamaño
  final stat = await sftp.stat(path);
  if (stat.size > editorMaxSize) {
    showWarning('Archivo demasiado grande para el editor integrado');
    return;
  }

  // 2. Descargar a temporal
  final temp = await downloadToTemp(path);

  // 3. Abrir en editor
  final content = await openEditor(temp.path);

  // 4. Subir de nuevo
  await uploadFile(temp.path, path);

  // 5. Limpieza
  await temp.delete();
}
```

### Integración con Editor Externo

```dart
Future<void> editInExternalEditor(String path) async {
  final ssh = await getSshClient(spiId);

  // Abrir terminal con editor
  final editor = getSetting('sftpEditor', 'vim');
  await ssh.exec('$editor "$path"');

  // El usuario edita en la terminal
  // Tras guardar, refrescar la vista SFTP
}
```

## Gestión de Errores

### Errores de Permiso

```dart
try {
  await sftp.upload(...);
} on SftpPermissionException {
  showError('Permiso denegado: ${stat.path}');
  showHint('Comprueba los permisos y la propiedad del archivo');
}
```

### Erreores de Conexión

```dart
try {
  await sftp.listDir(path);
} on SftpConnectionException {
  showError('Conexión perdida');
  await reconnect();
}
```

### Errores de Espacio

```dart
try {
  await sftp.upload(...);
} on SftpNoSpaceException {
  showError('Disco lleno en el servidor remoto');
}
```

## Optimizaciones de Rendimiento

### Caché de Directorios

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

### Carga Perezosa (Lazy Loading)

Para directorios grandes (>1000 elementos):

```dart
List<SftpFile> loadPage(String path, int page, int pageSize) {
  final all = cache[path] ?? [];
  final start = page * pageSize;
  final end = start + pageSize;
  return all.sublist(start, end.clamp(0, all.length));
}
```

### Paginación

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
