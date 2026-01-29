---
title: Data Persistence
description: How data is stored and managed
---

Understanding data persistence in Flutter Server Box.

## Storage Technology Stack

### Hive CE (Community Edition)

**Why Hive CE?**
- No native code dependencies
- Fast key-value storage
- Type-safe with code generation
- No manual field annotations needed
- Cross-platform support

**Comparison with standard Hive:**
- No `@HiveField()` annotations required
- No `@HiveType()` annotations required
- Automatic adapter generation
- Simpler API

## Storage Architecture

```
┌─────────────────────────────────────────────┐
│          Application Layer                  │
│  - UI, Business Logic                       │
└─────────────────────────────────────────────┘
                ↓ reads/writes
┌─────────────────────────────────────────────┐
│          Store Layer                        │
│  - SettingStore                             │
│  - ServerStore                              │
│  - SnippetStore                             │
│  - KeyStore                                 │
└─────────────────────────────────────────────┘
                ↓ uses
┌─────────────────────────────────────────────┐
│          Hive Box Layer                     │
│  - Type-safe boxes                          │
│  - Generated adapters                       │
└─────────────────────────────────────────────┘
                ↓ stores
┌─────────────────────────────────────────────┐
│          Physical Storage                   │
│  - iOS: NSUserDefaults / Files              │
│  - Android: SharedPreferences / Files       │
│  - Desktop: Local files                     │
└─────────────────────────────────────────────┘
```

## Store Classes

### SettingStore

App-level preferences:

```dart
class SettingStore {
  // Theme
  static final themeMode = propertyDefault<ThemeMode>(...);
  static final language = propertyDefault<String>(...);

  // SSH
  static final sshTimeout = propertyDefault<int>(...);
  static final sshKnownHostsFingerprints = listProperty<String>(...);

  // Terminal
  static final termFontSize = propertyDefault<double>(...);
  static final sshVirtualKeyAutoOff = propertyDefault<bool>(...);

  // SFTP
  static final sftpShowFoldersFirst = propertyDefault<bool>(...);
  static final sftpOpenLastPath = propertyDefault<bool>(...);

  // Editor
  static final closeAfterSave = propertyDefault<bool>(...);
  static final editorSoftWrap = propertyDefault<bool>(...);

  // Platform-specific
  static final bioAuth = propertyDefault<bool>(...);
  static final backgroundRunning = propertyDefault<bool>(...);

  // 60+ properties total
}
```

### ServerStore

Server configurations:

```dart
class ServerStore {
  static final servers = listProperty<Server>('servers');

  static void addServer(Server server) {
    servers.value = [...servers.value, server];
  }

  static void removeServer(String id) {
    servers.value = servers.value.where((s) => s.id != id).toList();
  }

  static Server? getServer(String id) {
    return servers.value.firstWhereOrNull((s) => s.id == id);
  }
}
```

### SnippetStore

Command snippets:

```dart
class SnippetStore {
  static final snippets = listProperty<Snippet>('snippets');

  static void addSnippet(Snippet snippet) {
    snippets.value = [...snippets.value, snippet];
  }

  static List<Snippet> getSnippetsForTag(String tag) {
    return snippets.value
        .where((s) => s.tags.contains(tag))
        .toList();
  }
}
```

### KeyStore

SSH keys (encrypted):

```dart
class KeyStore {
  static final keys = listProperty<StoredKey>('keys');

  static Future<void> addKey(String name, String pem, String? password) async {
    final encrypted = await encryptPem(pem, password);
    final key = StoredKey(
      id: generateId(),
      name: name,
      encryptedPem: encrypted,
    );
    keys.value = [...keys.value, key];
  }

  static Future<String> decryptKey(StoredKey key) async {
    final password = await getPasswordFromUser();  // Biometric/prompt
    return await decyptPem(key.encryptedPem, password);
  }
}
```

## Property Types

### propertyDefault<T>

Simple properties with defaults:

```dart
static final themeMode = propertyDefault<ThemeMode>(
  'theme_mode',
  defaultValue: ThemeMode.system,
);

// Usage
final theme = SettingStore.themeMode.value;
SettingStore.themeMode.value = ThemeMode.dark;
```

### listProperty<T>

List properties:

```dart
static final servers = listProperty<Server>('servers');

// Usage
final serverList = ServerStore.servers.value;
ServerStore.servers.value = [...serverList, newServer];
```

### SecureProp

Encrypted properties for sensitive data:

```dart
static final passwords = SecureProp<List<Password>>('passwords');

// Auto-encrypted before storage
// Decrypted on access with biometric
```

## Data Models

### Immutable Models with Freezed

```dart
@freezed
class Server with _$Server {
  const factory Server({
    required String id,
    required String name,
    required String ip,
    required int port,
    required String user,
    String? pwd,  // Encrypted
    String? keyId,
    String? jumpId,
    String? alterUrl,
  }) = _Server;

  factory Server.fromJson(Map<String, dynamic> json) =>
      _$ServerFromJson(json);
}
```

