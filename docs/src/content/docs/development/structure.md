---
title: Project Structure
description: Understanding the Flutter Server Box codebase
---

The Flutter Server Box project follows a modular architecture with clear separation of concerns.

## Directory Structure

```
lib/
├── core/              # Core utilities and extensions
├── data/              # Data layer
│   ├── model/         # Data models by feature
│   ├── provider/      # Riverpod providers
│   └── store/         # Local storage (Hive)
├── view/              # UI layer
│   ├── page/          # Main pages
│   └── widget/        # Reusable widgets
├── generated/         # Generated localization
├── l10n/              # Localization ARB files
└── hive/              # Hive adapters
```

## Core Layer (`lib/core/`)

Contains utilities, extensions, and routing configuration:

- **Extensions**: Dart extensions for common types
- **Routes**: App routing configuration
- **Utils**: Shared utility functions

## Data Layer (`lib/data/`)

### Models (`lib/data/model/`)

Organized by feature:

- `server/` - Server connection and status models
- `container/` - Docker container models
- `ssh/` - SSH session models
- `sftp/` - SFTP file models
- `app/` - App-specific models

### Providers (`lib/data/provider/`)

Riverpod providers for dependency injection and state management:

- Server providers
- UI state providers
- Service providers

### Stores (`lib/data/store/`)

Hive-based local storage:

- Server storage
- Settings storage
- Cache storage

## View Layer (`lib/view/`)

### Pages (`lib/view/page/`)

Main application screens:

- `server/` - Server management pages
- `ssh/` - SSH terminal pages
- `container/` - Container pages
- `setting/` - Settings pages
- `storage/` - SFTP pages
- `snippet/` - Snippet pages

### Widgets (`lib/view/widget/`)

Reusable UI components:

- Server cards
- Status charts
- Input components
- Dialogs

## Generated Files

- `lib/generated/l10n/` - Auto-generated localization
- `*.g.dart` - Generated code (json_serializable, freezed, hive, riverpod)
- `*.freezed.dart` - Freezed immutable classes

## Packages Directory (`/packages/`)

Contains custom forks of dependencies:

- `dartssh2/` - SSH library
- `xterm/` - Terminal emulator
- `fl_lib/` - Shared utilities
- `fl_build/` - Build system
