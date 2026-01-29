---
title: Estructura del Proyecto
description: Comprendiendo la base de código de Server Box
---

El proyecto Server Box sigue una arquitectura modular con una clara separación de responsabilidades.

## Estructura de Directorios

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
