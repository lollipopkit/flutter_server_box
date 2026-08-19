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
│  - Monitor agent HTTP API                       │
│  - Rust status parser (sbm_parser via FFI)      │
│  - Platform-specific code (iOS, Android, etc.)  │
└─────────────────────────────────────────────────┘
```

## Connection Methods

A server is reached either over SSH or through a monitor agent's HTTP API. The
two are mutually exclusive: a monitor server carries no SSH credential.

What each one can do is asked through `ServerCapabilities`, so a feature that
needs a shell never has to know which transport provides one:

| | SSH | Monitor agent |
|---|---|---|
| Status, charts | yes | yes |
| Stored history | no — sampled while the app is open | yes — the agent has been sampling all along |
| Commands (processes, systemd, containers, power) | yes | with the agent's `full_access` grant |
| Terminal | yes | with `full_access` |
| File browsing | yes, over SFTP | with the agent's file API, confined to its configured roots |
| SFTP transfers, port forwarding | yes | no |

SFTP and port forwarding are absent on a monitor server because the agent has
no endpoint that relays a connection to an address the app names.

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
- **Tabbed Interface**: Server, SSH, File, Snippet
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
- Follow the existing model pattern; some tracked models still use explicit field annotations

**Stores:**
- `SettingStore`: App preferences
- `ServerStore`: Server configurations
- `SnippetStore`: Command snippets
- `PrivateKeyStore`: SSH keys
- `ContainerStore`, `HistoryStore`, `PortForwardStore`, `ConnectionStatsStore`

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
| iOS | Swift Package Manager, Swift/Obj-C |
| Android | Gradle, Kotlin/Java |
| macOS | Swift Package Manager, Swift |
| Linux | CMake, C++ |
| Windows | CMake, C++ |

### Platform-Specific Features

**iOS Only:**
- Live Activities
- Apple Watch companion

**Mobile:**
- Home screen widgets (iOS/Android)
- Push notifications (via ServerBox Monitor)

**Android Only:**
- Background running (foreground service)

**Desktop Only:**
- Native menu bar (macOS)
- Window size persistence

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

Over SSH:

```
1. Timer triggers →
2. Provider calls service →
3. Service executes SSH command script →
4. Raw output parsed by the shared Rust parser (sbm_parser via FFI) →
5. State updated →
6. UI rebuilds with new data
```

Through a monitor agent:

```
1. Timer triggers →
2. Provider calls the agent's /api/v1/metrics →
3. The agent has already parsed it — with the same Rust crate →
4. State updated →
5. UI rebuilds with new data
```

Both ends parse with `sbm_parser`, which is why the two paths produce the same
`ServerStatus`.

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

- **Passwords / SSH Keys**: Stored in AES-encrypted Hive boxes; the encryption
  key itself is kept in the platform secure storage (Keychain/Keystore)
- **Host Fingerprints**: Stored securely
- **Session Data**: Not persisted

### Connection Security

- **Host Key Verification**: MITM detection
- **Encryption**: Standard SSH encryption
- **No Plain Text**: Sensitive data never stored plain
