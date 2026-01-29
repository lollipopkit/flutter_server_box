---
title: Architecture Overview
description: High-level application architecture
---

Server Box follows a layered architecture with clear separation of concerns.

## Architecture Layers

```
┌─────────────────────────────────────────────────┐
│          Presentation Layer (UI)                │
│          lib/view/page/, lib/view/widget/       │
│  - Pages, Widgets, Controllers                   │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Business Logic Layer                    │
│         lib/data/provider/                      │
│  - Riverpod Providers, State Notifiers          │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│           Data Access Layer                     │
│         lib/data/store/, lib/data/model/        │
│  - Hive Stores, Data Models                     │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         External Integration Layer              │
│  - SSH (dartssh2), Terminal (xterm), SFTP       │
│  - Platform-specific code (iOS, Android, etc.)  │
└─────────────────────────────────────────────────┘
```

## Application Foundation

### Main Entry Point

`lib/main.dart` initializes the app:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Root Widget

`MyApp` provides:
- **Theme Management**: Light/dark theme switching
- **Routing Configuration**: Navigation structure
- **Provider Scope**: Dependency injection root

### Home Page

`HomePage` serves as navigation hub:
- **Tabbed Interface**: Server, Snippet, Container, SSH
- **State Management**: Per-tab state
- **Navigation**: Feature access

## Core Systems

### State Management: Riverpod

**Why Riverpod?**
- Compile-time safety
- Easy testing
- No Build context dependency
- Works across platforms

**Provider Types Used:**
- `StateProvider`: Simple mutable state
- `AsyncNotifierProvider`: Loading/error/data states
- `StreamProvider`: Real-time data streams
- Future providers: One-time async operations

### Data Persistence: Hive CE

**Why Hive CE?**
- No native code dependencies
- Fast key-value storage
- Type-safe with code generation
- No manual field annotations needed

**Stores:**
- `SettingStore`: App preferences
- `ServerStore`: Server configurations
- `SnippetStore`: Command snippets
- `KeyStore`: SSH keys

### Immutable Models: Freezed

**Benefits:**
- Compile-time immutability
- Union types for state
- Built-in JSON serialization
- CopyWith extensions

## Cross-Platform Strategy

### Plugin System

Flutter plugins provide platform integration:

| Platform | Integration Method |
|----------|-------------------|
| iOS | CocoaPods, Swift/Obj-C |
| Android | Gradle, Kotlin/Java |
| macOS | CocoaPods, Swift |
| Linux | CMake, C++ |
| Windows | CMake, C# |

### Platform-Specific Features

**iOS Only:**
- Home screen widgets
- Live Activities
- Apple Watch companion

**Android Only:**
- Background service
- Push notifications
- File system access

**Desktop Only:**
- Menu bar integration
- Multiple windows
- Custom title bar

## Custom Dependencies

### dartssh2 Fork

Enhanced SSH client with:
- Better mobile support
- Enhanced error handling
- Performance optimizations

### xterm.dart Fork

Terminal emulator with:
- Mobile-optimized rendering
- Touch gesture support
- Virtual keyboard integration

### fl_lib

Shared utilities package with:
- Common widgets
- Extensions
- Helper functions

## Build System

### fl_build Package

Custom build system for:
- Multi-platform builds
- Code signing
- Asset bundling
- Version management

### Build Process

```
make.dart (version) → fl_build (build) → Platform output
```

1. **Pre-build**: Calculate version from Git
2. **Build**: Compile for target platform
3. **Post-build**: Package and sign

## Data Flow Example

### Server Status Update

```
1. Timer triggers →
2. Provider calls service →
3. Service executes SSH command →
4. Response parsed to model →
5. State updated →
6. UI rebuilds with new data
```

### User Action Flow

```
1. User taps button →
2. Widget calls provider method →
3. Provider updates state →
4. State change triggers rebuild →
5. New state reflected in UI
```

## Security Architecture

### Data Protection

- **Passwords**: Encrypted with flutter_secure_storage
- **SSH Keys**: Encrypted at rest
- **Host Fingerprints**: Stored securely
- **Session Data**: Not persisted

### Connection Security

- **Host Key Verification**: MITM detection
- **Encryption**: Standard SSH encryption
- **No Plain Text**: Sensitive data never stored plain
