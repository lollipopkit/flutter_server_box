---
title: Système SFTP
description: Comment fonctionne le navigateur de fichiers SFTP
---

Le système SFTP fournit des capacités de gestion de fichiers via SSH.

## Architecture

```
┌─────────────────────────────────────────────┐
│              Couche UI SFTP                 │
│  - Navigateur de fichiers (distant)         │
│  - Navigateur de fichiers (local)           │
│  - File d'attente de transfert              │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          Gestion de l'état SFTP             │
│  - sftpProvider                             │
│  - Gestion des chemins                      │
│  - File d'attente d'opérations              │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         Couche protocole SFTP               │
│  - Sous-système SSH                         │
│  - Opérations sur les fichiers              │
│  - Liste des répertoires                    │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            Transport SSH                    │
│  - Canal sécurisé                           │
│  - Streaming de données                     │
└─────────────────────────────────────────────┘
```

## Établissement de la connexion

### Création du client SFTP

```dart
Future<SftpClient> createSftpClient(Spi spi) async {
  // 1. Obtenir le client SSH (réutiliser si disponible)
  final sshClient = await genClient(spi);

  // 2. Ouvrir le sous-système SFTP
  final sftp = await sshClient.openSftp();

  return sftp;
}
```

### Réutilisation de la connexion

SFTP réutilise les connexions SSH existantes :

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

## Opérations du système de fichiers

### Liste des répertoires

```dart
Future<List<SftpFile>> listDirectory(String path) async {
  final sftp = await getSftpClient(spiId);

  // Lister le répertoire
  final files = await sftp.listDir(path);

  // Trier selon les paramètres
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

  // Dossiers en premier si activé
  if (showFoldersFirst) {
    final dirs = files.where((f) => f.isDirectory);
    final regular = files.where((f) => !f.isDirectory);
    return [...dirs, ...regular];
  }

  return files;
}
```

### Métadonnées de fichiers

```dart
class SftpFile {
  final String name;
  final String path;
  final int size;           // Octets
  final int modified;       // Horodatage Unix
  final String permissions;  // ex: "rwxr-xr-x"
  final String owner;
  final String group;
  final bool isDirectory;
  final bool isSymlink;

  String get sizeFormatted => formatBytes(size);
  String get modifiedFormatted => formatDate(modified);
}
```

## Opérations sur les fichiers

### Téléversement (Upload)

```dart
Future<void> uploadFile(
  String localPath,
  String remotePath,
) async {
  final sftp = await getSftpClient(spiId);

  // Créer la requête
  final req = SftpReq(
    spi: spi,
    remotePath: remotePath,
    localPath: localPath,
    type: SftpReqType.upload,
  );

  // Ajouter à la file d'attente
  _transferQueue.add(req);

  // Exécuter le transfert avec progression
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

  // Terminé
  _transferQueue.remove(req);
}
```

### Téléchargement (Download)

```dart
Future<void> downloadFile(
  String remotePath,
  String localPath,
) async {
  final sftp = await getSftpClient(spiId);

  // Créer le fichier local
  final file = File(localPath);
  final sink = file.openWrite();

  // Télécharger avec progression
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

### Édition des permissions

```dart
Future<void> setPermissions(
  String path,
  String permissions,
) async {
  final sftp = await getSftpClient(spiId);

  // Analyser les permissions (ex: "rwxr-xr-x" ou "755")
  final mode = parsePermissions(permissions);

  // Définir via commande SSH (plus fiable que SFTP)
  final ssh = await getSshClient(spiId);
  await ssh.exec('chmod $mode "$path"');
}
```

## Gestion des chemins

### Structure de chemin

```dart
class PathWithPrefix {
  final String prefix;  // ex: "/home/user"
  final String path;    // Relatif ou absolu

  String get fullPath {
    if (path.startsWith('/')) {
      return path;  // Chemin absolu
    }
    return '$prefix/$path';  // Chemin relatif
  }

  PathWithPrefix cd(String subPath) {
    return PathWithPrefix(
      prefix: fullPath,
      path: subPath,
    );
  }
}
```

### Historique de navigation

```dart
class PathHistory {
  final List<String> _history = [];
  int _index = -1;

  void push(String path) {
    // Supprimer l'historique suivant
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

## Système de transfert

### Requête de transfert

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

### Suivi de progression

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

### Gestion de la file d'attente

```dart
class TransferQueue {
  final List<SftpReq> _queue = [];
  final Map<String, TransferProgress> _progress = {};
  int _concurrent = 3;  // Nombre max de transferts simultanés

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

## Modèle de stockage local

### Cache de téléchargement

Fichiers téléchargés stockés sur :

```dart
String getLocalDownloadPath(String spiId, String remotePath) {
  final normalized = remotePath.replaceAll('/', '_');
  return 'Paths.file/$spiId/$normalized';
}
```

Exemple :
- Distant : `/var/log/nginx/access.log`
- spiId : `server-123`
- Local : `Paths.file/server-123/_var_log_nginx_access.log`

## Édition de fichiers

### Flux d'édition

```dart
Future<void> editFile(String path) async {
  final sftp = await getSftpClient(spiId);

  // 1. Vérifier la taille
  final stat = await sftp.stat(path);
  if (stat.size > editorMaxSize) {
    showWarning('Fichier trop volumineux pour l\'éditeur intégré');
    return;
  }

  // 2. Télécharger vers dossier temp
  final temp = await downloadToTemp(path);

  // 3. Ouvrir dans l'éditeur
  final content = await openEditor(temp.path);

  // 4. Téléverser en retour
  await uploadFile(temp.path, path);

  // 5. Nettoyage
  await temp.delete();
}
```

### Intégration d'un éditeur externe

```dart
Future<void> editInExternalEditor(String path) async {
  final ssh = await getSshClient(spiId);

  // Ouvrir le terminal avec l'éditeur
  final editor = getSetting('sftpEditor', 'vim');
  await ssh.exec('$editor "$path"');

  // L'utilisateur édite dans le terminal
  // Après sauvegarde, rafraîchir la vue SFTP
}
```

## Gestion des erreurs

### Erreurs de permission

```dart
try {
  await sftp.upload(...);
} on SftpPermissionException {
  showError('Permission refusée : ${stat.path}');
  showHint('Vérifiez les permissions et la propriété du fichier');
}
```

### Erreurs de connexion

```dart
try {
  await sftp.listDir(path);
} on SftpConnectionException {
  showError('Connexion perdue');
  await reconnect();
}
```

### Erreurs d'espace disque

```dart
try {
  await sftp.upload(...);
} on SftpNoSpaceException {
  showError('Disque plein sur le serveur distant');
}
```

## Optimisations de performance

### Cache de répertoire

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

### Chargement différé (Lazy Loading)

Pour les répertoires volumineux (>1000 éléments) :

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
