# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development

- `flutter run` - Run the app in development mode
- `dart run fl_build -p PLATFORM` - Build the app for specific platform (see fl_build package)
- `dart run build_runner build --delete-conflicting-outputs` - Generate code for models with annotations (json_serializable, freezed, hive, riverpod)
  - Every time you change model files, run this command to regenerate code (Hive adapters, Riverpod providers, etc.)
  - Generated files include: `*.g.dart`, `*.freezed.dart` files

### Testing

- `flutter test` - Run unit tests
- `flutter test test/battery_test.dart` - Run specific test file

## Architecture

This is a Flutter application for managing Linux servers with the following key architectural components:

### Project Structure

- `lib/core/` - Core utilities, extensions, and routing
- `lib/data/` - Data layer with models, providers, and storage
  - `model/` - Data models organized by feature (server, container, ssh, etc.)
  - `provider/` - Riverpod providers for state management
  - `store/` - Local storage implementations using Hive
- `lib/view/` - UI layer with pages and widgets
- `lib/generated/` - Generated localization files
- `lib/hive/` - Hive adapters for local storage

### Key Technologies

- **State Management**: Riverpod with code generation (riverpod_annotation)
- **Local Storage**: Hive for persistent data with generated adapters
- **SSH/SFTP**: Custom dartssh2 fork for server connections
- **Terminal**: Custom xterm.dart fork for SSH terminal interface
- **Networking**: dio for HTTP requests
- **Charts**: fl_chart for server status visualization
- **Localization**: Flutter's built-in i18n with ARB files
- **Code Generation**: Uses build_runner with json_serializable, freezed, hive_generator, riverpod_generator

### Data Models

- Server management models in `lib/data/model/server/`
- Container/Docker models in `lib/data/model/container/`
- SSH and SFTP models in respective directories
- Most models use freezed for immutability and json_annotation for serialization

### Features

- Server status monitoring (CPU, memory, disk, network)
- SSH terminal with virtual keyboard
- SFTP file browser
- Docker container management
- Process and systemd service management
- Server snippets and custom commands
- Multi-language support (12+ languages)
- Cross-platform support (iOS, Android, macOS, Linux, Windows)

### State Management Pattern

- Uses Riverpod providers for dependency injection and state management
- Uses Freezed for immutable state models
- Providers are organized by feature in `lib/data/provider/`
- State is often persisted using Hive stores in `lib/data/store/`

### Build System

- Uses custom `fl_build` package for cross-platform building
- `make.dart` script handles pre/post build tasks (metadata generation)
- Supports building for multiple platforms with platform-specific configurations
- Many dependencies are custom forks hosted on GitHub (dartssh2, xterm, fl_lib, etc.)

### Important Notes

- **Never run code formatting commands** - The codebase has specific formatting that should not be changed
- **Always run code generation** after modifying models with annotations (freezed, json_serializable, hive, riverpod)
- Generated files (`*.g.dart`, `*.freezed.dart`) should not be manually edited
- AGAIN, NEVER run code formatting commands.
- USE dependency injection via GetIt for services like Stores, Services and etc.
- Generate all l10n files using `flutter gen-l10n` command after modifying ARB files.
- USE `hive_ce` not `hive` package for Hive integration.
  - Which no need to config `HiveField` and `HiveType` manually.
- USE widgets and utilities from `fl_lib` package for common functionalities.
  - Such as `CustomAppBar`, `context.showRoundDialog`, `Input`, `Btnx.cancelOk`, etc.
  - You can use context7 MCP to search `lppcg fl_lib KEYWORD` to find relevant widgets and utilities.
- USE `libL10n` and `l10n` for localization strings.
  - `libL10n` is from `fl_lib` package, and `l10n` is from this project.
  - Before adding new strings, check if it already exists in `libL10n`.
  - Prioritize using strings from `libL10n` to avoid duplication, even if the meaning is not 100% exact, just use the substitution of `libL10n`.
- Split UI into Widget build, Actions, Utils. use `extension on` to achieve this