### Hive Integration

With `hive_ce`, no manual adapters needed:

```dart
// Just register the type
Hive.registerType<Server>(ServerTypeId);

// Store automatically
final box = await Hive.openBox<Server>('servers');
await box.put('server1', myServer);
```

## Encryption

### Password Storage

```dart
class SecureStorage {
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> setPassword(String serverId, String password) async {
    await _secureStorage.write(
      key: 'pwd_$serverId',
      value: password,
    );
  }

  static Future<String?> getPassword(String serverId) async {
    return await _secureStorage.read(key: 'pwd_$serverId');
  }
}
```

### SSH Key Encryption

```dart
Future<String> encryptPem(String pem, String? password) async {
  if (password == null) return pem;

  // Generate key from device
  final key = await _getEncryptionKey();

  // Encrypt with AES
  final encrypted = await encrypt(pem, key);

  return encrypted;
}

Future<String> decryptPem(String encrypted, String password) async {
  // Verify password (biometric)
  await _verifyUser();

  // Decrypt
  final key = await _getEncryptionKey();
  return await decrypt(encrypted, key);
}
```

## Initialization

### Hive Initialization

```dart
Future<void> initHive() async {
  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters (auto-generated)
  Hive.registerType<Server>(ServerTypeId);
  Hive.registerType<Snippet>(SnippetTypeId);
  Hive.registerType<StoredKey>(StoredKeyTypeId);

  // Open boxes
  await Hive.openBox<Server>('servers');
  await Hive.openBox<Snippet>('snippets');
  await Hive.openBox<StoredKey>('keys');
  await Hive.openBox<dynamic>('settings');

  // Initialize stores
  await SettingStore.init();
  await ServerStore.init();
  await SnippetStore.init();
  await KeyStore.init();
}
```

## Data Migration

### Version Migration

```dart
class StoreMigration {
  static const int currentVersion = 2;

  static Future<void> migrate() async {
    final version = _getStoredVersion();

    if (version < 2) {
      await _migrateToV2();
    }

    _setVersion(currentVersion);
  }

  static Future<void> _migrateToV2() async {
    // Migrate old data format
    final oldBox = await Hive.openBox('old_data');
    final newBox = await Hive.openBox('new_data');

    // Transform and copy
    for (final key in oldBox.keys) {
      final oldData = oldBox.get(key);
      final newData = _transform(oldData);
      await newBox.put(key, newData);
    }

    await oldBox.clear();
  }
}
```

## Backup & Restore

### Export

```dart
Future<Map<String, dynamic>> exportData() async {
  return {
    'version': currentVersion,
    'timestamp': DateTime.now().toIso8601String(),
    'servers': ServerStore.servers.value.map((s) => s.toJson()).toList(),
    'snippets': SnippetStore.snippets.value.map((s) => s.toJson()).toList(),
    'settings': _exportSettings(),
  };
}
```

### Import

```dart
Future<void> importData(Map<String, dynamic> data) async {
  final version = data['version'] as int;

  // Migrate if needed
  final migrated = await _migrateIfNeeded(data, version);

  // Import
  final servers = (migrated['servers'] as List)
      .map((j) => Server.fromJson(j))
      .toList();
  ServerStore.servers.value = servers;

  final snippets = (migrated['snippets'] as List)
      .map((j) => Snippet.fromJson(j))
      .toList();
  SnippetStore.snippets.value = snippets;

  _importSettings(migrated['settings']);
}
```

## Performance Optimizations

### Lazy Loading

```dart
class ServerStore {
  static late Box<Server> _box;

  static Future<void> init() async {
    _box = await Hive.openBox<Server>('servers');
  }

  // Lazy load on first access
  static List<Server> get servers {
    return _box.values.toList();
  }
}
```

### Indexing

```dart
// For faster lookups
final serverIndex = ServerStore.servers.value
    .map((s) => s.id)
    .toList();

Server? getServerById(String id) {
  final index = serverIndex.indexOf(id);
  if (index >= 0) {
    return ServerStore.servers.value[index];
  }
  return null;
}
```

### Caching

```dart
class CachedStore {
  static final _cache = <String, dynamic>{};

  static T? get<T>(String key) {
    return _cache[key] as T?;
  }

  static void set<T>(String key, T value) {
    _cache[key] = value;
    // Persist to Hive asynchronously
    _persistLater(key, value);
  }
}
```

## Best Practices

1. **Keep stores simple**: Don't add business logic to stores
2. **Use immutable models**: Prevent accidental mutations
3. **Encrypt sensitive data**: Always encrypt passwords and keys
4. **Handle migrations**: Plan for data format changes
5. **Test persistence**: Verify data survives app restarts
6. **Clean up old data**: Remove unused data periodically
7. **Backup regularly**: Provide export/import functionality
