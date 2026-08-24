---
title: Architecture Overview
description: High-level application architecture
---

Server Box separates presentation, business logic, data access, and external integrations.

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
│  - SQLite Stores, Data Models                   │
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

`ServerCapabilities` describes what each connection can do. Features that need
a shell can use that interface without knowing which transport provides it:

| | SSH | Monitor agent |
|---|---|---|
| Status, charts | yes | yes |
| Stored history | no, sampled while the app is open | yes, the agent has been sampling all along |
| Commands (processes, systemd, containers, power) | yes | with the agent's `full_access` grant |
| Terminal | yes | with `full_access` |
| File browsing | yes, over SFTP | with the agent's file API, confined to its configured roots |
| SFTP transfers, port forwarding | yes | no |

SFTP and port forwarding are not available through a monitor agent because the
agent has no endpoint that relays a connection to an address chosen by the app.

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

`HomePage` is the navigation hub:
- **Tabbed Interface**: Server, SSH, File, Snippet
- **State Management**: Per-tab state
- **Navigation**: Feature access

## Core Systems

### State Management: Riverpod

**Why Riverpod?**
- Compile-time safety
- Easy testing
- No `BuildContext` dependency
- Works across platforms

**Provider Types Used:**
- `NotifierProvider`: Mutable state with methods
- `AsyncNotifierProvider`: Loading/error/data states
- `StreamProvider`: Real-time data streams
- Future providers: One-time async operations

### Data Persistence: SQLite

The app stores data in one encrypted SQLite database, `store.db`. Key-value
storage is used for settings and history; related records use entity tables.

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
- JSON serialization when configured
- `copyWith` methods

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
fl_build (build) → Platform output
```

1. **Build**: derive the build number from the Git history, compile for the
   target platform
2. **Post-build**: Package and sign

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
3. `MonitorMetrics.fromJson` decodes the JSON and `applyMonitorMetrics` maps it to `ServerStatus` →
4. State updated →
5. UI rebuilds with new data
```

The SSH path parses command output through the FFI-backed `sbm_parser`; the
monitor path consumes the agent's JSON contract and maps it locally. They feed
the same `ServerStatus` shape, but they are not the same parser or guaranteed to
have identical field semantics.

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

- **Passwords / SSH Keys**: Stored in the encrypted SQLite database; the
  encryption key itself is kept in platform secure storage (Keychain/Keystore)
- **Host Fingerprints**: Stored securely
- **Session Data**: Not persisted

### Connection Security

- **Host Key Verification**: MITM detection
- **Encryption**: Standard SSH encryption
- **No Plain Text**: Sensitive data is not stored in plain text
