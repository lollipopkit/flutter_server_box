---
title: Arquitectura
description: Patrones de arquitectura y decisiones de diseño
---

Server Box sigue los principios de Clean Architecture con una clara separación entre las capas de datos, dominio y presentación.

## Arquitectura por Capas

```
┌─────────────────────────────────────┐
│          Capa de Presentación       │
│         (lib/view/page/)            │
│  - Páginas, Widgets, Controladores  │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│      Capa de Lógica de Negocio      │
│      (lib/data/provider/)           │
│  - Riverpod Providers               │
│  - Gestión de Estado                │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│           Capa de Datos             │
│      (lib/data/model/, store/)      │
│  - Modelos, Almacén, Servicios      │
└─────────────────────────────────────┘
```

## Patrones Clave

### Gestión de Estado: Riverpod

- **Generación de Código**: Usa `riverpod_generator` para providers con tipado seguro
- **State Notifiers**: Para estados mutables con lógica de negocio
- **Async Notifiers**: Para estados de carga y error
- **Stream Providers**: Para datos en tiempo real

### Modelos Inmutables: Freezed

- Todos los modelos de datos usan Freezed para inmutabilidad
- Tipos Union para representación de estados
- Serialización JSON integrada
- Extensiones CopyWith para actualizaciones

### Almacenamiento Local: Hive

- **hive_ce**: Edición comunitaria de Hive
- Sigue el patrón existente: la mayoría de los stores usan `hive_ce`, mientras algunos modelos versionados aún declaran explícitamente `@HiveType` y `@HiveField`
- Adaptadores de tipo generados automáticamente
- Almacenamiento persistente clave-valor

## Inyección de Dependencias

Los servicios y almacenes se inyectan a través de:

1. **Providers**: Exponen dependencias a la UI
2. **GetIt**: Localizador de servicios (donde sea aplicable)
3. **Inyección en Constructor**: Dependencias explícitas

## Flujo de Datos

```
Acción de Usuario → Widget → Provider → Servicio/Almacén → Actualización de Modelo → Reconstrucción de UI
```

1. El usuario interactúa con el widget
2. El widget llama al método del provider
3. El provider actualiza el estado a través del servicio/almacén
4. El cambio de estado activa la reconstrucción de la UI
5. El nuevo estado se refleja en el widget

## Análisis de Estado: Biblioteca Rust Compartida

El análisis del estado del servidor (CPU, memoria, disco, red, temperaturas, GPU,
SMART, …) está implementado una sola vez en el crate de Rust `crates/sbm_parser` y
la app lo usa a través de flutter_rust_bridge (`crates/sbm_ffi`, Dart generado en
`lib/src/rust/`). El monitor del lado del servidor usa el mismo crate directamente,
por lo que ambos extremos analizan siempre igual. Los parsers son funciones puras:
devuelven contadores brutos, y los cálculos de diferencia o ventana (p. ej. la
velocidad de red) también son funciones puras — ningún estado mutable cruza la
frontera FFI.

## Dependencias Personalizadas

El proyecto utiliza varias ramas (forks) personalizadas para extender la funcionalidad:

- **dartssh2**: Funciones SSH mejoradas
- **xterm**: Emulador de terminal con soporte móvil
- **fl_lib**: Componentes de UI y utilidades compartidas

## Multihilo

- **Isolates**: Computación pesada fuera del hilo principal
- **paquete computer**: Utilidades para multihilo
- **Async/Await**: Operaciones de E/S no bloqueantes
