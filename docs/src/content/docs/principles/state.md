---
title: State Model
description: How runtime state, server state, and persisted data fit together
---

Server Box uses Riverpod for page state, asynchronous data, and service dependencies. This page describes what state the app holds and where it lives. Declaring a provider and its lifecycle are in [Riverpod patterns](/docs/development/state/).

## Why Riverpod?

- **Compile-time type checking**: many errors are caught while compiling.
- **No `BuildContext` dependency**: services and business logic reach providers outside Widgets.
- **Provider isolation**: providers can be tested independently.
- **Code generation**: generated providers reduce boilerplate while preserving static typing.

## State layers

```text
┌─────────────────────────────────────────────┐
│ UI layer (Widget)                           │
│ ConsumerWidget / ConsumerStatefulWidget     │
│ ref.watch() / ref.read()                    │
└─────────────────────────────────────────────┘
                    ↓ subscribe or call
┌─────────────────────────────────────────────┐
│ Provider layer                              │
│ @riverpod and generated *.g.dart            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Service / Store layer                       │
│ Business logic and data access              │
└─────────────────────────────────────────────┘
```

Widgets use `ref.watch` to subscribe to state and `ref.read(...notifier)` to invoke operations. Providers coordinate services and stores; Widgets focus on presentation and interaction.

## Server-specific state

The per-server provider is `serverProvider(serverId)`. Each instance contains the server configuration, connection state, the SSH client, the current status, and Monitor agent access information. `ServerNotifier` owns connection, collection, and error handling, so pages read its state rather than managing a connection lifecycle of their own.

```dart
final serverState = ref.watch(serverProvider(serverId));

await ref.read(serverProvider(serverId).notifier).refresh();
```

## Reacting to time

Three schedules drive the app, all of them resolved per server through `Spix.transport`:

- **Status polling** is a timer owned by the notifier, cancelled from `ref.onDispose`.
- **Monitor HTTP history** is asked for on demand when a chart range is chosen; SSH has no stored history, so the app's own rolling buffer is all there is.
- **Work that outlives the frame** is moved off it: a benchmark run is started detached on the server and polled, and a file transfer runs on its own isolate, because either can last longer than the app stays in the foreground.

## State persistence

The authoritative local store is the encrypted SQLite database `store.db`:

- Settings and history use `SqliteStore`.
- Servers, private keys, snippets, and other related records use entity stores.
- Hive adapters only import data from old installations; Hive is not the current runtime backend.

```dart
final servers = Stores.server.readAll();
Stores.server.put(server);
Stores.server.deleteById(server.id);
```

Providers manage runtime state. Data that must survive a restart belongs in a store, not only in a provider cache.
