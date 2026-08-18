---
title: Estructura del Proyecto
description: Comprendiendo la base de código de Server Box
---

El proyecto Server Box sigue una arquitectura modular con una clara separación de responsabilidades.

## Disposición del Monorepo

```
flutter_server_box/
├── lib/               # Aplicación Flutter (ver abajo)
├── crates/
│   ├── sbm_parser/    # Parser de estado compartido (única fuente de verdad,
│   │                  # la app vía FFI, el monitor como dependencia directa)
│   ├── sbm_ffi/       # Crate de enlace flutter_rust_bridge + capa de
│   │                  # plugin Flutter cargokit (mismo directorio)
│   └── sbm_native/    # Muestreo nativo por plataforma (solo monitor)
├── monitor/           # Monitor del lado del servidor (servicio Rust + frontend Svelte)
├── packages/          # Forks de Dart vendorizados (dependencias por ruta), más
│                      # webui: UI Svelte compartida por monitor y website
├── docs/              # Este sitio de documentación (Astro Starlight)
├── website/           # Sitio web del proyecto
└── Cargo.toml         # Raíz del workspace de Rust
```

## Estructura de Directorios de la App

```
lib/
├── core/              # Utilidades centrales y extensiones
├── data/              # Capa de datos
│   ├── model/         # Modelos de datos por función
│   ├── provider/      # Riverpod providers
│   └── store/         # Almacenamiento local (Hive)
├── view/              # Capa de UI
│   ├── page/          # Páginas principales
│   └── widget/        # Widgets reutilizables
├── generated/         # Localización generada
├── l10n/              # Archivos ARB de localización
└── hive/              # Adaptadores de Hive
```

## Capa Central (`lib/core/`)

Contiene utilidades, extensiones y configuración de rutas:

- **Extensions**: Extensiones de Dart para tipos comunes
- **Routes**: Configuración de rutas de la app
- **Utils**: Funciones de utilidad compartidas

## Capa de Datos (`lib/data/`)

### Modelos (`lib/data/model/`)

Organizados por función:

- `server/` - Modelos de conexión y estado del servidor
- `container/` - Modelos de contenedores Docker
- `ssh/` - Modelos de sesión SSH
- `sftp/` - Modelos de archivos SFTP
- `app/` - Modelos específicos de la app

### Providers (`lib/data/provider/`)

Providers de Riverpod para inyección de dependencias y gestión de estado:

- Providers de servidor
- Providers de estado de UI
- Providers de servicios

### Almacenes (`lib/data/store/`)

Almacenamiento local basado en Hive:

- Almacén de servidores
- Almacén de ajustes
- Almacén de caché

## Capa de Vista (`lib/view/`)

### Páginas (`lib/view/page/`)

Pantallas principales de la aplicación:

- `server/` - Páginas de gestión de servidores
- `ssh/` - Páginas de terminal SSH
- `container/` - Páginas de contenedores
- `setting/` - Páginas de ajustes
- `storage/` - Páginas de SFTP
- `snippet/` - Páginas de fragmentos (snippets)

### Widgets (`lib/view/widget/`)

Componentes de UI reutilizables:

- Tarjetas de servidor
- Gráficos de estado
- Componentes de entrada
- Diálogos

## Archivos Generados

- `lib/generated/l10n/` - Localización auto-generada
- `*.g.dart` - Código generado (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Clases inmutables de Freezed

## Directorio de Paquetes (`/packages/`)

Contiene ramas (forks) personalizadas de las dependencias:

- `dartssh2/` - Librería SSH
- `xterm/` - Emulador de terminal
- `fl_lib/` - Utilidades compartidas
- `fl_build/` - Sistema de compilación

Un directorio de aquí no es un fork de Dart: `webui/` (`@serverbox/webui`) es un
paquete Svelte con primitivas de interfaz y design tokens compartidos, usado como
dependencia `file:` tanto por `monitor/frontend` como por `website/`.

## Lado Rust

- `crates/sbm_parser/` - Analiza la salida bruta de comandos en estado de servidor estructurado.
  Compartido por la app (vía FFI) y el monitor, por lo que ambos analizan siempre igual.
- `crates/sbm_ffi/` - Fina envoltura flutter_rust_bridge sobre `sbm_parser`.
  El lado Dart generado está en `lib/src/rust/`.
- `crates/sbm_native/` - Muestreo nativo por plataforma, usado solo por el
  monitor. Lee cpu/memoria/swap/disco/red/uptime directamente mediante llamadas
  al sistema o procfs, sin ejecutar comandos de shell. La app no depende de él:
  recopila por SSH y no puede ejecutar llamadas al sistema en un host remoto.
- `monitor/` - Servicio de monitorización independiente, documentación en `monitor/README.md`.
