---
title: Arquitectura
description: Patrones de arquitectura y decisiones de diseño
---

Flutter Server Box sigue los principios de Clean Architecture con una clara separación entre las capas de datos, dominio y presentación.

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
- No se requiere `@HiveField` o `@HiveType` manual
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

## Dependencias Personalizadas

El proyecto utiliza varias ramas (forks) personalizadas para extender la funcionalidad:

- **dartssh2**: Funciones SSH mejoradas
- **xterm**: Emulador de terminal con soporte móvil
- **fl_lib**: Componentes de UI y utilidades compartidas

## Multihilo

- **Isolates**: Computación pesada fuera del hilo principal
- **paquete computer**: Utilidades para multihilo
- **Async/Await**: Operaciones de E/S no bloqueantes
