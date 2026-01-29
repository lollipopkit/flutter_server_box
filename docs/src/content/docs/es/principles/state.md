---
title: Gestión de Estado
description: Cómo se gestiona el estado con Riverpod
---

Entendiendo la arquitectura de gestión de estado en Flutter Server Box.

## ¿Por qué Riverpod?

**Beneficios Clave:**
- **Seguridad en tiempo de compilación**: Detecta errores al compilar
- **Sin necesidad de BuildContext**: Accede al estado desde cualquier lugar
- **Facilidad de pruebas**: Sencillo de probar providers de forma aislada
- **Generación de código**: Menos código repetitivo, tipado seguro

## Arquitectura de Providers

```
┌─────────────────────────────────────────────┐
│          Capa UI (Widgets)                  │
│  - ConsumerWidget / ConsumerStatefulWidget  │
│  - ref.watch() / ref.read()                 │
└─────────────────────────────────────────────┘
                ↓ observa (watches)
┌─────────────────────────────────────────────┐
│          Capa de Provider                   │
│  - Anotaciones @riverpod                    │
│  - Archivos *.g.dart generados              │
└─────────────────────────────────────────────┘
                ↓ usa (uses)
┌─────────────────────────────────────────────┐
│          Capa de Servicio / Store           │
│  - Lógica de negocio                        │
│  - Acceso a datos                           │
└─────────────────────────────────────────────┘
```

## Tipos de Provider Utilizados

### 1. StateProvider (Estado Simple)

Para estados simples y observables:

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeMode build() {
    // Cargar desde ajustes
    return SettingStore.themeMode;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SettingStore.themeMode = mode;  // Persistir
  }
}
```

**Uso:**
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    return Text('Tema: $theme');
  }
}
```

### 2. AsyncNotifierProvider (Estado Asíncrono)

Para datos que se cargan de forma asíncrona:

```dart
@riverpod
class ServerStatus extends _$ServerStatus {
  @override
  Future<StatusModel> build(Server server) async {
    // Carga inicial
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

**Uso:**
```dart
final status = ref.watch(serverStatusProvider(server));

status.when(
  data: (data) => StatusWidget(data),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 3. StreamProvider (Datos en Tiempo Real)

Para flujos de datos continuos:

```dart
@riverpod
Stream<CpuUsage> cpuUsage(CpuUsageRef ref, Server server) {
  final client = ref.watch(sshClientProvider(server));
  final stream = client.monitorCpu();

  // Liberación automática cuando no se observa
  ref.onDispose(() {
    client.stopMonitoring();
  });

  return stream;
}
```

**Uso:**
```dart
final cpu = ref.watch(cpuUsageProvider(server));

cpu.when(
  data: (usage) => CpuChart(usage),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 4. Family Providers (Parametrizados)

Providers que aceptan parámetros:

```dart
@riverpod
Future<List<Container>> containers(ContainersRef ref, Server server) async {
  final client = await ref.watch(sshClientProvider(server).future);
  return await client.listContainers();
}
```

**Uso:**
```dart
final containers = ref.watch(containersProvider(server));

// Diferentes servidores = diferentes estados en caché
final containers2 = ref.watch(containersProvider(server2));
```

## Optimizaciones de Rendimiento

- **Provider Keep-Alive**: Usa `@Riverpod(keepAlive: true)` para evitar que se destruya automáticamente cuando no haya escuchadores.
- **Observación selectiva**: Usa `select` para observar solo una parte específica del estado.
- **Caché de Providers**: Los Family providers cachean resultados por parámetro.

## Mejores Prácticas

1. **Co-localizar providers**: Colócalos cerca de los widgets que los consumen.
2. **Usar generación de código**: Usa siempre `@riverpod`.
3. **Mantener providers enfocados**: Responsabilidad única.
4. **Gestionar estados de carga**: Maneja siempre los estados de AsyncValue.
5. **Liberar recursos**: Usa `ref.onDispose()` para la limpieza.
6. **Evitar árboles de providers profundos**: Mantén el grafo de providers plano.
