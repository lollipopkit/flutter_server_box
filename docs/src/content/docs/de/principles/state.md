---
title: Zustandsverwaltung
description: Wie der Zustand mit Riverpod verwaltet wird
---

Verständnis der Architektur zur Zustandsverwaltung in Flutter Server Box.

## Warum Riverpod?

**Hauptvorteile:**
- **Sicherheit zur Kompilierzeit**: Fehler werden bereits beim Kompilieren abgefangen
- **Kein BuildContext erforderlich**: Zugriff auf den Zustand von überall aus
- **Einfache Testbarkeit**: Provider können leicht isoliert getestet werden
- **Codegenerierung**: Weniger Boilerplate, typsicher

## Provider-Architektur

```
┌─────────────────────────────────────────────┐
│         UI-Schicht (Widgets)                │
│  - ConsumerWidget / ConsumerStatefulWidget  │
│  - ref.watch() / ref.read()                 │
└─────────────────────────────────────────────┘
                ↓ beobachtet (watches)
┌─────────────────────────────────────────────┐
│         Provider-Schicht                    │
│  - @riverpod Annotationen                   │
│  - Generierte *.g.dart Dateien              │
└─────────────────────────────────────────────┘
                ↓ nutzt (uses)
┌─────────────────────────────────────────────┐
│         Service- / Store-Schicht            │
│  - Business-Logik                           │
│  - Datenzugriff                             │
└─────────────────────────────────────────────┘
```

## Verwendete Provider-Typen

### 1. StateProvider (Einfacher Zustand)

Für einfachen, beobachtbaren Zustand:

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    // Aus Einstellungen laden
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;  // Persistieren
  }
}
```

**Verwendung:**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('Theme: $theme');
  }
}
```

### 2. AsyncNotifierProvider (Asynchroner Zustand)

Für Daten, die asynchron geladen werden:

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    // Initiales Laden
    return await fetchStatus(server);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await fetchStatus(server);
    });
  }
}
```

**Verwendung:**
```dart
final status = ref.watch(serverStatusProvider(server));

status.when(
  data: (data) => StatusWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 3. StreamProvider (Echtzeit-Daten)

Für kontinuierliche Datenströme:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  // Ressourcen freigeben, wenn nicht mehr beobachtet
  ref.onDispose(() {
    client.stopMonitoring();
  });

  return stream;
}
```

**Verwendung:**
```dart
final cpu = ref.watch(cpuUsageProvider(server));

cpu.when(
  data: (usage) => CpuChart(usage),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 4. Family Provider (Parametrisiert)

Provider, die Parameter akzeptieren:

```dart
@riverpod
Future<List<Container>> containers(ContainersRef ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return await client.listContainers();
}
```

**Verwendung:**
```dart
final containers = ref.watch(containersProvider(server));

// Verschiedene Server = verschiedene gecachte Zustände
final containers2 = ref.watch(containersProvider(server2));
```

## Muster für Zustandsaktualisierungen

### Direkte Zustandsaktualisierung

```dart
ref.read(settingsProvider.notifier).updateTheme(darkMode);
```

### Berechneter Zustand (Computed State)

```dart
@riverpod
int totalServers(TotalServersRef ref) {
  final servers = ref.watch(serversProvider);
  return servers.length;
}
```

### Abgeleiteter Zustand (Derived State)

```dart
@riverpod
List<Server> onlineServers(OnlineServersRef ref) {
  final all = ref.watch(serversProvider);
  return all.where((s) => s.isOnline).toList();
}
```

## Server-spezifischer Zustand

### Pro-Server Provider

Jeder Server hat einen isolierten Zustand:

```dart
@riverpod
class ServerProvider extends _$ServerProvider {
  @override
  ServerState build(Server server) {
    return ServerState.disconnected();
  }

  Future<void> connect() async {
    state = ServerState.connecting();
    try {
      final client = await genClient(server.spi);
      state = ServerState.connected(client);
    } catch (e) {
      state = ServerState.error(e.toString());
    }
  }
}
```

## Leistungsoptimierungen

- **Provider Keep-Alive**: `@Riverpod(keepAlive: true)` verwenden, um automatische Entsorgung ohne Listener zu verhindern.
- **Selektives Beobachten**: `select` verwenden, um nur bestimmte Teile des Zustands zu beobachten.
- **Provider Caching**: Family Provider cachen Ergebnisse pro Parameter.

## Best Practices

1. **Provider lokal platzieren**: In der Nähe der Widgets, die sie nutzen.
2. **Codegenerierung nutzen**: Immer `@riverpod` verwenden.
3. **Provider fokussiert halten**: Jedes Provider sollte nur eine Aufgabe haben.
4. **Ladezustände behandeln**: AsyncValue-Zustände immer vollständig behandeln.
5. **Ressourcen entsorgen**: `ref.onDispose()` für Aufräumarbeiten nutzen.
6. **Tiefe Provider-Bäume vermeiden**: Den Provider-Graphen flach halten.
